//
//  TransitionEngine.swift
//  ASCII Broadcast
//
//  Phase 1 §17. A track change is part of the performance. Two scenes are
//  rendered and composited by a bridge chosen for musical compatibility, with
//  an anti-repeat rule so the same trick never lands twice in a row.
//

import Foundation

struct TransitionEngine {

    /// Choose a bridge from the outgoing/incoming musical relationship.
    static func choose(outgoing: TrackAnalysis?,
                       incoming: TrackAnalysis?,
                       recentKinds: [TransitionKind],
                       variety: Double,
                       generator: inout SeededGenerator) -> TransitionKind {

        let tempoDelta = abs((outgoing?.tempo ?? 0) - (incoming?.tempo ?? 0))
        let energyDelta = abs((outgoing?.energy ?? 0) - (incoming?.energy ?? 0))
        let brightnessDelta = abs((outgoing?.brightness ?? 0) - (incoming?.brightness ?? 0))

        var candidates: [TransitionKind: Double] = [:]

        // Compatible tempo: a beat-matched cut reads as intentional.
        if tempoDelta < 4 && (outgoing?.tempoConfidence ?? 0) > 0.5 {
            candidates[.beatMatch] = 1.0
            candidates[.objectHandoff] = 0.8
        }
        // A big energy drop wants space, not a cut.
        if energyDelta > 0.3 {
            candidates[.negativeSpace] = 1.0
            candidates[.dissolve] = 0.7
        }
        // Similar material: carry something across.
        if energyDelta < 0.15 && brightnessDelta < 0.2 {
            candidates[.objectHandoff] = (candidates[.objectHandoff] ?? 0) + 0.9
            candidates[.crossfade] = 0.6
        }
        // A hard stylistic change earns a reset.
        if tempoDelta > 25 || brightnessDelta > 0.4 {
            candidates[.terminalReset] = 0.9
            candidates[.glitch] = 0.6
        }
        if candidates.isEmpty {
            candidates = [.dissolve: 1.0, .crossfade: 0.7, .objectHandoff: 0.6]
        }

        // Anti-repetition: the last two bridges are heavily penalised.
        for (index, kind) in recentKinds.suffix(2).enumerated() {
            let penalty = index == 1 ? 0.12 : 0.35
            if let weight = candidates[kind] { candidates[kind] = weight * penalty }
        }
        // Variety pushes weight towards the less obvious option.
        if variety > 0.6 {
            for kind in [TransitionKind.negativeSpace, .terminalReset, .objectHandoff] {
                candidates[kind] = (candidates[kind] ?? 0.2) * (1 + variety)
            }
        }

        let total = candidates.values.reduce(0, +)
        guard total > 0 else { return .dissolve }
        var roll = generator.unit() * total
        for (kind, weight) in candidates.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            roll -= weight
            if roll <= 0 { return kind }
        }
        return .dissolve
    }

    // MARK: - Compositing

    static func composite(outgoing: GlyphGrid,
                          incoming: GlyphGrid,
                          into target: GlyphGrid,
                          kind: TransitionKind,
                          progress: Double,
                          seed: UInt64,
                          carrier: MotifCarrierState?,
                          vocabulary: GlyphVocabulary) {

        let t = clamp(progress, 0, 1)
        let columns = target.columns
        let rows = target.rows
        guard outgoing.columns == columns, incoming.columns == columns,
              outgoing.rows == rows, incoming.rows == rows else {
            target.replaceCells(incoming.copyCells())
            return
        }

        switch kind {
        case .dissolve, .fadeIn, .fadeOut:
            stableDissolve(outgoing, incoming, target, t, seed)
        case .crossfade:
            intensityBlend(outgoing, incoming, target, t)
        case .beatMatch:
            columnWipe(outgoing, incoming, target, t, blockWidth: max(4, columns / 24))
        case .glitch:
            glitchSlabs(outgoing, incoming, target, t, seed)
        case .hold:
            target.replaceCells(t < 0.88 ? outgoing.copyCells() : incoming.copyCells())
        case .objectHandoff:
            radialHandoff(outgoing, incoming, target, t, carrier)
        case .negativeSpace:
            throughNothing(outgoing, incoming, target, t, seed)
        case .terminalReset:
            terminalReset(outgoing, incoming, target, t, vocabulary)
        }
    }

    // MARK: - Bridges

    private static func stableDissolve(_ a: GlyphGrid, _ b: GlyphGrid, _ out: GlyphGrid,
                                       _ t: Double, _ seed: UInt64) {
        for y in 0..<out.rows {
            for x in 0..<out.columns {
                let threshold = Noise.hash(x, y, seed)
                let cell = threshold < t ? b.cell(x, y) : a.cell(x, y)
                out.mutate(x, y) { $0 = cell }
            }
        }
    }

    private static func intensityBlend(_ a: GlyphGrid, _ b: GlyphGrid, _ out: GlyphGrid, _ t: Double) {
        for y in 0..<out.rows {
            for x in 0..<out.columns {
                let outgoing = a.cell(x, y)
                let incoming = b.cell(x, y)
                var cell = t < 0.5 ? outgoing : incoming
                let fade = t < 0.5 ? (1 - t * 2) : ((t - 0.5) * 2)
                if incoming.isBlank && !outgoing.isBlank && t >= 0.5 {
                    cell = outgoing
                    cell.intensity = Float(Double(outgoing.intensity) * (1 - fade))
                } else {
                    cell.intensity = Float(clamp(Double(cell.intensity) * (0.35 + fade * 0.65), 0, 1))
                }
                out.mutate(x, y) { $0 = cell }
            }
        }
    }

    private static func columnWipe(_ a: GlyphGrid, _ b: GlyphGrid, _ out: GlyphGrid,
                                   _ t: Double, blockWidth: Int) {
        let blocks = max(1, out.columns / max(1, blockWidth))
        let revealed = Int(Double(blocks) * t)
        for y in 0..<out.rows {
            for x in 0..<out.columns {
                let block = x / max(1, blockWidth)
                let cell = block < revealed ? b.cell(x, y) : a.cell(x, y)
                out.mutate(x, y) { $0 = cell }
            }
        }
    }

    private static func glitchSlabs(_ a: GlyphGrid, _ b: GlyphGrid, _ out: GlyphGrid,
                                    _ t: Double, _ seed: UInt64) {
        for y in 0..<out.rows {
            let slab = y / 3
            let bias = Noise.hash(slab, 7, seed)
            let shifted = bias < t
            let shift = shifted ? Int((bias - 0.5) * 16 * (1 - t)) : 0
            for x in 0..<out.columns {
                let source = clamp(x - shift, 0, out.columns - 1)
                let cell = shifted ? b.cell(source, y) : a.cell(x, y)
                out.mutate(x, y) { $0 = cell }
            }
        }
    }

    private static func radialHandoff(_ a: GlyphGrid, _ b: GlyphGrid, _ out: GlyphGrid,
                                      _ t: Double, _ carrier: MotifCarrierState?) {
        // The new world grows out of the object we carried across.
        let centreX = (carrier?.x ?? 0.5) * Double(out.columns)
        let centreY = (carrier?.y ?? 0.5) * Double(out.rows)
        let maxRadius = Double(max(out.columns, out.rows)) * 0.85
        let radius = smoothstep(0, 1, t) * maxRadius
        for y in 0..<out.rows {
            for x in 0..<out.columns {
                let dx = Double(x) - centreX
                let dy = (Double(y) - centreY) * 2.0
                let distance = sqrt(dx * dx + dy * dy)
                var cell = distance < radius ? b.cell(x, y) : a.cell(x, y)
                if abs(distance - radius) < 1.5 {
                    cell.role = .accent
                    cell.intensity = 1
                }
                out.mutate(x, y) { $0 = cell }
            }
        }
    }

    private static func throughNothing(_ a: GlyphGrid, _ b: GlyphGrid, _ out: GlyphGrid,
                                       _ t: Double, _ seed: UInt64) {
        // Subtract the old world completely, hold the emptiness, then build.
        if t < 0.45 {
            let erosion = t / 0.45
            for y in 0..<out.rows {
                for x in 0..<out.columns {
                    let threshold = Noise.hash(x, y, seed)
                    var cell = a.cell(x, y)
                    if threshold < erosion { cell = .empty }
                    out.mutate(x, y) { $0 = cell }
                }
            }
        } else if t < 0.58 {
            out.clear()
        } else {
            let growth = (t - 0.58) / 0.42
            for y in 0..<out.rows {
                for x in 0..<out.columns {
                    let threshold = Noise.hash(x, y, seed &+ 99)
                    let cell = threshold < growth ? b.cell(x, y) : GlyphCell.empty
                    out.mutate(x, y) { $0 = cell }
                }
            }
        }
    }

    private static func terminalReset(_ a: GlyphGrid, _ b: GlyphGrid, _ out: GlyphGrid,
                                      _ t: Double, _ vocabulary: GlyphVocabulary) {
        // Clear downwards with a scan line, then let the new world print in.
        let clearRow = Int(Double(out.rows) * min(1, t * 2))
        let printRow = Int(Double(out.rows) * max(0, (t - 0.5) * 2))
        for y in 0..<out.rows {
            for x in 0..<out.columns {
                var cell: GlyphCell
                if y < printRow {
                    cell = b.cell(x, y)
                } else if y < clearRow {
                    cell = .empty
                } else {
                    cell = a.cell(x, y)
                }
                if y == clearRow || y == printRow {
                    cell.scalar = vocabulary.lines.horizontal
                    cell.role = .accent
                    cell.intensity = 0.9
                }
                out.mutate(x, y) { $0 = cell }
            }
        }
    }
}
