//
//  TitleLayer.swift
//  ASCII Broadcast
//
//  Phase 1 §18. Metadata is real information: it gets explicit space and time.
//  Readability always wins over the environmental trick, so every treatment
//  reserves a protected region first and decorates second.
//

import Foundation

struct TitleLayer {

    /// Title-safe inset as a fraction of the frame, applied on all sides.
    static let safeInset = 0.05

    static func render(into grid: GlyphGrid,
                       cues: [ScoreTitleCue],
                       time: Double,
                       dna: VisualDNA,
                       vocabulary: GlyphVocabulary,
                       ports: MusicPorts) {
        for cue in cues {
            let progress = clamp((time - cue.start) / max(0.01, cue.duration), 0, 1)
            // Ease in, hold, ease out. The hold is never shorter than a read.
            let appear = smoothstep(0, 0.16, progress)
            let leave = 1 - smoothstep(0.86, 1, progress)
            let presence = min(appear, leave)
            guard presence > 0.01 else { continue }
            draw(cue: cue, presence: presence, progress: progress,
                 into: grid, dna: dna, vocabulary: vocabulary, ports: ports)
        }
    }

    private static func draw(cue: ScoreTitleCue,
                             presence: Double,
                             progress: Double,
                             into grid: GlyphGrid,
                             dna: VisualDNA,
                             vocabulary: GlyphVocabulary,
                             ports: MusicPorts) {

        let scale = clamp(Double(dna.controls.titles) / 100.0, 0.25, 1.0)
        let insetX = max(2, Int(Double(grid.columns) * safeInset))
        let insetY = max(1, Int(Double(grid.rows) * safeInset))

        let primary = cue.primary.uppercased()
        let secondary = cue.secondary.uppercased()

        switch cue.treatment {
        case .cornerPlate:
            drawPlate(grid: grid, primary: primary, secondary: secondary,
                      insetX: insetX, insetY: insetY, presence: presence,
                      vocabulary: vocabulary, scale: scale)
        case .stationSign:
            drawSign(grid: grid, primary: primary, secondary: secondary,
                     insetX: insetX, insetY: insetY, presence: presence,
                     vocabulary: vocabulary, scale: scale, ports: ports)
        case .terminalOutput:
            drawTerminal(grid: grid, primary: primary, secondary: secondary,
                         insetX: insetX, insetY: insetY, presence: presence,
                         progress: progress, vocabulary: vocabulary)
        case .kinetic:
            drawKinetic(grid: grid, primary: primary, secondary: secondary,
                        insetX: insetX, insetY: insetY, presence: presence,
                        progress: progress, vocabulary: vocabulary,
                        reduceMotion: dna.reduceMotion)
        }
    }

    // MARK: - Treatments

    private static func drawPlate(grid: GlyphGrid, primary: String, secondary: String,
                                  insetX: Int, insetY: Int, presence: Double,
                                  vocabulary: GlyphVocabulary, scale: Double) {
        let width = max(primary.count, secondary.count) + 4
        let x = insetX
        let y = grid.rows - insetY - 5
        grid.protectRegion(x: x - 1, y: y - 1, width: width + 2, height: 5,
                           dim: Float(1.0 - presence * 0.85))
        grid.box(x: x - 1, y: y - 1, width: width + 2, height: 5,
                 role: .text, intensity: Float(presence * 0.5), depth: 0.98,
                 entity: 900, vocabulary: vocabulary)
        grid.text(primary, x: x + 1, y: y + 1, role: .text,
                  intensity: Float(presence), depth: 0.99, entity: 900, protected: true)
        grid.text(secondary, x: x + 1, y: y + 2, role: .memory,
                  intensity: Float(presence * 0.8), depth: 0.99, entity: 900, protected: true)
    }

    private static func drawSign(grid: GlyphGrid, primary: String, secondary: String,
                                 insetX: Int, insetY: Int, presence: Double,
                                 vocabulary: GlyphVocabulary, scale: Double, ports: MusicPorts) {
        // Architectural signage: right aligned on the lower third, hung from a
        // rule that belongs to the world.
        let tracking = 1
        let primaryWidth = primary.count * (1 + tracking)
        let secondaryWidth = secondary.count * (1 + tracking)
        let width = max(primaryWidth, secondaryWidth)
        let x = max(insetX, grid.columns - insetX - width)
        let y = grid.rows - insetY - 7

        grid.protectRegion(x: x - 2, y: y - 2, width: width + 4, height: 8,
                           dim: Float(1.0 - presence * 0.8))

        let ruleIntensity = Float(presence * (0.35 + ports.pressure * 0.3))
        grid.horizontalLine(y: y - 2, from: x - 2, to: min(grid.columns - 1, x + width + 1),
                            role: .accent, intensity: ruleIntensity, depth: 0.97,
                            entity: 901, vocabulary: vocabulary)

        grid.text(primary, x: x, y: y, role: .text, intensity: Float(presence),
                  depth: 0.99, entity: 901, protected: true, tracking: tracking)
        grid.text(secondary, x: x + (width - secondaryWidth), y: y + 2, role: .memory,
                  intensity: Float(presence * 0.85), depth: 0.99, entity: 901,
                  protected: true, tracking: tracking)
    }

    private static func drawTerminal(grid: GlyphGrid, primary: String, secondary: String,
                                     insetX: Int, insetY: Int, presence: Double,
                                     progress: Double, vocabulary: GlyphVocabulary) {
        // Typed output with a cursor. The type-on is bounded so the text is
        // fully readable for most of the cue.
        let typed = clamp(progress / 0.22, 0, 1)
        let x = insetX + 1
        let y = grid.rows - insetY - 6
        let primaryCount = Int(Double(primary.count) * typed)
        let secondaryCount = Int(Double(secondary.count) * clamp((progress - 0.14) / 0.22, 0, 1))

        grid.protectRegion(x: x - 1, y: y - 1, width: max(primary.count, secondary.count) + 12,
                           height: 5, dim: Float(1.0 - presence * 0.85))

        grid.text("> ", x: x, y: y, role: .accent, intensity: Float(presence * 0.8),
                  depth: 0.99, entity: 902, protected: true)
        grid.text(String(primary.prefix(primaryCount)), x: x + 2, y: y, role: .text,
                  intensity: Float(presence), depth: 0.99, entity: 902, protected: true)
        grid.text("> ", x: x, y: y + 1, role: .accent, intensity: Float(presence * 0.55),
                  depth: 0.99, entity: 902, protected: true)
        grid.text(String(secondary.prefix(secondaryCount)), x: x + 2, y: y + 1, role: .memory,
                  intensity: Float(presence * 0.85), depth: 0.99, entity: 902, protected: true)

        if typed < 1 {
            grid.text("_", x: x + 2 + primaryCount, y: y, role: .accent,
                      intensity: Float(presence), depth: 0.99, entity: 902, protected: true)
        }
    }

    private static func drawKinetic(grid: GlyphGrid, primary: String, secondary: String,
                                    insetX: Int, insetY: Int, presence: Double,
                                    progress: Double, vocabulary: GlyphVocabulary,
                                    reduceMotion: Bool) {
        // Letters arrive from scene fragments and settle. Reduce Motion skips
        // the travel and cross-fades the assembled state instead.
        let assembly = reduceMotion ? 1.0 : smoothstep(0, 0.30, progress)
        let width = primary.count
        let x = max(insetX, (grid.columns - width) / 2)
        let y = Int(Double(grid.rows) * 0.62)

        grid.protectRegion(x: x - 2, y: y - 2, width: width + 4, height: 6,
                           dim: Float(1.0 - presence * 0.9))

        let scalars = GlyphVocabulary.scalars(primary)
        for (offset, scalar) in scalars.enumerated() {
            let jitterSeed = Noise.hash(offset, 11, 0xBEEF)
            let travel = (1.0 - assembly) * (jitterSeed - 0.5) * Double(grid.rows) * 0.5
            let rowOffset = Int(travel)
            let intensity = Float(presence * (0.35 + assembly * 0.65))
            grid.plot(x + offset, y + rowOffset, scalar, role: .text,
                      intensity: intensity, depth: 0.99, entity: 903,
                      flags: GlyphCell.protectedText | GlyphCell.noEffect)
        }

        if assembly > 0.75 {
            let secondaryX = max(insetX, (grid.columns - secondary.count) / 2)
            grid.text(secondary, x: secondaryX, y: y + 2, role: .memory,
                      intensity: Float(presence * (assembly - 0.75) * 4 * 0.85),
                      depth: 0.99, entity: 903, protected: true)
        }
    }

    // MARK: - Broadcast graphics

    /// Optional channel branding and an unobtrusive clock, both opt-in.
    static func renderBranding(into grid: GlyphGrid,
                               channelName: String?,
                               elapsed: Double?,
                               dna: VisualDNA,
                               vocabulary: GlyphVocabulary) {
        let insetX = max(2, Int(Double(grid.columns) * safeInset))
        let insetY = max(1, Int(Double(grid.rows) * safeInset))
        if let channelName, !channelName.isEmpty {
            grid.text(channelName.uppercased(), x: insetX, y: insetY,
                      role: .memory, intensity: 0.55, depth: 0.99, entity: 904,
                      protected: true, tracking: 1)
        }
        if let elapsed {
            let text = Timecode.elapsed(elapsed)
            grid.text(text, x: grid.columns - insetX - text.count, y: insetY,
                      role: .memory, intensity: 0.5, depth: 0.99, entity: 904, protected: true)
        }
    }
}
