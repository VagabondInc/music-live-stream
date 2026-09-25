//
//  FoldedCityScene.swift
//  ASCII Broadcast
//
//  Family: THE FOLDED CITY — prototype episode "The Station Opens".
//
//  Establish a single concourse and an incomplete arch. Develop through doors
//  opening onto contradictory rooms. Withhold by stopping the carriage while
//  its route continues to assemble. Release by unfolding the concourse into an
//  overhead map. Settle around one persistent window.
//

import Foundation

final class FoldedCityScene: SceneEpisode {

    let family: SceneFamily = .foldedCity
    private(set) var episodeTitle: String = "THE STATION OPENS"

    // Persistent entity state. Bounded: nothing here grows over time.
    private struct Window {
        var ring: Int
        var side: Int          // -1 left, +1 right
        var row: Int
        var lit: Double
        var isPersistent: Bool
    }

    private var seed: UInt64 = 1
    private var columns = 240
    private var rows = 68
    private var windows: [Window] = []
    private var carriageDepth: Double = 7.5
    private var carriageSpeed: Double = 0
    private var dolly: Double = 0
    private var mapReveal: Double = 0
    private var apertureOpen: Double = 0
    private var lateralDrift: Double = 0
    private var incomingCarrier: MotifCarrierState?
    private var persistentWindowPoint: (Double, Double) = (0.62, 0.42)
    private var routeAssembly: Double = 0
    private var platformNumber: Int = 3

    private var pressureEnvelope = Envelope(attack: 0.05, release: 0.55)
    private var articulationEnvelope = Envelope(attack: 0.01, release: 0.16)
    private var revealEnvelope = Envelope(attack: 0.9, release: 2.4)

    private let ringCount = 15

    // MARK: - Lifecycle

    func prepare(cue: ScoreSceneCue, dna: VisualDNA, columns: Int, rows: Int) {
        self.seed = cue.seed
        self.columns = columns
        self.rows = rows
        self.episodeTitle = cue.episodeTitle

        var generator = SeededGenerator(seed: cue.seed, stream: "folded-city")
        platformNumber = 1 + generator.index(9)
        windows.removeAll(keepingCapacity: true)
        for ring in 2..<ringCount {
            let count = 1 + generator.index(3)
            for _ in 0..<count {
                windows.append(Window(ring: ring,
                                      side: generator.chance(0.5) ? -1 : 1,
                                      row: generator.index(3) - 1,
                                      lit: generator.unit() * 0.4,
                                      isPersistent: false))
            }
        }
        // One window survives the whole episode and can leave with the carrier.
        if !windows.isEmpty {
            let keeper = generator.index(windows.count)
            windows[keeper].isPersistent = true
            windows[keeper].lit = 0.9
        }
        carriageDepth = 8.5
        dolly = 0
        mapReveal = 0
        routeAssembly = 0
        apertureOpen = 0
    }

    func accept(carrier: MotifCarrierState) {
        incomingCarrier = carrier
        persistentWindowPoint = (carrier.x, carrier.y)
    }

    func exitCarrier() -> MotifCarrierState? {
        MotifCarrierState(carrier: .frame,
                          name: "lit window",
                          signature: "[#]",
                          x: persistentWindowPoint.0,
                          y: persistentWindowPoint.1,
                          scale: 1,
                          role: .accent,
                          history: 1)
    }

    // MARK: - Render

    func render(into grid: GlyphGrid, snapshot: RenderSnapshot, vocabulary: GlyphVocabulary) {
        columns = grid.columns
        rows = grid.rows

        let dt = snapshot.deltaTime
        let ports = snapshot.ports
        let pressure = pressureEnvelope.update(ports.pressure, dt: dt)
        let articulation = articulationEnvelope.update(ports.articulation, dt: dt)
        let motion = snapshot.motion

        // Camera: locked wide shot with a slow lateral track. Reduce Motion
        // substitutes discrete architectural states for travel.
        let driftTarget = snapshot.reduceMotion
            ? 0
            : (Noise.fbm1D(snapshot.programTime * 0.055, seed: seed, octaves: 3) - 0.5) * 0.09 * motion
        lateralDrift += (driftTarget - lateralDrift) * min(1, dt * 1.2)

        if !snapshot.reduceMotion {
            dolly += dt * (0.18 + pressure * 0.9) * motion
        } else {
            dolly += dt * 0.05
        }

        // The concourse unfolds into an overhead map at the release.
        let wantsMap = (snapshot.section?.kind == .chorus || snapshot.section?.kind == .drop)
            || ports.release > 0.45
        mapReveal = revealEnvelope.update(wantsMap ? 1 : 0, dt: dt)
        routeAssembly = min(1, routeAssembly + dt * (0.04 + ports.density * 0.14))
        apertureOpen = clamp(apertureOpen + (ports.release > 0.6 ? dt * 0.9 : -dt * 0.35), 0, 1)

        let camera = GridCamera(columns: columns,
                                rows: rows,
                                vanishingX: 0.5 + lateralDrift,
                                vanishingY: 0.455 - pressure * 0.012,
                                focal: 0.60 + apertureOpen * 0.06)

        drawTunnel(grid: grid, camera: camera, snapshot: snapshot, vocabulary: vocabulary,
                   pressure: pressure, articulation: articulation)
        drawRails(grid: grid, camera: camera, snapshot: snapshot, vocabulary: vocabulary)
        drawWindows(grid: grid, camera: camera, snapshot: snapshot, vocabulary: vocabulary,
                    articulation: articulation)
        drawCarriage(grid: grid, camera: camera, snapshot: snapshot, vocabulary: vocabulary,
                     pressure: pressure)
        drawSignage(grid: grid, camera: camera, snapshot: snapshot, vocabulary: vocabulary)
        if mapReveal > 0.02 {
            drawOverheadMap(grid: grid, snapshot: snapshot, vocabulary: vocabulary, amount: mapReveal)
        }
        drawAtmosphere(grid: grid, snapshot: snapshot, vocabulary: vocabulary)
    }

    func renderFallback(into grid: GlyphGrid, snapshot: RenderSnapshot, vocabulary: GlyphVocabulary) {
        // Quality tier 2+: keep the arch, the carriage, and the persistent
        // window. Lose the distant rooms and the atmosphere.
        let camera = GridCamera(columns: grid.columns, rows: grid.rows,
                                vanishingX: 0.5, vanishingY: 0.455)
        drawTunnel(grid: grid, camera: camera, snapshot: snapshot, vocabulary: vocabulary,
                   pressure: snapshot.ports.pressure, articulation: 0, ringLimit: 7)
        drawCarriage(grid: grid, camera: camera, snapshot: snapshot, vocabulary: vocabulary,
                     pressure: snapshot.ports.pressure)
    }

    // MARK: - Pieces

    private func ringDepth(_ index: Int) -> Double {
        let phase = dolly.truncatingRemainder(dividingBy: 1.0)
        return 0.9 * pow(1.30, Double(index) - phase)
    }

    private func drawTunnel(grid: GlyphGrid, camera: GridCamera, snapshot: RenderSnapshot,
                            vocabulary: GlyphVocabulary, pressure: Double, articulation: Double,
                            ringLimit: Int? = nil) {
        let limit = ringLimit ?? ringCount
        let halfWidth = 1.0
        let ceiling = -0.78
        let floor = 0.66

        // Long converging edges first: they establish the space.
        for edge in 0..<4 {
            let x: Double = (edge % 2 == 0) ? -halfWidth : halfWidth
            let y: Double = (edge < 2) ? ceiling : floor
            var previous: (Int, Int)?
            for ring in 0..<limit {
                let z = ringDepth(ring)
                let (px, py, _) = camera.project(x, y, z)
                if let start = previous {
                    grid.line(from: start, to: (px, py),
                              role: .structure,
                              intensity: Float(clamp(1.0 - Double(ring) / Double(limit) * 0.65, 0.3, 1)),
                              depth: Float(0.9 - Double(ring) * 0.04),
                              entity: 10,
                              vocabulary: vocabulary)
                }
                previous = (px, py)
            }
        }

        // Ring structure: arch ribs and floor bands.
        for ring in 1..<limit {
            let z = ringDepth(ring)
            let fade = clamp(1.0 - Double(ring) / Double(limit), 0.12, 1)
            let intensity = Float(fade * (0.55 + pressure * 0.5))
            let depth = Float(0.85 - Double(ring) * 0.045)

            // Arch: a shallow parabola across the ceiling, the family's motif.
            let segments = max(10, Int(46.0 * fade) + 10)
            var previousPoint: (Int, Int)?
            for step in 0...segments {
                let t = Double(step) / Double(segments)
                let x = -halfWidth + t * halfWidth * 2
                let arch = ceiling + (1 - pow(abs(x) / halfWidth, 2)) * -0.30
                let (px, py, _) = camera.project(x, arch, z)
                if let start = previousPoint {
                    // The incomplete arch: one missing cell keeps the motif's
                    // invariant signature across every mutation.
                    let missing = ring % 3 == 0 && abs(t - 0.5) < 0.035
                    if !missing {
                        grid.line(from: start, to: (px, py), role: .structure,
                                  intensity: intensity, depth: depth, entity: UInt16(20 + ring),
                                  vocabulary: vocabulary)
                    }
                }
                previousPoint = (px, py)
            }

            // Floor band under the arch.
            let (flx, fly, _) = camera.project(-halfWidth, floor, z)
            let (frx, fry, _) = camera.project(halfWidth, floor, z)
            if fly == fry {
                grid.horizontalLine(y: fly, from: flx, to: frx, role: .ground,
                                    intensity: Float(fade * 0.5), depth: depth - 0.02,
                                    entity: 11, vocabulary: vocabulary)
            } else {
                grid.line(from: (flx, fly), to: (frx, fry), role: .ground,
                          intensity: Float(fade * 0.5), depth: depth - 0.02,
                          entity: 11, vocabulary: vocabulary)
            }

            // Columns: vertical ribs where wall meets arch.
            for side in [-1.0, 1.0] {
                let (cx, cyTop, _) = camera.project(side * halfWidth, ceiling, z)
                let (_, cyBottom, _) = camera.project(side * halfWidth, floor, z)
                grid.verticalLine(x: cx, from: cyTop, to: cyBottom, role: .structure,
                                  intensity: Float(fade * (0.4 + articulation * 0.4)),
                                  depth: depth, entity: UInt16(30 + ring),
                                  vocabulary: vocabulary,
                                  heavy: ring % 4 == 0)
            }
        }
    }

    private func drawRails(grid: GlyphGrid, camera: GridCamera, snapshot: RenderSnapshot,
                           vocabulary: GlyphVocabulary) {
        let floor = 0.655
        let railOffsets: [Double] = [-0.30, -0.14, 0.14, 0.30]
        for offset in railOffsets {
            var previous: (Int, Int)?
            for ring in 0..<ringCount {
                let z = ringDepth(ring)
                let (px, py, _) = camera.project(offset, floor, z)
                if let start = previous {
                    grid.line(from: start, to: (px, py), role: .memory,
                              intensity: Float(clamp(0.9 - Double(ring) * 0.06, 0.15, 0.9)),
                              depth: Float(0.55 - Double(ring) * 0.02),
                              entity: 12, vocabulary: vocabulary)
                }
                previous = (px, py)
            }
        }

        // Sleepers appear in time with the route assembling.
        let sleeperCount = Int(routeAssembly * 22)
        if sleeperCount > 0 {
            for index in 0..<sleeperCount {
                let z = 0.9 + Double(index) * 0.42
                let (lx, ly, _) = camera.project(-0.34, floor, z)
                let (rx, _, _) = camera.project(0.34, floor, z)
                guard rx > lx else { continue }
                grid.horizontalLine(y: ly, from: lx, to: rx, role: .ground,
                                    intensity: Float(clamp(0.5 - Double(index) * 0.02, 0.08, 0.5)),
                                    depth: 0.5, entity: 13, vocabulary: vocabulary)
            }
        }
    }

    private func drawWindows(grid: GlyphGrid, camera: GridCamera, snapshot: RenderSnapshot,
                             vocabulary: GlyphVocabulary, articulation: Double) {
        let dt = snapshot.deltaTime
        for index in windows.indices {
            var window = windows[index]
            // A transient can light a window; it decays on its own clock.
            let excite = Noise.hash(window.ring, index, seed) < Double(snapshot.features.onset) * 0.8
            if excite { window.lit = min(1, window.lit + 0.7) }
            window.lit = max(window.isPersistent ? 0.55 : 0.05, window.lit - dt * 0.55)
            windows[index] = window

            let z = ringDepth(window.ring)
            guard z < 26 else { continue }
            let (x, y, scale) = camera.projectFloat(Double(window.side) * 0.98,
                                                    -0.20 + Double(window.row) * 0.22,
                                                    z)
            let width = max(2, Int(scale * 7))
            let height = max(1, Int(scale * 4))
            let originX = Int(x) - width / 2
            let originY = Int(y) - height / 2
            let role: PaletteRole = window.isPersistent ? .accent : (window.lit > 0.5 ? .accent : .structure)
            let intensity = Float(clamp(0.22 + window.lit * 0.9, 0.12, 1.0))

            if width > 2 && height > 1 {
                grid.box(x: originX, y: originY, width: width, height: height + 1,
                         role: role, intensity: intensity, depth: Float(0.7),
                         entity: UInt16(100 + index), vocabulary: vocabulary)
                if window.lit > 0.35 {
                    grid.fill(x: originX + 1, y: originY + 1, width: width - 2, height: height - 1,
                              scalar: vocabulary.glyph(coverage: 0.35 + window.lit * 0.5),
                              role: .accent, intensity: Float(window.lit),
                              depth: 0.69, entity: UInt16(100 + index))
                }
            } else {
                grid.plot(Int(x), Int(y), vocabulary.glyph(coverage: window.lit),
                          role: role, intensity: intensity, depth: 0.7,
                          entity: UInt16(100 + index))
            }

            if window.isPersistent {
                persistentWindowPoint = (x / Double(max(1, columns)), y / Double(max(1, rows)))
            }
        }
    }

    private func drawCarriage(grid: GlyphGrid, camera: GridCamera, snapshot: RenderSnapshot,
                              vocabulary: GlyphVocabulary, pressure: Double) {
        // Low-frequency pressure moves the carriage; a withheld passage stops
        // it while its route keeps assembling.
        let withholding = snapshot.section?.kind == .breakdown || snapshot.ports.pressure < 0.08
        let targetSpeed = withholding ? 0 : (0.25 + pressure * 2.4) * snapshot.motion
        carriageSpeed += (targetSpeed - carriageSpeed) * min(1, snapshot.deltaTime * 1.6)
        carriageDepth -= carriageSpeed * snapshot.deltaTime
        if carriageDepth < 1.6 { carriageDepth = 11.0 }

        let z = carriageDepth
        let (cx, cy, scale) = camera.projectFloat(0, 0.30, z)
        let halfWidth = max(3, Int(scale * 26))
        let height = max(3, Int(scale * 22))
        let left = Int(cx) - halfWidth / 2
        let top = Int(cy) - height

        grid.box(x: left, y: top, width: halfWidth, height: height,
                 role: .subject, intensity: Float(clamp(0.6 + pressure * 0.5, 0.35, 1)),
                 depth: 0.92, entity: 50, vocabulary: vocabulary, heavy: scale > 0.14)

        // Front face: two lit windows, the shape the audience learns to read.
        if halfWidth > 7 && height > 4 {
            let inset = max(1, halfWidth / 6)
            let windowWidth = max(1, (halfWidth - inset * 3) / 2)
            let windowTop = top + max(1, height / 4)
            let windowHeight = max(1, height / 3)
            for slot in 0..<2 {
                let wx = left + inset + slot * (windowWidth + inset)
                grid.fill(x: wx, y: windowTop, width: windowWidth, height: windowHeight,
                          scalar: vocabulary.glyph(coverage: 0.72 + pressure * 0.25),
                          role: .accent, intensity: Float(0.75 + pressure * 0.25),
                          depth: 0.93, entity: 51)
            }
            // Headlamp spill on the floor.
            let spill = Int(Double(halfWidth) * 0.9)
            let spillY = top + height
            for offset in -spill...spill {
                let fade = 1.0 - abs(Double(offset)) / Double(max(1, spill))
                if fade > 0.15 {
                    grid.plot(Int(cx) + offset, spillY,
                              vocabulary.glyph(coverage: fade * 0.4 * (0.5 + pressure)),
                              role: .accent, intensity: Float(fade * 0.5),
                              depth: 0.6, entity: 52)
                }
            }
        }
    }

    private func drawSignage(grid: GlyphGrid, camera: GridCamera, snapshot: RenderSnapshot,
                             vocabulary: GlyphVocabulary) {
        // Environmental typography lives in world depth and is generated by us,
        // so it is safe to constrain to the art vocabulary.
        let (lx, ly, lscale) = camera.projectFloat(-1.02, -0.42, 2.6)
        if lscale > 0.08 {
            let label = "PLATFORM"
            grid.text(label, x: Int(lx) - label.count / 2, y: Int(ly),
                      role: .structure, intensity: 0.55, depth: 0.74, entity: 60)
            grid.text("\(platformNumber)", x: Int(lx) - 1, y: Int(ly) + 2,
                      role: .accent, intensity: 0.9, depth: 0.74, entity: 60)
            grid.box(x: Int(lx) - 3, y: Int(ly) + 1, width: 5, height: 3,
                     role: .accent, intensity: 0.7, depth: 0.73, entity: 60,
                     vocabulary: vocabulary)
        }

        let (rx, ry, rscale) = camera.projectFloat(1.02, -0.30, 2.2)
        if rscale > 0.08 {
            let exit = "EXIT >"
            grid.text(exit, x: Int(rx) - exit.count / 2, y: Int(ry),
                      role: .accent, intensity: 0.8, depth: 0.74, entity: 61)
        }

        // Destination board over the far platform: the world names itself.
        let (bx, by, bscale) = camera.projectFloat(0, -0.52, 5.2)
        if bscale > 0.05 {
            let board = snapshot.dna.direction.description
            let width = board.count + 2
            grid.box(x: Int(bx) - width / 2, y: Int(by) - 1, width: width, height: 3,
                     role: .accent, intensity: 0.5, depth: 0.7, entity: 62, vocabulary: vocabulary)
            grid.text(board, x: Int(bx) - board.count / 2, y: Int(by),
                      role: .accent, intensity: 0.75, depth: 0.71, entity: 62)
        }
    }

    private func drawOverheadMap(grid: GlyphGrid, snapshot: RenderSnapshot,
                                 vocabulary: GlyphVocabulary, amount: Double) {
        // The rails from the floor reappear overhead as a diagram: the same
        // material, a different purpose. This is the episode's consequence.
        let top = 2
        let height = max(6, Int(Double(rows) * 0.26))
        let inset = Int(Double(columns) * 0.08)
        let width = columns - inset * 2
        let reveal = smoothstep(0, 1, amount)
        let visibleWidth = Int(Double(width) * reveal)
        guard visibleWidth > 4 else { return }

        var generator = SeededGenerator(seed: seed, stream: "overhead-map")
        let lines = 3
        for lineIndex in 0..<lines {
            let baseRow = top + 2 + lineIndex * (height / lines)
            var x = inset
            var y = baseRow
            var previous = (x, y)
            while x < inset + visibleWidth {
                let step = 6 + generator.index(9)
                x += step
                if generator.chance(0.35) {
                    y += generator.chance(0.5) ? 1 : -1
                    y = clamp(y, top + 1, top + height - 1)
                }
                let point = (min(x, inset + visibleWidth), y)
                grid.line(from: previous, to: point, role: .memory,
                          intensity: Float(0.35 + reveal * 0.5), depth: 0.96,
                          entity: UInt16(70 + lineIndex), vocabulary: vocabulary)
                // Stations: the interchange marks are the motif in miniature.
                if generator.chance(0.4) {
                    grid.plot(point.0, point.1, vocabulary.glyph(coverage: 0.85),
                              role: .accent, intensity: Float(0.6 + reveal * 0.4),
                              depth: 0.97, entity: UInt16(70 + lineIndex),
                              flags: GlyphCell.motifMark)
                }
                previous = point
            }
        }
    }

    private func drawAtmosphere(grid: GlyphGrid, snapshot: RenderSnapshot, vocabulary: GlyphVocabulary) {
        let amount = Double(snapshot.dna.controls.atmosphere) / 100.0
        guard amount > 0.02 else { return }
        let count = Int(Double(columns * rows) * 0.004 * amount)
        guard count > 0 else { return }
        let marks = vocabulary.marks
        let time = snapshot.programTime
        for index in 0..<count {
            let nx = Noise.hash(index, 1, seed)
            let ny = Noise.hash(index, 2, seed)
            let drift = snapshot.reduceMotion ? 0 : (time * (0.2 + nx * 0.3)).truncatingRemainder(dividingBy: 1.0)
            let x = Int(((nx + drift).truncatingRemainder(dividingBy: 1.0)) * Double(columns))
            let y = Int(ny * Double(rows))
            let glyph = marks[index % marks.count]
            grid.plotAtmosphere(x, y, glyph, intensity: Float(0.18 + nx * 0.2))
        }
    }
}
