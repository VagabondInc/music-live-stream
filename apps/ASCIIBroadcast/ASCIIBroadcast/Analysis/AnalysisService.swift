//
//  AnalysisService.swift
//  ASCII Broadcast
//
//  Cancellable, resumable analysis jobs. A programme can be previewed while
//  analysis is still running: the UI says "still analysing" and later passages
//  are enriched as results land (Phase 2 §3).
//

import Foundation

// MARK: - Programme level

enum ProgramAnalyzer {

    static func analyze(tracks: [TrackAnalysis], playlistRevision: Int) -> ProgramAnalysis {
        var program = ProgramAnalysis()
        program.playlistRevision = playlistRevision
        program.trackCount = tracks.count
        guard !tracks.isEmpty else { return program }

        program.totalDuration = tracks.reduce(0) { $0 + $1.duration }
        let usable = tracks.filter { $0.isUsable }
        let tempos = usable.map(\.tempo).filter { $0 > 40 }
        program.meanTempo = tempos.isEmpty ? 0 : tempos.reduce(0, +) / Double(tempos.count)
        if tempos.count > 1 {
            let mean = program.meanTempo
            let variance = tempos.reduce(0) { $0 + pow($1 - mean, 2) } / Double(tempos.count)
            program.tempoSpread = sqrt(variance)
        }
        program.energyTrajectory = tracks.map(\.energy)
        program.brightnessTrajectory = tracks.map(\.brightness)
        program.meanEnergy = tracks.isEmpty ? 0 : tracks.map(\.energy).reduce(0, +) / Double(tracks.count)
        program.coverage = tracks.isEmpty ? 0 : tracks.map(\.coverage).reduce(0, +) / Double(tracks.count)

        // Abrupt changes: a large jump in energy or tempo between neighbours.
        for index in 1..<max(1, tracks.count) {
            let energyJump = abs(tracks[index].energy - tracks[index - 1].energy)
            let tempoJump = abs(tracks[index].tempo - tracks[index - 1].tempo)
            if energyJump > 0.28 || tempoJump > 22 { program.abruptChanges.append(index) }
        }

        program.chapters = chapters(tracks: tracks, breaks: program.abruptChanges)
        program.computedAt = Date()
        return program
    }

    /// Chapters group adjacent tracks that belong together. A later chapter
    /// that resembles an earlier one is marked as a reprise, which is what
    /// gives the score its A / B / C / A′ shape.
    private static func chapters(tracks: [TrackAnalysis], breaks: [Int]) -> [ProgramChapter] {
        guard !tracks.isEmpty else { return [] }
        var boundaries = Set(breaks)
        // Never let a chapter run longer than five tracks: a two-hour channel
        // needs visible structure.
        var runLength = 0
        for index in tracks.indices {
            runLength += 1
            if runLength >= 5 { boundaries.insert(index); runLength = 0 }
        }

        var ranges: [(Int, Int)] = []
        var start = 0
        for index in 1..<tracks.count where boundaries.contains(index) {
            ranges.append((start, index - 1))
            start = index
        }
        ranges.append((start, tracks.count - 1))

        let names = ["THE ARRIVAL", "THE TRANSIT", "THE CITY", "THE ARCHIVE",
                     "THE CROSSING", "THE RETURN", "THE LAST LIGHT"]
        let alphabet = Array("ABCDEFGH")

        var chapters: [ProgramChapter] = []
        var signatures: [(letter: String, energy: Double, tempo: Double)] = []

        for (position, range) in ranges.enumerated() {
            let slice = Array(tracks[range.0...range.1])
            let energy = slice.map(\.energy).reduce(0, +) / Double(slice.count)
            let tempo = slice.map(\.tempo).reduce(0, +) / Double(slice.count)

            var letter = String(alphabet[min(position, alphabet.count - 1)])
            var isReprise = false
            for signature in signatures where abs(signature.energy - energy) < 0.1 && abs(signature.tempo - tempo) < 8 {
                letter = signature.letter + "'"
                isReprise = true
                break
            }
            if !isReprise { signatures.append((letter, energy, tempo)) }

            chapters.append(ProgramChapter(letter: letter,
                                           title: names[position % names.count],
                                           startTrackIndex: range.0,
                                           endTrackIndex: range.1,
                                           meanEnergy: energy,
                                           meanTempo: tempo,
                                           isReprise: isReprise))
        }
        return chapters
    }
}

// MARK: - Service

/// Plain `ObservableObject` (not actor-isolated): all `@Published` mutations
/// are funnelled through the main queue explicitly, and the cancel flag is
/// guarded by a lock so the worker can read it without hopping threads.
final class AnalysisService: ObservableObject {

    struct Job {
        var assetID: UUID
        var fingerprint: String
        var title: String
        var url: URL?
        var demoIndex: Int?
        var needsSecurityScope: Bool
    }

    @Published private(set) var isRunning = false
    @Published private(set) var phase: String = "IDLE"
    @Published private(set) var overallProgress: Double = 0
    @Published private(set) var completed: Int = 0
    @Published private(set) var total: Int = 0
    @Published private(set) var failures: [String] = []

    private let cancelLock = NSLock()
    private var cancelFlag = false
    private let queue = DispatchQueue(label: "com.vagabond.asciibroadcast.analysis", qos: .userInitiated)

    private func isCancelled() -> Bool {
        cancelLock.lock()
        defer { cancelLock.unlock() }
        return cancelFlag
    }

    private func setCancelled(_ value: Bool) {
        cancelLock.lock()
        cancelFlag = value
        cancelLock.unlock()
    }

    /// Results arrive incrementally so the score can be recompiled with partial
    /// coverage and enriched later.
    func run(jobs: [Job],
             existing: [String: TrackAnalysis],
             onTrack: @escaping (String, TrackAnalysis) -> Void,
             onFinished: @escaping (Bool) -> Void) {

        guard !isRunning else { return }
        let pending = jobs.filter { job in
            guard let cached = existing[job.fingerprint] else { return true }
            return cached.state != .complete || cached.extractorVersion != TrackAnalysis().extractorVersion
        }
        guard !pending.isEmpty else {
            phase = "ANALYSIS CURRENT"
            overallProgress = 1
            onFinished(true)
            return
        }

        setCancelled(false)
        isRunning = true
        failures = []
        completed = 0
        total = pending.count
        overallProgress = 0
        phase = "ANALYZING 1/\(pending.count)"

        queue.async { [weak self] in
            guard let self else { return }
            var index = 0
            for job in pending {
                if self.isCancelled() { break }

                let jobProgress: (Double) -> Void = { fraction in
                    let overall = (Double(index) + fraction) / Double(pending.count)
                    DispatchQueue.main.async {
                        self.overallProgress = overall
                        self.phase = "ANALYZING \(index + 1)/\(pending.count) — \(job.title.uppercased())"
                    }
                }
                let cancelled: () -> Bool = { self.isCancelled() }

                var result: TrackAnalysis?
                var failure: String?

                if let demoIndex = job.demoIndex {
                    result = TrackAnalyzer.analyzeDemo(index: demoIndex,
                                                       fingerprint: job.fingerprint,
                                                       isCancelled: cancelled,
                                                       progress: jobProgress)
                } else if let url = job.url {
                    do {
                        result = try TrackAnalyzer.analyze(url: url,
                                                           fingerprint: job.fingerprint,
                                                           needsSecurityScope: job.needsSecurityScope,
                                                           isCancelled: cancelled,
                                                           progress: jobProgress)
                    } catch {
                        failure = "\(job.title): \(error.localizedDescription)"
                    }
                } else {
                    failure = "\(job.title): no readable source is attached to this track."
                }

                let capturedIndex = index
                DispatchQueue.main.async {
                    if let result {
                        onTrack(job.fingerprint, result)
                    }
                    if let failure {
                        self.failures.append(failure)
                    }
                    self.completed = capturedIndex + 1
                    self.overallProgress = Double(capturedIndex + 1) / Double(pending.count)
                }
                index += 1
            }

            let wasCancelled = self.isCancelled()
            DispatchQueue.main.async {
                self.isRunning = false
                self.phase = wasCancelled ? "CANCELLED" : "ANALYSIS COMPLETE"
                if !wasCancelled { self.overallProgress = 1 }
                onFinished(!wasCancelled)
            }
        }
    }

    func cancel() {
        setCancelled(true)
        phase = "CANCELLING"
    }
}
