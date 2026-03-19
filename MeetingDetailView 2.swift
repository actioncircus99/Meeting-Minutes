import SwiftUI
import SwiftData
import Combine

struct MeetingDetailView: View {
    @Bindable var record: MeetingRecord
    @State private var selectedTab = 0

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
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
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
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60)).foregroundStyle(.red)
            Text("處理失敗").font(.headline)
            if let msg = record.errorMessage {
                Text(msg).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).font(.callout)
            }
            Text("請確認 API Keys 是否正確後，重新錄製")
                .foregroundStyle(.tertiary).font(.caption)
        }
        .padding()
    }

    // MARK: - Result

    private var resultView: some View {
        VStack(spacing: 0) {
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
                        .foregroundStyle(Color.red)
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
