//
//  Analysis.swift
//  ASCII Broadcast
//
//  Measured audio features and the structure inferred from them.
//  Phase 1 §4.1: measurement, inference, and interpretation are kept apart and
//  every inferred label carries a confidence the renderer can degrade against.
//

import Foundation

// MARK: - Feature frame

/// One analysis window. Deterministic measurements only.
struct FeatureFrame: Codable, Hashable {
    var time: Double = 0             // program seconds at window centre
    var rms: Float = 0               // 0...1
    var peak: Float = 0              // 0...1
    var bands: [Float] = Array(repeating: 0, count: FeatureFrame.bandCount)
    var centroid: Float = 0          // normalised 0...1
    var flux: Float = 0              // positive spectral change
    var onset: Float = 0             // 0...1 detection strength this frame
    var lowEnergy: Float = 0
    var midEnergy: Float = 0
    var highEnergy: Float = 0
    var stereoWidth: Float = 0

    static let bandCount = 24

    static let silent = FeatureFrame()

    /// Perceptual-ish drive used by scenes that want "how much is happening".
    var pressure: Float { min(1, lowEnergy * 1.25) }
    var articulation: Float { min(1, (highEnergy * 0.7 + flux * 0.6)) }
    var body: Float { min(1, midEnergy * 1.1) }
}

// MARK: - Musical events

enum MusicalEventKind: String, Codable {
    case beat
    case downbeat
    case onset
    case transient
    case sectionBoundary
    case buildStart
    case drop
    case breakdown
    case silence
}

struct MusicalEvent: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var kind: MusicalEventKind
    var time: Double
    var strength: Double = 1
    var confidence: Double = 1
}

// MARK: - Structure

enum SectionKind: String, Codable, CaseIterable {
    case intro
    case verse
    case prechorus
    case chorus
    case bridge
    case breakdown
    case buildup
    case drop
    case instrumental
    case outro

    var display: String { rawValue.uppercased() }

    /// How much spectacle the director is allowed to spend here.
    var spectacleWeight: Double {
        switch self {
        case .intro:        return 0.25
        case .verse:        return 0.35
        case .prechorus:    return 0.55
        case .chorus:       return 0.85
        case .bridge:       return 0.5
        case .breakdown:    return 0.2
        case .buildup:      return 0.7
        case .drop:         return 1.0
        case .instrumental: return 0.45
        case .outro:        return 0.2
        }
    }
}

struct MusicSection: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var kind: SectionKind
    /// A/B/A′ label derived from self-similarity — measured, unlike `kind`.
    var letter: String
    var start: Double
    var end: Double
    var energy: Double          // 0...1 mean
    var confidence: Double      // 0...1 in the *label*, not the boundary

    var duration: Double { max(0, end - start) }
}

// MARK: - Track analysis

struct TrackAnalysis: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var assetFingerprint: String
    var extractorVersion: Int = 3
    var duration: Double = 0
    var tempo: Double = 0               // BPM, 0 = unknown
    var tempoConfidence: Double = 0
    var meterNumerator: Int = 4
    var meterDenominator: Int = 4
    var beatGridOffset: Double = 0
    var integratedLoudness: Double = -23 // dBFS approximation
    var energy: Double = 0              // 0...1
    var brightness: Double = 0          // mean spectral centroid 0...1
    var rhythmicDensity: Double = 0     // onsets per second, normalised
    var dynamicRange: Double = 0
    var sections: [MusicSection] = []
    var energyCurve: [Float] = []       // ~1 Hz summary for the score lane
    var brightnessCurve: [Float] = []
    var events: [MusicalEvent] = []
    var coverage: Double = 0            // fraction of file actually analysed
    var state: AnalysisState = .none
    var failureReason: String?

    var isUsable: Bool { state == .complete || state == .partial }

    func section(at time: Double) -> MusicSection? {
        sections.first { time >= $0.start && time < $0.end }
    }

    /// Honest confidence for the whole track, used to pick free-running mode.
    var overallConfidence: Double {
        guard isUsable else { return 0 }
        let sectionConfidence = sections.isEmpty ? 0.2 : sections.map(\.confidence).reduce(0, +) / Double(sections.count)
        return clamp(coverage * 0.5 + tempoConfidence * 0.2 + sectionConfidence * 0.3, 0, 1)
    }
}

// MARK: - Program analysis

/// Chapters group adjacent tracks that belong together stylistically. They are
/// the A / B / C / A′ lane at the top of the visual score.
struct ProgramChapter: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var letter: String
    var title: String
    var startTrackIndex: Int
    var endTrackIndex: Int
    var meanEnergy: Double
    var meanTempo: Double
    var isReprise: Bool = false
}

struct ProgramAnalysis: Codable, Hashable {
    var playlistRevision: Int = 0
    var trackCount: Int = 0
    var totalDuration: Double = 0
    var meanTempo: Double = 0
    var tempoSpread: Double = 0
    var meanEnergy: Double = 0
    var energyTrajectory: [Double] = []    // one value per track
    var brightnessTrajectory: [Double] = []
    var chapters: [ProgramChapter] = []
    var abruptChanges: [Int] = []          // track indices with a hard change
    var coverage: Double = 0
    var computedAt: Date = Date()

    var isEmpty: Bool { trackCount == 0 }

    /// One line the creator can read: the rationale shown after generation.
    var rationale: String {
        guard !isEmpty else { return "No analysis yet." }
        let tempoWord: String
        switch meanTempo {
        case ..<90:    tempoWord = "slow"
        case ..<115:   tempoWord = "mid-tempo"
        case ..<135:   tempoWord = "steady"
        default:       tempoWord = "driving"
        }
        let energyWord: String
        switch meanEnergy {
        case ..<0.3:  energyWord = "restrained"
        case ..<0.55: energyWord = "measured"
        case ..<0.75: energyWord = "forceful"
        default:      energyWord = "loud"
        }
        let shape = chapters.count <= 1 ? "one continuous chapter" : "\(chapters.count) chapters"
        return "\(trackCount) tracks, \(tempoWord) and \(energyWord), read as \(shape)."
    }
}
