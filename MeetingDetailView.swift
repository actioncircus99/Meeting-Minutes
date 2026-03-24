import SwiftUI
import SwiftData
import AVFoundation
import Combine

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
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            LinearGradient(
                colors: [Color.brand, Color.brandLight],
                startPoint: .leading,
                endPoint: .trailing
            ),
            for: .navigationBar
        )
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            // Figma: Inter 500 18px, letterSpacing -2.44% × 18px = -0.44pt
            ToolbarItem(placement: .principal) {
                Text(record.title ?? "會議詳情")
                    .font(.system(size: 18, weight: .medium))
                    .tracking(-0.44)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            if record.status == .complete {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: DS.Spacing.lg) {
                        if !record.speakerLabels.isEmpty {
                            Button {
                                showingSpeakerEditor = true
                            } label: {
                                Image(systemName: "person.2")
                            }
                        }
                        if let path = record.audioFilePath,
                           FileManager.default.fileExists(atPath: path) {
                            ShareLink(
                                item: URL(fileURLWithPath: path),
                                preview: SharePreview(
                                    record.title ?? "會議錄音",
                                    image: Image(systemName: "waveform")
                                )
                            ) {
                                Image(systemName: "waveform.circle")
                            }
                        }
                        if let url = transcriptExportURL {
                            ShareLink(
                                item: url,
                                preview: SharePreview(
                                    (record.title ?? "逐字稿") + " 逐字稿",
                                    image: Image(systemName: "doc.text")
                                )
                            ) {
                                Image(systemName: "doc.text.below.ecg")
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
        ZStack {
            Color.appBg.ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView().scaleEffect(2).padding()
                Text("分析中...").font(.title3).foregroundStyle(Color.inkDark)
                Text("完成後會發送通知給你，可先離開此畫面")
                    .foregroundStyle(Color.inkGray).multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    // MARK: - Failed

    private var failedView: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
            VStack(spacing: DS.Spacing.xl) {
                ZStack {
                    Circle().fill(Color.morandiBrick.opacity(0.12)).frame(width: 110, height: 110)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 54)).foregroundStyle(Color.morandiBrick)
                }
                Text("處理失敗").font(.title2.bold()).foregroundStyle(Color.inkDark)
                if let msg = record.errorMessage {
                    Text(msg).foregroundStyle(Color.inkGray)
                        .multilineTextAlignment(.center).font(.callout)
                }

                Button {
                    Task { await retryAnalysis() }
                } label: {
                    Group {
                        if isRetrying {
                            HStack(spacing: DS.Spacing.sm) {
                                ProgressView().tint(.white)
                                Text("重新分析中...")
                            }
                        } else {
                            Label("重新分析", systemImage: "arrow.clockwise")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .background(isRetrying ? Color.borderGray : Color.ctaDark)
                .disabled(isRetrying)
                .clipShape(Capsule())
                .padding(.horizontal)

                Text("確認 API Keys 正確後再點重新分析")
                    .foregroundStyle(Color.inkGray.opacity(0.7)).font(.caption)
            }
            .padding()
        }
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
            record.topics = summary.topics
            if !summary.speakerPredictions.isEmpty {
                record.speakerNames = summary.speakerPredictions
            }
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
        ZStack {
            Color.appBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Player + Chips 整組，統一給 20px 頂距，
                // 無論 player 是否存在，chips 都不會黏頂
                VStack(spacing: DS.Spacing.md) {
                    // Audio Player Card（僅音檔存在時顯示）
                    if let path = record.audioFilePath,
                       FileManager.default.fileExists(atPath: path) {
                        AudioPlayerBar(url: URL(fileURLWithPath: path))
                            .padding(.vertical, DS.Spacing.page)
                            .padding(.horizontal, DS.Spacing.lg)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
                            .dsShadow(DS.Shadow.overlay)
                    }

                    // Info Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.sm) {
                            InfoChip(icon: "calendar",
                                     text: record.startedAt.formatted(date: .abbreviated, time: .shortened))
                            if let sec = record.durationSeconds {
                                InfoChip(icon: "clock", text: sec.formattedDuration)
                            }
                            InfoChip(icon: "checkmark.seal",
                                     text: "\(record.summaryPoints.count) 個結論")
                            if !record.nextSteps.isEmpty {
                                InfoChip(icon: "checklist",
                                         text: "\(record.nextSteps.filter { !$0.isCompleted }.count) 項待辦")
                            }
                            if !record.speakerNames.isEmpty {
                                InfoChip(icon: "person.2",
                                         text: "\(record.speakerNames.count) 位已命名")
                            }
                        }
                        .padding(.horizontal, DS.Spacing.page)
                    }
                }
                .padding(.top, DS.Spacing.page)    // 永遠保留 20px 頂距，不依賴 player 是否存在
                .padding(.bottom, DS.Spacing.md)

                // Custom Tab Picker
                MeetingTabPicker(selected: $selectedTab,
                                 tabs: ["結論", "討論摘要", "行動項目", "逐字稿"])
                    .padding(.horizontal, DS.Spacing.page) // Figma: x:20, width 353
                    .padding(.bottom, 0)

                currentTab
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private var currentTab: some View {
        switch selectedTab {
        case 0: summaryTab
        case 1: topicsTab
        case 2: nextStepsTab
        default: transcriptTab
        }
    }

    // MARK: - Summary tab（會議結論）

    private var summaryTab: some View {
        Group {
            if record.summaryPoints.isEmpty {
                ContentUnavailableView("無會議結論", systemImage: "checkmark.seal",
                    description: Text("重新分析後即可顯示"))
            } else {
                ScrollView {
                    VStack(spacing: DS.Spacing.md) {
                        ForEach(Array(record.summaryPoints.enumerated()), id: \.offset) { i, point in
                            HStack(alignment: .top, spacing: DS.Spacing.md) {
                                // Figma: 24×24 circle, fill #6B7FD4, text white, Noto Sans TC 12px
                                Text("\(i + 1)")
                                    .font(.system(size: 12))
                                    .frame(width: 24, height: 24)
                                    .background(Color.brand)
                                    .foregroundStyle(.white)
                                    .clipShape(Circle())
                                Text(point)
                                    .font(.system(size: 16))   // Figma: Noto Sans TC 16px
                                    .foregroundStyle(Color.inkDark)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            // Figma: padding 16px 16px 0px (top/horizontal only, no bottom)
                            .padding(.top, DS.Spacing.lg)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.bottom, DS.Spacing.lg) // keep some bottom for readability; Figma clips at content bottom
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
                            .dsShadow(DS.Shadow.subtle)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.page) // Figma: content area padding 16px 20px 0px
                    .padding(.top, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.lg)
                }
            }
        }
    }

    // MARK: - Topics tab（討論摘要）

    private var topicsTab: some View {
        Group {
            if record.topics.isEmpty {
                ContentUnavailableView("無討論摘要", systemImage: "text.bubble",
                    description: Text("重新分析後即可顯示"))
            } else {
                ScrollView {
                    VStack(spacing: DS.Spacing.md) { // Figma: gap 12px
                        ForEach(record.topics) { topic in
                            VStack(alignment: .leading, spacing: DS.Spacing.sm) { // Figma: gap 8px
                                Text(topic.title)
                                    .font(.system(size: 16, weight: .medium)) // Figma: Noto Sans TC 500 16px
                                    .foregroundStyle(Color.brand)
                                Text(topic.summary)
                                    .font(.system(size: 16)) // Figma: Noto Sans TC 400 16px
                                    .lineSpacing(4) // Figma: lineHeight 1.625em（較寬行距提升中文可讀性）
                                    .foregroundStyle(Color.inkBody) // Figma: #444444
                            }
                            .padding(DS.Spacing.lg) // Figma: padding 16px all sides
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
                            .dsShadow(DS.Shadow.subtle)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.page) // Figma: padding 16px 20px 0px
                    .padding(.top, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.lg)
                }
            }
        }
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
                ScrollView {
                    VStack(spacing: DS.Spacing.lg) { // Figma: gap 16px between sections
                        let pending = record.nextSteps.filter { !$0.isCompleted }
                        let done    = record.nextSteps.filter { $0.isCompleted }

                        if !pending.isEmpty {
                            VStack(spacing: DS.Spacing.sm) { // Figma: gap 8px within section
                                Text("待完成（\(pending.count)）")
                                    .font(.system(size: 12, weight: .medium)) // Figma: Inter 500 12px
                                    .foregroundStyle(Color.inkGray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                ForEach(pending) { step in nextStepRow(step: step) }
                            }
                        }

                        if !done.isEmpty {
                            VStack(spacing: DS.Spacing.sm) {
                                Text("已完成（\(done.count)）")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.inkGray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                ForEach(done) { step in nextStepRow(step: step) }
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.page) // Figma: padding 16px 20px 0px
                    .padding(.top, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.lg)
                }
            }
        }
    }

    private func nextStepRow(step: NextStepItem) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Button {
                toggleStep(id: step.id)
            } label: {
                Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(step.isCompleted ? Color.morandiSage : Color.brand) // Figma: brand blue for unchecked
                    .animation(.spring(duration: 0.2), value: step.isCompleted)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) { // Figma: gap 6px
                Text(step.description)
                    .font(.system(size: 16)) // Figma: Noto Sans TC 400 16px
                    .tracking(-0.15)         // letterSpacing -0.93994% × 16px
                    .foregroundStyle(Color.inkDark)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: DS.Spacing.sm) {
                    if let p = step.priority, !step.isCompleted {
                        Text(p)
                            .font(.system(size: 11)) // Figma: 11px
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, 2)
                            .background(priorityBgColor(p))
                            .foregroundStyle(priorityColor(p))
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                    }
                    if let a = step.assignee {
                        Label(a, systemImage: "person.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.inkGray)
                    }
                    if let d = step.dueDate {
                        Label(d, systemImage: "calendar")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.inkGray)
                    }
                }
            }
        }
        .padding(DS.Spacing.lg) // Figma: card padding 16px
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        .dsShadow(DS.Shadow.subtle)
        .opacity(step.isCompleted ? 0.6 : 1.0) // Figma: completed cards at opacity 0.6
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "高": return .morandiBrick // #D93900
        case "中": return .brand        // #6B7FD4
        default:   return .inkGray      // #6B7280
        }
    }

    private func priorityBgColor(_ priority: String) -> Color {
        switch priority {
        case "高": return Color(red: 254/255, green: 242/255, blue: 242/255) // #FEF2F2
        case "中": return Color.infoBg                                        // #EEF0FF
        default:   return Color(red: 241/255, green: 241/255, blue: 241/255) // #F1F1F1
        }
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
        Group {
            if transcriptSegments.isEmpty {
                ContentUnavailableView("無逐字稿", systemImage: "doc.text",
                    description: Text("此會議沒有逐字稿資料"))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(transcriptSegments) { seg in
                            HStack(alignment: .top, spacing: 0) {
                                // 2px left border — brand blue 與說話者標籤顏色一致
                                Rectangle()
                                    .fill(Color.brand)
                                    .frame(width: 2)

                                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                    if let speaker = seg.speaker {
                                        Text(speaker)
                                            .font(.caption.bold())
                                            .foregroundStyle(Color.brand)
                                    }
                                    Text(seg.text)
                                        .font(.system(size: 16)) // 與其他 tab 正文一致
                                        .foregroundStyle(Color.inkBody) // 長文閱讀用 inkBody
                                        .lineSpacing(4)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, 10)
                            }
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                            .padding(.horizontal, DS.Spacing.page) // 與其他 tab 內容區一致
                            .padding(.vertical, DS.Spacing.xs)
                        }
                    }
                    .padding(.vertical, DS.Spacing.sm)
                }
            }
        }
    }

    private var transcriptSegments: [TranscriptSegment] {
        guard let raw = record.transcript, !raw.isEmpty else { return [] }
        let lines = raw.components(separatedBy: "\n")
        var segments: [TranscriptSegment] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix("["),
               let closeBracket = trimmed.firstIndex(of: "]") {
                let speaker = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closeBracket])
                let rest = trimmed[trimmed.index(after: closeBracket)...].trimmingCharacters(in: .whitespaces)
                segments.append(TranscriptSegment(speaker: speaker, text: rest.isEmpty ? " " : rest))
            } else {
                segments.append(TranscriptSegment(speaker: nil, text: trimmed))
            }
        }
        return segments
    }

    // MARK: - Transcript export

    private var transcriptExportURL: URL? {
        guard let text = record.transcript, !text.isEmpty else { return nil }
        let title = (record.title ?? "逐字稿")
            .components(separatedBy: .whitespacesAndNewlines).joined(separator: "_")
        let date = record.startedAt.formatted(.dateTime.year().month().day())
        let filename = "\(title)_逐字稿_\(date).txt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Share text

    private var shareText: String {
        let title = record.title ?? "會議記錄"
        let dateStr = record.startedAt.formatted(date: .abbreviated, time: .shortened)
        var lines: [String] = []

        lines.append("【主旨】\(title) 會議記錄 - \(record.startedAt.formatted(.dateTime.year().month().day()))")
        lines.append("")
        lines.append("各位好，")
        lines.append("")
        lines.append("附上今日會議記錄如下，請確認相關決議與行動項目。")
        lines.append("")

        lines.append("【會議資訊】")
        lines.append("時間：\(dateStr)")
        if let sec = record.durationSeconds { lines.append("時長：\(sec.formattedDuration)") }
        lines.append("")

        if !record.summaryPoints.isEmpty {
            lines.append("【會議結論】")
            for (i, p) in record.summaryPoints.enumerated() { lines.append("\(i+1). \(p)") }
            lines.append("")
        }

        let steps = record.nextSteps
        if !steps.isEmpty {
            lines.append("【行動項目】")
            for s in steps {
                var line = (s.isCompleted ? "☑" : "☐") + " \(s.description)"
                if let p = s.priority { line += "（優先級：\(p)）" }
                if let a = s.assignee { line += "　負責：\(a)" }
                if let d = s.dueDate { line += "　期限：\(d)" }
                lines.append(line)
            }
            lines.append("")
        }

        if !record.topics.isEmpty {
            lines.append("【討論摘要】")
            for topic in record.topics {
                lines.append("")
                lines.append("🔶 \(topic.title)")
                lines.append(topic.summary)
            }
            lines.append("")
        }

        lines.append("請確認內容，若有疑問或補充歡迎回覆。謝謝。")

        return lines.joined(separator: "\n")
    }
}

// MARK: - Custom Tab Picker

struct MeetingTabPicker: View {
    @Binding var selected: Int
    let tabs: [String]

    var body: some View {
        HStack(spacing: DS.Spacing.xs) { // Figma: gap 4px
            ForEach(tabs.indices, id: \.self) { i in
                Button {
                    withAnimation(.spring(duration: 0.25)) { selected = i }
                } label: {
                    Text(tabs[i])
                        .font(.system(size: 14, weight: .medium)) // Figma: Noto Sans TC 500 14px
                        .foregroundStyle(selected == i ? Color.brand : Color.inkGray) // active: #6B7FD4
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7) // Figma: hug height, padding 7px top/bottom
                        .background(
                            selected == i
                                ? RoundedRectangle(cornerRadius: DS.Radius.md) // Figma: active radius 12px
                                    .fill(.white)
                                    .dsShadow(DS.Shadow.subtle)
                                : nil
                        )
                }
                .buttonStyle(.plain)
            }
        }
        // Figma: padding 2px all sides
        .padding(2)
        .background(Color.borderGray) // #E5E7EB
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.fieldButton))
    }
}

// MARK: - Transcript Segment

struct TranscriptSegment: Identifiable {
    let id = UUID()
    let speaker: String?
    let text: String
}

// MARK: - InfoChip

struct InfoChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) { // Figma: gap 6px
            Image(systemName: icon)
                .font(.system(size: 14))  // Figma: icon 16×16
                .frame(width: 16, height: 16)
                .foregroundStyle(Color.brand)
            Text(text)
                .font(.system(size: 14)) // Figma: Noto Sans TC 14px
                .foregroundStyle(Color.inkDark)
        }
        .padding(.horizontal, DS.Spacing.md) // Figma: padding 0px 12px
        .padding(.vertical, DS.Spacing.sm)  // Figma: hug height, padding 8px top/bottom
        .background(Color.chipBackground)
        .clipShape(Capsule())
    }
}

// MARK: - Audio Player

struct AudioPlayerBar: View {
    let url: URL
    @StateObject private var vm = AudioPlayerViewModel()

    var body: some View {
        HStack(spacing: 9) { // Figma: gap 9px
            Button {
                vm.togglePlay()
            } label: {
                Image(systemName: vm.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 24)) // Figma: Button 24×24
                    .foregroundStyle(Color.brand)
            }
            .buttonStyle(.plain)

            Slider(
                value: Binding(
                    get: { vm.duration > 0 ? vm.currentTime / vm.duration : 0 },
                    set: { vm.seek(to: $0) }
                )
            )
            .tint(Color.brand)

            // Figma: "27:00 / 90:00" — single time label, Noto Sans TC 14px, #6B7280
            Text("\(Int(vm.currentTime).formattedDuration) / \(Int(vm.duration).formattedDuration)")
                .font(.system(size: 14))
                .foregroundStyle(Color.inkGray)
                .fixedSize()
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
    @State private var orderedLabels: [String] = []
    @State private var isReanalyzing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(orderedLabels, id: \.self) { label in
                        HStack(spacing: DS.Spacing.md) {
                            let rank = (orderedLabels.firstIndex(of: label) ?? 0) + 1
                            Text("\(rank)")
                                .font(.caption.bold())
                                .frame(width: 28, height: 28)
                                .background(rank == 1 ? Color.infoBg : Color.borderGray)
                                .foregroundStyle(rank == 1 ? Color.brand : Color.inkGray)
                                .clipShape(Circle())

                            Text("說話者 \(label)")
                                .foregroundStyle(Color.inkGray)
                                .frame(width: 64, alignment: .leading)

                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(Color.borderGray)

                            TextField(
                                "輸入名稱（例如：老闆）",
                                text: Binding(
                                    get: { names[label] ?? "" },
                                    set: { names[label] = $0 }
                                )
                            )
                        }
                    }
                    .onMove { from, to in
                        orderedLabels.move(fromOffsets: from, toOffset: to)
                    }
                } header: {
                    Text("說話者名稱與發言權重")
                } footer: {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Label("第 1 位的發言在歧見時優先採納", systemImage: "arrow.up.circle")
                            .font(.caption)
                            .foregroundStyle(Color.brand)
                        if names.values.contains(where: { !$0.isEmpty }) {
                            Label("已預填的名稱由 AI 從逐字稿推測，請確認是否正確", systemImage: "sparkles")
                                .font(.caption)
                                .foregroundStyle(Color.inkGray)
                        }
                        Text("長按右側拖把可調整順序；命名後點「套用並重新分析」")
                            .font(.caption)
                            .foregroundStyle(Color.inkGray)
                    }
                }

                if let msg = errorMessage {
                    Section {
                        Text(msg)
                            .foregroundStyle(Color.morandiBrick)
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
                    .listRowBackground(isReanalyzing ? Color.borderGray : Color.ctaDark)
                    .disabled(isReanalyzing || !hasAnyName)
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("說話者設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(
                LinearGradient(
                    colors: [Color.brand, Color.brandLight],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                for: .navigationBar
            )
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("關閉") {
                        saveNamesAndOrder()
                        dismiss()
                    }
                }
            }
            .onAppear {
                names = record.speakerNames
                let saved = record.speakerOrder
                let all = record.speakerLabels
                if !saved.isEmpty {
                    let savedFiltered = saved.filter { all.contains($0) }
                    let missing = all.filter { !savedFiltered.contains($0) }
                    orderedLabels = savedFiltered + missing
                } else {
                    orderedLabels = all
                }
            }
        }
    }

    private var hasAnyName: Bool {
        names.values.contains(where: { !$0.isEmpty })
    }

    private func saveNamesAndOrder() {
        record.speakerNames = names.filter { !$0.value.isEmpty }
        record.speakerOrder = orderedLabels
        try? modelContext.save()
    }

    private func reanalyze() async {
        guard let transcript = record.transcript, !transcript.isEmpty else {
            errorMessage = "找不到逐字稿，無法重新分析"
            return
        }
        errorMessage = nil
        isReanalyzing = true
        saveNamesAndOrder()

        var renamedTranscript = transcript
        for (label, name) in record.speakerNames where !name.isEmpty {
            renamedTranscript = renamedTranscript.replacingOccurrences(
                of: "[說話者 \(label)]",
                with: "[\(name)]"
            )
        }

        let orderForAPI = orderedLabels.map { label in
            record.speakerNames[label].flatMap { $0.isEmpty ? nil : $0 } ?? "說話者 \(label)"
        }

        do {
            let summary = try await AIService.shared.summarize(
                transcript: renamedTranscript,
                speakerOrder: orderForAPI
            )
            record.summaryPoints = summary.points
            record.topics = summary.topics
            if !summary.speakerPredictions.isEmpty {
                record.speakerNames = summary.speakerPredictions
            }
            record.nextSteps = summary.nextSteps
            try? modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isReanalyzing = false
    }
}
