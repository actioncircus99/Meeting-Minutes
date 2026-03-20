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
            ZStack(alignment: .bottom) {
                // Background
                Color.appBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Gradient Header ───────────────────────────────────
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: [Color.brand, Color.brandLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("會議記錄")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                            Text("共 \(meetings.count) 場會議")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .frame(height: 140)

                    // ── Meeting List ──────────────────────────────────────
                    if meetings.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "mic.slash")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.inkGray)
                            Text("尚無會議記錄")
                                .font(.headline)
                                .foregroundStyle(Color.inkDark)
                            Text("點選下方按鈕開始錄音")
                                .font(.subheadline)
                                .foregroundStyle(Color.inkGray)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(sortedMeetings) { meeting in
                                    NavigationLink(destination: MeetingDetailView(record: meeting)) {
                                        MeetingRowView(record: meeting)
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            meeting.isPinned = !(meeting.isPinned == true)
                                            try? modelContext.save()
                                        } label: {
                                            let isPinned = meeting.isPinned == true
                                            Label(isPinned ? "取消置頂" : "置頂",
                                                  systemImage: isPinned ? "pin.slash" : "pin")
                                        }
                                        .tint(Color.infoBg)
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
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 100)
                        }
                    }
                }

                // ── FAB ───────────────────────────────────────────────────
                Button { showingRecorder = true } label: {
                    Label("開始錄音", systemImage: "mic.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .frame(height: 56)
                        .background(Color.ctaDark)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                }
                .padding(.bottom, 24)
            }
            .navigationBarHidden(true)
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
        HStack(spacing: 12) {
            // Status indicator
            statusDot

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if record.isPinned == true {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.brand)
                    }
                    Text(record.title ?? "會議 \(record.startedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.headline)
                        .foregroundStyle(Color.inkDark)
                        .lineLimit(1)
                }

                HStack(spacing: 12) {
                    Label(record.startedAt.formatted(date: .abbreviated, time: .shortened),
                          systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(Color.inkGray)

                    if let sec = record.durationSeconds {
                        Label(sec.formattedDuration, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(Color.inkGray)
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private var statusDot: some View {
        switch record.status {
        case .processing:
            ProgressView()
                .scaleEffect(0.7)
                .tint(Color.inkGray)
                .frame(width: 10, height: 10)
        case .complete:
            Circle()
                .fill(Color.morandiSage)
                .frame(width: 10, height: 10)
        case .failed:
            Circle()
                .fill(Color.morandiBrick)
                .frame(width: 10, height: 10)
        }
    }
}
