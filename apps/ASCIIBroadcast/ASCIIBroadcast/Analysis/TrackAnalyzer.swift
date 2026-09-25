//
//  TrackAnalyzer.swift
//  ASCII Broadcast
//
//  Offline, streaming analysis of one asset. Measured quantities (energy,
//  spectrum, onsets, recurrence) are separated from inferred labels
//  (verse / chorus / drop), and inferred labels always carry a confidence the
//  director can degrade against.
//

import Foundation
import AVFoundation
import Accelerate

struct TrackAnalyzer {

    /// Coarse feature vector, one every `summaryInterval` seconds.
    private static let summaryInterval = 0.5

    enum AnalyzerError: LocalizedError {
        case unreadable(String)
        case empty

        var errorDescription: String? {
            switch self {
            case .unreadable(let reason):
                return "The audio could not be read (\(reason)). The track stays in your playlist; use Locate File or remove it."
            case .empty:
                return "The file decoded to no audio. The track stays in your playlist and is excluded from live use."
            }
        }
    }

    // MARK: - Entry points

    static func analyze(url: URL,
                        fingerprint: String,
                        needsSecurityScope: Bool,
                        isCancelled: () -> Bool,
                        progress: (Double) -> Void) throws -> TrackAnalysis {

        var scoped = false
        if needsSecurityScope { scoped = url.startAccessingSecurityScopedResource() }
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw AnalyzerError.unreadable(error.localizedDescription)
        }

        let format = file.processingFormat
        let sampleRate = format.sampleRate
        let totalFrames = file.length
        guard totalFrames > 0 else { throw AnalyzerError.empty }

        let chunkFrames = AVAudioFrameCount(FeatureExtractor.fftSize * 8)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) else {
            throw AnalyzerError.unreadable("buffer allocation failed")
        }

        var collector = Collector(sampleRate: sampleRate)
        var framesRead: AVAudioFramePosition = 0

        while framesRead < totalFrames {
            if isCancelled() { break }
            buffer.frameLength = 0
            do {
                try file.read(into: buffer, frameCount: chunkFrames)
            } catch {
                break
            }
            let count = Int(buffer.frameLength)
            if count == 0 { break }
            guard let channels = buffer.floatChannelData else { break }
            collector.consume(channels: channels,
                              channelCount: Int(format.channelCount),
                              frameCount: count)
            framesRead += AVAudioFramePosition(count)
            progress(Double(framesRead) / Double(totalFrames))
        }

        let duration = Double(totalFrames) / sampleRate
        var analysis = collector.finish(duration: duration, fingerprint: fingerprint)
        analysis.coverage = totalFrames > 0 ? Double(framesRead) / Double(totalFrames) : 0
        analysis.state = analysis.coverage > 0.98 ? .complete : (analysis.coverage > 0.2 ? .partial : .failed)
        return analysis
    }

    /// The bundled demo is synthesised, then analysed through exactly the same
    /// path as an imported file, so nothing about the demo is faked.
    static func analyzeDemo(index: Int,
                            fingerprint: String,
                            isCancelled: () -> Bool,
                            progress: (Double) -> Void) -> TrackAnalysis {
        let track = DemoProgram.tracks[clamp(index, 0, DemoProgram.tracks.count - 1)]
        let sampleRate = 48_000.0
        let synth = DemoSynthesizer(sampleRate: sampleRate, track: track)
        let chunk = FeatureExtractor.fftSize * 8
        var collector = Collector(sampleRate: sampleRate)
        var left = [Float](repeating: 0, count: chunk)
        var right = [Float](repeating: 0, count: chunk)
        let totalFrames = Int64(track.duration * sampleRate)
        var position: Int64 = 0

        while position < totalFrames {
            if isCancelled() { break }
            let count = Int(min(Int64(chunk), totalFrames - position))
            left.withUnsafeMutableBufferPointer { leftBuffer in
                right.withUnsafeMutableBufferPointer { rightBuffer in
                    guard let leftBase = leftBuffer.baseAddress, let rightBase = rightBuffer.baseAddress else { return }
                    synth.render(left: leftBase, right: rightBase, count: count, startFrame: position)
                    var pointers: [UnsafeMutablePointer<Float>] = [leftBase, rightBase]
                    pointers.withUnsafeMutableBufferPointer { channelBuffer in
                        if let channelBase = channelBuffer.baseAddress {
                            collector.consume(channels: channelBase, channelCount: 2, frameCount: count)
                        }
                    }
                }
            }
            position += Int64(count)
            progress(Double(position) / Double(totalFrames))
        }

        var analysis = collector.finish(duration: track.duration, fingerprint: fingerprint)
        analysis.coverage = 1
        analysis.state = .complete
        return analysis
    }

    // MARK: - Collector

    private struct Collector {
        let sampleRate: Double
        private let extractor: FeatureExtractor
        private var pending = [Float](repeating: 0, count: FeatureExtractor.fftSize)
        private var pendingRight = [Float](repeating: 0, count: FeatureExtractor.fftSize)
        private var fill = 0
        private var windowIndex = 0

        private var onsetEnvelope: [Float] = []
        private var summaries: [[Float]] = []      // per 0.5 s: 24 bands + rms + centroid
        private var summaryAccumulator = [Float](repeating: 0, count: FeatureFrame.bandCount + 2)
        private var summaryCount = 0
        private var summaryWindowTarget: Int
        private var peakLevel: Float = 0
        private var energySum: Double = 0
        private var brightnessSum: Double = 0
        private var onsetCount = 0

        init(sampleRate: Double) {
            self.sampleRate = sampleRate
            self.extractor = FeatureExtractor(sampleRate: sampleRate)
            let windowsPerSecond = sampleRate / Double(FeatureExtractor.fftSize)
            summaryWindowTarget = max(1, Int(windowsPerSecond * TrackAnalyzer.summaryInterval))
        }

        mutating func consume(channels: UnsafePointer<UnsafeMutablePointer<Float>>,
                              channelCount: Int,
                              frameCount: Int) {
            let size = FeatureExtractor.fftSize
            var consumed = 0
            while consumed < frameCount {
                let take = min(size - fill, frameCount - consumed)
                for offset in 0..<take {
                    pending[fill + offset] = channels[0][consumed + offset]
                    pendingRight[fill + offset] = channelCount > 1
                        ? channels[1][consumed + offset]
                        : channels[0][consumed + offset]
                }
                fill += take
                consumed += take

                if fill == size {
                    fill = 0
                    let time = Double(windowIndex) * Double(size) / sampleRate
                    var frame = FeatureFrame()
                    pending.withUnsafeBufferPointer { leftBuffer in
                        pendingRight.withUnsafeBufferPointer { rightBuffer in
                            guard let leftBase = leftBuffer.baseAddress,
                                  let rightBase = rightBuffer.baseAddress else { return }
                            frame = extractor.process(leftBase, count: size, time: time, rightChannel: rightBase)
                        }
                    }
                    accumulate(frame)
                    windowIndex += 1
                }
            }
        }

        private mutating func accumulate(_ frame: FeatureFrame) {
            onsetEnvelope.append(frame.flux)
            if frame.onset > 0.2 { onsetCount += 1 }
            peakLevel = max(peakLevel, frame.peak)
            energySum += Double(frame.rms)
            brightnessSum += Double(frame.centroid)

            for bandIndex in 0..<min(FeatureFrame.bandCount, frame.bands.count) {
                summaryAccumulator[bandIndex] += frame.bands[bandIndex]
            }
            summaryAccumulator[FeatureFrame.bandCount] += frame.rms
            summaryAccumulator[FeatureFrame.bandCount + 1] += frame.centroid
            summaryCount += 1

            if summaryCount >= summaryWindowTarget {
                var vector = summaryAccumulator
                let divisor = Float(summaryCount)
                for index in vector.indices { vector[index] /= divisor }
                summaries.append(vector)
                for index in summaryAccumulator.indices { summaryAccumulator[index] = 0 }
                summaryCount = 0
            }
        }

        func finish(duration: Double, fingerprint: String) -> TrackAnalysis {
            var analysis = TrackAnalysis(assetFingerprint: fingerprint)
            analysis.duration = duration
            let windowCount = max(1, windowIndex)

            analysis.energy = clamp(energySum / Double(windowCount) * 1.6, 0, 1)
            analysis.brightness = clamp(brightnessSum / Double(windowCount), 0, 1)
            analysis.rhythmicDensity = duration > 0
                ? clamp(Double(onsetCount) / duration / 6.0, 0, 1)
                : 0
            analysis.dynamicRange = clamp(Double(peakLevel) - analysis.energy, 0, 1)
            analysis.integratedLoudness = -23 + analysis.energy * 12

            let frameRate = sampleRate / Double(FeatureExtractor.fftSize)
            let tempo = TempoEstimator.estimate(onsetEnvelope: onsetEnvelope, frameRate: frameRate)
            analysis.tempo = tempo.bpm
            analysis.tempoConfidence = tempo.confidence

            analysis.energyCurve = downsample(summaries.map { $0[FeatureFrame.bandCount] }, to: 240)
            analysis.brightnessCurve = downsample(summaries.map { $0[FeatureFrame.bandCount + 1] }, to: 240)
            analysis.sections = SectionFinder.sections(from: summaries,
                                                       interval: TrackAnalyzer.summaryInterval,
                                                       duration: duration)
            analysis.events = beatEvents(tempo: tempo.bpm, confidence: tempo.confidence, duration: duration)
            return analysis
        }

        private func downsample(_ values: [Float], to count: Int) -> [Float] {
            guard values.count > count, count > 0 else { return values }
            var out = [Float](repeating: 0, count: count)
            let stride = Double(values.count) / Double(count)
            for index in 0..<count {
                let start = Int(Double(index) * stride)
                let end = min(values.count, max(start + 1, Int(Double(index + 1) * stride)))
                var sum: Float = 0
                for position in start..<end { sum += values[position] }
                out[index] = sum / Float(max(1, end - start))
            }
            return out
        }

        private func beatEvents(tempo: Double, confidence: Double, duration: Double) -> [MusicalEvent] {
            guard tempo > 40, confidence > 0.25, duration > 0 else { return [] }
            let interval = 60.0 / tempo
            var events: [MusicalEvent] = []
            var time = 0.0
            var beat = 0
            // Bounded: one entry per beat, capped so a long file cannot grow
            // the record without limit.
            while time < duration && events.count < 4_000 {
                events.append(MusicalEvent(kind: beat % 4 == 0 ? .downbeat : .beat,
                                           time: time,
                                           strength: beat % 4 == 0 ? 1.0 : 0.6,
                                           confidence: confidence))
                time += interval
                beat += 1
            }
            return events
        }
    }
}

// MARK: - Structure

/// Measured recurrence first (A / B / A′), inferred names second.
enum SectionFinder {

    static func sections(from summaries: [[Float]], interval: Double, duration: Double) -> [MusicSection] {
        guard summaries.count > 8, duration > 0 else {
            return [MusicSection(kind: .instrumental, letter: "A", start: 0, end: duration,
                                 energy: 0.5, confidence: 0.1)]
        }

        // 1. Novelty curve: how different is the near future from the near past.
        let window = max(4, Int(4.0 / interval))
        var novelty = [Double](repeating: 0, count: summaries.count)
        for index in window..<(summaries.count - window) {
            let past = meanVector(summaries, from: index - window, to: index)
            let future = meanVector(summaries, from: index, to: index + window)
            novelty[index] = 1 - cosineSimilarity(past, future)
        }

        // 2. Peak pick with a minimum musical distance.
        let mean = novelty.reduce(0, +) / Double(novelty.count)
        let variance = novelty.reduce(0) { $0 + pow($1 - mean, 2) } / Double(novelty.count)
        let threshold = mean + sqrt(variance) * 0.9
        let minimumSeparation = max(2, Int(12.0 / interval))

        var boundaries: [Int] = [0]
        var index = window
        while index < summaries.count - window {
            if novelty[index] > threshold,
               novelty[index] >= novelty[max(0, index - 1)],
               novelty[index] >= novelty[min(novelty.count - 1, index + 1)],
               index - (boundaries.last ?? 0) >= minimumSeparation {
                boundaries.append(index)
                index += minimumSeparation
            } else {
                index += 1
            }
        }
        boundaries.append(summaries.count)

        // 3. Letter the segments by similarity: this part is measured.
        var segments: [(range: Range<Int>, vector: [Float], energy: Double)] = []
        for position in 0..<(boundaries.count - 1) {
            let range = boundaries[position]..<boundaries[position + 1]
            guard range.count > 0 else { continue }
            let vector = meanVector(summaries, from: range.lowerBound, to: range.upperBound)
            let energy = Double(vector[FeatureFrame.bandCount])
            segments.append((range, vector, energy))
        }
        guard !segments.isEmpty else {
            return [MusicSection(kind: .instrumental, letter: "A", start: 0, end: duration,
                                 energy: 0.5, confidence: 0.15)]
        }

        var letters: [String] = []
        var prototypes: [[Float]] = []
        var repeatCounts: [Int] = []
        let alphabet = Array("ABCDEFGH")
        for segment in segments {
            var matched: Int?
            for (prototypeIndex, prototype) in prototypes.enumerated() {
                if cosineSimilarity(prototype, segment.vector) > 0.965 { matched = prototypeIndex; break }
            }
            if let matched {
                repeatCounts[matched] += 1
                let base = String(alphabet[min(matched, alphabet.count - 1)])
                letters.append(repeatCounts[matched] > 1 ? base + "'" : base)
            } else {
                prototypes.append(segment.vector)
                repeatCounts.append(1)
                letters.append(String(alphabet[min(prototypes.count - 1, alphabet.count - 1)]))
            }
        }

        // 4. Infer names. Clearly uncertain, so confidence stays modest.
        let energies = segments.map(\.energy)
        let maximumEnergy = energies.max() ?? 1
        let minimumEnergy = energies.min() ?? 0
        let span = max(0.0001, maximumEnergy - minimumEnergy)

        var result: [MusicSection] = []
        for (position, segment) in segments.enumerated() {
            let start = Double(segment.range.lowerBound) * interval
            let end = min(duration, Double(segment.range.upperBound) * interval)
            let relative = (segment.energy - minimumEnergy) / span
            var kind: SectionKind
            if position == 0 && relative < 0.6 {
                kind = .intro
            } else if position == segments.count - 1 && relative < 0.7 {
                kind = .outro
            } else if relative > 0.82 {
                kind = repeatCounts.count > 1 && letters[position].contains("'") ? .chorus : .drop
            } else if relative > 0.6 {
                kind = .chorus
            } else if relative < 0.22 {
                kind = .breakdown
            } else if position + 1 < segments.count,
                      (segments[position + 1].energy - segment.energy) / span > 0.3 {
                kind = .buildup
            } else {
                kind = .verse
            }

            // A short high-energy segment right before a chorus reads as a build.
            if kind == .verse && end - start < 14 && relative > 0.45 { kind = .prechorus }

            let confidence = clamp(0.25 + Double(repeatCounts.count) * 0.05 + relative * 0.2, 0.15, 0.6)
            result.append(MusicSection(kind: kind,
                                       letter: letters[position],
                                       start: start,
                                       end: end,
                                       energy: clamp(segment.energy * 1.4, 0, 1),
                                       confidence: confidence))
        }
        return result
    }

    private static func meanVector(_ summaries: [[Float]], from: Int, to: Int) -> [Float] {
        let lower = max(0, from)
        let upper = min(summaries.count, to)
        guard upper > lower, let width = summaries.first?.count else { return [] }
        var out = [Float](repeating: 0, count: width)
        for index in lower..<upper {
            let vector = summaries[index]
            for position in 0..<min(width, vector.count) { out[position] += vector[position] }
        }
        let divisor = Float(upper - lower)
        for position in out.indices { out[position] /= divisor }
        return out
    }

    private static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        guard !a.isEmpty, a.count == b.count else { return 0 }
        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        for index in a.indices {
            dot += a[index] * b[index]
            normA += a[index] * a[index]
            normB += b[index] * b[index]
        }
        guard normA > 0, normB > 0 else { return 0 }
        return Double(dot / (sqrt(normA) * sqrt(normB)))
    }
}
