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
            contentView
                .navigationTitle("會議記錄")
                .safeAreaInset(edge: .bottom) { fab }
                .sheet(isPresented: $showingRecorder) { RecordingView() }
                .confirmationDialog(
                    "確定要刪除這筆會議記錄？",
                    isPresented: .init(
                        get: { meetingToDelete != nil },
                        set: { if !$0 { meetingToDelete = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button("刪除", role: .destructive) { deleteMeeting() }
                    Button("取消", role: .cancel) { meetingToDelete = nil }
                } message: {
                    Text("此操作無法復原，錄音檔案也將一併刪除。")
                }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if meetings.isEmpty {
            ContentUnavailableView(
                "尚無會議記錄",
                systemImage: "mic.slash",
                description: Text("點選下方按鈕開始錄音")
            )
        } else {
            meetingList
        }
    }

    private var meetingList: some View {
        List {
            ForEach(sortedMeetings) { meeting in
                NavigationLink(destination: MeetingDetailView(record: meeting)) {
                    MeetingRowView(record: meeting)
                }
                .listRowBackground(Color.morandiSand)
                .swipeActions(edge: .leading) {
                    Button {
                        meeting.isPinned = !(meeting.isPinned == true)
                        try? modelContext.save()
                    } label: {
                        let isPinned = meeting.isPinned == true
                        Label(isPinned ? "取消置頂" : "置頂",
                              systemImage: isPinned ? "pin.slash" : "pin")
                    }
                    .tint(Color.morandiTerracotta)
                }
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
        .scrollContentBackground(.hidden)
        .background(Color.morandiLinen)
    }

    private var fab: some View {
        VStack(spacing: 0) {
            Divider()
            Button { showingRecorder = true } label: {
                Label("開始錄音", systemImage: "mic.fill")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.brandCharcoal)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.morandiLinen)
        }
    }

    private func deleteMeeting() {
        guard let meeting = meetingToDelete else { return }
        if let path = meeting.audioFilePath {
            try? FileManager.default.removeItem(atPath: path)
        }
        modelContext.delete(meeting)
        try? modelContext.save()
        meetingToDelete = nil
    }
}

// MARK: - Row

struct MeetingRowView: View {
    let record: MeetingRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if record.isPinned == true {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(Color.morandiTerracotta)
                }
                Text(record.title ?? "會議 \(record.startedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.headline)
                    .lineLimit(1)
            }

            HStack(spacing: 12) {
                Label(record.startedAt.formatted(date: .abbreviated, time: .shortened),
                      systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(Color.morandiWarmGray)

                if let sec = record.durationSeconds {
                    Label(sec.formattedDuration, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(Color.morandiWarmGray)
                }

                Spacer()

                statusBadge
            }
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch record.status {
        case .processing:
            HStack(spacing: 4) {
                ProgressView().scaleEffect(0.7).tint(Color.morandiWarmGray)
                Text("分析中").font(.caption).foregroundStyle(Color.morandiWarmGray)
            }
        case .complete:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.morandiSage).font(.subheadline)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.morandiBrick).font(.subheadline)
        }
    }
}
