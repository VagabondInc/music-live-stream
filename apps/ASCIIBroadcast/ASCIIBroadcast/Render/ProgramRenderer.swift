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
    private let videoASCII = VideoASCIIEngine()
    private let transport: AudioTransport

    private let lock = NSLock()
    // VisualEngine is stateful. UI preview and broadcast frame pumps may call
    // frame() concurrently, so serialize engine mutation independently of the
    // short-lived state/cache lock.
    private let renderLock = NSLock()
    // GlyphRasterizer owns mutable font metrics/cache and is shared by the UI
    // preview and offscreen encoder path. Keep those draws mutually exclusive.
    private let rasterLock = NSLock()
    private var cachedFrame: GlyphFrame?
    private var lastRenderHostTime: CFTimeInterval = 0
    private var lastTransportEpoch: Int = -1

    // Inputs, swapped atomically by the coordinator.
    private var score = VisualScore()
    private var dna = VisualDNA.starter
    private var analyses: [UUID: TrackAnalysis] = [:]    // track instance -> analysis
    private var instanceOrder: [UUID] = []
    private var channelName: String?
    private var broadcastStart: Date?

    private(set) var health = EngineHealth()
    private var frameDurations: [Double] = []
    private var diagnosticFrameCounter: UInt64 = 0

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

    func setVideoSource(_ url: URL?) {
        renderLock.lock()
        videoASCII.setSource(url)
        renderLock.unlock()
        lock.lock(); cachedFrame = nil; lock.unlock()
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
        lastTransportEpoch = -1
        lock.unlock()
        engine.reset()
    }

    // MARK: - Frame production

    /// Returns the current program frame, recomputing at most once per video
    /// frame interval. Safe to call from the UI at any refresh rate.
    @discardableResult
    func frame(now: CFTimeInterval = CACurrentMediaTime()) -> GlyphFrame {
        let transportSnapshot = transport.snapshot()

        lock.lock()
        let interval = 1.0 / Double(max(1, frameRate))
        let elapsed = now - lastRenderHostTime

        // The audio transport is the authoritative program clock. When playback
        // is paused or stopped, return the exact last frame until the transport
        // epoch changes (for example, a seek or track change). This prevents the
        // stateful visual engine from advancing scenes merely because SwiftUI or
        // the broadcast pump asks for another frame.
        if let cached = cachedFrame,
           !transportSnapshot.isPlaying,
           transportSnapshot.epoch == lastTransportEpoch {
            lastRenderHostTime = now
            lock.unlock()
            return cached
        }

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
        lastRenderHostTime = now
        lock.unlock()

        let began = CACurrentMediaTime()
        let features = transport.latestFeatures()

        // Program time is sample-clock time only. Wall-clock time must never
        // advance the visual score while the transport is paused or stopped.
        let programTime = transportSnapshot.programTime

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

        renderLock.lock()
        var produced = engine.render(input)
        produced = videoASCII.render(base: produced, trackTime: transportSnapshot.trackTime, features: features, dna: dnaCopy)
        renderLock.unlock()
        let renderMilliseconds = (CACurrentMediaTime() - began) * 1000

        // Temporary, throttled diagnostics for the black-preview investigation.
        // Emit once every ~2 seconds so diagnostics cannot become a logging storm.
        diagnosticFrameCounter &+= 1
        if diagnosticFrameCounter % UInt64(max(1, frameRate * 2)) == 0 {
            let nonBlank = produced.cells.reduce(into: 0) { count, cell in
                if cell.scalar != 32 { count += 1 }
            }
            print(String(format: "[PreviewDiagnostics] scene=%d grid=%dx%d fill=%.4f nonBlank=%d/%d render=%.2fms tier=%d",
                         produced.sceneIndex,
                         produced.columns,
                         produced.rows,
                         produced.fillFraction,
                         nonBlank,
                         produced.cells.count,
                         renderMilliseconds,
                         qualityTier))
        }

        lock.lock()
        cachedFrame = produced
        lastTransportEpoch = transportSnapshot.epoch
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
        rasterLock.lock()
        rasterizer.draw(frame: target, in: context, size: size)
        rasterLock.unlock()
    }

    /// Rasterise the program into a conventional bitmap before handing it to
    /// SwiftUI. Canvas' borrowed CGContext can carry a display-specific CTM;
    /// keeping that context out of the glyph renderer makes preview and encoder
    /// rasterisation use the same predictable pixel coordinate space.
    func previewImage(size: CGSize, frame: GlyphFrame? = nil) -> CGImage? {
        let width = max(1, Int(size.width.rounded(.up)))
        let height = max(1, Int(size.height.rounded(.up)))
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        // Use an explicit premultiplied RGBA surface. A skip-alpha bitmap is
        // valid Core Graphics storage, but giving SwiftUI a conventional alpha
        // channel removes ambiguity when the CGImage crosses the rendering
        // bridge and is composited by the view hierarchy.
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo) else {
            return nil
        }

        let target = frame ?? self.frame()
        rasterLock.lock()
        rasterizer.draw(frame: target,
                        in: context,
                        size: CGSize(width: width, height: height))
        let image = context.makeImage()
        rasterLock.unlock()
        return image
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
