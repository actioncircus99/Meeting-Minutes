import SwiftUI
import SwiftData
import AVFoundation

struct MeetingDetailView: View {
    @Bindable var record: MeetingRecord
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @State private var isRetrying = false
    @State private var showingSpeakerEditor = false

    var body: some View {
        Group {
            switch record.status {
            case .processing:
                processingView
            case .failed:
                failedView
            case .complete:
                resultView
            }
        }
        .navigationTitle(record.title ?? "會議詳情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if record.status == .complete {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if !record.speakerLabels.isEmpty {
                            Button {
                                showingSpeakerEditor = true
                            } label: {
                                Image(systemName: "person.2")
                            }
                        }
                        ShareLink(item: shareText) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingSpeakerEditor) {
            SpeakerEditorView(record: record)
        }
    }

    // MARK: - Processing

    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView().scaleEffect(2).padding()
            Text("分析中...").font(.title3)
            Text("完成後會發送通知給你，可先離開此畫面")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Failed

    private var failedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60)).foregroundStyle(.red)
            Text("處理失敗").font(.headline)
            if let msg = record.errorMessage {
                Text(msg).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).font(.callout)
            }

            Button {
                Task { await retryAnalysis() }
            } label: {
                Group {
                    if isRetrying {
                        HStack(spacing: 8) {
                            ProgressView().tint(.white)
                            Text("重新分析中...")
                        }
                    } else {
                        Label("重新分析", systemImage: "arrow.clockwise")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(isRetrying)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)

            Text("確認 API Keys 正確後再點重新分析")
                .foregroundStyle(.tertiary).font(.caption)
        }
        .padding()
    }

    private func retryAnalysis() async {
        isRetrying = true
        record.status = .processing
        record.errorMessage = nil
        try? modelContext.save()

        let transcript: String

        if let existing = record.transcript, !existing.isEmpty {
            transcript = existing
        } else if let path = record.audioFilePath,
                  FileManager.default.fileExists(atPath: path) {
            let audioURL = URL(fileURLWithPath: path)
            do {
                transcript = try await AIService.shared.transcribe(audioURL: audioURL)
                record.transcript = transcript
                try? modelContext.save()
            } catch {
                record.status = .failed
                record.errorMessage = error.localizedDescription
                try? modelContext.save()
                isRetrying = false
                return
            }
        } else {
            record.status = .failed
            record.errorMessage = "音檔已不存在，請重新錄製"
            record.audioFilePath = nil
            try? modelContext.save()
            isRetrying = false
            return
        }

        do {
            let summary = try await AIService.shared.summarize(transcript: transcript)
            if record.title == nil { record.title = summary.title }
            record.summaryPoints = summary.points
            record.nextSteps = summary.nextSteps
            record.status = .complete
            try? modelContext.save()
        } catch {
            record.status = .failed
            record.errorMessage = error.localizedDescription
            try? modelContext.save()
        }

        isRetrying = false
    }

    // MARK: - Result

    private var resultView: some View {
        VStack(spacing: 0) {
            // 音訊播放器
            if let path = record.audioFilePath,
               FileManager.default.fileExists(atPath: path) {
                AudioPlayerBar(url: URL(fileURLWithPath: path))
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                Divider()
            }

            // 會議資訊標頭
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    InfoChip(icon: "calendar",
                             text: record.startedAt.formatted(date: .abbreviated, time: .shortened))
                    if let sec = record.durationSeconds {
                        InfoChip(icon: "clock", text: sec.formattedDuration)
                    }
                    InfoChip(icon: "doc.text",
                             text: "\(record.summaryPoints.count) 個重點")
                    if !record.nextSteps.isEmpty {
                        InfoChip(icon: "checklist",
                                 text: "\(record.nextSteps.filter { !$0.isCompleted }.count) 項待辦")
                    }
                    if !record.speakerNames.isEmpty {
                        InfoChip(icon: "person.2",
                                 text: "\(record.speakerNames.count) 位已命名")
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 8)

            Picker("", selection: $selectedTab) {
                Text("10 大重點").tag(0)
                Text("行動項目").tag(1)
                Text("逐字稿").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            TabView(selection: $selectedTab) {
                summaryTab.tag(0)
                nextStepsTab.tag(1)
                transcriptTab.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    // MARK: - Summary tab

    private var summaryTab: some View {
        List {
            ForEach(Array(record.summaryPoints.enumerated()), id: \.offset) { i, point in
                HStack(alignment: .top, spacing: 14) {
                    Text("\(i + 1)")
                        .font(.caption.bold())
                        .frame(width: 26, height: 26)
                        .background(Color.red.opacity(0.12))
                        .clipShape(Circle())
                        .foregroundStyle(.red)
                    Text(point).font(.body)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Next Steps tab

    private var nextStepsTab: some View {
        Group {
            if record.nextSteps.isEmpty {
                ContentUnavailableView(
                    "無行動項目",
                    systemImage: "checkmark.circle",
                    description: Text("這場會議沒有提取到具體的行動項目")
                )
            } else {
                List {
                    let pending = record.nextSteps.filter { !$0.isCompleted }
                    let done    = record.nextSteps.filter { $0.isCompleted }

                    if !pending.isEmpty {
                        Section("待完成（\(pending.count)）") {
                            ForEach(pending) { step in
                                nextStepRow(step: step)
                            }
                        }
                    }
                    if !done.isEmpty {
                        Section("已完成（\(done.count)）") {
                            ForEach(done) { step in
                                nextStepRow(step: step)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private func nextStepRow(step: NextStepItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                toggleStep(id: step.id)
            } label: {
                Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(step.isCompleted ? .green : .secondary)
                    .font(.title3)
                    .animation(.spring(duration: 0.2), value: step.isCompleted)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(step.description)
                    .strikethrough(step.isCompleted)
                    .foregroundStyle(step.isCompleted ? .secondary : .primary)
                HStack(spacing: 12) {
                    if let a = step.assignee {
                        Label(a, systemImage: "person.fill").font(.caption).foregroundStyle(.secondary)
                    }
                    if let d = step.dueDate {
                        Label(d, systemImage: "calendar").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func toggleStep(id: UUID) {
        var steps = record.nextSteps
        if let i = steps.firstIndex(where: { $0.id == id }) {
            steps[i].isCompleted.toggle()
            record.nextSteps = steps
        }
    }

    // MARK: - Transcript tab

    private var transcriptTab: some View {
        ScrollView {
            Text(record.transcript?.isEmpty == false ? record.transcript! : "無逐字稿")
                .font(.body)
                .lineSpacing(6)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    // MARK: - Share text

    private var shareText: String {
        var lines: [String] = []
        lines.append("📋 \(record.title ?? "會議記錄")")
        lines.append("📅 \(record.startedAt.formatted(date: .abbreviated, time: .shortened))")
        if let sec = record.durationSeconds { lines.append("⏱ \(sec.formattedDuration)") }
        lines.append("")
        if !record.summaryPoints.isEmpty {
            lines.append("── 10 大重點 ──")
            for (i, p) in record.summaryPoints.enumerated() { lines.append("\(i+1). \(p)") }
            lines.append("")
        }
        let steps = record.nextSteps
        if !steps.isEmpty {
            lines.append("── 行動項目 ──")
            for s in steps {
                var line = (s.isCompleted ? "☑ " : "☐ ") + s.description
                if let a = s.assignee { line += "（\(a)）" }
                if let d = s.dueDate { line += " 期限：\(d)" }
                lines.append(line)
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - InfoChip

struct InfoChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2).foregroundStyle(.secondary)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }
}

// MARK: - Audio Player

struct AudioPlayerBar: View {
    let url: URL
    @StateObject private var vm = AudioPlayerViewModel()

    var body: some View {
        HStack(spacing: 12) {
            Button {
                vm.togglePlay()
            } label: {
                Image(systemName: vm.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)

            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { vm.duration > 0 ? vm.currentTime / vm.duration : 0 },
                        set: { vm.seek(to: $0) }
                    )
                )
                .tint(.red)

                HStack {
                    Text(Int(vm.currentTime).formattedDuration)
                    Spacer()
                    Text(Int(vm.duration).formattedDuration)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .onAppear { vm.setup(url: url) }
        .onDisappear { vm.stop() }
    }
}

final class AudioPlayerViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func setup(url: URL) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        duration = player?.duration ?? 0
    }

    func togglePlay() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            timer?.invalidate()
            timer = nil
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    guard let self, let p = self.player else { return }
                    self.currentTime = p.currentTime
                    if !p.isPlaying {
                        self.isPlaying = false
                        self.currentTime = 0
                        self.timer?.invalidate()
                        self.timer = nil
                    }
                }
            }
        }
    }

    func seek(to fraction: Double) {
        guard let player else { return }
        let wasPlaying = player.isPlaying
        player.currentTime = fraction * duration
        currentTime = player.currentTime
        if wasPlaying { player.play() }
    }

    func stop() {
        player?.stop()
        timer?.invalidate()
        timer = nil
        isPlaying = false
    }
}

// MARK: - Speaker Editor

struct SpeakerEditorView: View {
    var record: MeetingRecord
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var names: [String: String] = [:]
    @State private var isReanalyzing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(record.speakerLabels, id: \.self) { label in
                        HStack(spacing: 12) {
                            Text("說話者 \(label)")
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .leading)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            TextField(
                                "輸入名稱（例如：老闆）",
                                text: Binding(
                                    get: { names[label] ?? "" },
                                    set: { names[label] = $0 }
                                )
                            )
                        }
                    }
                } header: {
                    Text("說話者名稱")
                } footer: {
                    Text("命名後點「套用並重新分析」，AI 會依據每位說話者的角色重新解讀會議重點")
                }

                if let msg = errorMessage {
                    Section {
                        Text(msg)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }

                Section {
                    Button {
                        Task { await reanalyze() }
                    } label: {
                        HStack {
                            Spacer()
                            if isReanalyzing {
                                ProgressView().tint(.white)
                                Text("重新分析中...").fontWeight(.semibold)
                            } else {
                                Label("套用並重新分析", systemImage: "sparkles")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .foregroundStyle(.white)
                    .listRowBackground(isReanalyzing ? Color.gray : Color.red)
                    .disabled(isReanalyzing || !hasAnyName)
                }
            }
            .navigationTitle("說話者設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("關閉") {
                        saveNames()
                        dismiss()
                    }
                }
            }
            .onAppear {
                names = record.speakerNames
            }
        }
    }

    private var hasAnyName: Bool {
        names.values.contains(where: { !$0.isEmpty })
    }

    private func saveNames() {
        record.speakerNames = names.filter { !$0.value.isEmpty }
        try? modelContext.save()
    }

    private func reanalyze() async {
        guard let transcript = record.transcript, !transcript.isEmpty else {
            errorMessage = "找不到逐字稿，無法重新分析"
            return
        }
        errorMessage = nil
        isReanalyzing = true
        saveNames()

        // 將 [說話者 A] 替換為使用者輸入的名稱
        var renamedTranscript = transcript
        for (label, name) in record.speakerNames where !name.isEmpty {
            renamedTranscript = renamedTranscript.replacingOccurrences(
                of: "[說話者 \(label)]",
                with: "[\(name)]"
            )
        }

        do {
            let summary = try await AIService.shared.summarize(transcript: renamedTranscript)
            record.summaryPoints = summary.points
            record.nextSteps = summary.nextSteps
            try? modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isReanalyzing = false
    }
}
