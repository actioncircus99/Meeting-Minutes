import SwiftUI
import SwiftData
import UserNotifications
import Combine
import UniformTypeIdentifiers

// MARK: - ViewModel

@MainActor
final class RecordingViewModel: ObservableObject {
    @Published var phase: Phase = .idle
    @Published var meetingTitle = ""
    @Published var showStopConfirm = false
    @Published var errorMessage: String?

    private var startedAt: Date = .now
    @Published private(set) var failedRecord: MeetingRecord?  // 分析失敗時保留，供重試用

    enum Phase: Equatable {
        case idle
        case recording
        case transcribing   // 語音轉文字中
        case summarizing    // 產生摘要中
        case complete(MeetingRecord)
        case failed(String)

        static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.recording, .recording),
                 (.transcribing, .transcribing), (.summarizing, .summarizing): return true
            default: return false
            }
        }
    }

    // MARK: - Recording control

    func startRecording() async {
        let recorder = AudioRecordingManager.shared
        let url = await recorder.startRecording()
        if url != nil {
            startedAt = .now
            phase = .recording
        } else {
            errorMessage = recorder.error ?? "無法開始錄音，請確認已開啟麥克風權限"
        }
    }

    func requestStop() {
        showStopConfirm = true
    }

    func processUploadedFile(url: URL, modelContext: ModelContext) async {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let ext = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
        let audioURL = docsDir.appendingPathComponent(UUID().uuidString + "." + ext)

        do {
            try FileManager.default.copyItem(at: url, to: audioURL)
        } catch {
            phase = .failed("無法讀取音檔：\(error.localizedDescription)")
            return
        }

        let title = meetingTitle.isEmpty ? nil : meetingTitle
        let record = MeetingRecord(title: title, startedAt: .now)
        record.audioFilePath = audioURL.path
        modelContext.insert(record)
        try? modelContext.save()

        phase = .transcribing
        let transcript: String
        do {
            transcript = try await AIService.shared.transcribe(audioURL: audioURL)
        } catch {
            record.status = .failed
            record.errorMessage = error.localizedDescription
            try? modelContext.save()
            failedRecord = record
            phase = .failed(error.localizedDescription)
            return
        }

        record.transcript = transcript
        try? modelContext.save()

        phase = .summarizing
        do {
            let summary = try await AIService.shared.summarize(transcript: transcript)
            if record.title == nil { record.title = summary.title }
            record.summaryPoints = summary.points
            record.topics = summary.topics
            record.nextSteps = summary.nextSteps
            record.status = .complete
            try? modelContext.save()
            sendNotification(meetingTitle: record.title ?? "本次會議")
            phase = .complete(record)
        } catch {
            record.status = .failed
            record.errorMessage = error.localizedDescription
            try? modelContext.save()
            failedRecord = record
            phase = .failed(error.localizedDescription)
        }
    }

    func stopAndProcess(modelContext: ModelContext) async {
        showStopConfirm = false

        guard let tempURL = AudioRecordingManager.shared.stopRecording() else {
            phase = .failed("無法取得錄音檔案")
            return
        }

        // 將音檔從暫存移到 Documents（永久保留，供失敗重試用）
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = docsDir.appendingPathComponent(UUID().uuidString + ".m4a")
        do {
            try FileManager.default.moveItem(at: tempURL, to: audioURL)
        } catch {
            phase = .failed("無法儲存錄音檔案")
            return
        }

        let durationSec = AudioRecordingManager.shared.elapsedSeconds
        let title = meetingTitle.isEmpty ? nil : meetingTitle

        // 先建立記錄存入 SwiftData，並記錄音檔路徑
        let record = MeetingRecord(title: title, startedAt: startedAt)
        record.endedAt = .now
        record.durationSeconds = durationSec
        record.audioFilePath = audioURL.path
        modelContext.insert(record)
        try? modelContext.save()

        // 1. 語音轉文字
        phase = .transcribing
        let transcript: String
        do {
            transcript = try await AIService.shared.transcribe(audioURL: audioURL)
        } catch {
            record.status = .failed
            record.errorMessage = error.localizedDescription
            try? modelContext.save()
            failedRecord = record
            phase = .failed(error.localizedDescription)
            return
        }

        record.transcript = transcript
        try? modelContext.save()

        // 2. 產生摘要
        phase = .summarizing
        do {
            let summary = try await AIService.shared.summarize(transcript: transcript)
            if record.title == nil { record.title = summary.title }
            record.summaryPoints = summary.points
            record.topics = summary.topics
            record.nextSteps = summary.nextSteps
            record.status = .complete
            try? modelContext.save()

            sendNotification(meetingTitle: record.title ?? "本次會議")
            phase = .complete(record)
        } catch {
            record.status = .failed
            record.errorMessage = error.localizedDescription
            try? modelContext.save()
            failedRecord = record
            phase = .failed(error.localizedDescription)
        }
    }

    func retryFailed(modelContext: ModelContext) async {
        guard let record = failedRecord else { return }
        record.status = .processing
        record.errorMessage = nil
        try? modelContext.save()

        let transcript: String

        if let existing = record.transcript, !existing.isEmpty {
            transcript = existing
        } else if let path = record.audioFilePath,
                  FileManager.default.fileExists(atPath: path) {
            phase = .transcribing
            do {
                transcript = try await AIService.shared.transcribe(audioURL: URL(fileURLWithPath: path))
                record.transcript = transcript
                try? modelContext.save()
            } catch {
                record.status = .failed
                record.errorMessage = error.localizedDescription
                try? modelContext.save()
                phase = .failed(error.localizedDescription)
                return
            }
        } else {
            record.status = .failed
            record.errorMessage = "音檔已不存在，請重新錄製"
            try? modelContext.save()
            phase = .failed("音檔已不存在，請重新錄製")
            return
        }

        phase = .summarizing
        do {
            let summary = try await AIService.shared.summarize(transcript: transcript)
            if record.title == nil { record.title = summary.title }
            record.summaryPoints = summary.points
            record.topics = summary.topics
            record.nextSteps = summary.nextSteps
            record.status = .complete
            try? modelContext.save()
            sendNotification(meetingTitle: record.title ?? "本次會議")
            phase = .complete(record)
        } catch {
            record.status = .failed
            record.errorMessage = error.localizedDescription
            try? modelContext.save()
            phase = .failed(error.localizedDescription)
        }
    }

    private func sendNotification(meetingTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = "會議記錄完成 ✓"
        content.body = "「\(meetingTitle)」的摘要已產生，點此查看。"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        )
    }
}

// MARK: - View

struct RecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = RecordingViewModel()
    @ObservedObject private var recorder = AudioRecordingManager.shared
    @State private var showingFileImporter = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                phaseContent
                Spacer()
            }
            .padding(.horizontal, 28)
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if vm.phase == .recording { EmptyView() }
                    else { Button("關閉") { dismiss() } }
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.audio, .mpeg4Audio, .mp3, .wav, .aiff],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task { await vm.processUploadedFile(url: url, modelContext: modelContext) }
                    }
                case .failure:
                    break
                }
            }
            .confirmationDialog(
                "確定要停止錄音嗎？",
                isPresented: $vm.showStopConfirm,
                titleVisibility: .visible
            ) {
                Button("停止並產生摘要", role: .destructive) {
                    Task { await vm.stopAndProcess(modelContext: modelContext) }
                }
                Button("繼續錄音", role: .cancel) {}
            } message: {
                Text("停止後 App 會自動分析，完成後發送通知給你。")
            }
        }
    }

    private var navTitle: String {
        switch vm.phase {
        case .idle:         return "新會議"
        case .recording:    return "錄音中"
        case .transcribing: return "語音轉文字中"
        case .summarizing:  return "產生摘要中"
        case .complete:     return "完成"
        case .failed:       return "發生錯誤"
        }
    }

    // MARK: - Phase switch

    @ViewBuilder
    private var phaseContent: some View {
        switch vm.phase {
        case .idle:
            idleView
        case .recording:
            recordingView
        case .transcribing:
            processingView(
                icon: "waveform", color: .blue,
                title: "語音轉文字中...",
                subtitle: "正在將錄音轉換成逐字稿"
            )
        case .summarizing:
            processingView(
                icon: "sparkles", color: .purple,
                title: "產生摘要中...",
                subtitle: "AI 正在分析會議重點，完成後會發送通知"
            )
        case .complete(let record):
            completeView(record: record)
        case .failed(let msg):
            failedView(message: msg)
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 28) {
            Image(systemName: "mic.circle")
                .font(.system(size: 90))
                .foregroundStyle(.red.opacity(0.8))

            VStack(alignment: .leading, spacing: 8) {
                Text("會議名稱（選填）")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField("例如：產品週會、Q2 預算討論", text: $vm.meetingTitle)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text("不填的話，AI 會根據內容自動命名")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Button {
                Task { await vm.startRecording() }
            } label: {
                Label("開始錄音", systemImage: "mic.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Button {
                showingFileImporter = true
            } label: {
                Label("上傳錄音檔", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if let err = vm.errorMessage {
                Text(err).foregroundStyle(.red).font(.callout).multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Recording

    private var recordingView: some View {
        VStack(spacing: 28) {
            ZStack {
                ForEach([0, 1, 2], id: \.self) { i in
                    Circle()
                        .fill(.red.opacity(0.06 - Double(i) * 0.015))
                        .frame(width: 130 + CGFloat(i) * 25, height: 130 + CGFloat(i) * 25)
                        .scaleEffect(1 + CGFloat(recorder.audioLevel) * 0.25)
                        .animation(.easeOut(duration: 0.08), value: recorder.audioLevel)
                }
                Circle().fill(.red).frame(width: 120, height: 120)
                Image(systemName: "mic.fill")
                    .font(.system(size: 46)).foregroundStyle(.white)
            }
            .frame(width: 220, height: 220)

            Text(recorder.elapsedSeconds.formattedDuration)
                .font(.system(size: 54, weight: .thin, design: .monospaced))

            if !vm.meetingTitle.isEmpty {
                Text(vm.meetingTitle)
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Circle().fill(.red).frame(width: 8, height: 8)
                    .opacity(recorder.elapsedSeconds % 2 == 0 ? 1 : 0.2)
                Text("REC").font(.caption.bold()).foregroundStyle(.red)
            }

            Button { vm.requestStop() } label: {
                Label("停止錄音", systemImage: "stop.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Processing

    private func processingView(icon: String, color: Color, title: String, subtitle: String) -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().fill(color.opacity(0.1)).frame(width: 110, height: 110)
                Image(systemName: icon).font(.system(size: 48)).foregroundStyle(color)
            }
            ProgressView().scaleEffect(1.3)
            VStack(spacing: 8) {
                Text(title).font(.title3.weight(.medium))
                Text(subtitle).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Complete

    private func completeView(record: MeetingRecord) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(.green.opacity(0.1)).frame(width: 110, height: 110)
                Image(systemName: "checkmark.circle.fill").font(.system(size: 68)).foregroundStyle(.green)
            }
            VStack(spacing: 8) {
                Text("完成！").font(.title.bold())
                Text(record.title ?? "會議摘要已產生")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            Button("回到列表") { dismiss() }
                .buttonStyle(.borderedProminent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Failed

    private func failedView(message: String) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(.red.opacity(0.1)).frame(width: 110, height: 110)
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 54)).foregroundStyle(.red)
            }
            VStack(spacing: 8) {
                Text("分析失敗").font(.title.bold())
                Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }

            if vm.failedRecord != nil {
                Text("錄音已保存，修正問題後可直接重新分析")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)

                Button {
                    Task { await vm.retryFailed(modelContext: modelContext) }
                } label: {
                    Label("重新分析", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button("關閉") { dismiss() }
                .buttonStyle(.bordered)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
