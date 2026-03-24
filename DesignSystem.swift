import SwiftUI

// MARK: - DS: Design System Tokens
//
// 統一管理所有間距、圓角、陰影數值，確保視覺節奏符合 4pt Grid。
// 使用方式：DS.Spacing.lg、DS.Radius.card、DS.Shadow.subtle
//
// 規則：
//   - 新增 padding / spacing 請優先從 DS.Spacing 取值
//   - 新增 cornerRadius 請優先從 DS.Radius 取值
//   - 陰影請使用 .dsShadow(DS.Shadow.xxx) 而非手寫數值

enum DS {

    // MARK: Spacing（4pt Grid）
    //
    // xs(4) → sm(8) → md(12) → lg(16) → page(20) → xl(24) → pageTop(48)
    //
    // page 是語義值，固定對應「頁面水平 padding 20pt」（DESIGN.md 規範）。
    // pageTop 是語義值，固定對應「頁面頂部 padding 48pt」。
    enum Spacing {
        /// 4pt — 最小間距（badge 內距、微調元素）
        static let xs:      CGFloat = 4
        /// 8pt — 元素間距（小）
        static let sm:      CGFloat = 8
        /// 12pt — 元素間距（中）
        static let md:      CGFloat = 12
        /// 16pt — 內容 padding、卡片 padding、按鈕垂直 padding
        static let lg:      CGFloat = 16
        /// 20pt — 頁面水平 padding（禁止改為其他數值）
        static let page:    CGFloat = 20
        /// 24pt — 區塊間距
        static let xl:      CGFloat = 24
        /// 48pt — 頁面頂部 padding（Header 距頂）
        static let pageTop: CGFloat = 48
    }

    // MARK: Corner Radius
    //
    // xs → sm → md → fieldButton → card，語義由小到大。
    // 全圓膠囊形請直接使用 .clipShape(Capsule())，不要寫死大半徑數值。
    enum Radius {
        /// 4pt — 微型 Badge（行內優先級標籤）
        static let xs:          CGFloat = 4
        /// 8pt — 小型元素（Badge 圓圈、逐字稿行）
        static let sm:          CGFloat = 8
        /// 12pt — 輸入框、ErrorBanner、Segment active tab
        static let md:          CGFloat = 12
        /// 14pt — 表單欄位背景、Segment 外框
        static let fieldButton: CGFloat = 14
        /// 16pt — 卡片、FieldCard、AudioPlayerBar
        static let card:        CGFloat = 16
    }

    // MARK: Shadow

    struct ShadowConfig {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    enum Shadow {
        /// 一般內容卡片（結論、摘要、行動項目）
        static let subtle  = ShadowConfig(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        /// 懸浮元件（AudioPlayerBar 等略微突出的卡片）
        static let overlay = ShadowConfig(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// MARK: - View Helper

extension View {
    /// 套用設計系統陰影，取代手寫 .shadow(color:radius:x:y:)
    func dsShadow(_ shadow: DS.ShadowConfig) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
