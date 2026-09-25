//
//  VisualDNA.swift
//  ASCII Broadcast
//
//  Phase 1 §3. Visual DNA is a versioned, constrained style program: it says
//  what belongs to this broadcast, not what happens at 00:01:42.
//

import Foundation

// MARK: - Guided vocabulary

enum WorldDirection: String, Codable, CaseIterable, CustomStringConvertible {
    case nightTransit
    case livingIndex
    case tidalInstrument

    var description: String {
        switch self {
        case .nightTransit:    return "NIGHT_TRANSIT"
        case .livingIndex:     return "LIVING_INDEX"
        case .tidalInstrument: return "TIDAL_INSTRUMENT"
        }
    }

    var prose: String {
        switch self {
        case .nightTransit:    return "Switchyards, concourses and observatories. Strict structure, deep empty fields, mechanical anticipation."
        case .livingIndex:     return "Archives, terraces and language organisms. Paper ground, ink marks, one botanical accent."
        case .tidalInstrument: return "Pressure chambers and suspended strings. Long elastic releases over blue-black ground."
        }
    }

    /// Scene families this direction is allowed to draw from, in weight order.
    var familyWeights: [SceneFamily: Double] {
        switch self {
        case .nightTransit:
            return [.foldedCity: 0.5, .negativeSpaceTheatre: 0.3, .weavingEngine: 0.2]
        case .livingIndex:
            return [.weavingEngine: 0.45, .foldedCity: 0.25, .negativeSpaceTheatre: 0.3]
        case .tidalInstrument:
            return [.negativeSpaceTheatre: 0.45, .weavingEngine: 0.35, .foldedCity: 0.2]
        }
    }
}

enum PerformanceMode: String, Codable, CaseIterable, CustomStringConvertible {
    case restrained
    case expressive
    case spectacular

    var description: String { rawValue.uppercased() }

    /// Multiplier on the director's spectacle budget per passage.
    var spectacleBudget: Double {
        switch self {
        case .restrained:  return 0.45
        case .expressive:  return 0.75
        case .spectacular: return 1.0
        }
    }
}

enum DetailLevel: String, Codable, CaseIterable, CustomStringConvertible {
    case sparse
    case layered
    case dense

    var description: String { rawValue.uppercased() }

    var fillTarget: Double {
        switch self {
        case .sparse:  return 0.28
        case .layered: return 0.52
        case .dense:   return 0.74
        }
    }
}

enum ColorBehavior: String, Codable, CaseIterable, CustomStringConvertible {
    case monochrome
    case restrained
    case duotone
    case saturated

    var description: String { rawValue.uppercased() }
}

enum GlyphProfile: String, Codable, CaseIterable, CustomStringConvertible {
    case strictASCII
    case terminal
    case expanded

    var description: String {
        switch self {
        case .strictASCII: return "STRICT"
        case .terminal:    return "STANDARD"
        case .expanded:    return "EXPANDED"
        }
    }
}

enum CameraGrammar: String, Codable, CaseIterable, CustomStringConvertible {
    case locked
    case lateral
    case travelling

    var description: String { rawValue.uppercased() }
}

enum SceneFamily: String, Codable, CaseIterable, Hashable, CustomStringConvertible {
    case foldedCity
    case weavingEngine
    case negativeSpaceTheatre

    var description: String {
        switch self {
        case .foldedCity:           return "FOLDED_CITY"
        case .weavingEngine:        return "WEAVING_ENGINE"
        case .negativeSpaceTheatre: return "NEGATIVE_SPACE"
        }
    }

    /// Episode names shown in the PROGRAM header and the score's SCENES lane.
    var episodeTitles: [String] {
        switch self {
        case .foldedCity:
            return ["THE STATION OPENS", "THE FOLDED CITY", "APPROACH", "OVERHEAD MAP", "THE LAST WINDOW"]
        case .weavingEngine:
            return ["A BRIDGE FROM THE RHYTHM", "TWO MARGINS", "THE LOOM TURNS", "SUSPENDED THREADS"]
        case .negativeSpaceTheatre:
            return ["THE VISITOR", "NEGATIVE SPACE", "THE WALL LEARNS", "WHAT IS MISSING"]
        }
    }
}

// MARK: - Guided controls

/// The nine guided parameters from Phase 2 §3. Everything is 0...100 so the
/// UI, presets, and automation agree on a single scale.
struct GuidedControls: Codable, Hashable {
    var glyphDensity: Int = 70
    var motion: Int = 60
    var glitch: Int = 18
    var titles: Int = 80
    var camera: Int = 50
    var atmosphere: Int = 45
    var sceneDwell: Int = 55        // lower = faster scene turnover
    var transitionVariety: Int = 70
    var paletteDrift: Int = 35

    static let safeDefault = GuidedControls()
}

// MARK: - Motifs

/// Two to four recurring forms with an invariant signature. A motif survives
/// mutation: the silhouette persists even when the material changes.
struct Motif: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var signature: String           // short glyph signature, e.g. "[_]"
    var carrier: MotifCarrier
    var recurrenceCount: Int = 0
    var lastSeenTime: Double = -999
}

enum MotifCarrier: String, Codable, CaseIterable {
    case point
    case path
    case frame
    case ribbon
    case fragments
    case token
    case silhouette
}

// MARK: - Visual DNA

struct VisualDNA: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String = "NIGHT_TRANSIT"
    var seed: UInt64 = 48_271
    var revision: Int = 1
    var compilerVersion: Int = 3
    var sourceAnalysisRevision: Int = 0

    var direction: WorldDirection = .nightTransit
    var performance: PerformanceMode = .expressive
    var detail: DetailLevel = .layered
    var color: ColorBehavior = .restrained
    var glyphProfile: GlyphProfile = .terminal
    var cameraGrammar: CameraGrammar = .lateral

    var controls: GuidedControls = .safeDefault
    var familyWeights: [String: Double] = [:]      // SceneFamily.rawValue -> weight
    var motifs: [Motif] = []
    var paletteID: String = "night-transit"

    // Accessibility and safety travel with the DNA (Phase 2 §3).
    var photosensitivitySafe: Bool = true
    var reduceMotion: Bool = false
    var colorBlindSafe: Bool = false
    var titleHoldSeconds: Double = 10

    // Locks survive regeneration and later analysis updates.
    var lockedPalette: Bool = false
    var lockedFamilies: Bool = false
    var lockedMotifs: Bool = false

    var rationale: String = ""

    var weightedFamilies: [SceneFamily: Double] {
        var out: [SceneFamily: Double] = [:]
        for (key, value) in familyWeights {
            if let family = SceneFamily(rawValue: key) { out[family] = value }
        }
        return out.isEmpty ? direction.familyWeights : out
    }

    /// Effective motion after accessibility overrides. Reduce Motion is not a
    /// suggestion: it clamps the grammar the scenes are allowed to use.
    var effectiveMotion: Double {
        let base = Double(controls.motion) / 100.0
        return reduceMotion ? min(base, 0.25) : base
    }

    var effectiveGlitch: Double {
        let base = Double(controls.glitch) / 100.0
        if photosensitivitySafe { return min(base, 0.35) }
        return base
    }

    static let starter = VisualDNA()
}
