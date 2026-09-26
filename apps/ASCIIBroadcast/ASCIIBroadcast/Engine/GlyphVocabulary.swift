//
//  GlyphVocabulary.swift
//  ASCII Broadcast
//
//  Phase 1 §11. Three deliberate art vocabularies, functional glyph subsets,
//  and a substitution graph so a mark can morph through shapes that share an
//  authored action instead of through arbitrary alphanumeric noise.
//
//  The vocabulary applies to ART glyphs only. Song titles and artist names go
//  through the shaped-text path and keep their real scripts.
//

import Foundation

enum GlyphRole {
    case contour        // silhouettes and outlines
    case junction       // where lines meet
    case mass           // filled interior
    case grain          // texture, dithering
    case flow           // movement, direction
    case agent          // little creatures made of punctuation
    case language       // diegetic text
    case blank          // space is a first-class glyph
}

/// A measured, bounded set of scalars the renderer is allowed to emit.
struct GlyphVocabulary {

    let profile: GlyphProfile

    // MARK: Density ramps (dark -> light coverage)

    /// Strict ASCII keeps to printable U+0020...U+007E.
    private static let asciiRamp: [UInt16] = Array(" .`',:;\"~-_+=*i?xX%#@$".unicodeScalars.map { UInt16($0.value) })
    private static let terminalRamp: [UInt16] = Array(" .:-=+*#%\u{2591}\u{2592}\u{2593}\u{2588}".unicodeScalars.map { UInt16($0.value) })
    private static let expandedRamp: [UInt16] = Array(" \u{2802}\u{2806}\u{2846}\u{28C6}\u{28E6}\u{28F6}\u{28FE}\u{28FF}\u{2591}\u{2592}\u{2593}\u{2588}".unicodeScalars.map { UInt16($0.value) })

    var ramp: [UInt16] {
        switch profile {
        case .strictASCII: return GlyphVocabulary.asciiRamp
        case .terminal:    return GlyphVocabulary.terminalRamp
        case .expanded:    return GlyphVocabulary.expandedRamp
        }
    }

    // MARK: Line and junction sets

    struct LineSet {
        let horizontal: UInt16
        let vertical: UInt16
        let topLeft: UInt16
        let topRight: UInt16
        let bottomLeft: UInt16
        let bottomRight: UInt16
        let teeDown: UInt16
        let teeUp: UInt16
        let teeRight: UInt16
        let teeLeft: UInt16
        let cross: UInt16
        let diagonalDown: UInt16
        let diagonalUp: UInt16
    }

    private static let asciiLines = LineSet(
        horizontal: u("-"), vertical: u("|"),
        topLeft: u("."), topRight: u("."), bottomLeft: u("'"), bottomRight: u("'"),
        teeDown: u("+"), teeUp: u("+"), teeRight: u("+"), teeLeft: u("+"),
        cross: u("+"), diagonalDown: u("\\"), diagonalUp: u("/")
    )

    private static let boxLines = LineSet(
        horizontal: 0x2500, vertical: 0x2502,
        topLeft: 0x250C, topRight: 0x2510, bottomLeft: 0x2514, bottomRight: 0x2518,
        teeDown: 0x252C, teeUp: 0x2534, teeRight: 0x251C, teeLeft: 0x2524,
        cross: 0x253C, diagonalDown: 0x2572, diagonalUp: 0x2571
    )

    var lines: LineSet {
        profile == .strictASCII ? GlyphVocabulary.asciiLines : GlyphVocabulary.boxLines
    }

    /// Heavy variants read as structure that carries load.
    var heavyLines: LineSet {
        guard profile != .strictASCII else { return GlyphVocabulary.asciiLines }
        return LineSet(
            horizontal: 0x2501, vertical: 0x2503,
            topLeft: 0x250F, topRight: 0x2513, bottomLeft: 0x2517, bottomRight: 0x251B,
            teeDown: 0x2533, teeUp: 0x253B, teeRight: 0x2523, teeLeft: 0x252B,
            cross: 0x254B, diagonalDown: 0x2572, diagonalUp: 0x2571
        )
    }

    // MARK: Functional subsets

    var agents: [UInt16] {
        Array("()[]{}<>".unicodeScalars.map { UInt16($0.value) })
    }

    var marks: [UInt16] {
        Array(".,:;'\"`^~*".unicodeScalars.map { UInt16($0.value) })
    }

    var flowGlyphs: [UInt16] {
        profile == .strictASCII
            ? Array("/\\|_-~".unicodeScalars.map { UInt16($0.value) })
            : [0x2571, 0x2572, 0x2502, 0x2500, 0x223C, 0x2508]
    }

    var blocks: [UInt16] {
        profile == .strictASCII
            ? Array("#%*+=:.".unicodeScalars.map { UInt16($0.value) })
            : [0x2588, 0x2593, 0x2592, 0x2591, 0x25AA, 0x00B7]
    }

    static let space: UInt16 = 32

    // MARK: Selection

    /// Coverage 0...1 to a glyph. Hysteresis is applied by the caller so slow
    /// changes do not turn into per-frame sparkle.
    func glyph(coverage: Double) -> UInt16 {
        let table = ramp
        guard !table.isEmpty else { return GlyphVocabulary.space }
        let index = Int(clamp(coverage, 0, 1) * Double(table.count - 1) + 0.5)
        return table[clamp(index, 0, table.count - 1)]
    }

    /// Connectivity wins over brightness for lines and junctions (Phase 1 §10).
    func junction(up: Bool, down: Bool, left: Bool, right: Bool, heavy: Bool = false) -> UInt16 {
        let set = heavy ? heavyLines : lines
        switch (up, down, left, right) {
        case (true, true, true, true):    return set.cross
        case (true, true, true, false):   return set.teeLeft
        case (true, true, false, true):   return set.teeRight
        case (true, false, true, true):   return set.teeUp
        case (false, true, true, true):   return set.teeDown
        case (true, true, false, false):  return set.vertical
        case (false, false, true, true):  return set.horizontal
        case (true, false, false, true):  return set.bottomLeft
        case (true, false, true, false):  return set.bottomRight
        case (false, true, false, true):  return set.topLeft
        case (false, true, true, false):  return set.topRight
        case (true, false, false, false),
             (false, true, false, false): return set.vertical
        case (false, false, true, false),
             (false, false, false, true): return set.horizontal
        default:                          return set.cross
        }
    }

    // MARK: Substitution graph

    /// A hinge evolves `.` -> `:` -> `|` -> `[` because those shapes share an
    /// authored action. Semantic letters never enter this graph.
    private static let hingePath: [UInt16] = [u("."), u(":"), u("|"), u("["), u("#")]
    private static let aperturePath: [UInt16] = [u("."), u("o"), u("O"), u("0"), u("@")]
    private static let threadPath: [UInt16] = [u("`"), u("'"), u("-"), u("="), u("#")]

    enum SubstitutionPath {
        case hinge
        case aperture
        case thread
    }

    func morph(_ path: SubstitutionPath, progress: Double) -> UInt16 {
        let table: [UInt16]
        switch path {
        case .hinge:    table = GlyphVocabulary.hingePath
        case .aperture: table = GlyphVocabulary.aperturePath
        case .thread:   table = GlyphVocabulary.threadPath
        }
        let index = Int(clamp(progress, 0, 1) * Double(table.count - 1) + 0.5)
        return table[clamp(index, 0, table.count - 1)]
    }

    // MARK: Text

    /// Scalars for diegetic text. Art profile never rewrites metadata, but
    /// environmental signage is generated by us and is safe to constrain.
    static func scalars(_ string: String) -> [UInt16] {
        string.unicodeScalars.compactMap { scalar in
            scalar.value <= 0xFFFF ? UInt16(scalar.value) : nil
        }
    }

}

/// Local helper: `Character` to a BMP scalar the grid can store.
private func u(_ character: Character) -> UInt16 {
    UInt16(character.unicodeScalars.first?.value ?? 32)
}
