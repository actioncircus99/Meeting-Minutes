import SwiftUI
import SwiftData

struct MeetingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var meetings: [MeetingRecord]
    @State private var showingRecorder = false
    @State private var meetingToDelete: MeetingRecord?

    var sortedMeetings: [MeetingRecord] {
        meetings.sorted {
            let lPinned = $0.isPinned == true
            let rPinned = $1.isPinned == true
            if lPinned != rPinned { return lPinned }
            return $0.createdAt > $1.createdAt
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if meetings.isEmpty {
                    ContentUnavailableView(
                        "尚無會議記錄",
                        systemImage: "mic.slash",
                        description: Text("點選下方按鈕開始錄音")
                    )
                } else {
                    List {
                        ForEach(sortedMeetings) { meeting in
                            NavigationLink(destination: MeetingDetailView(record: meeting)) {
                                MeetingRowView(record: meeting)
                            }
                            // 左滑：置頂 / 取消置頂
                            .swipeActions(edge: .leading) {
                                Button {
                                    meeting.isPinned = !(meeting.isPinned == true)
                                    try? modelContext.save()
                                } label: {
                                    Label(
                                        meeting.isPinned == true ? "取消置頂" : "置頂",
                                        systemImage: meeting.isPinned == true ? "pin.slash" : "pin"
                                    )
                                }
                                .tint(.orange)
                            }
                            // 右滑：刪除（需確認）
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    meetingToDelete = meeting
                                } label: {
                                    Label("刪除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("會議記錄")
            .safeAreaInset(edge: .bottom) {
                Button {
                    showingRecorder = true
                } label: {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.red)
                        .shadow(color: .red.opacity(0.3), radius: 8, y: 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
                .background(.ultraThinMaterial)
            }
            .sheet(isPresented: $showingRecorder) {
                RecordingView()
            }
            .confirmationDialog(
                "確定要刪除這筆會議記錄？",
                isPresented: Binding(
                    get: { meetingToDelete != nil },
                    set: { if !$0 { meetingToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("刪除", role: .destructive) {
                    if let meeting = meetingToDelete {
                        if let path = meeting.audioFilePath {
                            try? FileManager.default.removeItem(atPath: path)
                        }
                        modelContext.delete(meeting)
                        try? modelContext.save()
                        meetingToDelete = nil
                    }
                }
                Button("取消", role: .cancel) { meetingToDelete = nil }
            } message: {
                Text("此操作無法復原，錄音檔案也將一併刪除。")
            }
        }
    }
}

// MARK: - Row

struct MeetingRowView: View {
    let record: MeetingRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if record.isPinned == true {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text(record.title ?? "會議 \(record.startedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.headline)
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                Label(record.startedAt.formatted(date: .abbreviated, time: .shortened),
                      systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let sec = record.durationSeconds {
                    Label(sec.formattedDuration, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                statusBadge
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch record.status {
        case .processing:
            HStack(spacing: 4) {
                ProgressView().scaleEffect(0.7)
                Text("分析中").font(.caption).foregroundStyle(.orange)
            }
        case .complete:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green).font(.subheadline)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red).font(.subheadline)
        }
    }
}
