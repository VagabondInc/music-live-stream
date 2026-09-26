//
//  Theme.swift
//  ASCII Broadcast
//
//  Design tokens sampled directly from mocks/GUI Mockup.png.
//  Every surface, rule, and accent in the studio comes from here so the
//  broadcast UI stays a single coherent instrument panel.
//

import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

enum Theme {

    // MARK: - Surfaces

    /// Deepest background, behind every panel.
    static let void = Color(hex: 0x03070A)
    /// Standard panel fill.
    static let panel = Color(hex: 0x081013)
    /// Raised rows, pills, and inset wells.
    static let panelRaised = Color(hex: 0x0C161A)
    /// Inset well (slider tracks, program letterbox).
    static let well = Color(hex: 0x050B0E)
    /// Program canvas background.
    static let canvas = Color(hex: 0x04080A)

    // MARK: - Rules

    static let hairline = Color(hex: 0x16262C)
    static let hairlineStrong = Color(hex: 0x21383F)
    static let hairlineFaint = Color(hex: 0x0E1A1F)

    // MARK: - Type

    static let textPrimary = Color(hex: 0xE0DCD4)
    static let textSecondary = Color(hex: 0x8A9294)
    static let textDim = Color(hex: 0x566064)
    static let textFaint = Color(hex: 0x36444A)

    // MARK: - Accents

    static let cyan = Color(hex: 0x3FA6C0)
    static let cyanBright = Color(hex: 0x5FCDE4)
    static let cyanDim = Color(hex: 0x24606F)
    static let amber = Color(hex: 0xE8982F)
    static let amberDim = Color(hex: 0x8A5A1E)
    static let amberWash = Color(hex: 0x2E2213)
    static let green = Color(hex: 0x78B080)
    static let greenBright = Color(hex: 0x8FD39A)
    static let red = Color(hex: 0xC0433A)
    static let redDim = Color(hex: 0x5E211C)
    static let magenta = Color(hex: 0xA05A8A)

    // MARK: - Semantic status

    static func statusColor(_ state: LocalPipelineState) -> Color {
        switch state {
        case .offline:      return Theme.textDim
        case .previewing:   return Theme.cyan
        case .preflighting: return Theme.amber
        case .connecting:   return Theme.amber
        case .sending:      return Theme.green
        case .reconnecting: return Theme.amber
        case .stopping:     return Theme.amber
        case .error:        return Theme.red
        }
    }

    // MARK: - Metrics

    enum Metric {
        static let topBarHeight: CGFloat = 34
        static let statusBarHeight: CGFloat = 26
        static let sideColumnWidth: CGFloat = 302
        static let bottomDeckHeight: CGFloat = 196
        static let panelRadius: CGFloat = 3
        static let gutter: CGFloat = 6
        static let rowHeight: CGFloat = 34
        static let headerHeight: CGFloat = 24
    }

    // MARK: - Typography

    /// The studio is monospaced end to end: the control surface should read
    /// like the medium it directs.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static let label = mono(9, .semibold)
    static let value = mono(10, .medium)
    static let body = mono(11, .regular)
    static let title = mono(11, .semibold)
    static let display = mono(26, .medium)
}

// MARK: - Shared shapes

struct PanelBorder: ViewModifier {
    var color: Color = Theme.hairline
    var fill: Color = Theme.panel

    func body(content: Content) -> some View {
        content
            .background(fill)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metric.panelRadius)
                    .strokeBorder(color, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.panelRadius))
    }
}

extension View {
    func panelChrome(fill: Color = Theme.panel, border: Color = Theme.hairline) -> some View {
        modifier(PanelBorder(color: border, fill: fill))
    }

    /// Wide letter spacing is a load-bearing part of the broadcast look.
    func tracked(_ amount: CGFloat = 0.8) -> some View {
        self.tracking(amount)
    }
}
