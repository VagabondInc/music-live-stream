//
//  ScoreCompiler.swift
//  ASCII Broadcast
//
//  Turns a playlist plus its analyses and a Visual DNA into the bounded score
//  the engine performs: chapters, scene episodes, bridges, protected titles,
//  signal effects, and memory marks.
//
//  The compiler is deterministic. Same playlist + same DNA + same seed = same
//  score, which is what makes seek, recovery, and bug reports possible.
//

import Foundation

struct ScoreCompiler {

    struct TrackInput {
        var instanceID: UUID
        var title: String
        var artist: String
        var duration: Double
        var analysis: TrackAnalysis?
    }

    static func compile(playlistName: String,
                        playlistRevision: Int,
                        tracks: [TrackInput],
                        program: ProgramAnalysis,
                        dna: VisualDNA) -> VisualScore {

        var score = VisualScore()
        score.name = playlistName
        score.dnaRevision = dna.revision
        score.playlistRevision = playlistRevision
        guard !tracks.isEmpty else { return score }

        var generator = SeededGenerator(seed: dna.seed, stream: "score")
        var cursor = 0.0
        var sceneIndex = 0
        var recentFamilies: [SceneFamily] = []
        var recentTransitions: [TransitionKind] = []
        var recentTitles: [String] = []
        var fxLastUsed: [SignalFXKind: Double] = [:]
        var memoryIndex = 0

        let dwellBase = 26.0 + (100.0 - Double(dna.controls.sceneDwell)) * 0.55   // 26...81s
        let weights = dna.weightedFamilies

        for (trackIndex, track) in tracks.enumerated() {
            let trackStart = cursor
            let duration = max(8, track.duration)
            let trackEnd = trackStart + duration
            let analysis = track.analysis

            // ---- Scenes -------------------------------------------------
            // Prefer measured section boundaries; fall back to an even split
            // at the DNA's dwell target when structure is unknown.
            var boundaries: [Double] = [trackStart]
            if let analysis, !analysis.sections.isEmpty {
                var accumulated = 0.0
                for section in analysis.sections {
                    accumulated += section.duration
                    if accumulated >= dwellBase * 0.7 {
                        boundaries.append(trackStart + section.end)
                        accumulated = 0
                    }
                }
            } else {
                var time = dwellBase
                while time < duration - dwellBase * 0.4 {
                    boundaries.append(trackStart + time)
                    time += dwellBase
                }
            }
            boundaries.append(trackEnd)
            boundaries = boundaries.sorted().reduce(into: [Double]()) { result, value in
                if result.isEmpty || value - (result.last ?? 0) > 6 { result.append(value) }
            }
            if boundaries.count < 2 { boundaries = [trackStart, trackEnd] }

            for boundaryIndex in 0..<(boundaries.count - 1) {
                let start = boundaries[boundaryIndex]
                let end = boundaries[boundaryIndex + 1]
                sceneIndex += 1

                let family = chooseFamily(weights: weights,
                                          recent: recentFamilies,
                                          generator: &generator)
                recentFamilies.append(family)
                if recentFamilies.count > 3 { recentFamilies.removeFirst() }

                let title = chooseEpisodeTitle(family: family, recent: recentTitles, generator: &generator)
                recentTitles.append(title)
                if recentTitles.count > 5 { recentTitles.removeFirst() }

                let sectionEnergy = analysis?.section(at: start - trackStart)?.energy ?? program.meanEnergy
                let cue = ScoreSceneCue(index: sceneIndex,
                                        family: family,
                                        episodeTitle: title,
                                        slug: slug(index: sceneIndex, title: title),
                                        start: start,
                                        end: end,
                                        seed: dna.seed &+ UInt64(sceneIndex &* 7919),
                                        intensity: clamp(sectionEnergy * dna.performance.spectacleBudget, 0.1, 1),
                                        trackInstanceID: track.instanceID)
                score.scenes.append(cue)

                // ---- Memory marks --------------------------------------
                memoryIndex += 1
                let motifName = dna.motifs.isEmpty
                    ? "mark"
                    : dna.motifs[(memoryIndex - 1) % dna.motifs.count].name
                score.memory.append(ScoreMemoryMark(label: "M\(memoryIndex)",
                                                    time: start,
                                                    motifName: motifName,
                                                    sceneIndex: sceneIndex))
            }

            // ---- Titles -------------------------------------------------
            // First and last ten seconds by default, shortened for short
            // tracks so two treatments never overlap.
            let hold = min(dna.titleHoldSeconds, max(4, duration / 3))
            let treatmentIn = titleTreatment(for: dna, generator: &generator)
            score.titles.append(ScoreTitleCue(primary: track.title,
                                              secondary: track.artist,
                                              start: trackStart + 1.0,
                                              duration: hold,
                                              treatment: treatmentIn,
                                              isOutgoing: false))
            if duration > hold * 2.6 {
                score.titles.append(ScoreTitleCue(primary: track.title,
                                                  secondary: track.artist,
                                                  start: trackEnd - hold - 1.0,
                                                  duration: hold,
                                                  treatment: .cornerPlate,
                                                  isOutgoing: true))
            }

            // ---- Signal FX ----------------------------------------------
            if let analysis {
                for section in analysis.sections {
                    let absoluteStart = trackStart + section.start
                    guard section.kind.spectacleWeight > 0.5 else { continue }
                    let candidates = effectCandidates(for: section.kind, dna: dna)
                    guard !candidates.isEmpty else { continue }
                    let kind = candidates[generator.index(candidates.count)]
                    if let last = fxLastUsed[kind], absoluteStart - last < kind.cooldown { continue }
                    fxLastUsed[kind] = absoluteStart
                    let intensity = clamp(section.energy * dna.performance.spectacleBudget, 0.15, 1)
                    score.fx.append(ScoreFXCue(kind: kind,
                                               start: absoluteStart,
                                               duration: clamp(section.duration * 0.25, 0.8, 4.0),
                                               intensity: intensity))
                }
            } else {
                // Free-running: a sparse, tasteful pulse rather than nothing.
                var time = trackStart + 20
                while time < trackEnd - 8 {
                    let kind: SignalFXKind = generator.chance(0.5) ? .characterRain : .scanDeform
                    score.fx.append(ScoreFXCue(kind: kind, start: time, duration: 1.6,
                                               intensity: 0.35))
                    time += 34 + generator.range(0, 22)
                }
            }

            // ---- Transition into the next track --------------------------
            if trackIndex < tracks.count - 1 {
                let next = tracks[trackIndex + 1]
                let kind = TransitionEngine.choose(outgoing: analysis,
                                                   incoming: next.analysis,
                                                   recentKinds: recentTransitions,
                                                   variety: Double(dna.controls.transitionVariety) / 100.0,
                                                   generator: &generator)
                recentTransitions.append(kind)
                if recentTransitions.count > 4 { recentTransitions.removeFirst() }
                let carried = dna.motifs.isEmpty ? nil : dna.motifs[trackIndex % dna.motifs.count].id
                score.transitions.append(ScoreTransitionCue(kind: kind,
                                                            start: trackEnd - kind.duration * 0.5,
                                                            duration: kind.duration,
                                                            carriedMotifID: carried))
            } else {
                score.transitions.append(ScoreTransitionCue(kind: .fadeOut,
                                                            start: max(trackStart, trackEnd - 3),
                                                            duration: 3,
                                                            carriedMotifID: nil))
            }

            if trackIndex == 0 {
                score.transitions.insert(ScoreTransitionCue(kind: .fadeIn, start: 0, duration: 2.5,
                                                            carriedMotifID: nil), at: 0)
            }

            cursor = trackEnd
        }

        // ---- Chapters ---------------------------------------------------
        score.chapters = chapters(program: program, tracks: tracks)
        score.duration = cursor
        score.compiledAt = Date()
        score.revision = max(1, dna.revision)
        return score
    }

    // MARK: - Helpers

    static func slug(index: Int, title: String) -> String {
        let words = title.uppercased().split(separator: " ").filter { $0.count > 2 }
        let stem = words.prefix(2).joined(separator: "_")
        let compact = stem.isEmpty ? "SCENE" : String(stem.prefix(16))
        return String(format: "%02d_%@", index, compact)
    }

    private static func chooseFamily(weights: [SceneFamily: Double],
                                     recent: [SceneFamily],
                                     generator: inout SeededGenerator) -> SceneFamily {
        var adjusted: [SceneFamily: Double] = [:]
        let table = weights.isEmpty ? WorldDirection.nightTransit.familyWeights : weights
        for (family, weight) in table {
            var value = max(0.01, weight)
            // Scene cooldown: the family used last is heavily penalised, the
            // one before it mildly. This is how a channel avoids feeling like
            // a two-state loop.
            if recent.last == family { value *= 0.12 }
            else if recent.count > 1 && recent[recent.count - 2] == family { value *= 0.5 }
            adjusted[family] = value
        }
        let total = adjusted.values.reduce(0, +)
        guard total > 0 else { return .foldedCity }
        var roll = generator.unit() * total
        for (family, weight) in adjusted.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            roll -= weight
            if roll <= 0 { return family }
        }
        return .foldedCity
    }

    private static func chooseEpisodeTitle(family: SceneFamily,
                                           recent: [String],
                                           generator: inout SeededGenerator) -> String {
        let titles = family.episodeTitles
        let fresh = titles.filter { !recent.contains($0) }
        let pool = fresh.isEmpty ? titles : fresh
        return pool[generator.index(pool.count)]
    }

    private static func titleTreatment(for dna: VisualDNA,
                                       generator: inout SeededGenerator) -> TitleTreatment {
        // Readability first: Reduce Motion never gets the kinetic assembly.
        var pool: [TitleTreatment] = [.cornerPlate, .stationSign, .terminalOutput]
        if !dna.reduceMotion { pool.append(.kinetic) }
        switch dna.direction {
        case .nightTransit:    pool.append(.stationSign)
        case .livingIndex:     pool.append(.terminalOutput)
        case .tidalInstrument: pool.append(.cornerPlate)
        }
        return pool[generator.index(pool.count)]
    }

    private static func effectCandidates(for kind: SectionKind, dna: VisualDNA) -> [SignalFXKind] {
        var candidates: [SignalFXKind]
        switch kind {
        case .drop:       candidates = [.shockwave, .fragmentation, .pixelSort, .inversion]
        case .chorus:     candidates = [.shockwave, .characterRain, .dissolveField]
        case .buildup:    candidates = [.characterRain, .scanDeform]
        case .prechorus:  candidates = [.scanDeform, .dissolveField]
        case .bridge:     candidates = [.pixelSort, .dissolveField]
        case .breakdown:  candidates = [.dissolveField]
        default:          candidates = [.characterRain]
        }
        if dna.photosensitivitySafe {
            candidates = candidates.filter { $0.isSafeUnderPhotosensitivity }
        }
        if dna.reduceMotion {
            candidates = candidates.filter { $0 != .scanDeform && $0 != .fragmentation }
        }
        return candidates
    }

    private static func chapters(program: ProgramAnalysis, tracks: [TrackInput]) -> [ScoreChapterCue] {
        guard !tracks.isEmpty else { return [] }
        var starts: [Double] = []
        var cursor = 0.0
        for track in tracks {
            starts.append(cursor)
            cursor += max(8, track.duration)
        }
        let total = cursor

        guard !program.chapters.isEmpty else {
            return [ScoreChapterCue(letter: "A", title: "THE PROGRAM", start: 0, end: total)]
        }

        return program.chapters.map { chapter in
            let startIndex = clamp(chapter.startTrackIndex, 0, starts.count - 1)
            let endIndex = clamp(chapter.endTrackIndex, 0, starts.count - 1)
            let start = starts[startIndex]
            let end = endIndex + 1 < starts.count ? starts[endIndex + 1] : total
            return ScoreChapterCue(letter: chapter.letter,
                                   title: chapter.title,
                                   start: start,
                                   end: end,
                                   isReprise: chapter.isReprise)
        }
    }
}
