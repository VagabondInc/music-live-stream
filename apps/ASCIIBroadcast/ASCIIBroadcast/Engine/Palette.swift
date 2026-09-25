//
//  Palette.swift
//  ASCII Broadcast
//
//  Phase 1 §12. Semantic roles, not free RGB. A scene asks for "subject" and
//  the palette decides what that means in this broadcast, under this
//  accessibility profile.
//

import Foundation
import CoreGraphics

/// Semantic colour roles. Everything the engine draws claims one.
enum PaletteRole: UInt8, Codable, CaseIterable {
    case ground = 0      // the field itself
    case structure = 1   // world separated from ground
    case subject = 2     // the focal entity
    case accent = 3      // signal, warning, arrival
    case memory = 4      // marks carried from earlier
    case atmosphere = 5  // dust, residue, weather
    case text = 6        // protected reading
    case shadow = 7      // recessive detail
}

struct RGB: Hashable {
    var r: Double
    var g: Double
    var b: Double

    static func hex(_ value: UInt32) -> RGB {
        RGB(r: Double((value >> 16) & 0xFF) / 255.0,
            g: Double((value >> 8) & 0xFF) / 255.0,
            b: Double(value & 0xFF) / 255.0)
    }

    func scaled(_ factor: Double) -> RGB {
        RGB(r: clamp(r * factor, 0, 1), g: clamp(g * factor, 0, 1), b: clamp(b * factor, 0, 1))
    }

    func mixed(with other: RGB, _ t: Double) -> RGB {
        RGB(r: lerp(r, other.r, t), g: lerp(g, other.g, t), b: lerp(b, other.b, t))
    }

    /// Rec.709 relative luminance — the quantity the safety envelope limits.
    var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }

    var cgColor: CGColor {
        CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [r, g, b, 1.0])
            ?? CGColor(gray: CGFloat(luminance), alpha: 1)
    }
}

struct Palette {
    var id: String
    var name: String
    var background: RGB
    var colors: [PaletteRole: RGB]

    func color(_ role: PaletteRole) -> RGB {
        colors[role] ?? RGB.hex(0xE0DCD4)
    }

    // MARK: - Authored palettes

    static let nightTransit = Palette(
        id: "night-transit",
        name: "NIGHT TRANSIT",
        background: RGB.hex(0x05080A),
        colors: [
            .ground:     RGB.hex(0x16242B),
            .structure:  RGB.hex(0x4E8FA6),
            .subject:    RGB.hex(0xD9E2E6),
            .accent:     RGB.hex(0xE8982F),
            .memory:     RGB.hex(0x2F6E80),
            .atmosphere: RGB.hex(0x2A3E46),
            .text:       RGB.hex(0xEDE7DD),
            .shadow:     RGB.hex(0x0D1519)
        ]
    )

    static let livingIndex = Palette(
        id: "living-index",
        name: "LIVING INDEX",
        background: RGB.hex(0x0A0907),
        colors: [
            .ground:     RGB.hex(0x241F18),
            .structure:  RGB.hex(0xA08F6A),
            .subject:    RGB.hex(0xF0E6D2),
            .accent:     RGB.hex(0x86A66B),
            .memory:     RGB.hex(0x6E5A3C),
            .atmosphere: RGB.hex(0x3A332A),
            .text:       RGB.hex(0xF2EADA),
            .shadow:     RGB.hex(0x13100C)
        ]
    )

    static let tidalInstrument = Palette(
        id: "tidal-instrument",
        name: "TIDAL INSTRUMENT",
        background: RGB.hex(0x04070D),
        colors: [
            .ground:     RGB.hex(0x101C2E),
            .structure:  RGB.hex(0x3D6E9C),
            .subject:    RGB.hex(0xCFE3EE),
            .accent:     RGB.hex(0x8FD3C4),
            .memory:     RGB.hex(0x2B4A66),
            .atmosphere: RGB.hex(0x1B2C40),
            .text:       RGB.hex(0xE6EEF4),
            .shadow:     RGB.hex(0x080D16)
        ]
    )

    static func authored(for direction: WorldDirection) -> Palette {
        switch direction {
        case .nightTransit:    return .nightTransit
        case .livingIndex:     return .livingIndex
        case .tidalInstrument: return .tidalInstrument
        }
    }

    // MARK: - Behaviour and accessibility

    /// Apply the DNA's colour behaviour and accessibility envelope.
    /// Colour is never the only carrier of information: roles also differ in
    /// glyph vocabulary and luminance, so a colour-blind-safe pass stays legible.
    func adjusted(behaviour: ColorBehavior, colorBlindSafe: Bool, drift: Double = 0) -> Palette {
        var out = self
        switch behaviour {
        case .monochrome:
            let base = color(.subject)
            for role in PaletteRole.allCases {
                let luminance = color(role).luminance
                out.colors[role] = base.scaled(clamp(0.25 + luminance * 1.2, 0.08, 1.0))
            }
        case .restrained:
            for role in PaletteRole.allCases where role != .accent {
                let original = color(role)
                let grey = RGB(r: original.luminance, g: original.luminance, b: original.luminance)
                out.colors[role] = original.mixed(with: grey, 0.35)
            }
        case .duotone:
            let a = color(.structure)
            let b = color(.accent)
            for role in PaletteRole.allCases {
                let luminance = clamp(color(role).luminance * 1.4, 0, 1)
                out.colors[role] = a.mixed(with: b, luminance)
            }
            out.colors[.text] = color(.text)
        case .saturated:
            break
        }

        if colorBlindSafe {
            // Separate accent from structure on the blue/yellow axis and keep a
            // clear luminance gap, which survives all three common deficiencies.
            out.colors[.accent] = RGB.hex(0xF0B429)
            out.colors[.structure] = RGB.hex(0x4C9BD1)
            out.colors[.memory] = RGB.hex(0x7F8C99)
        }

        if drift != 0 {
            let warm = RGB.hex(0xE8A64C)
            let cool = RGB.hex(0x4C88E8)
            let target = drift > 0 ? warm : cool
            let amount = min(0.22, abs(drift))
            for role in PaletteRole.allCases where role != .text {
                out.colors[role] = out.color(role).mixed(with: target, amount)
            }
        }
        return out
    }

    /// Photosensitivity Safe reduces the maximum luminance span so an effect
    /// cannot swing the whole field between extremes.
    func photosensitivityLimited() -> Palette {
        var out = self
        for role in PaletteRole.allCases {
            let original = color(role)
            out.colors[role] = original.scaled(clamp(0.92, 0, 1)).mixed(with: RGB(r: 0.16, g: 0.17, b: 0.18), 0.12)
        }
        return out
    }
}
