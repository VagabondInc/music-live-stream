//
//  PreflightService.swift
//  ASCII Broadcast
//
//  Preflight is a contract, not a formality: every blocking item names what is
//  wrong, why it matters, and the one action that clears it. Nothing here
//  touches the network except the destination shape check.
//

import Foundation

enum PreflightService {

    struct Context {
        var playlist: Playlist
        var library: MediaLibrary
        var analyses: [UUID: TrackAnalysis]
        var score: VisualScore
        var scoreRevision: Int
        var destination: Destination
        var profile: OutputProfile
        var hasStoredKey: Bool
        var recordLocally: Bool
        var freeDiskGB: Double
        var engineHealth: EngineHealth
        var photosensitivitySafe: Bool
    }

    static func run(_ context: Context) -> PreflightReport {
        var items: [PreflightItem] = []

        // 1. Programme content
        if context.playlist.instances.isEmpty {
            items.append(PreflightItem(
                severity: .blocking,
                title: "The queue is empty",
                detail: "A channel needs at least one track. Nothing has been sent and no session has started.",
                remedy: "Add tracks from the library, or load the demo programme."))
        }

        // 2. Sources present and playable
        let missing = context.playlist.instances.filter { entry in
            guard let asset = context.library.asset(entry.assetID) else { return true }
            return !asset.availability.isPlayable
        }
        if !missing.isEmpty {
            let names = missing.prefix(3).map { entry in
                context.library.asset(entry.assetID)?.titleOrFilename ?? "Unknown track"
            }.joined(separator: ", ")
            items.append(PreflightItem(
                severity: .blocking,
                title: "\(missing.count) source\(missing.count == 1 ? " is" : "s are") unavailable",
                detail: "\(names)\(missing.count > 3 ? "…" : "") cannot be read. A live programme must never hit a silent gap, so the session will not start.",
                remedy: "Relink the files, or remove them from the queue."))
        }

        // 3. Rights
        let unclearedCount = context.playlist.instances.filter { entry in
            guard let asset = context.library.asset(entry.assetID) else { return false }
            return !context.library.rightsRecord(for: asset.id).allowsBroadcast
        }.count
        if unclearedCount > 0 {
            items.append(PreflightItem(
                severity: .warning,
                title: "\(unclearedCount) track\(unclearedCount == 1 ? "" : "s") without a rights note",
                detail: "You are responsible for the rights to everything you broadcast. The app does not judge your music; it only records what you have told it.",
                remedy: "Open Rights in the library panel and mark each track, or continue if you already hold the rights."))
        }

        // 4. Analysis
        let analysed = context.playlist.instances.filter { entry in
            context.analyses[entry.id]?.state == .complete
        }.count
        if !context.playlist.instances.isEmpty && analysed < context.playlist.instances.count {
            let outstanding = context.playlist.instances.count - analysed
            items.append(PreflightItem(
                severity: outstanding == context.playlist.instances.count ? .blocking : .warning,
                title: "\(outstanding) track\(outstanding == 1 ? "" : "s") not analysed",
                detail: outstanding == context.playlist.instances.count
                    ? "Without analysis the visuals cannot follow the music, only react to it. The session will not start."
                    : "Unanalysed tracks fall back to live reaction: still musical, but without planned structure.",
                remedy: "Run Analyse in the library panel. It takes roughly a second per minute of audio."))
        }

        // 5. Score acceptance
        if context.score.isEmpty && !context.playlist.instances.isEmpty {
            items.append(PreflightItem(
                severity: .warning,
                title: "No visual score has been compiled",
                detail: "The engine will free-run: scenes will cycle on a timer instead of following the programme's structure.",
                remedy: "Press Generate in the Visual DNA inspector to compile a score."))
        }

        // 6. Destination
        if context.destination.kind != .localRecordingOnly {
            if let error = context.destination.validationError() {
                items.append(PreflightItem(
                    severity: .blocking,
                    title: "The destination is not usable",
                    detail: error,
                    remedy: "Correct the ingest URL in Output settings."))
            }
            if !context.hasStoredKey {
                items.append(PreflightItem(
                    severity: .blocking,
                    title: "No stream key stored",
                    detail: "The destination needs a key before a connection can be attempted. Keys are stored in the keychain and never written to the session file.",
                    remedy: "Paste the stream key in Output settings."))
            }
        }

        // 7. Disk
        let estimatedGBPerHour = Double(context.profile.videoBitrate + context.profile.audioBitrate) * 3600 / 8 / 1_000_000_000
        if context.recordLocally {
            if context.freeDiskGB < estimatedGBPerHour {
                items.append(PreflightItem(
                    severity: .blocking,
                    title: "Not enough free space to record",
                    detail: String(format: "Recording needs about %.1f GB per hour at %@; %.1f GB is free.",
                                   estimatedGBPerHour, context.profile.summary, context.freeDiskGB),
                    remedy: "Free up space, or turn off local recording."))
            } else if context.freeDiskGB < estimatedGBPerHour * 3 {
                items.append(PreflightItem(
                    severity: .warning,
                    title: "Less than three hours of recording space",
                    detail: String(format: "%.1f GB free, about %.1f GB per hour.", context.freeDiskGB, estimatedGBPerHour),
                    remedy: "Free up space if you plan a long session."))
            }
        }

        // 8. Headroom
        let budget = 1000.0 / Double(max(1, context.profile.frameRate))
        if context.engineHealth.p95FrameMilliseconds > budget * 0.9 && context.engineHealth.renderedFrames > 120 {
            items.append(PreflightItem(
                severity: .warning,
                title: "The renderer is close to its frame budget",
                detail: String(format: "95th percentile frame time is %.1f ms against a %.1f ms budget. The engine will reduce detail before it drops frames.",
                               context.engineHealth.p95FrameMilliseconds, budget),
                remedy: "Lower the output to 720p30, or reduce glyph density in the inspector."))
        }

        // 9. Safety
        items.append(PreflightItem(
            severity: .info,
            title: context.photosensitivitySafe ? "Photosensitivity safeguards on" : "Photosensitivity safeguards off",
            detail: context.photosensitivitySafe
                ? "Luminance flashes are limited to three per second and full-frame inversions are suppressed."
                : "Flash limiting is relaxed. Consider leaving safeguards on for a public broadcast.",
            remedy: nil))

        // 10. Output summary
        items.append(PreflightItem(
            severity: .info,
            title: "Output \(context.profile.summary) · \(context.profile.bitrateLabel) · AAC \(Int(context.profile.audioSampleRate / 1000)) kHz",
            detail: "H.264 High, keyframe every \(Int(context.profile.keyframeIntervalSeconds))s, \(context.destination.kind.description).",
            remedy: nil))

        return PreflightReport(items: items,
                               ranAt: Date(),
                               playlistRevision: context.playlist.revision,
                               scoreRevision: context.scoreRevision)
    }

    static func freeDiskGB() -> Double {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let capacity = values.volumeAvailableCapacityForImportantUsage else { return 0 }
        return Double(capacity) / 1_000_000_000
    }
}
