//
//  ArtDirector.swift
//  ASCII Broadcast
//
//  Phase 1 §20. Automatic mode must be exemplary: the first generated identity
//  has to be presentable without repairing it through expert controls.
//
//  Generation reads distributions and transitions, selects an authored
//  direction, solves for compatible families and motion/colour/glyph rules,
//  then instantiates motifs. It never averages every track into one mood.
//

import Foundation

struct ArtDirector {

    struct Request {
        var playlistName: String
        var program: ProgramAnalysis
        var tracks: [TrackAnalysis]
        var existing: VisualDNA?
        var newVariant: Bool = false
    }

    static func generate(_ request: Request) -> VisualDNA {
        let program = request.program
        var dna = request.existing ?? VisualDNA()

        // A new variant advances the seed; a regeneration of the same identity
        // keeps it, so the show is reproducible.
        if request.newVariant || request.existing == nil {
            dna.seed = seed(for: request.playlistName, variant: request.newVariant ? UInt64(Date().timeIntervalSince1970) : 0)
            dna.id = UUID()
        }
        dna.revision += 1
        dna.sourceAnalysisRevision = program.playlistRevision

        var generator = SeededGenerator(seed: dna.seed, stream: "art-direction")

        // 1. Direction. Brightness and tempo spread separate the three
        //    authored worlds far better than genre guesswork does.
        if !dna.lockedFamilies {
            dna.direction = chooseDirection(program: program, generator: &generator)
        }

        // 2. Performance level from energy trajectory, not from peak alone: a
        //    programme that is loud throughout does not need constant spectacle.
        let energyRange = (program.energyTrajectory.max() ?? 0) - (program.energyTrajectory.min() ?? 0)
        if program.meanEnergy > 0.68 && energyRange > 0.25 {
            dna.performance = .spectacular
        } else if program.meanEnergy < 0.32 && energyRange < 0.2 {
            dna.performance = .restrained
        } else {
            dna.performance = .expressive
        }

        // 3. Detail from rhythmic density and tempo.
        let density = request.tracks.isEmpty
            ? 0.4
            : request.tracks.map(\.rhythmicDensity).reduce(0, +) / Double(request.tracks.count)
        dna.detail = density > 0.6 ? .dense : (density < 0.28 ? .sparse : .layered)

        // 4. Colour behaviour. A wide brightness spread earns more colour.
        let brightnessSpread = (program.brightnessTrajectory.max() ?? 0) - (program.brightnessTrajectory.min() ?? 0)
        if !dna.lockedPalette {
            if brightnessSpread > 0.35 {
                dna.color = .duotone
            } else if program.meanEnergy > 0.7 {
                dna.color = .saturated
            } else {
                dna.color = .restrained
            }
            dna.paletteID = Palette.authored(for: dna.direction).id
        }

        // 5. Glyph profile. Strict ASCII stays available as an art choice, but
        //    dense programmes read better with the terminal repertoire.
        dna.glyphProfile = dna.detail == .dense ? .terminal : (density < 0.25 ? .strictASCII : .terminal)

        // 6. Camera grammar.
        dna.cameraGrammar = program.meanTempo > 128 ? .travelling
            : (program.meanTempo > 96 ? .lateral : .locked)

        // 7. Guided control defaults derived from the same measurements, so a
        //    creator opening the inspector sees values that explain the result.
        var controls = dna.controls
        controls.glyphDensity = Int(clamp(38 + density * 62, 20, 95))
        controls.motion = Int(clamp(28 + program.meanEnergy * 70, 15, 92))
        controls.glitch = Int(clamp(6 + brightnessSpread * 45, 0, 55))
        controls.titles = 80
        controls.camera = dna.cameraGrammar == .locked ? 25 : (dna.cameraGrammar == .lateral ? 50 : 72)
        controls.atmosphere = Int(clamp(25 + (1 - program.meanEnergy) * 45, 10, 80))
        controls.sceneDwell = Int(clamp(75 - program.meanTempo / 3, 25, 85))
        controls.transitionVariety = 70
        controls.paletteDrift = Int(clamp(20 + brightnessSpread * 60, 0, 70))
        dna.controls = controls

        // 8. Families. Chapters that disagree are allowed to disagree, as long
        //    as they share an alphabet.
        if !dna.lockedFamilies {
            var weights: [String: Double] = [:]
            for (family, weight) in dna.direction.familyWeights {
                weights[family.rawValue] = weight
            }
            if program.chapters.count > 2 {
                // A varied programme spreads weight so no family dominates.
                for key in weights.keys { weights[key] = (weights[key] ?? 0) * 0.7 + 0.1 }
            }
            dna.familyWeights = weights
        }

        // 9. Motifs: two to four recurring forms with invariant signatures.
        if !dna.lockedMotifs {
            dna.motifs = motifs(for: dna.direction, generator: &generator)
        }

        dna.name = dna.direction.description
        dna.rationale = rationale(program: program, dna: dna)
        return dna
    }

    // MARK: - Pieces

    private static func chooseDirection(program: ProgramAnalysis,
                                        generator: inout SeededGenerator) -> WorldDirection {
        let brightness = program.brightnessTrajectory.isEmpty
            ? 0.5
            : program.brightnessTrajectory.reduce(0, +) / Double(program.brightnessTrajectory.count)

        var scores: [WorldDirection: Double] = [:]
        // Mechanical, bright, steady tempo -> Night Transit.
        scores[.nightTransit] = 0.4 + brightness * 0.5 + (program.meanTempo > 110 ? 0.3 : 0)
        // Mid brightness, wide tempo spread, warm -> Living Index.
        scores[.livingIndex] = 0.35 + (program.tempoSpread > 18 ? 0.4 : 0) + (1 - abs(brightness - 0.5)) * 0.3
        // Dark, slow, sustained -> Tidal Instrument.
        scores[.tidalInstrument] = 0.3 + (1 - brightness) * 0.6 + (program.meanTempo < 100 ? 0.35 : 0)

        // A small seeded nudge keeps two similar playlists from always landing
        // on the same world.
        for key in scores.keys { scores[key] = (scores[key] ?? 0) * (0.9 + generator.unit() * 0.2) }
        return scores.max { $0.value < $1.value }?.key ?? .nightTransit
    }

    private static func motifs(for direction: WorldDirection,
                               generator: inout SeededGenerator) -> [Motif] {
        let count = 2 + generator.index(3)
        let library: [(String, String, MotifCarrier)]
        switch direction {
        case .nightTransit:
            library = [
                ("split arch", "/~\\", .frame),
                ("lit window", "[#]", .frame),
                ("route line", "===", .path),
                ("switch point", ">|<", .point),
                ("platform number", "(3)", .token)
            ]
        case .livingIndex:
            library = [
                ("migrating parentheses", "( )", .fragments),
                ("terrace fold", "\\_/", .ribbon),
                ("annotation", "*--", .token),
                ("shelf line", "___", .path),
                ("seed head", ":*:", .point)
            ]
        case .tidalInstrument:
            library = [
                ("suspended bead", "-o-", .point),
                ("waterline", "~~~", .path),
                ("valve", "[|]", .frame),
                ("string", "|||", .ribbon),
                ("pressure mark", "^^^", .fragments)
            ]
        }
        var pool = library
        var chosen: [Motif] = []
        for _ in 0..<min(count, pool.count) {
            let index = generator.index(pool.count)
            let entry = pool.remove(at: index)
            chosen.append(Motif(name: entry.0, signature: entry.1, carrier: entry.2))
        }
        return chosen
    }

    private static func rationale(program: ProgramAnalysis, dna: VisualDNA) -> String {
        guard !program.isEmpty else {
            return "Free-running identity: no analysis yet, so the engine performs on its own clock."
        }
        let motifNames = dna.motifs.prefix(2).map(\.name).joined(separator: " and ")
        return "\(program.rationale) Directed as \(dna.direction.description) — "
            + "\(dna.performance.description.lowercased()) performance, \(dna.detail.description.lowercased()) detail, "
            + "recurring \(motifNames.isEmpty ? "marks" : motifNames)."
    }

    private static func seed(for name: String, variant: UInt64) -> UInt64 {
        var hash: UInt64 = 0xCBF29CE484222325
        for byte in name.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001B3
        }
        return hash ^ variant
    }
}
