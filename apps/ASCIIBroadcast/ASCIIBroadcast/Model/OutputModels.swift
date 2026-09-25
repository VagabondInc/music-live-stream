//
//  OutputModels.swift
//  ASCII Broadcast
//
//  Output profile, destination, preflight, and the health record the studio
//  shows while a channel is running.
//

import Foundation

// MARK: - Output profile

struct OutputProfile: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String = "1080p30"
    var width: Int = 1920
    var height: Int = 1080
    var frameRate: Int = 30
    var videoBitrate: Int = 9_800_000
    var keyframeIntervalSeconds: Double = 2
    var audioSampleRate: Double = 44_100     // YouTube's documented recommendation
    var audioBitrate: Int = 128_000
    var videoCodec: String = "h264"
    var audioCodec: String = "aac_lc"

    var resolutionLabel: String { "\(width)x\(height)" }
    var summary: String { "\(height)p\(frameRate)" }
    var bitrateLabel: String { String(format: "%.1f Mbps", Double(videoBitrate) / 1_000_000) }

    /// Character grid that fits this raster with 2:1 cells (Phase 1 §10).
    var glyphColumns: Int {
        switch height {
        case ..<800:   return 160
        case ..<1200:  return 200
        default:       return 240
        }
    }

    var glyphRows: Int {
        Int((Double(glyphColumns) * Double(height) / Double(width) * 2.0).rounded())
    }

    static let p720 = OutputProfile(name: "720p30", width: 1280, height: 720, frameRate: 30, videoBitrate: 4_000_000)
    static let p1080 = OutputProfile()
    static let all: [OutputProfile] = [.p720, .p1080]
}

// MARK: - Destination

enum DestinationKind: String, Codable, CaseIterable, CustomStringConvertible {
    case youTubeRTMPS
    case customRTMPS
    case localRecordingOnly

    var description: String {
        switch self {
        case .youTubeRTMPS:      return "YOUTUBE"
        case .customRTMPS:       return "CUSTOM RTMPS"
        case .localRecordingOnly: return "LOCAL FILE"
        }
    }
}

struct Destination: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String = "YouTube Live"
    var kind: DestinationKind = .youTubeRTMPS
    var ingestURL: String = "rtmps://a.rtmps.youtube.com/live2"
    /// Keychain account name. The key itself is never in this struct.
    var keyReference: String = "youtube.primary"
    var hasStoredKey: Bool = false

    var redactedKey: String { hasStoredKey ? String(repeating: "•", count: 22) : "no key stored" }

    /// Basic shape validation. A malformed host never reaches the network.
    func validationError() -> String? {
        guard kind != .localRecordingOnly else { return nil }
        guard let url = URL(string: ingestURL) else { return "The ingest URL could not be parsed." }
        guard let scheme = url.scheme?.lowercased() else { return "The ingest URL has no scheme." }
        guard scheme == "rtmps" || scheme == "rtmp" else {
            return "Only rtmps:// (or rtmp://) ingest URLs are supported. Found \(scheme)://."
        }
        guard let host = url.host, host.contains("."), !host.hasSuffix(".") else {
            return "The ingest URL has no usable host name."
        }
        if scheme == "rtmp" { return nil }
        return nil
    }

    var usesTLS: Bool { ingestURL.lowercased().hasPrefix("rtmps") }
}

// MARK: - Preflight

enum PreflightSeverity: String, Codable {
    case blocking
    case warning
    case info
}

struct PreflightItem: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var severity: PreflightSeverity
    var title: String
    /// What happened, why, whether data is safe, and what to do (Phase 2 §3).
    var detail: String
    var remedy: String?
}

struct PreflightReport: Codable, Hashable {
    var items: [PreflightItem] = []
    var ranAt: Date = Date()
    var playlistRevision: Int = 0
    var scoreRevision: Int = 0

    var blocking: [PreflightItem] { items.filter { $0.severity == .blocking } }
    var warnings: [PreflightItem] { items.filter { $0.severity == .warning } }
    var infos: [PreflightItem] { items.filter { $0.severity == .info } }
    var canGoLive: Bool { blocking.isEmpty && !items.isEmpty }
}

// MARK: - Health

struct PublisherHealth: Codable, Hashable {
    var connected: Bool = false
    var bytesSent: Int = 0
    var measuredBitrate: Double = 0        // bits/sec
    var roundTripMilliseconds: Double = 0
    var reconnectAttempts: Int = 0
    var lastError: String?
    var queueDepth: Int = 0
    var droppedPackets: Int = 0
}

struct EngineHealth: Codable, Hashable {
    var renderedFrames: Int = 0
    var droppedFrames: Int = 0
    var meanFrameMilliseconds: Double = 0
    var p95FrameMilliseconds: Double = 0
    var audioUnderruns: Int = 0
    var featureAgeMilliseconds: Double = 0
    var qualityTier: Int = 0               // 0 = full, higher = reduced
    var safetyInterventions: Int = 0
    var cpuFraction: Double = 0
    var gpuFraction: Double = 0
    var thermalState: String = "nominal"
    var freeStorageGB: Double = 0

    var dropRate: Double {
        let total = renderedFrames + droppedFrames
        return total == 0 ? 0 : Double(droppedFrames) / Double(total)
    }
}

// MARK: - Session

struct BroadcastSession: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var epoch: Int = 0
    var startedAt: Date?
    var endedAt: Date?
    var state: LocalPipelineState = .offline
    var visibility: DestinationVisibility = .unknown
    var playlistID: UUID?
    var acceptedScoreRevision: Int = 0
    var currentInstanceID: UUID?
    var playheadSeconds: Double = 0
    var programSeconds: Double = 0
    var wasInterrupted: Bool = false
    var lastErrorSummary: String?

    var elapsed: Double {
        guard let start = startedAt else { return 0 }
        return (endedAt ?? Date()).timeIntervalSince(start)
    }
}

/// Journal entries survive a crash so the next launch can tell the truth about
/// what happened instead of showing a stale green badge.
struct RecoveryJournalEntry: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var at: Date = Date()
    var code: String
    var message: String
    var severity: PreflightSeverity = .info
}
