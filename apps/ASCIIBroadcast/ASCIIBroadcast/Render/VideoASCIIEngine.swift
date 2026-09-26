//
//  VideoASCIIEngine.swift
//  ASCII Broadcast
//
//  Optional video-reactive visual instrument. Source video is decoded and
//  reduced to a compact shape field on a background queue. Playback only
//  reads cached shape data, so AVAsset seeking/decoding never blocks the
//  program render clock. Live audio features are applied after the cache read
//  so the cached footage remains musically reactive.
//
//  The shape-vector idea is inspired by finnvoor/mirror (CC0-1.0); this
//  implementation is native to ASCII Broadcast and uses the existing
//  GlyphFrame pipeline.
//

import Foundation
import AVFoundation
import CoreGraphics

final class VideoASCIIEngine {
    private struct CachedGrid {
        let columns: Int
        let rows: Int
        /// Six UInt8 channels per cell: horizontal, vertical, diag \\,
        /// diag /, centre, and mass.
        let vectors: [UInt8]
    }

    private var asset: AVAsset?
    private var generator: AVAssetImageGenerator?
    private var duration: Double = 0
    private var sourceURL: URL?

    private let cacheQueue = DispatchQueue(label: "com.vagabond.asciibroadcast.video-cache", qos: .userInitiated)
    private let cacheLock = NSLock()
    private var cache: [Int: CachedGrid] = [:]
    private var pending: Set<Int> = []
    private var cacheColumns = 0
    private var cacheRows = 0
    private var cacheGeneration = 0
    private let cacheFPS = 15.0
    private let lookAheadSeconds = 4.0
    private let lookBehindSeconds = 1.0
    private let maximumCachedSeconds = 45.0

    func setSource(_ url: URL?) {
        guard url != sourceURL else { return }
        sourceURL = url

        cacheLock.lock()
        cacheGeneration &+= 1
        cache.removeAll(keepingCapacity: false)
        pending.removeAll(keepingCapacity: false)
        cacheColumns = 0
        cacheRows = 0
        cacheLock.unlock()

        guard let url else {
            asset = nil; generator = nil; duration = 0
            return
        }
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 60)
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 60)
        self.asset = asset
        self.generator = generator
        duration = max(0, asset.duration.seconds)
    }

    func render(base: GlyphFrame,
                trackTime: Double,
                features: FeatureFrame,
                dna: VisualDNA) -> GlyphFrame {
        guard dna.effectiveVisualSource != .procedural, generator != nil else { return base }
        configureCache(columns: base.columns, rows: base.rows)

        let sourceTime = duration > 0 ? trackTime.truncatingRemainder(dividingBy: duration) : trackTime
        let targetIndex = max(0, Int((max(0, sourceTime) * cacheFPS).rounded()))
        scheduleCacheWindow(around: targetIndex)

        guard let grid = cachedGrid(near: targetIndex) else {
            // Cache warming must never stall audio or the program renderer.
            return base
        }
        return compose(grid: grid, base: base, features: features, dna: dna)
    }

    private func configureCache(columns: Int, rows: Int) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        guard columns != cacheColumns || rows != cacheRows else { return }
        cacheGeneration &+= 1
        cache.removeAll(keepingCapacity: false)
        pending.removeAll(keepingCapacity: false)
        cacheColumns = columns
        cacheRows = rows
    }

    private func scheduleCacheWindow(around target: Int) {
        let behind = Int((lookBehindSeconds * cacheFPS).rounded())
        let ahead = Int((lookAheadSeconds * cacheFPS).rounded())
        let maximumIndex = duration > 0 ? max(0, Int((duration * cacheFPS).rounded()) - 1) : target + ahead
        let lower = max(0, target - behind)
        let upper = min(maximumIndex, target + ahead)

        // Target first, then fan outward. This makes seeking responsive while
        // still building a continuous look-ahead buffer for smooth playback.
        var indices: [Int] = [target]
        if upper >= lower {
            for offset in 1...max(target - lower, upper - target) {
                let forward = target + offset
                let backward = target - offset
                if forward <= upper { indices.append(forward) }
                if backward >= lower { indices.append(backward) }
            }
        }

        for index in indices { schedule(index: index) }
    }

    private func schedule(index: Int) {
        cacheLock.lock()
        if cache[index] != nil || pending.contains(index) {
            cacheLock.unlock()
            return
        }
        pending.insert(index)
        let generation = cacheGeneration
        let columns = cacheColumns
        let rows = cacheRows
        let generator = self.generator
        cacheLock.unlock()

        guard columns > 0, rows > 0, let generator else { return }
        cacheQueue.async { [weak self] in
            guard let self else { return }
            let time = CMTime(seconds: Double(index) / self.cacheFPS, preferredTimescale: 600)
            let image = try? generator.copyCGImage(at: time, actualTime: nil)
            let grid = image.flatMap { self.analyse(image: $0, columns: columns, rows: rows) }

            self.cacheLock.lock()
            defer { self.cacheLock.unlock() }
            self.pending.remove(index)
            guard generation == self.cacheGeneration,
                  columns == self.cacheColumns,
                  rows == self.cacheRows,
                  let grid else { return }
            self.cache[index] = grid
            self.trimCache(around: index)
        }
    }

    private func cachedGrid(near index: Int) -> CachedGrid? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let exact = cache[index] { return exact }
        // Reusing a nearby cached source frame is preferable to blocking the
        // render clock. At 15 fps this tolerance is at most ~130 ms.
        for distance in 1...2 {
            if let previous = cache[index - distance] { return previous }
            if let next = cache[index + distance] { return next }
        }
        return nil
    }

    private func trimCache(around index: Int) {
        let radius = Int((maximumCachedSeconds * cacheFPS / 2).rounded())
        guard cache.count > radius * 2 else { return }
        let lower = max(0, index - radius)
        let upper = index + radius
        cache = cache.filter { $0.key >= lower && $0.key <= upper }
    }

    private func analyse(image: CGImage, columns: Int, rows: Int) -> CachedGrid? {
        let sampleWidth = columns * 3
        let sampleHeight = rows * 3
        let pixelCount = sampleWidth * sampleHeight
        let pixelBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelCount)
        pixelBuffer.initialize(repeating: 0, count: pixelCount)
        defer { pixelBuffer.deallocate() }

        guard let context = CGContext(data: pixelBuffer,
                                      width: sampleWidth, height: sampleHeight,
                                      bitsPerComponent: 8, bytesPerRow: sampleWidth,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }

        context.interpolationQuality = .medium
        let sourceAspect = CGFloat(image.width) / CGFloat(max(1, image.height))
        let targetAspect = CGFloat(sampleWidth) / CGFloat(max(1, sampleHeight))
        var rect = CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight)
        if sourceAspect > targetAspect {
            let width = CGFloat(sampleHeight) * sourceAspect
            rect.origin.x = (CGFloat(sampleWidth) - width) * 0.5
            rect.size.width = width
        } else {
            let height = CGFloat(sampleWidth) / sourceAspect
            rect.origin.y = (CGFloat(sampleHeight) - height) * 0.5
            rect.size.height = height
        }
        context.draw(image, in: rect)

        @inline(__always) func raw(_ x: Int, _ y: Int) -> Double {
            Double(pixelBuffer[clamp(y, 0, sampleHeight - 1) * sampleWidth + clamp(x, 0, sampleWidth - 1)]) / 255.0
        }
        @inline(__always) func byte(_ value: Double) -> UInt8 {
            UInt8((clamp(value, 0, 1) * 255.0).rounded())
        }

        var vectors = [UInt8]()
        vectors.reserveCapacity(columns * rows * 6)
        for row in 0..<rows {
            for col in 0..<columns {
                let x = col * 3, y = row * 3
                let a = raw(x, y), b = raw(x+1, y), c = raw(x+2, y)
                let d = raw(x, y+1), e = raw(x+1, y+1), f = raw(x+2, y+1)
                let g = raw(x, y+2), h = raw(x+1, y+2), i = raw(x+2, y+2)
                let mass = (a+b+c+d+e+f+g+h+i) / 9
                let horizontal = abs((a+d+g) - (c+f+i)) / 3 * 1.7
                let vertical = abs((a+b+c) - (g+h+i)) / 3 * 1.7
                let diagDown = abs((a+e+i) - (c+e+g)) / 3 * 1.7
                let diagUp = abs((c+e+g) - (a+e+i)) / 3 * 1.7
                let centre = abs(e - (a+c+g+i)/4) * 2.0
                vectors.append(byte(horizontal))
                vectors.append(byte(vertical))
                vectors.append(byte(diagDown))
                vectors.append(byte(diagUp))
                vectors.append(byte(centre))
                vectors.append(byte(mass))
            }
        }
        return CachedGrid(columns: columns, rows: rows, vectors: vectors)
    }

    private struct Template {
        let scalar: UInt16
        let vector: [Double]
    }

    private static let templates: [Template] = {
        func u(_ s: Character) -> UInt16 { UInt16(String(s).unicodeScalars.first!.value) }
        return [
            Template(scalar: 32,     vector: [0,0,0,0,0,0.02]),
            Template(scalar: u("."), vector: [0,0,0,0,0.35,0.16]),
            Template(scalar: u("-"), vector: [0.95,0.08,0.1,0.1,0.25,0.35]),
            Template(scalar: u("|"), vector: [0.08,0.95,0.1,0.1,0.25,0.35]),
            Template(scalar: u("\\"),vector: [0.1,0.1,0.95,0.08,0.3,0.35]),
            Template(scalar: u("/"), vector: [0.1,0.1,0.08,0.95,0.3,0.35]),
            Template(scalar: u("+"), vector: [0.72,0.72,0.2,0.2,0.55,0.52]),
            Template(scalar: u("x"), vector: [0.2,0.2,0.72,0.72,0.55,0.52]),
            Template(scalar: u("*"), vector: [0.55,0.55,0.55,0.55,0.8,0.68]),
            Template(scalar: u("#"), vector: [0.75,0.75,0.45,0.45,0.8,0.82]),
            Template(scalar: u("@"), vector: [0.55,0.55,0.45,0.45,0.95,0.98])
        ]
    }()

    private func compose(grid: CachedGrid, base: GlyphFrame, features: FeatureFrame, dna: VisualDNA) -> GlyphFrame {
        guard grid.columns == base.columns, grid.rows == base.rows else { return base }
        let onset = Double(features.onset), flux = Double(features.flux)
        let pulse = clamp(onset * 0.75 + flux * 0.35 + Double(features.lowEnergy) * 0.18, 0, 1)
        let contrast = 1.15 + pulse * 1.9 + Double(features.highEnergy) * 0.45
        let lift = (Double(features.rms) - 0.25) * 0.16 + pulse * 0.18
        let vocabulary = GlyphVocabulary(profile: dna.glyphProfile)
        var cells = base.cells

        for cellIndex in 0..<(grid.columns * grid.rows) {
            let offset = cellIndex * 6
            let horizontal = Double(grid.vectors[offset]) / 255
            let vertical = Double(grid.vectors[offset + 1]) / 255
            let diagDown = Double(grid.vectors[offset + 2]) / 255
            let diagUp = Double(grid.vectors[offset + 3]) / 255
            let centre = Double(grid.vectors[offset + 4]) / 255
            let rawMass = Double(grid.vectors[offset + 5]) / 255
            let mass = clamp((rawMass - 0.5) * contrast + 0.5 + lift, 0, 1)
            let vector = [horizontal, vertical, diagDown, diagUp, centre, mass]

            var best = Self.templates[0], bestDistance = Double.greatestFiniteMagnitude
            for template in Self.templates {
                var distance = 0.0
                for k in 0..<6 {
                    let weight = k == 5 ? 0.72 : 1.0
                    let delta = vector[k] - template.vector[k]
                    distance += delta * delta * weight
                }
                if distance < bestDistance { bestDistance = distance; best = template }
            }

            let edge = max(horizontal, vertical, diagDown, diagUp, centre)
            let scalar = edge > 0.22 ? best.scalar : vocabulary.glyph(coverage: mass)
            let role: PaletteRole = mass > 0.72 ? .accent : (edge > 0.3 ? .subject : .structure)
            let newCell = GlyphCell(scalar: scalar, role: role,
                                    intensity: Float(clamp(0.25 + mass * 0.8 + pulse * 0.12, 0, 1)),
                                    depth: 0.88, entity: 900)
            if dna.effectiveVisualSource == .videoReactive ||
                (dna.effectiveVisualSource == .hybrid && (edge > 0.20 || mass > 0.58)) {
                cells[cellIndex] = newCell
            }
        }

        var out = base
        out.cells = cells
        out.worldLabel = dna.effectiveVisualSource.description
        out.fillFraction = Double(cells.reduce(into: 0) { if !$1.isBlank { $0 += 1 } }) / Double(max(1, cells.count))
        return out
    }
}
