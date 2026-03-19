import SwiftUI
import SwiftData
import UserNotifications

// MARK: - ViewModel

@MainActor
final class RecordingViewModel: ObservableObject {
    @Published var phase: Phase = .idle
    @Published var meetingTitle = ""
    @Published var showStopConfirm = false
    @Published var errorMessage: String?

    private var startedAt: Date = .now

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

    func stopAndProcess(modelContext: ModelContext) async {
        showStopConfirm = false

        guard let audioURL = AudioRecordingManager.shared.stopRecording() else {
            phase = .failed("無法取得錄音檔案")
            return
        }

        let durationSec = AudioRecordingManager.shared.elapsedSeconds
        let title = meetingTitle.isEmpty ? nil : meetingTitle

        // 先建立記錄存入 SwiftData
        let record = MeetingRecord(title: title, startedAt: startedAt)
        record.endedAt = .now
        record.durationSeconds = durationSec
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
            phase = .failed(error.localizedDescription)
            try? FileManager.default.removeItem(at: audioURL)
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

        // 清除暫存音檔
        try? FileManager.default.removeItem(at: audioURL)
    }

    private func sendNotification(meetingTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = "會議記錄完成 ✓"
        content.body = "「\(meetingTitle)」的摘要已產生，點此查看。"
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }
}

// MARK: - View

struct RecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = RecordingViewModel()
    @ObservedObject private var recorder = AudioRecordingManager.shared

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
                Text("發生錯誤").font(.title.bold())
                Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            Button("關閉") { dismiss() }
                .buttonStyle(.bordered)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
