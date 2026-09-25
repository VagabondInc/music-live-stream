//
//  CoreTypes.swift
//  ASCII Broadcast
//
//  Vocabulary shared by every module. The two-value broadcast state model from
//  Phase 2 §3 lives here: what OUR pipeline is doing is never conflated with
//  what YouTube is showing viewers.
//

import Foundation

// MARK: - Broadcast state

/// What this machine's pipeline is doing. Locally observable, always true.
enum LocalPipelineState: String, Codable, CaseIterable {
    case offline
    case previewing
    case preflighting
    case connecting
    case sending
    case reconnecting
    case stopping
    case error

    var display: String {
        switch self {
        case .offline:      return "OFFLINE"
        case .previewing:   return "PREVIEWING"
        case .preflighting: return "PREFLIGHT"
        case .connecting:   return "CONNECTING"
        case .sending:      return "SENDING"
        case .reconnecting: return "RECONNECTING"
        case .stopping:     return "STOPPING"
        case .error:        return "ERROR"
        }
    }

    /// True when encoded packets are leaving the machine.
    var isTransmitting: Bool { self == .sending || self == .reconnecting || self == .stopping }
}

/// What the destination is showing. Never inferred from an open socket.
enum DestinationVisibility: String, Codable {
    case unknown
    case creatorReportedLive
    case providerConfirmedLive
    case providerReportedNotLive
    case providerError

    var display: String {
        switch self {
        case .unknown:                 return "LIVE STATUS UNVERIFIED"
        case .creatorReportedLive:     return "LIVE — CREATOR CONFIRMED"
        case .providerConfirmedLive:   return "LIVE — PROVIDER VERIFIED"
        case .providerReportedNotLive: return "DESTINATION NOT LIVE"
        case .providerError:           return "DESTINATION ERROR"
        }
    }
}

// MARK: - Source capability and rights

enum SourceKind: String, Codable {
    case localFile
    case filesProvider
    case bundledDemo

    var display: String {
        switch self {
        case .localFile:     return "LOCAL FILE"
        case .filesProvider: return "FILES / ICLOUD"
        case .bundledDemo:   return "BUNDLED DEMO"
        }
    }
}

enum SourceAvailability: String, Codable {
    case referenced
    case resolving
    case materializing
    case ready
    case unavailable
    case changed

    var display: String {
        switch self {
        case .referenced:    return "REFERENCED"
        case .resolving:     return "RESOLVING"
        case .materializing: return "PREPARING"
        case .ready:         return "READY"
        case .unavailable:   return "MISSING"
        case .changed:       return "CHANGED"
        }
    }

    var isPlayable: Bool { self == .ready }
}

/// A creator attestation. The app never certifies legal sufficiency; it only
/// records what the creator declared and blocks live use when unresolved.
enum RightsStatus: String, Codable, CaseIterable, CustomStringConvertible {
    case unknown
    case ownedByCreator
    case licensed
    case publicDomainOrCC
    case notCleared

    var description: String {
        switch self {
        case .unknown:          return "UNKNOWN"
        case .ownedByCreator:   return "I OWN THIS"
        case .licensed:         return "LICENSED"
        case .publicDomainOrCC: return "PD / CC"
        case .notCleared:       return "NOT CLEARED"
        }
    }

    /// Only an affirmative declaration allows an item into a live queue.
    var allowsBroadcast: Bool {
        self == .ownedByCreator || self == .licensed || self == .publicDomainOrCC
    }
}

// MARK: - Analysis coverage

enum AnalysisState: String, Codable {
    case none
    case queued
    case running
    case partial
    case complete
    case failed

    var display: String {
        switch self {
        case .none:     return "NOT ANALYZED"
        case .queued:   return "QUEUED"
        case .running:  return "ANALYZING"
        case .partial:  return "PARTIAL"
        case .complete: return "ANALYZED"
        case .failed:   return "FAILED"
        }
    }
}

// MARK: - Time

enum Timecode {

    /// `HH:MM:SS:FF` broadcast timecode.
    static func broadcast(_ seconds: Double, fps: Int = 30) -> String {
        let safe = max(0, seconds)
        let total = Int(safe)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        let frames = Int((safe - Double(total)) * Double(fps))
        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, secs, min(fps - 1, frames))
    }

    /// `M:SS` clock used in the queue and now-playing.
    static func clock(_ seconds: Double) -> String {
        let safe = max(0, seconds)
        let total = Int(safe.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// `HH:MM:SS` elapsed broadcast duration.
    static func elapsed(_ seconds: Double) -> String {
        let total = Int(max(0, seconds))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}

// MARK: - Deterministic randomness

/// Small, fast, seedable generator. Every visual decision that needs randomness
/// draws from a named stream so a score can be replayed frame-for-frame.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    init(seed: UInt64, stream: String) {
        var hash: UInt64 = 0xCBF29CE484222325
        for byte in stream.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001B3
        }
        self.state = (seed ^ hash) == 0 ? 0x9E3779B97F4A7C15 : (seed ^ hash)
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }

    mutating func range(_ lower: Double, _ upper: Double) -> Double {
        lower + unit() * (upper - lower)
    }

    mutating func index(_ count: Int) -> Int {
        guard count > 0 else { return 0 }
        return Int(next() % UInt64(count))
    }

    mutating func chance(_ probability: Double) -> Bool {
        unit() < probability
    }
}

/// Stable value noise, used for slow parameter drift that must be identical on
/// replay. Deliberately not `Double.random` anywhere in the render path.
enum Noise {
    static func hash(_ x: Int, _ y: Int, _ seed: UInt64) -> Double {
        var h = UInt64(bitPattern: Int64(x &* 374_761_393 &+ y &* 668_265_263)) ^ seed
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h ^= h >> 16
        return Double(h & 0xFFFFFF) / Double(0xFFFFFF)
    }

    static func value1D(_ t: Double, seed: UInt64) -> Double {
        let i = Int(floor(t))
        let f = t - Double(i)
        let smooth = f * f * (3 - 2 * f)
        let a = hash(i, 0, seed)
        let b = hash(i + 1, 0, seed)
        return a + (b - a) * smooth
    }

    static func fbm1D(_ t: Double, seed: UInt64, octaves: Int = 3) -> Double {
        var sum = 0.0
        var amplitude = 0.5
        var frequency = 1.0
        for octave in 0..<octaves {
            sum += value1D(t * frequency, seed: seed &+ UInt64(octave * 977)) * amplitude
            amplitude *= 0.5
            frequency *= 2.0
        }
        return sum
    }
}

// MARK: - Math helpers

@inline(__always) func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
    min(max(value, lower), upper)
}

@inline(__always) func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * clamp(t, 0, 1)
}

@inline(__always) func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    guard edge1 > edge0 else { return x < edge0 ? 0 : 1 }
    let t = clamp((x - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)
}
