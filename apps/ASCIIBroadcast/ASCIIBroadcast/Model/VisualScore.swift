//
//  VisualScore.swift
//  ASCII Broadcast
//
//  The compiled performance. One row per lane in the VISUAL_SCORE panel:
//  chapters, scenes, transitions, titles, signal FX, memory.
//

import Foundation

// MARK: - Lanes

struct ScoreChapterCue: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var letter: String
    var title: String
    var start: Double
    var end: Double
    var isReprise: Bool = false
}

struct ScoreSceneCue: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var index: Int
    var family: SceneFamily
    var episodeTitle: String
    var slug: String                 // 03_STATION_OPEN
    var start: Double
    var end: Double
    var seed: UInt64
    var intensity: Double            // 0...1 planned dramatic level
    var trackInstanceID: UUID?

    var duration: Double { max(0.1, end - start) }
}

struct ScoreTransitionCue: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var kind: TransitionKind
    var start: Double
    var duration: Double
    var carriedMotifID: UUID?

    var end: Double { start + duration }
}

enum TitleTreatment: String, Codable, CaseIterable {
    case stationSign        // architectural signage in world depth
    case terminalOutput     // typed, left aligned, cursor
    case kinetic            // assembles from scene fragments
    case cornerPlate        // quiet screen-space plate

    var display: String {
        switch self {
        case .stationSign:    return "SIGNAGE"
        case .terminalOutput: return "TERMINAL"
        case .kinetic:        return "KINETIC"
        case .cornerPlate:    return "PLATE"
        }
    }
}

struct ScoreTitleCue: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var primary: String              // title
    var secondary: String            // artist
    var start: Double
    var duration: Double
    var treatment: TitleTreatment
    var isOutgoing: Bool = false

    var end: Double { start + duration }
}

enum SignalFXKind: String, Codable, CaseIterable {
    case characterRain
    case shockwave
    case fragmentation
    case scanDeform
    case corruption
    case pixelSort
    case inversion
    case dissolveField

    var display: String {
        switch self {
        case .characterRain:  return "RAIN"
        case .shockwave:      return "SHOCK"
        case .fragmentation:  return "FRAGMENT"
        case .scanDeform:     return "SCAN"
        case .corruption:     return "CORRUPT"
        case .pixelSort:      return "SORT"
        case .inversion:      return "INVERT"
        case .dissolveField:  return "DISSOLVE"
        }
    }

    /// Photosensitivity Safe removes whole-frame luminance events.
    var isSafeUnderPhotosensitivity: Bool {
        switch self {
        case .inversion, .corruption: return false
        default: return true
        }
    }

    var cooldown: Double {
        switch self {
        case .shockwave: return 12
        case .inversion: return 45
        default: return 20
        }
    }
}

struct ScoreFXCue: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var kind: SignalFXKind
    var start: Double
    var duration: Double
    var intensity: Double

    var end: Double { start + duration }
}

/// A point the engine can reconstruct from: seek, crash recovery, and the
/// MEMORY lane's diamonds are the same mechanism.
struct ScoreMemoryMark: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var label: String                // M1, M2...
    var time: Double
    var motifName: String
    var sceneIndex: Int
}

// MARK: - Score

struct VisualScore: Codable, Hashable {
    var id: UUID = UUID()
    var revision: Int = 1
    var dnaRevision: Int = 0
    var playlistRevision: Int = 0
    var name: String = ""
    var duration: Double = 0
    var chapters: [ScoreChapterCue] = []
    var scenes: [ScoreSceneCue] = []
    var transitions: [ScoreTransitionCue] = []
    var titles: [ScoreTitleCue] = []
    var fx: [ScoreFXCue] = []
    var memory: [ScoreMemoryMark] = []
    var compiledAt: Date = Date()

    var isEmpty: Bool { scenes.isEmpty }

    func scene(at time: Double) -> ScoreSceneCue? {
        scenes.first { time >= $0.start && time < $0.end } ?? scenes.last
    }

    func chapter(at time: Double) -> ScoreChapterCue? {
        chapters.first { time >= $0.start && time < $0.end }
    }

    func transition(at time: Double) -> ScoreTransitionCue? {
        transitions.first { time >= $0.start && time < $0.end }
    }

    func activeTitles(at time: Double) -> [ScoreTitleCue] {
        titles.filter { time >= $0.start && time < $0.end }
    }

    func activeFX(at time: Double) -> [ScoreFXCue] {
        fx.filter { time >= $0.start && time < $0.end }
    }

    func sceneIndex(at time: Double) -> Int {
        scene(at: time)?.index ?? 0
    }
}
