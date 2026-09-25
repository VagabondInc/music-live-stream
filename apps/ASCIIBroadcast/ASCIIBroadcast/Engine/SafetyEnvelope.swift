//
//  SafetyEnvelope.swift
//  ASCII Broadcast
//
//  Phase 1 §24.2 / Phase 2 §7. The safety pass is mandatory and runs on the
//  composed frame *before* it can reach the preview or the encoder. Neither a
//  preset nor a loud track can bypass it.
//
//  IMPORTANT: this is an engineering control, not a medical guarantee. The
//  Phase 1 §29 test protocol must pass on encoded output before any claim of
//  clinical safety is made.
//

import Foundation

final class SafetyEnvelope {

    /// Maximum relative luminance change per second for the whole field while
    /// Photosensitivity Safe is on. Starting requirement, to be validated.
    private let maxLuminanceRatePerSecond = 2.4
    /// Maximum single-step change regardless of frame rate.
    private let maxLuminanceStep = 0.085
    /// A flash is only dangerous over a large area; small accents are fine.
    private let largeAreaFraction = 0.25

    private var previousLuminance: Double = 0
    private var hasHistory = false
    private(set) var interventionCount = 0
    private(set) var lastIntervention: String?

    func reset() {
        hasHistory = false
        interventionCount = 0
        lastIntervention = nil
    }

    /// Returns the gain that was applied (1.0 = untouched).
    @discardableResult
    func enforce(on grid: GlyphGrid,
                 palette: Palette,
                 dna: VisualDNA,
                 deltaTime: Double) -> Double {

        guard dna.photosensitivitySafe else {
            previousLuminance = grid.meanIntensity(palette: palette)
            hasHistory = true
            return 1.0
        }

        let luminance = grid.meanIntensity(palette: palette)
        guard hasHistory else {
            previousLuminance = luminance
            hasHistory = true
            return 1.0
        }

        let allowed = min(maxLuminanceStep, maxLuminanceRatePerSecond * max(0.001, deltaTime))
        let delta = luminance - previousLuminance

        guard abs(delta) > allowed, luminance > 0.0001 else {
            previousLuminance = luminance
            return 1.0
        }

        // Scale the whole field towards the allowed luminance. Protected
        // reading is exempt: dimming a title is not a safety measure.
        let target = previousLuminance + (delta > 0 ? allowed : -allowed)
        let gain = clamp(target / luminance, 0.25, 2.0)

        for y in 0..<grid.rows {
            for x in 0..<grid.columns {
                grid.mutate(x, y) { cell in
                    guard !cell.isProtected else { return }
                    cell.intensity = Float(clamp(Double(cell.intensity) * gain, 0, 1))
                }
            }
        }

        interventionCount += 1
        lastIntervention = String(format: "luminance step %.3f limited to %.3f", abs(delta), allowed)
        previousLuminance = target
        return gain
    }

    /// Reduce Motion clamps the grammar before scenes even run.
    static func motionCeiling(for dna: VisualDNA) -> Double {
        dna.reduceMotion ? 0.25 : 1.0
    }

    /// Effects a preset asks for but the active safety profile forbids.
    static func suppressedEffects(for dna: VisualDNA) -> [SignalFXKind] {
        guard dna.photosensitivitySafe else { return [] }
        return SignalFXKind.allCases.filter { !$0.isSafeUnderPhotosensitivity }
    }
}
