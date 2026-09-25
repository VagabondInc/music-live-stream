//
//  FeatureExtractor.swift
//  ASCII Broadcast
//
//  Deterministic measurement of the program signal. No machine learning is
//  used for anything signal processing does faster and more reliably
//  (Phase 1 §27).
//
//  All buffers are preallocated: this runs close to the audio path and must
//  not allocate, lock, or touch the file system.
//

import Foundation
import Accelerate

final class FeatureExtractor {

    static let fftSize = 1024
    private let log2n: vDSP_Length
    private var fftSetup: FFTSetup?

    private var window: [Float]
    private var windowed: [Float]
    private var realParts: [Float]
    private var imaginaryParts: [Float]
    private var magnitudes: [Float]
    private var previousMagnitudes: [Float]
    private var bandEnergies: [Float]

    /// Rolling onset history for an adaptive threshold.
    private var fluxHistory: [Float]
    private var fluxCursor = 0

    private let sampleRate: Double

    init(sampleRate: Double = 48_000) {
        self.sampleRate = sampleRate
        let size = FeatureExtractor.fftSize
        log2n = vDSP_Length(log2(Double(size)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

        window = [Float](repeating: 0, count: size)
        vDSP_hann_window(&window, vDSP_Length(size), Int32(vDSP_HANN_NORM))

        windowed = [Float](repeating: 0, count: size)
        realParts = [Float](repeating: 0, count: size / 2)
        imaginaryParts = [Float](repeating: 0, count: size / 2)
        magnitudes = [Float](repeating: 0, count: size / 2)
        previousMagnitudes = [Float](repeating: 0, count: size / 2)
        bandEnergies = [Float](repeating: 0, count: FeatureFrame.bandCount)
        fluxHistory = [Float](repeating: 0, count: 43)      // ~1 second at 43 Hz
    }

    deinit {
        if let fftSetup { vDSP_destroy_fftsetup(fftSetup) }
    }

    func reset() {
        for index in previousMagnitudes.indices { previousMagnitudes[index] = 0 }
        for index in fluxHistory.indices { fluxHistory[index] = 0 }
        fluxCursor = 0
    }

    // MARK: - Analysis

    /// Process one mono window. `samples` must hold at least `fftSize` values.
    func process(_ samples: UnsafePointer<Float>, count: Int, time: Double,
                 rightChannel: UnsafePointer<Float>? = nil) -> FeatureFrame {
        let size = FeatureExtractor.fftSize
        guard count >= size, let setup = fftSetup else { return FeatureFrame(time: time) }

        var frame = FeatureFrame()
        frame.time = time

        // Time-domain measurements.
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(size))
        frame.rms = min(1, rms * 3.2)

        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(size))
        frame.peak = min(1, peak)

        if let rightChannel {
            // Stereo width from the difference signal's energy.
            var difference: Float = 0
            var sum: Float = 0
            for index in 0..<size {
                let l = samples[index]
                let r = rightChannel[index]
                difference += (l - r) * (l - r)
                sum += (l + r) * (l + r)
            }
            frame.stereoWidth = sum > 0 ? min(1, sqrt(difference / max(0.0001, sum)) * 2) : 0
        }

        // Window then real FFT.
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(size))

        realParts.withUnsafeMutableBufferPointer { realBuffer in
            imaginaryParts.withUnsafeMutableBufferPointer { imaginaryBuffer in
                guard let realBase = realBuffer.baseAddress, let imaginaryBase = imaginaryBuffer.baseAddress else { return }
                var split = DSPSplitComplex(realp: realBase, imagp: imaginaryBase)
                windowed.withUnsafeBufferPointer { windowedBuffer in
                    guard let windowedBase = windowedBuffer.baseAddress else { return }
                    windowedBase.withMemoryRebound(to: DSPComplex.self, capacity: size / 2) { complexPointer in
                        vDSP_ctoz(complexPointer, 2, &split, 1, vDSP_Length(size / 2))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
                magnitudes.withUnsafeMutableBufferPointer { magnitudeBuffer in
                    guard let magnitudeBase = magnitudeBuffer.baseAddress else { return }
                    vDSP_zvabs(&split, 1, magnitudeBase, 1, vDSP_Length(size / 2))
                }
            }
        }

        // Normalise: vDSP's real FFT is scaled by 2 * n.
        magnitudes.withUnsafeMutableBufferPointer { magnitudeBuffer in
            guard let base = magnitudeBuffer.baseAddress else { return }
            var scale = Float(1.0 / Double(size))
            vDSP_vsmul(base, 1, &scale, base, 1, vDSP_Length(size / 2))
        }

        // Log-spaced bands from 30 Hz to Nyquist.
        let binCount = size / 2
        let binWidth = sampleRate / Double(size)
        let lowestFrequency = 30.0
        let highestFrequency = min(sampleRate / 2, 16_000)
        let ratio = pow(highestFrequency / lowestFrequency, 1.0 / Double(FeatureFrame.bandCount))

        var lowSum: Float = 0
        var midSum: Float = 0
        var highSum: Float = 0
        var weightedFrequency: Double = 0
        var totalMagnitude: Double = 0

        for bandIndex in 0..<FeatureFrame.bandCount {
            let lower = lowestFrequency * pow(ratio, Double(bandIndex))
            let upper = lower * ratio
            let startBin = max(1, Int(lower / binWidth))
            let endBin = min(binCount - 1, Int(upper / binWidth))
            var sum: Float = 0
            if endBin >= startBin {
                for bin in startBin...endBin { sum += magnitudes[bin] }
                sum /= Float(endBin - startBin + 1)
            }
            // Perceptual compression: raw linear magnitude looks dead.
            let value = min(1, sqrt(sum) * 4.2)
            bandEnergies[bandIndex] = value
            if lower < 200 { lowSum += value }
            else if lower < 2_000 { midSum += value }
            else { highSum += value }
        }

        for bin in 1..<binCount {
            let magnitude = Double(magnitudes[bin])
            weightedFrequency += magnitude * (Double(bin) * binWidth)
            totalMagnitude += magnitude
        }

        frame.bands = bandEnergies
        frame.lowEnergy = min(1, lowSum / 7.0)
        frame.midEnergy = min(1, midSum / 9.0)
        frame.highEnergy = min(1, highSum / 9.0)
        frame.centroid = totalMagnitude > 0
            ? Float(min(1, (weightedFrequency / totalMagnitude) / 6_000))
            : 0

        // Spectral flux: positive change only.
        var flux: Float = 0
        for bin in 0..<binCount {
            let difference = magnitudes[bin] - previousMagnitudes[bin]
            if difference > 0 { flux += difference }
            previousMagnitudes[bin] = magnitudes[bin]
        }
        flux = min(1, flux * 6)
        frame.flux = flux

        // Adaptive onset threshold from the rolling median-ish mean.
        fluxHistory[fluxCursor] = flux
        fluxCursor = (fluxCursor + 1) % fluxHistory.count
        var mean: Float = 0
        vDSP_meanv(fluxHistory, 1, &mean, vDSP_Length(fluxHistory.count))
        let threshold = mean * 1.55 + 0.012
        frame.onset = flux > threshold ? min(1, (flux - threshold) * 7) : 0

        return frame
    }
}

// MARK: - Tempo

/// Autocorrelation tempo estimate over an onset envelope. Deterministic, and
/// honest about confidence: an ambiguous envelope returns a low score rather
/// than a confident wrong number.
enum TempoEstimator {

    static func estimate(onsetEnvelope: [Float], frameRate: Double) -> (bpm: Double, confidence: Double) {
        guard onsetEnvelope.count > 64, frameRate > 0 else { return (0, 0) }

        var envelope = onsetEnvelope
        var mean: Float = 0
        vDSP_meanv(envelope, 1, &mean, vDSP_Length(envelope.count))
        envelope.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            var negativeMean = -mean
            vDSP_vsadd(base, 1, &negativeMean, base, 1, vDSP_Length(buffer.count))
        }

        let minimumBPM = 60.0
        let maximumBPM = 190.0
        let minimumLag = max(1, Int(frameRate * 60.0 / maximumBPM))
        let maximumLag = min(envelope.count - 2, Int(frameRate * 60.0 / minimumBPM))
        guard maximumLag > minimumLag else { return (0, 0) }

        var best = (lag: 0, value: -Float.greatestFiniteMagnitude)
        var second: Float = -Float.greatestFiniteMagnitude
        var energy: Float = 0
        vDSP_svesq(envelope, 1, &energy, vDSP_Length(envelope.count))
        guard energy > 0.0001 else { return (0, 0) }

        for lag in minimumLag...maximumLag {
            var sum: Float = 0
            let count = envelope.count - lag
            envelope.withUnsafeBufferPointer { pointer in
                guard let base = pointer.baseAddress else { return }
                vDSP_dotpr(base, 1, base + lag, 1, &sum, vDSP_Length(count))
            }
            let normalised = sum / Float(count)
            if normalised > best.value {
                second = best.value
                best = (lag, normalised)
            } else if normalised > second {
                second = normalised
            }
        }

        guard best.lag > 0 else { return (0, 0) }
        let bpm = 60.0 * frameRate / Double(best.lag)
        // Confidence: how much the winner beats the runner-up.
        let margin = best.value > 0 ? Double((best.value - max(0, second)) / best.value) : 0
        let confidence = clamp(margin * 1.8, 0, 1)
        return (bpm, confidence)
    }
}
