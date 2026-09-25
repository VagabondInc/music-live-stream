//
//  GlyphGrid.swift
//  ASCII Broadcast
//
//  The character field. Every cell records what drew it, how near it is, and
//  whether it is protected reading — so a foreground object can never
//  accidentally combine its contour with another object's density ramp
//  (Phase 1 §9).
//

import Foundation

struct GlyphCell {
    var scalar: UInt16 = 32
    var role: PaletteRole = .ground
    var intensity: Float = 1.0       // multiplies the role colour
    var depth: Float = 0             // 0 far ... 1 near; nearest owns the cell
    var entity: UInt16 = 0           // owning entity, for effects and masks
    var background: UInt8 = 255      // PaletteRole raw value, 255 = none
    var flags: UInt8 = 0

    static let protectedText: UInt8 = 1 << 0
    static let noEffect: UInt8 = 1 << 1
    static let motifMark: UInt8 = 1 << 2

    var isBlank: Bool { scalar == 32 && background == 255 }
    var isProtected: Bool { flags & GlyphCell.protectedText != 0 }

    static let empty = GlyphCell()
}

/// A complete frame of character state, handed to the rasteriser.
final class GlyphGrid {

    private(set) var columns: Int
    private(set) var rows: Int
    private(set) var cells: [GlyphCell]

    init(columns: Int, rows: Int) {
        self.columns = max(8, columns)
        self.rows = max(6, rows)
        self.cells = Array(repeating: .empty, count: self.columns * self.rows)
    }

    func resize(columns newColumns: Int, rows newRows: Int) {
        guard newColumns != columns || newRows != rows else { return }
        columns = max(8, newColumns)
        rows = max(6, newRows)
        cells = Array(repeating: .empty, count: columns * rows)
    }

    @inline(__always) func index(_ x: Int, _ y: Int) -> Int { y * columns + x }

    @inline(__always) func inBounds(_ x: Int, _ y: Int) -> Bool {
        x >= 0 && y >= 0 && x < columns && y < rows
    }

    func clear(role: PaletteRole = .ground) {
        var blank = GlyphCell.empty
        blank.role = role
        for i in 0..<cells.count { cells[i] = blank }
    }

    func cell(_ x: Int, _ y: Int) -> GlyphCell {
        guard inBounds(x, y) else { return .empty }
        return cells[index(x, y)]
    }

    // MARK: - Plotting

    /// Depth-tested write. Protected reading cells are never overwritten by
    /// world content.
    @inline(__always)
    func plot(_ x: Int, _ y: Int,
              _ scalar: UInt16,
              role: PaletteRole,
              intensity: Float = 1,
              depth: Float = 0.5,
              entity: UInt16 = 0,
              background: UInt8 = 255,
              flags: UInt8 = 0) {
        guard inBounds(x, y) else { return }
        let i = index(x, y)
        let existing = cells[i]
        if existing.isProtected && (flags & GlyphCell.protectedText) == 0 { return }
        if depth < existing.depth { return }
        cells[i] = GlyphCell(scalar: scalar,
                             role: role,
                             intensity: intensity,
                             depth: depth,
                             entity: entity,
                             background: background,
                             flags: flags)
    }

    /// Additive-feeling write used by atmosphere: only brightens a cell that is
    /// otherwise empty, so dust can never eat a silhouette.
    @inline(__always)
    func plotAtmosphere(_ x: Int, _ y: Int, _ scalar: UInt16, intensity: Float, depth: Float = 0.15) {
        guard inBounds(x, y) else { return }
        let i = index(x, y)
        guard cells[i].isBlank, !cells[i].isProtected else { return }
        cells[i] = GlyphCell(scalar: scalar, role: .atmosphere, intensity: intensity, depth: depth)
    }

    // MARK: - Primitives

    func horizontalLine(y: Int, from x0: Int, to x1: Int,
                        role: PaletteRole, intensity: Float = 1,
                        depth: Float = 0.5, entity: UInt16 = 0,
                        vocabulary: GlyphVocabulary, heavy: Bool = false) {
        let glyph = heavy ? vocabulary.heavyLines.horizontal : vocabulary.lines.horizontal
        for x in min(x0, x1)...max(x0, x1) {
            plot(x, y, glyph, role: role, intensity: intensity, depth: depth, entity: entity)
        }
    }

    func verticalLine(x: Int, from y0: Int, to y1: Int,
                      role: PaletteRole, intensity: Float = 1,
                      depth: Float = 0.5, entity: UInt16 = 0,
                      vocabulary: GlyphVocabulary, heavy: Bool = false) {
        let glyph = heavy ? vocabulary.heavyLines.vertical : vocabulary.lines.vertical
        for y in min(y0, y1)...max(y0, y1) {
            plot(x, y, glyph, role: role, intensity: intensity, depth: depth, entity: entity)
        }
    }

    /// Bresenham with orientation-aware glyph choice: a diagonal run reads as a
    /// diagonal, not as a staircase of pipes.
    func line(from p0: (Int, Int), to p1: (Int, Int),
              role: PaletteRole, intensity: Float = 1,
              depth: Float = 0.5, entity: UInt16 = 0,
              vocabulary: GlyphVocabulary) {
        var (x0, y0) = p0
        let (x1, y1) = p1
        let dx = abs(x1 - x0)
        let dy = -abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var error = dx + dy
        let steep = abs(y1 - y0) > abs(x1 - x0)
        let flat = abs(y1 - y0) * 3 < abs(x1 - x0)
        var guardCount = 0

        while guardCount < 8192 {
            guardCount += 1
            let glyph: UInt16
            if flat {
                glyph = vocabulary.lines.horizontal
            } else if steep && abs(x1 - x0) * 3 < abs(y1 - y0) {
                glyph = vocabulary.lines.vertical
            } else {
                glyph = (sx == sy) ? vocabulary.lines.diagonalDown : vocabulary.lines.diagonalUp
            }
            plot(x0, y0, glyph, role: role, intensity: intensity, depth: depth, entity: entity)
            if x0 == x1 && y0 == y1 { break }
            let doubled = 2 * error
            if doubled >= dy { error += dy; x0 += sx }
            if doubled <= dx { error += dx; y0 += sy }
        }
    }

    func box(x: Int, y: Int, width: Int, height: Int,
             role: PaletteRole, intensity: Float = 1,
             depth: Float = 0.5, entity: UInt16 = 0,
             vocabulary: GlyphVocabulary, heavy: Bool = false) {
        guard width > 1, height > 1 else { return }
        let set = heavy ? vocabulary.heavyLines : vocabulary.lines
        let right = x + width - 1
        let bottom = y + height - 1
        for column in (x + 1)..<right {
            plot(column, y, set.horizontal, role: role, intensity: intensity, depth: depth, entity: entity)
            plot(column, bottom, set.horizontal, role: role, intensity: intensity, depth: depth, entity: entity)
        }
        for row in (y + 1)..<bottom {
            plot(x, row, set.vertical, role: role, intensity: intensity, depth: depth, entity: entity)
            plot(right, row, set.vertical, role: role, intensity: intensity, depth: depth, entity: entity)
        }
        plot(x, y, set.topLeft, role: role, intensity: intensity, depth: depth, entity: entity)
        plot(right, y, set.topRight, role: role, intensity: intensity, depth: depth, entity: entity)
        plot(x, bottom, set.bottomLeft, role: role, intensity: intensity, depth: depth, entity: entity)
        plot(right, bottom, set.bottomRight, role: role, intensity: intensity, depth: depth, entity: entity)
    }

    func fill(x: Int, y: Int, width: Int, height: Int,
              scalar: UInt16, role: PaletteRole, intensity: Float = 1,
              depth: Float = 0.4, entity: UInt16 = 0) {
        guard width > 0, height > 0 else { return }
        for row in y..<(y + height) {
            for column in x..<(x + width) {
                plot(column, row, scalar, role: role, intensity: intensity, depth: depth, entity: entity)
            }
        }
    }

    // MARK: - Text

    /// Environmental or diegetic text. `protected` marks the run as reading
    /// content that world geometry must not overwrite.
    @discardableResult
    func text(_ string: String, x: Int, y: Int,
              role: PaletteRole = .text,
              intensity: Float = 1,
              depth: Float = 0.95,
              entity: UInt16 = 0,
              protected: Bool = false,
              tracking: Int = 0,
              background: UInt8 = 255) -> Int {
        var cursor = x
        let flags: UInt8 = protected ? (GlyphCell.protectedText | GlyphCell.noEffect) : 0
        for scalar in GlyphVocabulary.scalars(string) {
            guard cursor < columns else { break }
            if cursor >= 0 {
                let i = index(cursor, clamp(y, 0, rows - 1))
                if inBounds(cursor, y) {
                    if protected || cells[i].depth <= depth {
                        cells[i] = GlyphCell(scalar: scalar, role: role, intensity: intensity,
                                             depth: depth, entity: entity,
                                             background: background, flags: flags)
                    }
                }
            }
            cursor += 1 + tracking
        }
        return cursor - x
    }

    /// Reserve a quiet region so a title can be read over a busy scene.
    func protectRegion(x: Int, y: Int, width: Int, height: Int, dim: Float) {
        for row in y..<(y + height) {
            for column in x..<(x + width) {
                guard inBounds(column, row) else { continue }
                let i = index(column, row)
                if cells[i].isProtected { continue }
                cells[i].intensity *= dim
                cells[i].flags |= GlyphCell.noEffect
            }
        }
    }

    // MARK: - Measurements

    /// Fraction of non-blank cells; the director uses it to hold the DNA's
    /// density target instead of letting scenes creep towards full.
    var fillFraction: Double {
        var filled = 0
        for cell in cells where !cell.isBlank { filled += 1 }
        return Double(filled) / Double(max(1, cells.count))
    }

    /// Mean luminance proxy for the safety envelope, computed on roles before
    /// rasterisation so the check is cheap.
    func meanIntensity(palette: Palette) -> Double {
        var sum = 0.0
        for cell in cells where !cell.isBlank {
            sum += palette.color(cell.role).luminance * Double(cell.intensity)
        }
        return sum / Double(max(1, cells.count))
    }

    func copyCells() -> [GlyphCell] { cells }

    func replaceCells(_ newCells: [GlyphCell]) {
        guard newCells.count == cells.count else { return }
        cells = newCells
    }

    /// Mutate one cell in place (used by the effect stage).
    @inline(__always)
    func mutate(_ x: Int, _ y: Int, _ transform: (inout GlyphCell) -> Void) {
        guard inBounds(x, y) else { return }
        transform(&cells[index(x, y)])
    }
}
