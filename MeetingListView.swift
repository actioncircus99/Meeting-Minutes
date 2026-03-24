import SwiftUI
import SwiftData

struct MeetingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var meetings: [MeetingRecord]
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
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 14/255, green: 160/255, blue: 200/255), location: 0),
                        .init(color: Color(red: 14/255, green: 68/255,  blue: 234/255), location: 0.35),
                        .init(color: Color(red: 39/255, green: 44/255,  blue: 62/255),  location: 1)
                    ],
                    startPoint: .bottomTrailing,
                    endPoint: .topLeading
                )
                .ignoresSafeArea()

                Image("login_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
                    .opacity(0.15)

                VStack(spacing: 0) {
                    // ── Gradient Header ───────────────────────────────────
                    // Figma: padding 48px 20px 0px, container height 127px
                    // (48 top + 42 title + 21 subtitle + 16 bottom natural gap)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("會議記錄")
                            .font(.system(size: 28, weight: .medium))
                            .tracking(0.38) // letterSpacing 1.3671875% × 28px
                            .foregroundStyle(.white)
                        Text("共 \(meetings.count) 場會議")
                            .font(.system(size: 14))
                            .tracking(-0.15) // letterSpacing -1.07421875% × 14px
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DS.Spacing.page)
                    .padding(.top, DS.Spacing.pageTop)
                    .padding(.bottom, DS.Spacing.lg) // Figma container: 127px = 48+42+21+16

                    // ── Content ───────────────────────────────────────────
                    if meetings.isEmpty {
                        Spacer()
                        VStack(spacing: DS.Spacing.md) {
                            Image(systemName: "mic.slash")
                                .font(.system(size: 48))
                                .foregroundStyle(.white.opacity(0.6))
                            Text("尚無會議記錄")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("點下方「馬上錄音」開始第一場")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: DS.Spacing.md) {
                                ForEach(sortedMeetings) { meeting in
                                    MeetingCardView(
                                        record: meeting,
                                        onPin: {
                                            meeting.isPinned = !(meeting.isPinned == true)
                                            try? modelContext.save()
                                        },
                                        onDelete: { meetingToDelete = meeting }
                                    )
                                }
                            }
                            .padding(.horizontal, DS.Spacing.page) // Figma: left 20px, cards are 353px → right margin is also 20px
                            // No top padding — Figma card container has padding: 0 0 0 20px
                            .padding(.bottom, DS.Spacing.xl)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: MeetingRecord.self) { record in
                MeetingDetailView(record: record)
            }
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

// MARK: - Card

struct MeetingCardView: View {
    let record: MeetingRecord
    let onPin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        // Figma card: column, gap 12px, padding 16px, width 353, radius 16
        VStack(spacing: DS.Spacing.md) {
            // ── Top section — navigates to detail ────────────────────────
            NavigationLink(value: record) {
                VStack(spacing: DS.Spacing.xs) {
                    // Row 1: pin badge (if pinned) | title | chevron
                    HStack(spacing: DS.Spacing.sm) {
                        HStack(spacing: 6) {
                            if record.isPinned == true {
                                HStack(spacing: 3) {
                                    Image(systemName: "pin.fill")
                                        .font(.system(size: 9, weight: .semibold))
                                    Text("置頂")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundStyle(Color(red: 180/255, green: 83/255, blue: 9/255))
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(Color(red: 255/255, green: 251/255, blue: 235/255))
                                .clipShape(Capsule())
                            }
                            Text(record.title ?? "會議 \(record.startedAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.system(size: 16))
                                .tracking(-0.23)
                                .foregroundStyle(Color.inkDark)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.inkGray)
                            .frame(width: 16, height: 16)
                    }

                    // Row 2: date · duration — Figma padding: 0px 28px (both sides)
                    HStack(spacing: DS.Spacing.sm) {
                        Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12))
                            .foregroundStyle(Color.inkGray)
                        if let sec = record.durationSeconds {
                            Text("·")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.inkGray)
                            Text(sec.formattedDuration)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.inkGray)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, DS.Spacing.page) // 對齊 Row 1 標題的水平間距
                }
            }
            .buttonStyle(.plain)

            // ── Bottom section — status + action pills ───────────────────
            HStack(spacing: DS.Spacing.sm) {
                // 分析中／失敗 indicator 移到 CTA 區塊
                switch record.status {
                case .processing:
                    HStack(spacing: DS.Spacing.xs) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(Color(red: 1.00, green: 90/255, blue: 95/255))
                            .frame(width: 14, height: 14)
                        Text("分析中")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.inkGray)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Color(red: 245/255, green: 245/255, blue: 245/255))
                    .clipShape(Capsule())
                case .failed:
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.morandiBrick)
                        Text("失敗")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.morandiBrick)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Color(red: 254/255, green: 242/255, blue: 242/255))
                    .clipShape(Capsule())
                case .complete:
                    EmptyView()
                }

                if record.isPinned == true {
                    // Figma: 取消置頂 — 88×26, #FFF0F0 bg, #FF5A5F text
                    ActionPill(
                        label: "取消置頂",
                        icon: "pin.slash",
                        foreground: Color(red: 1.00, green: 90/255, blue: 95/255), // #FF5A5F
                        background: Color(red: 1.00, green: 240/255, blue: 240/255), // #FFF0F0
                        action: onPin
                    )
                } else {
                    // Figma: 置頂 — 64×26, #EEF0FF bg, #6B7FD4 text
                    ActionPill(
                        label: "置頂",
                        icon: "pin",
                        foreground: Color.brand,
                        background: Color.infoBg,
                        action: onPin
                    )
                }

                // Figma: 刪除 — 64×26, #FEF2F2 bg, #D93900 text
                ActionPill(
                    label: "刪除",
                    icon: "trash",
                    foreground: Color.morandiBrick,   // #D93900
                    background: Color(red: 254/255, green: 242/255, blue: 242/255), // #FEF2F2
                    action: onDelete
                )

                Spacer()
            }
            .padding(.top, DS.Spacing.md) // Figma section inner padding-top: 12px
            .overlay(alignment: .top) {
                // Figma stroke: 1px top only, white
                Rectangle()
                    .fill(Color.white)
                    .frame(height: 1)
            }
        }
        .padding(DS.Spacing.lg) // Figma card padding: 16px all sides
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        .overlay(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .stroke(Color.white.opacity(0.8), lineWidth: 8)
                    .blur(radius: 8)
                    .offset(x: 2, y: 2)
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .stroke(Color.black.opacity(0.2), lineWidth: 8)
                    .blur(radius: 8)
                    .offset(x: -4, y: -4)
            }
            .mask(RoundedRectangle(cornerRadius: DS.Radius.card).fill(.black))
        )
    }

}

// MARK: - Action Pill Button

struct ActionPill: View {
    let label: String
    let icon: String
    let foreground: Color
    let background: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) { // Figma: icon at x:12, text at x:28 → gap = 28-12-12 = 4px
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 12, height: 12) // Figma icon: 12×12
                Text(label)
                    .font(.system(size: 12, weight: .medium)) // Figma: Inter 500 12px
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, DS.Spacing.md) // Figma: icon starts at x:12 from left edge
            .frame(height: 26) // Figma: button height 26px
            .background(background)
            .clipShape(Capsule()) // Figma: borderRadius 16777200px = full capsule
        }
        .buttonStyle(.plain)
    }
}
