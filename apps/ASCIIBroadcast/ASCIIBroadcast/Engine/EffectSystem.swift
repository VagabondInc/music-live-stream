//
//  EffectSystem.swift
//  ASCII Broadcast
//
//  Phase 1 §15. Effects are orchestrated, never sprayed. Each one is masked by
//  ownership, spends from a global intensity budget, and refuses to touch
//  protected reading cells.
//

import Foundation

struct EffectSystem {

    /// Total effect intensity allowed in one frame. Prevents the "effect
    /// lottery" where four systems fire at once and the subject disappears.
    static let frameBudget = 1.35

    static func apply(_ cues: [ScoreFXCue],
                      to grid: GlyphGrid,
                      time: Double,
                      snapshot: RenderSnapshot,
                      vocabulary: GlyphVocabulary) {
        var spent = 0.0
        for cue in cues.sorted(by: { $0.intensity > $1.intensity }) {
            if snapshot.dna.photosensitivitySafe && !cue.kind.isSafeUnderPhotosensitivity { continue }
            let progress = clamp((time - cue.start) / max(0.01, cue.duration), 0, 1)
            let envelope = sin(progress * .pi)                     // in and out
            let strength = cue.intensity * envelope * clamp(snapshot.dna.effectiveGlitch + 0.35, 0, 1)
            guard strength > 0.02, spent + strength <= frameBudget else { continue }
            spent += strength
            run(cue.kind, grid: grid, strength: strength, progress: progress,
                snapshot: snapshot, vocabulary: vocabulary)
        }
    }

    private static func run(_ kind: SignalFXKind,
                            grid: GlyphGrid,
                            strength: Double,
                            progress: Double,
                            snapshot: RenderSnapshot,
                            vocabulary: GlyphVocabulary) {
        switch kind {
        case .characterRain:  characterRain(grid, strength, snapshot, vocabulary)
        case .shockwave:      shockwave(grid, strength, progress, snapshot, vocabulary)
        case .fragmentation:  fragmentation(grid, strength, snapshot, vocabulary)
        case .scanDeform:     scanDeform(grid, strength, snapshot)
        case .corruption:     corruption(grid, strength, snapshot, vocabulary)
        case .pixelSort:      pixelSort(grid, strength, snapshot)
        case .inversion:      inversion(grid, strength)
        case .dissolveField:  dissolveField(grid, strength, snapshot, vocabulary)
        }
    }

    // MARK: - Effects

    private static func characterRain(_ grid: GlyphGrid, _ strength: Double,
                                      _ snapshot: RenderSnapshot, _ vocabulary: GlyphVocabulary) {
        let columnsTouched = Int(Double(grid.columns) * 0.18 * strength)
        guard columnsTouched > 0 else { return }
        let ramp = vocabulary.ramp
        for step in 0..<columnsTouched {
            let column = Int(Noise.hash(step, 3, snapshot.cue.seed) * Double(grid.columns))
            let speed = 12.0 + Noise.hash(step, 5, snapshot.cue.seed) * 26.0
            let head = Int((snapshot.sceneTime * speed).truncatingRemainder(dividingBy: Double(grid.rows + 12)))
            let tail = 4 + Int(strength * 8)
            for offset in 0..<tail {
                let row = head - offset
                guard row >= 0, row < grid.rows else { continue }
                let fade = 1.0 - Double(offset) / Double(tail)
                grid.mutate(column, row) { cell in
                    guard cell.flags & GlyphCell.noEffect == 0 else { return }
                    cell.scalar = ramp[min(ramp.count - 1, Int(fade * Double(ramp.count - 1)))]
                    cell.role = offset == 0 ? .accent : .memory
                    cell.intensity = Float(max(Double(cell.intensity), fade * strength))
                }
            }
        }
    }

    private static func shockwave(_ grid: GlyphGrid, _ strength: Double, _ progress: Double,
                                  _ snapshot: RenderSnapshot, _ vocabulary: GlyphVocabulary) {
        // A typographic shockwave from the frame's focal point.
        let centreX = Double(grid.columns) * 0.5
        let centreY = Double(grid.rows) * 0.5
        let maxRadius = Double(max(grid.columns, grid.rows)) * 0.6
        let radius = progress * maxRadius
        let thickness = 1.5 + strength * 2.5
        let glyphs = vocabulary.flowGlyphs
        var y = 0
        while y < grid.rows {
            var x = 0
            while x < grid.columns {
                let dx = Double(x) - centreX
                let dy = (Double(y) - centreY) * 2.0        // 2:1 cells
                let distance = sqrt(dx * dx + dy * dy)
                if abs(distance - radius) < thickness {
                    grid.mutate(x, y) { cell in
                        guard cell.flags & GlyphCell.noEffect == 0 else { return }
                        cell.scalar = glyphs[(x &+ y) % glyphs.count]
                        cell.role = .accent
                        cell.intensity = Float(clamp(Double(cell.intensity) + strength * 0.8, 0, 1))
                    }
                }
                x += 1
            }
            y += 1
        }
    }

    private static func fragmentation(_ grid: GlyphGrid, _ strength: Double,
                                      _ snapshot: RenderSnapshot, _ vocabulary: GlyphVocabulary) {
        // Horizontal slabs slip sideways. Ownership is preserved: a slab moves
        // whole rather than smearing one object into another.
        let slabCount = 2 + Int(strength * 6)
        let cells = grid.copyCells()
        for slab in 0..<slabCount {
            let seedValue = Noise.hash(slab, 17, snapshot.cue.seed)
            let top = Int(seedValue * Double(grid.rows))
            let height = 1 + Int(Noise.hash(slab, 19, snapshot.cue.seed) * 4)
            let shift = Int((Noise.hash(slab, 23, snapshot.cue.seed) - 0.5) * 26 * strength)
            guard shift != 0 else { continue }
            for row in top..<min(grid.rows, top + height) {
                for column in 0..<grid.columns {
                    let source = column - shift
                    guard source >= 0, source < grid.columns else { continue }
                    let sourceCell = cells[row * grid.columns + source]
                    grid.mutate(column, row) { cell in
                        guard cell.flags & GlyphCell.noEffect == 0 else { return }
                        guard sourceCell.flags & GlyphCell.protectedText == 0 else { return }
                        cell = sourceCell
                    }
                }
            }
        }
    }

    private static func scanDeform(_ grid: GlyphGrid, _ strength: Double, _ snapshot: RenderSnapshot) {
        let amplitude = strength * 3.0
        guard amplitude >= 1 else { return }
        let cells = grid.copyCells()
        for row in 0..<grid.rows {
            let phase = Double(row) * 0.35 + snapshot.sceneTime * 4.0
            let shift = Int(sin(phase) * amplitude)
            guard shift != 0 else { continue }
            for column in 0..<grid.columns {
                let source = clamp(column - shift, 0, grid.columns - 1)
                let sourceCell = cells[row * grid.columns + source]
                grid.mutate(column, row) { cell in
                    guard cell.flags & GlyphCell.noEffect == 0 else { return }
                    guard sourceCell.flags & GlyphCell.protectedText == 0 else { return }
                    cell = sourceCell
                }
            }
        }
    }

    private static func corruption(_ grid: GlyphGrid, _ strength: Double,
                                   _ snapshot: RenderSnapshot, _ vocabulary: GlyphVocabulary) {
        let count = Int(Double(grid.columns * grid.rows) * 0.02 * strength)
        guard count > 0 else { return }
        let ramp = vocabulary.ramp
        var generator = SeededGenerator(seed: snapshot.cue.seed &+ UInt64(snapshot.frameIndex / 3),
                                        stream: "corrupt")
        for _ in 0..<count {
            let x = generator.index(grid.columns)
            let y = generator.index(grid.rows)
            grid.mutate(x, y) { cell in
                guard cell.flags & GlyphCell.noEffect == 0 else { return }
                cell.scalar = ramp[generator.index(ramp.count)]
                cell.role = generator.chance(0.3) ? .accent : cell.role
            }
        }
    }

    private static func pixelSort(_ grid: GlyphGrid, _ strength: Double, _ snapshot: RenderSnapshot) {
        // Sort runs of cells by intensity: the ASCII equivalent of pixel sorting.
        let rowsTouched = Int(Double(grid.rows) * 0.25 * strength)
        guard rowsTouched > 0 else { return }
        for step in 0..<rowsTouched {
            let row = Int(Noise.hash(step, 29, snapshot.cue.seed) * Double(grid.rows))
            guard row >= 0, row < grid.rows else { continue }
            let start = Int(Noise.hash(step, 31, snapshot.cue.seed) * Double(grid.columns) * 0.6)
            let length = 8 + Int(strength * 40)
            let end = min(grid.columns - 1, start + length)
            guard end > start + 2 else { continue }

            var run: [GlyphCell] = []
            var protectedFound = false
            for column in start...end {
                let cell = grid.cell(column, row)
                if cell.flags & GlyphCell.noEffect != 0 { protectedFound = true; break }
                run.append(cell)
            }
            guard !protectedFound, run.count > 2 else { continue }
            run.sort { $0.intensity < $1.intensity }
            for (offset, cell) in run.enumerated() {
                grid.mutate(start + offset, row) { $0 = cell }
            }
        }
    }

    private static func inversion(_ grid: GlyphGrid, _ strength: Double) {
        // Swapped foreground and ground. Excluded under Photosensitivity Safe.
        for y in 0..<grid.rows {
            for x in 0..<grid.columns {
                grid.mutate(x, y) { cell in
                    guard cell.flags & GlyphCell.noEffect == 0 else { return }
                    if cell.isBlank {
                        cell.background = PaletteRole.structure.rawValue
                        cell.intensity = Float(strength * 0.5)
                    } else {
                        cell.role = cell.role == .ground ? .subject : .ground
                    }
                }
            }
        }
    }

    private static func dissolveField(_ grid: GlyphGrid, _ strength: Double,
                                      _ snapshot: RenderSnapshot, _ vocabulary: GlyphVocabulary) {
        // Stable spatial dither, anchored to the grid: slow movement must not
        // become random sparkle (Phase 1 §10).
        let threshold = 1.0 - strength
        for y in 0..<grid.rows {
            for x in 0..<grid.columns {
                let stable = Noise.hash(x, y, snapshot.cue.seed)
                guard stable > threshold else { continue }
                grid.mutate(x, y) { cell in
                    guard cell.flags & GlyphCell.noEffect == 0 else { return }
                    cell.scalar = GlyphVocabulary.space
                    cell.background = 255
                }
            }
        }
    }
}
