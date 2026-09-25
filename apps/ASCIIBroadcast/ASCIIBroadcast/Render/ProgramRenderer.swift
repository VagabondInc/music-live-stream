//
//  ProgramRenderer.swift
//  ASCII Broadcast
//
//  One program image is authoritative. The UI preview and the encoder both
//  subscribe to it; neither one owns it and neither can advance its clock.
//

import Foundation
import CoreGraphics
import QuartzCore

final class ProgramRenderer {

    private let engine = VisualEngine()
    private let rasterizer = GlyphRasterizer()
    private let transport: AudioTransport

    private let lock = NSLock()
    private var cachedFrame: GlyphFrame?
    private var lastRenderHostTime: CFTimeInterval = 0
    private var lastProgramTime: Double = 0

    // Inputs, swapped atomically by the coordinator.
    private var score = VisualScore()
    private var dna = VisualDNA.starter
    private var analyses: [UUID: TrackAnalysis] = [:]    // track instance -> analysis
    private var instanceOrder: [UUID] = []
    private var channelName: String?
    private var broadcastStart: Date?

    private(set) var health = EngineHealth()
    private var frameDurations: [Double] = []

    var frameRate: Int = 30
    var qualityTier: Int = 0
    var columns: Int = 200
    var rows: Int = 56

    init(transport: AudioTransport) {
        self.transport = transport
    }

    // MARK: - Configuration

    func apply(score newScore: VisualScore, dna newDNA: VisualDNA) {
        lock.lock()
        score = newScore
        dna = newDNA
        lock.unlock()
    }

    func apply(analyses newAnalyses: [UUID: TrackAnalysis], order: [UUID]) {
        lock.lock()
        analyses = newAnalyses
        instanceOrder = order
        lock.unlock()
    }

    func setBranding(channelName: String?, broadcastStart: Date?) {
        lock.lock()
        self.channelName = channelName
        self.broadcastStart = broadcastStart
        lock.unlock()
    }

    func setGrid(columns newColumns: Int, rows newRows: Int) {
        lock.lock()
        let changed = newColumns != columns || newRows != rows
        columns = newColumns
        rows = newRows
        lock.unlock()
        if changed { engine.resize(columns: newColumns, rows: newRows) }
    }

    func reset() {
        lock.lock()
        cachedFrame = nil
        lastProgramTime = 0
        lock.unlock()
        engine.reset()
    }

    // MARK: - Frame production

    /// Returns the current program frame, recomputing at most once per video
    /// frame interval. Safe to call from the UI at any refresh rate.
    @discardableResult
    func frame(now: CFTimeInterval = CACurrentMediaTime()) -> GlyphFrame {
        lock.lock()
        let interval = 1.0 / Double(max(1, frameRate))
        let elapsed = now - lastRenderHostTime
        if let cached = cachedFrame, elapsed < interval * 0.92 {
            lock.unlock()
            return cached
        }
        let scoreCopy = score
        let dnaCopy = dna
        let analysesCopy = analyses
        let orderCopy = instanceOrder
        let channel = channelName
        let start = broadcastStart
        let previousProgramTime = lastProgramTime
        lastRenderHostTime = now
        lock.unlock()

        let began = CACurrentMediaTime()
        let transportSnapshot = transport.snapshot()
        let features = transport.latestFeatures()

        // Program time comes from the audio clock, with a bounded fallback so
        // the preview still moves when nothing is playing.
        var programTime = transportSnapshot.programTime
        if !transportSnapshot.isPlaying {
            programTime = previousProgramTime + min(interval, max(0, elapsed))
        }

        let instanceID = orderCopy.indices.contains(transportSnapshot.currentIndex)
            ? orderCopy[transportSnapshot.currentIndex]
            : nil
        let analysis = instanceID.flatMap { analysesCopy[$0] }

        var input = VisualEngine.Input(programTime: programTime,
                                       trackTime: transportSnapshot.trackTime,
                                       deltaTime: max(0.004, min(0.25, elapsed)),
                                       features: transportSnapshot.isPlaying ? features : .silent,
                                       score: scoreCopy,
                                       dna: dnaCopy,
                                       analysis: analysis)
        input.channelName = channel
        input.elapsedBroadcast = start.map { Date().timeIntervalSince($0) }
        input.qualityTier = qualityTier

        let produced = engine.render(input)
        let renderMilliseconds = (CACurrentMediaTime() - began) * 1000

        lock.lock()
        cachedFrame = produced
        lastProgramTime = programTime
        frameDurations.append(renderMilliseconds)
        if frameDurations.count > 240 { frameDurations.removeFirst(frameDurations.count - 240) }
        health.renderedFrames += 1
        health.meanFrameMilliseconds = frameDurations.reduce(0, +) / Double(frameDurations.count)
        let sorted = frameDurations.sorted()
        health.p95FrameMilliseconds = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
        health.safetyInterventions = produced.safetyInterventions
        health.qualityTier = qualityTier
        health.featureAgeMilliseconds = max(0, (programTime - features.time) * 1000)
        lock.unlock()

        // Adaptive quality: step down before the deadline is missed, and take
        // detail rather than the focal action or audio timing.
        adaptQuality(lastFrameMilliseconds: renderMilliseconds)
        return produced
    }

    var latestFrame: GlyphFrame? {
        lock.lock()
        defer { lock.unlock() }
        return cachedFrame
    }

    private func adaptQuality(lastFrameMilliseconds: Double) {
        let budget = 1000.0 / Double(max(1, frameRate))
        if lastFrameMilliseconds > budget * 0.92 && qualityTier < 3 {
            qualityTier += 1
        } else if lastFrameMilliseconds < budget * 0.45 && qualityTier > 0 {
            qualityTier -= 1
        }
    }

    // MARK: - Rasterisation

    func draw(into context: CGContext, size: CGSize, frame: GlyphFrame? = nil) {
        let target = frame ?? self.frame()
        rasterizer.draw(frame: target, in: context, size: size)
    }

    func setScanlines(_ enabled: Bool) {
        rasterizer.drawsScanlines = enabled
    }

    /// Grid dimensions for a raster size, keeping 2:1 character cells.
    static func gridSize(forWidth width: Int, height: Int, density: Int) -> (columns: Int, rows: Int) {
        let base: Int
        switch height {
        case ..<800:  base = 160
        case ..<1200: base = 200
        default:      base = 240
        }
        let scaled = Int(Double(base) * (0.7 + Double(clamp(density, 0, 100)) / 100.0 * 0.5))
        let columns = max(80, min(320, scaled))
        let rows = max(24, Int((Double(columns) * Double(height) / Double(max(1, width)) / 2.0).rounded()))
        return (columns, rows)
    }
}
