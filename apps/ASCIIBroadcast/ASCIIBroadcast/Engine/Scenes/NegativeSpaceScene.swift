//
//  NegativeSpaceScene.swift
//  ASCII Broadcast
//
//  Family: NEGATIVE-SPACE THEATRE — prototype episode "The Visitor".
//
//  Establish a dense wall and one unprinted doorway. A small figure exists as
//  an absence; its passage leaves temporary gaps that slowly close. The section
//  change reveals that the wall is the inside of a giant object. Strict ASCII
//  still produces the complete composition.
//

import Foundation

final class NegativeSpaceScene: SceneEpisode {

    let family: SceneFamily = .negativeSpaceTheatre
    private(set) var episodeTitle: String = "THE VISITOR"

    private var seed: UInt64 = 1
    private var columns = 240
    private var rows = 68

    /// How open each cell is, 0 = solid wall, 1 = fully absent. Bounded buffer,
    /// reused every frame; nothing here grows.
    private var openness: [Float] = []
    private var visitorX: Double = 0
    private var visitorY: Double = 0
    private var visitorPhase: Double = 0
    private var doorwayColumn: Int = 0
    private var revealAmount: Double = 0
    private var wallDrift: Double = 0
    private var incomingCarrier: MotifCarrierState?

    private var pressureEnvelope = Envelope(attack: 0.06, release: 0.9)
    private var revealEnvelope = Envelope(attack: 1.2, release: 3.2)

    func prepare(cue: ScoreSceneCue, dna: VisualDNA, columns: Int, rows: Int) {
        seed = cue.seed
        self.columns = columns
        self.rows = rows
        episodeTitle = cue.episodeTitle
        openness = Array(repeating: 0, count: columns * rows)
        var generator = SeededGenerator(seed: cue.seed, stream: "negative-space")
        doorwayColumn = columns / 5 + generator.index(max(1, columns / 2))
        visitorX = Double(doorwayColumn)
        visitorY = Double(rows) * 0.62
        revealAmount = 0
    }

    func accept(carrier: MotifCarrierState) {
        incomingCarrier = carrier
        visitorX = carrier.x * Double(columns)
        visitorY = carrier.y * Double(rows)
    }

    func exitCarrier() -> MotifCarrierState? {
        MotifCarrierState(carrier: .silhouette,
                          name: "the visitor",
                          signature: "( )",
                          x: clamp(visitorX / Double(max(1, columns)), 0, 1),
                          y: clamp(visitorY / Double(max(1, rows)), 0, 1),
                          role: .subject,
                          history: 1)
    }

    func render(into grid: GlyphGrid, snapshot: RenderSnapshot, vocabulary: GlyphVocabulary) {
        if columns != grid.columns || rows != grid.rows || openness.count != grid.columns * grid.rows {
            columns = grid.columns
            rows = grid.rows
            openness = Array(repeating: 0, count: columns * rows)
        }

        let dt = snapshot.deltaTime
        let pressure = pressureEnvelope.update(snapshot.ports.pressure, dt: dt)
        let wantsReveal = snapshot.section?.kind == .chorus
            || snapshot.section?.kind == .drop
            || snapshot.ports.release > 0.5
        revealAmount = revealEnvelope.update(wantsReveal ? 1 : 0, dt: dt)
        wallDrift += dt * 0.08 * snapshot.motion

        decayOpenness(dt: dt)
        moveVisitor(snapshot: snapshot, pressure: pressure)
        carveVisitor(snapshot: snapshot, pressure: pressure)
        if revealAmount > 0.02 { carveGiantContour(amount: revealAmount) }

        drawWall(grid: grid, snapshot: snapshot, vocabulary: vocabulary, pressure: pressure)
        drawDoorway(grid: grid, snapshot: snapshot, vocabulary: vocabulary)
        drawVisitorEdge(grid: grid, snapshot: snapshot, vocabulary: vocabulary)
    }

    // MARK: - Absence field

    private func decayOpenness(dt: Double) {
        // Gaps close slowly: the wall remembers where the visitor went.
        let decay = Float(1.0 - min(0.9, dt * 0.55))
        for index in openness.indices {
            let value = openness[index] * decay
            openness[index] = value < 0.004 ? 0 : value
        }
    }

    private func moveVisitor(snapshot: RenderSnapshot, pressure: Double) {
        visitorPhase += snapshot.deltaTime * (1.4 + snapshot.ports.density * 2.0)
        let speed = (4.0 + pressure * 16.0) * snapshot.motion
        visitorX += speed * snapshot.deltaTime
        if visitorX > Double(columns) + 6 { visitorX = -6 }
        let target = Double(rows) * (0.42 + 0.18 * sin(visitorPhase * 0.4))
        visitorY += (target - visitorY) * min(1, snapshot.deltaTime * 1.1)
    }

    private func carveVisitor(snapshot: RenderSnapshot, pressure: Double) {
        // The boundary of what is missing is the music's business.
        let radiusX = 3.0 + pressure * 5.0 + Double(snapshot.features.rms) * 4.0
        let radiusY = radiusX * 0.55
        let step = 1
        let minX = Int(visitorX - radiusX) - 1
        let maxX = Int(visitorX + radiusX) + 1
        let minY = Int(visitorY - radiusY) - 1
        let maxY = Int(visitorY + radiusY) + 1
        var y = max(0, minY)
        while y <= min(rows - 1, maxY) {
            var x = max(0, minX)
            while x <= min(columns - 1, maxX) {
                let dx = (Double(x) - visitorX) / max(0.5, radiusX)
                let dy = (Double(y) - visitorY) / max(0.5, radiusY)
                let distance = dx * dx + dy * dy
                if distance < 1.0 {
                    let amount = Float(1.0 - distance)
                    let index = y * columns + x
                    openness[index] = max(openness[index], amount)
                }
                x += step
            }
            y += step
        }

        // A transient scatters a few extra holes ahead of the figure.
        if snapshot.features.onset > 0.4 {
            var generator = SeededGenerator(seed: seed &+ UInt64(snapshot.frameIndex), stream: "scatter")
            let count = 2 + generator.index(6)
            for _ in 0..<count {
                let x = clamp(Int(visitorX + generator.range(-18, 26)), 0, columns - 1)
                let y = clamp(Int(visitorY + generator.range(-8, 8)), 0, rows - 1)
                openness[y * columns + x] = max(openness[y * columns + x], Float(generator.range(0.4, 0.9)))
            }
        }
    }

    /// The reveal: the wall is the inside of an enormous letter counter.
    private func carveGiantContour(amount: Double) {
        let inset = Double(columns) * 0.18
        let centreX = Double(columns) * 0.5
        let centreY = Double(rows) * 0.5
        let radiusX = (Double(columns) * 0.5 - inset) * smoothstep(0, 1, amount)
        let radiusY = (Double(rows) * 0.42) * smoothstep(0, 1, amount)
        guard radiusX > 2, radiusY > 1 else { return }
        let steps = 420
        for step in 0..<steps {
            let angle = Double(step) / Double(steps) * 2 * .pi
            // A counter, not a circle: flatten the right side so it reads as a
            // letterform rather than a ring.
            let squash = angle > .pi * 0.5 && angle < .pi * 1.5 ? 1.0 : 0.72
            let x = centreX + cos(angle) * radiusX * squash
            let y = centreY + sin(angle) * radiusY
            for thickness in -1...1 {
                let xi = Int(x)
                let yi = Int(y) + thickness
                guard xi >= 0, xi < columns, yi >= 0, yi < rows else { continue }
                openness[yi * columns + xi] = max(openness[yi * columns + xi], Float(amount))
            }
        }
    }

    // MARK: - Drawing

    private func drawWall(grid: GlyphGrid, snapshot: RenderSnapshot,
                          vocabulary: GlyphVocabulary, pressure: Double) {
        let density = clamp(snapshot.detailTarget + pressure * 0.2, 0.15, 0.95)
        let ramp = vocabulary.ramp
        guard ramp.count > 2 else { return }
        let drift = snapshot.reduceMotion ? 0.0 : wallDrift

        for y in 0..<rows {
            for x in 0..<columns {
                let index = y * columns + x
                let open = Double(openness[index])
                if open > 0.62 { continue }              // the absence itself

                // Stable spatial grain anchored to the grid, never per-frame noise.
                let grain = Noise.hash(x, y, seed)
                let band = Noise.value1D(Double(y) * 0.06 + drift, seed: seed &+ 7)
                let coverage = clamp(density * (0.55 + grain * 0.5 + band * 0.25) - open * 0.9, 0, 1)
                guard coverage > 0.06 else { continue }

                let role: PaletteRole = open > 0.25 ? .memory : (grain > 0.93 ? .structure : .ground)
                let intensity = Float(clamp(0.28 + coverage * 0.75 - open * 0.5, 0.05, 1))
                grid.plot(x, y, vocabulary.glyph(coverage: coverage),
                          role: role, intensity: intensity, depth: 0.3, entity: 1)
            }
        }
    }

    private func drawDoorway(grid: GlyphGrid, snapshot: RenderSnapshot, vocabulary: GlyphVocabulary) {
        // The one unprinted doorway: negative space with an authored edge.
        let width = max(6, columns / 18)
        let height = max(6, rows / 3)
        let x = clamp(doorwayColumn, 2, columns - width - 2)
        let y = rows - height - 2
        grid.fill(x: x, y: y, width: width, height: height,
                  scalar: GlyphVocabulary.space, role: .ground, intensity: 0, depth: 0.45, entity: 2)
        grid.box(x: x - 1, y: y - 1, width: width + 2, height: height + 2,
                 role: .structure, intensity: 0.5, depth: 0.5, entity: 2, vocabulary: vocabulary)
        let lintel = Int(Double(snapshot.ports.pressure) * 3)
        if lintel > 0 {
            grid.horizontalLine(y: y - 2, from: x - 2, to: x + width + 1, role: .accent,
                                intensity: Float(0.3 + snapshot.ports.pressure * 0.5),
                                depth: 0.52, entity: 2, vocabulary: vocabulary, heavy: true)
        }
    }

    private func drawVisitorEdge(grid: GlyphGrid, snapshot: RenderSnapshot, vocabulary: GlyphVocabulary) {
        // The figure is never printed. Only the cells at the boundary of its
        // absence get a contour glyph, so the eye assembles the shape.
        for y in 0..<rows {
            for x in 0..<columns {
                let index = y * columns + x
                let value = openness[index]
                guard value > 0.45 else { continue }
                var isEdge = false
                if x > 0 && openness[index - 1] < 0.42 { isEdge = true }
                if !isEdge && x < columns - 1 && openness[index + 1] < 0.42 { isEdge = true }
                if !isEdge && y > 0 && openness[index - columns] < 0.42 { isEdge = true }
                if !isEdge && y < rows - 1 && openness[index + columns] < 0.42 { isEdge = true }
                guard isEdge else { continue }
                let up = y > 0 && openness[index - columns] > 0.45
                let down = y < rows - 1 && openness[index + columns] > 0.45
                let left = x > 0 && openness[index - 1] > 0.45
                let right = x < columns - 1 && openness[index + 1] > 0.45
                let glyph = vocabulary.junction(up: up, down: down, left: left, right: right)
                grid.plot(x, y, glyph, role: .subject,
                          intensity: Float(clamp(0.45 + Double(value) * 0.55, 0.2, 1)),
                          depth: 0.72, entity: 3)
            }
        }
    }
}
