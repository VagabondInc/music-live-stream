//
//  Playlist.swift
//  ASCII Broadcast
//
//  The program: source assets, the creator's rights declarations, and the
//  ordered track instances that make up a broadcast.
//

import Foundation

// MARK: - Source asset

/// A file the creator pointed us at. Stored by bookmark so the reference
/// survives relaunch; a missing file keeps its entry and its analysis.
struct SourceAsset: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var kind: SourceKind = .localFile
    var displayName: String
    var artist: String
    var album: String
    var year: Int?
    var duration: Double            // seconds, 0 when unknown
    var sampleRate: Double
    var channelCount: Int
    var codecDescription: String
    var bookmark: Data?             // security-scoped, never exported
    var lastKnownPath: String
    var fingerprint: String         // size + mtime + head hash
    var availability: SourceAvailability = .referenced
    var hasEmbeddedArtwork: Bool = false
    var importedAt: Date = Date()

    var titleOrFilename: String {
        displayName.isEmpty ? (lastKnownPath as NSString).lastPathComponent : displayName
    }

    static func demo(title: String, artist: String, duration: Double, index: Int) -> SourceAsset {
        SourceAsset(
            kind: .bundledDemo,
            displayName: title,
            artist: artist,
            album: "Glass Cities",
            year: 2026,
            duration: duration,
            sampleRate: 48_000,
            channelCount: 2,
            codecDescription: "demo synth",
            bookmark: nil,
            lastKnownPath: "bundled://demo/\(index)",
            fingerprint: "demo-\(index)",
            availability: .ready,
            hasEmbeddedArtwork: false
        )
    }
}

// MARK: - Rights

struct SourceRightsRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var assetID: UUID
    var recording: RightsStatus = .unknown
    var composition: RightsStatus = .unknown
    var artwork: RightsStatus = .unknown
    var evidenceNote: String = ""
    var reviewedAt: Date?

    /// Both the recording and the composition must be affirmatively declared.
    /// Artwork only gates artwork: missing artwork rights means typography.
    var allowsBroadcast: Bool { recording.allowsBroadcast && composition.allowsBroadcast }
    var allowsArtworkOnOutput: Bool { artwork.allowsBroadcast }

    var summary: String {
        if allowsBroadcast { return artwork.allowsBroadcast ? "DECLARED" : "DECLARED / NO ART" }
        if recording == .notCleared || composition == .notCleared { return "NOT CLEARED" }
        return "UNDECLARED"
    }
}

// MARK: - Track instance

/// One placement of an asset in a program. Two copies of the same file are two
/// distinct instances with their own trims, gain, and transition preference.
struct TrackInstance: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var assetID: UUID
    var trimStart: Double = 0
    var trimEnd: Double? = nil
    var gainDB: Double = 0
    var transitionPreference: TransitionKind? = nil
    var titleOverride: String? = nil
    var artistOverride: String? = nil
}

enum TransitionKind: String, Codable, CaseIterable, CustomStringConvertible {
    case fadeIn
    case dissolve
    case beatMatch
    case glitch
    case crossfade
    case hold
    case objectHandoff
    case negativeSpace
    case terminalReset
    case fadeOut

    var description: String {
        switch self {
        case .fadeIn:        return "FADE IN"
        case .dissolve:      return "DISSOLVE"
        case .beatMatch:     return "BEAT MATCH"
        case .glitch:        return "GLITCH"
        case .crossfade:     return "CROSSFADE"
        case .hold:          return "HOLD"
        case .objectHandoff: return "HANDOFF"
        case .negativeSpace: return "NEG SPACE"
        case .terminalReset: return "RESET"
        case .fadeOut:       return "FADE OUT"
        }
    }

    /// Seconds the bridge occupies either side of the track boundary.
    var duration: Double {
        switch self {
        case .fadeIn, .fadeOut: return 3.0
        case .dissolve:         return 4.0
        case .beatMatch:        return 2.0
        case .glitch:           return 1.2
        case .crossfade:        return 5.0
        case .hold:             return 2.0
        case .objectHandoff:    return 4.5
        case .negativeSpace:    return 3.5
        case .terminalReset:    return 1.8
        }
    }
}

// MARK: - Playlist

struct Playlist: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var revision: Int = 1
    var instances: [TrackInstance] = []
    var loops: Bool = true
    var autoAdvance: Bool = true
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    mutating func touch() {
        revision += 1
        modifiedAt = Date()
    }

    /// Session name in the mockup's title bar: GLASS_CITIES.
    var sessionSlug: String {
        let upper = name.uppercased()
        let mapped = upper.map { char -> Character in
            if char.isLetter || char.isNumber { return char }
            return "_"
        }
        return String(mapped)
    }
}

// MARK: - Library

/// Everything the studio knows about the creator's imported material.
struct MediaLibrary: Codable {
    var assets: [UUID: SourceAsset] = [:]
    var rights: [UUID: SourceRightsRecord] = [:]

    mutating func insert(_ asset: SourceAsset) {
        assets[asset.id] = asset
        if rights[asset.id] == nil {
            rights[asset.id] = SourceRightsRecord(assetID: asset.id)
        }
    }

    func asset(_ id: UUID) -> SourceAsset? { assets[id] }

    func rightsRecord(for id: UUID) -> SourceRightsRecord {
        rights[id] ?? SourceRightsRecord(assetID: id)
    }
}
