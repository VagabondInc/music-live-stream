//
//  WeavingEngineScene.swift
//  ASCII Broadcast
//
//  Family: THE WEAVING ENGINE — prototype episode "A Bridge from the Rhythm".
//
//  Establish two separated margins. Onsets place short local stitches;
//  recurring phrases repeat a motif without duplicating every stitch. A meso
//  cue links the margins; the next recurrence reveals an inhabited bridge.
//  A missed beat does not tear the bridge apart.
//

import Foundation

final class WeavingEngineScene: SceneEpisode {

    let family: SceneFamily = .weavingEngine
    private(set) var episodeTitle: String = "A BRIDGE FROM THE RHYTHM"

    private struct Stitch {
        var row: Int
        var startColumn: Int
        var length: Int
        var age: Double
        var fromLeft: Bool
        var isKnot: Bool
    }

    private struct Walker {
        var position: Double
        var row: Int
        var speed: Double
        var glyphIndex: Int
    }

    private var seed: UInt64 = 1
    private var columns = 240
    private var rows = 68
    private var stitches: [Stitch] = []
    private var walkers: [Walker] = []
    private var bridgeProgress: Double = 0
    private var tension: Double = 0.5
    private var warpPhase: Double = 0
    private var marginWidth = 18
    private var incomingCarrier: MotifCarrierState?
    private var lastStitchTime: Double = -1

    private var bodyEnvelope = Envelope(attack: 0.08, release: 0.7)
    private var airEnvelope = Envelope(attack: 0.02, release: 0.22)
    private var bridgeEnvelope = Envelope(attack: 1.6, release: 4.0)

    private let maxStitches = 260

    func prepare(cue: ScoreSceneCue, dna: VisualDNA, columns: Int, rows: Int) {
        seed = cue.seed
        self.columns = columns
        self.rows = rows
        episodeTitle = cue.episodeTitle
        stitches.removeAll(keepingCapacity: true)
        walkers.removeAll(keepingCapacity: true)
        bridgeProgress = 0
        marginWidth = max(8, columns / 12)
        var generator = SeededGenerator(seed: cue.seed, stream: "weaving")
        tension = 0.35 + generator.unit() * 0.4
    }

    func accept(carrier: MotifCarrierState) {
        incomingCarrier = carrier
        // An arriving carrier becomes the first knot: continuity you can see.
        let row = clamp(Int(carrier.y * Double(rows)), 2, rows - 3)
        let column = clamp(Int(carrier.x * Double(columns)), 2, columns - 3)
        stitches.append(Stitch(row: row, startColumn: column, length: 3, age: 0,
                               fromLeft: carrier.x < 0.5, isKnot: true))
    }

    func exitCarrier() -> MotifCarrierState? {
        guard let knot = stitches.last(where: { $0.isKnot }) else {
            return MotifCarrierState(carrier: .ribbon, name: "suspended thread", signature: "===",
                                     x: 0.5, y: 0.5, role: .structure)
        }
        return MotifCarrierState(carrier: .fragments,
                                 name: "knot",
                                 signature: "#=#",
                                 x: Double(knot.startColumn) / Double(max(1, columns)),
                                 y: Double(knot.row) / Double(max(1, rows)),
                                 role: .accent,
                                 history: stitches.count)
    }

    func render(into grid: GlyphGrid, snapshot: RenderSnapshot, vocabulary: GlyphVocabulary) {
        columns = grid.columns
        rows = grid.rows
        marginWidth = max(8, columns / 12)

        let dt = snapshot.deltaTime
        let body = bodyEnvelope.update(snapshot.ports.body, dt: dt)
        let air = airEnvelope.update(snapshot.ports.air, dt: dt)

        // A meso cue links the margins; the bridge does not tear on one miss.
        let wantsBridge = snapshot.ports.recurrence > 0.45
            || snapshot.section?.kind == .chorus
            || snapshot.section?.kind == .bridge
        bridgeProgress = bridgeEnvelope.update(wantsBridge ? 1 : 0.12, dt: dt)

        warpPhase += dt * (0.1 + body * 0.5) * snapshot.motion
        tension += (0.3 + snapshot.ports.pressure * 0.6 - tension) * min(1, dt * 0.8)

        placeStitches(snapshot: snapshot)
        ageStitches(dt: dt)

        drawMargins(grid: grid, snapshot: snapshot, vocabulary: vocabulary, body: body)
        drawWarp(grid: grid, snapshot: snapshot, vocabulary: vocabulary, air: air)
        drawStitches(grid: grid, snapshot: snapshot, vocabulary: vocabulary)
        drawBridge(grid: grid, snapshot: snapshot, vocabulary: vocabulary)
        updateWalkers(grid: grid, snapshot: snapshot, vocabulary: vocabulary)
    }

    // MARK: - Material

    private func placeStitches(snapshot: RenderSnapshot) {
        let onset = Double(snapshot.features.onset)
        guard onset > 0.25 else { return }
        guard snapshot.programTime - lastStitchTime > 0.06 else { return }
        lastStitchTime = snapshot.programTime

        var generator = SeededGenerator(seed: seed &+ UInt64(snapshot.frameIndex), stream: "stitch")
        let fromLeft = generator.chance(0.5)
        let row = clamp(2 + generator.index(max(1, rows - 4)), 2, rows - 3)
        let reach = Int(Double(columns) * (0.06 + onset * 0.22 * snapshot.motion))
        let start = fromLeft
            ? marginWidth + generator.index(max(1, columns / 3))
            : columns - marginWidth - reach - generator.index(max(1, columns / 3))

        stitches.append(Stitch(row: row,
                               startColumn: clamp(start, 1, columns - 2),
                               length: max(2, reach),
                               age: 0,
                               fromLeft: fromLeft,
                               isKnot: onset > 0.72))

        if stitches.count > maxStitches {
            stitches.removeFirst(stitches.count - maxStitches)
        }
    }

    private func ageStitches(dt: Double) {
        for index in stitches.indices {
            stitches[index].age += dt
        }
        // Bounded history: old material leaves through the pool, it is not cached.
        stitches.removeAll { $0.age > (($0.isKnot) ? 90 : 26) }
    }

    private func drawMargins(grid: GlyphGrid, snapshot: RenderSnapshot,
                             vocabulary: GlyphVocabulary, body: Double) {
        let left = marginWidth
        let right = columns - marginWidth - 1
        for row in 0..<rows {
            let wobble = snapshot.reduceMotion ? 0.0
                : sin(Double(row) * 0.18 + warpPhase) * 1.4 * snapshot.motion
            let leftX = left + Int(wobble)
            let rightX = right - Int(wobble)
            let intensity = Float(0.35 + body * 0.5)
            grid.plot(leftX, row, vocabulary.lines.vertical, role: .structure,
                      intensity: intensity, depth: 0.7, entity: 1)
            grid.plot(rightX, row, vocabulary.lines.vertical, role: .structure,
                      intensity: intensity, depth: 0.7, entity: 2)
            if row % 6 == 0 {
                grid.plot(leftX - 1, row, vocabulary.lines.teeRight, role: .structure,
                          intensity: intensity * 0.8, depth: 0.7, entity: 1)
                grid.plot(rightX + 1, row, vocabulary.lines.teeLeft, role: .structure,
                          intensity: intensity * 0.8, depth: 0.7, entity: 2)
            }
        }
    }

    private func drawWarp(grid: GlyphGrid, snapshot: RenderSnapshot,
                          vocabulary: GlyphVocabulary, air: Double) {
        let spacing = max(3, Int(12 - Double(snapshot.dna.controls.glyphDensity) / 12.0))
        let left = marginWidth + 2
        let right = columns - marginWidth - 2
        guard right > left else { return }
        var column = left
        while column < right {
            let n = Noise.value1D(Double(column) * 0.08 + warpPhase * 0.4, seed: seed)
            let slack = snapshot.reduceMotion ? 0.0 : (n - 0.5) * (1.0 - tension) * 6.0
            for row in stride(from: 1, to: rows - 1, by: 1) {
                let offset = Int(slack * sin(Double(row) / Double(max(1, rows)) * .pi))
                let intensity = Float(0.10 + air * 0.22 + n * 0.08)
                grid.plot(column + offset, row,
                          vocabulary.glyph(coverage: 0.12 + n * 0.1),
                          role: .ground, intensity: intensity, depth: 0.25, entity: 3)
            }
            column += spacing
        }
    }

    private func drawStitches(grid: GlyphGrid, snapshot: RenderSnapshot, vocabulary: GlyphVocabulary) {
        for stitch in stitches {
            let fade = stitch.isKnot
                ? clamp(1.0 - stitch.age / 90.0, 0.25, 1.0)
                : clamp(1.0 - stitch.age / 26.0, 0.0, 1.0)
            guard fade > 0.02 else { continue }
            let role: PaletteRole = stitch.isKnot ? .accent : (stitch.age > 8 ? .memory : .subject)
            let glyph = stitch.isKnot
                ? vocabulary.glyph(coverage: 0.9)
                : vocabulary.lines.horizontal
            for offset in 0..<stitch.length {
                let x = stitch.fromLeft ? stitch.startColumn + offset : stitch.startColumn + offset
                grid.plot(x, stitch.row, glyph, role: role,
                          intensity: Float(fade * (stitch.isKnot ? 1.0 : 0.7)),
                          depth: Float(0.55 + (stitch.isKnot ? 0.2 : 0)),
                          entity: 4,
                          flags: stitch.isKnot ? GlyphCell.motifMark : 0)
            }
            if stitch.isKnot {
                grid.plot(stitch.startColumn - 1, stitch.row, vocabulary.lines.teeRight,
                          role: .accent, intensity: Float(fade), depth: 0.76, entity: 4)
                grid.plot(stitch.startColumn + stitch.length, stitch.row, vocabulary.lines.teeLeft,
                          role: .accent, intensity: Float(fade), depth: 0.76, entity: 4)
            }
        }
    }

    private func drawBridge(grid: GlyphGrid, snapshot: RenderSnapshot, vocabulary: GlyphVocabulary) {
        guard bridgeProgress > 0.05 else { return }
        let deckRow = rows / 2 + Int(sin(warpPhase * 0.6) * 2 * snapshot.motion)
        let left = marginWidth
        let right = columns - marginWidth - 1
        let span = Double(right - left)
        let reach = Int(span * smoothstep(0, 1, bridgeProgress))
        guard reach > 2 else { return }

        for offset in 0..<reach {
            let x = left + offset
            let t = Double(offset) / max(1, span)
            let sag = Int(sin(t * .pi) * 2.5 * (1.0 - bridgeProgress))
            let intensity = Float(clamp(0.4 + bridgeProgress * 0.6, 0.2, 1))
            grid.plot(x, deckRow + sag, vocabulary.heavyLines.horizontal,
                      role: .subject, intensity: intensity, depth: 0.8, entity: 5)
            if offset % 7 == 0 {
                // Hangers tie the deck to the warp above.
                let height = 3 + Int(sin(t * .pi) * 4)
                for step in 1...height {
                    grid.plot(x, deckRow + sag - step, vocabulary.lines.vertical,
                              role: .memory, intensity: Float(0.25 + bridgeProgress * 0.35),
                              depth: 0.72, entity: 5)
                }
            }
        }

        // The next recurrence reveals the bridge is inhabited.
        if bridgeProgress > 0.8 && walkers.count < 4 {
            var generator = SeededGenerator(seed: seed &+ UInt64(walkers.count), stream: "walker")
            walkers.append(Walker(position: Double(left),
                                  row: deckRow - 1,
                                  speed: 6 + generator.unit() * 10,
                                  glyphIndex: generator.index(4)))
        }
    }

    private func updateWalkers(grid: GlyphGrid, snapshot: RenderSnapshot, vocabulary: GlyphVocabulary) {
        guard !walkers.isEmpty else { return }
        let agents = vocabulary.agents
        let right = Double(columns - marginWidth)
        for index in walkers.indices {
            walkers[index].position += walkers[index].speed * snapshot.deltaTime * snapshot.motion
        }
        walkers.removeAll { $0.position > right }
        for walker in walkers {
            let bob = Int(sin(walker.position * 0.4) * 1.0)
            let glyph = agents[walker.glyphIndex % agents.count]
            grid.plot(Int(walker.position), walker.row + bob, glyph,
                      role: .accent, intensity: 0.95, depth: 0.88, entity: 6)
        }
    }
}
