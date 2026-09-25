//
//  StudioViewModel.swift
//  ASCII Broadcast
//
//  The studio's single source of truth. Plain `ObservableObject`: every
//  mutation happens on the main queue, and the audio, analysis, render, and
//  broadcast layers hop here explicitly rather than inheriting isolation.
//

import Foundation
import AVFoundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

final class StudioViewModel: ObservableObject {

    // MARK: - Document

    @Published var library = MediaLibrary()
    @Published var playlist = Playlist(name: "Glass Cities")
    @Published var dna = VisualDNA.starter
    @Published var score = VisualScore()
    @Published var programAnalysis = ProgramAnalysis()
    @Published var destination = Destination()
    @Published var profile = OutputProfile.p1080
    @Published var trackAnalyses: [String: TrackAnalysis] = [:]   // fingerprint -> analysis

    // MARK: - Transport mirror (updated by the UI ticker)

    @Published private(set) var isPlaying = false
    @Published private(set) var currentIndex = 0
    @Published private(set) var trackTime: Double = 0
    @Published private(set) var trackDuration: Double = 0
    @Published private(set) var programTime: Double = 0
    @Published private(set) var levelLeft: Double = 0
    @Published private(set) var levelRight: Double = 0
    @Published private(set) var liveBPM: Double = 0
    @Published private(set) var bandEnergies: [Double] = Array(repeating: 0, count: 24)

    // MARK: - UI state

    enum LibraryTab: String, CaseIterable { case queue = "QUEUE", library = "LIBRARY" }

    @Published var libraryTab: LibraryTab = .queue
    @Published var filterText = ""
    @Published var selectedInstanceID: UUID?
    @Published var streamKeyInput = ""
    @Published var recordLocally = true
    @Published var useSimulatedLink = false
    @Published var showPreflight = false
    @Published var showRightsSheet = false
    @Published var showOnboarding = false
    @Published var preflight = PreflightReport()
    @Published var banner: Banner?
    @Published var inspectorSections: Set<String> = ["SCENE_FAMILIES"]
    @Published var statusMessage = "READY"

    struct Banner: Identifiable, Equatable {
        enum Kind: Equatable { case info, warning, error, success }
        var id = UUID()
        var kind: Kind
        var title: String
        var detail: String
        var remedy: String?
    }

    // MARK: - Collaborators

    let transport: AudioTransport
    let analysisService = AnalysisService()
    let renderer: ProgramRenderer
    let coordinator: BroadcastCoordinator

    private var ticker: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var scoreRevision = 0
    private var hasStoredKey = false

    // MARK: - Init

    init() {
        // Build the graph locally first: `self` is not usable until every
        // stored property has a value.
        let transport = AudioTransport()
        let renderer = ProgramRenderer(transport: transport)
        self.transport = transport
        self.renderer = renderer
        self.coordinator = BroadcastCoordinator(renderer: renderer, transport: transport)

        restore()
        wireTransport()
        startTicker()

        // Child objects publish independently; mirror the two values the top
        // bar needs so the header does not re-render at 30 Hz.
        coordinator.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let message else { return }
                self?.show(.error, "Broadcast", message, remedy: nil)
            }
            .store(in: &cancellables)

        coordinator.$lastNotice
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let message else { return }
                self?.show(.success, "Recording", message, remedy: nil)
            }
            .store(in: &cancellables)
    }

    // MARK: - Persistence

    private func restore() {
        if let document = SessionStore.shared.load() {
            library = document.library
            playlist = document.playlist
            dna = document.dna
            score = document.score
            trackAnalyses = document.trackAnalyses
            programAnalysis = document.programAnalysis
            destination = document.destination
            profile = document.outputProfile
        } else {
            installDemoProgram()
            showOnboarding = true
        }
        hasStoredKey = KeychainStore.hasKey(for: destination.keyReference)
        destination.hasStoredKey = hasStoredKey
        loadTransportEntries(startAt: 0)
        pushEngineInputs()
        renderer.setGrid(columns: profile.glyphColumns, rows: profile.glyphRows)
        renderer.frameRate = profile.frameRate
    }

    func save() {
        var document = StudioDocument()
        document.library = library
        document.playlist = playlist
        document.dna = dna
        document.score = score
        document.trackAnalyses = trackAnalyses
        document.programAnalysis = programAnalysis
        document.destination = destination
        document.outputProfile = profile
        SessionStore.shared.save(document)
    }

    // MARK: - Demo programme

    func installDemoProgram() {
        var newLibrary = MediaLibrary()
        var newPlaylist = Playlist(name: "Glass Cities")
        for (index, track) in DemoProgram.tracks.enumerated() {
            let asset = SourceAsset.demo(title: track.title,
                                         artist: track.artist,
                                         duration: track.duration,
                                         index: index)
            newLibrary.insert(asset)
            var rights = newLibrary.rightsRecord(for: asset.id)
            // The demo programme is synthesised by this app, so it is cleared
            // by construction. Imported music is never marked for the creator.
            rights.recording = .ownedByCreator
            rights.composition = .ownedByCreator
            rights.artwork = .ownedByCreator
            rights.evidenceNote = "Generated by ASCII Broadcast's demo synthesiser."
            rights.reviewedAt = Date()
            newLibrary.rights[asset.id] = rights
            newPlaylist.instances.append(TrackInstance(assetID: asset.id))
        }
        library = newLibrary
        playlist = newPlaylist
        trackAnalyses = [:]
        score = VisualScore()
        programAnalysis = ProgramAnalysis()
        loadTransportEntries(startAt: 0)
        statusMessage = "DEMO PROGRAM LOADED — 9 TRACKS"
        save()
    }

    // MARK: - Transport wiring

    private func wireTransport() {
        transport.loops = playlist.loops
        transport.autoAdvance = playlist.autoAdvance
        transport.onTrackChanged = { [weak self] index in
            guard let self else { return }
            self.currentIndex = index
            self.selectedInstanceID = self.playlist.instances[safe: index]?.id
        }
        transport.onProgramEnded = { [weak self] in
            self?.statusMessage = "PROGRAM ENDED"
        }
        transport.onSourceFailure = { [weak self] instanceID, reason in
            guard let self else { return }
            let title = self.title(forInstance: instanceID) ?? "A track"
            self.show(.error, "\(title) could not be played", reason,
                      remedy: "Relink or remove the file, then continue. The programme skipped ahead so the channel kept running.")
        }
    }

    func loadTransportEntries(startAt index: Int) {
        let entries: [AudioTransport.Entry] = playlist.instances.compactMap { instance in
            guard let asset = library.asset(instance.assetID) else { return nil }
            var demoIndex: Int?
            if asset.kind == .bundledDemo,
               let raw = asset.lastKnownPath.split(separator: "/").last,
               let parsed = Int(raw) {
                demoIndex = parsed
            }
            var url: URL?
            if demoIndex == nil {
                url = resolveURL(for: asset)
            }
            return AudioTransport.Entry(id: instance.id,
                                        url: url,
                                        demoIndex: demoIndex,
                                        duration: asset.duration,
                                        title: instance.titleOverride ?? asset.titleOrFilename,
                                        artist: instance.artistOverride ?? asset.artist,
                                        needsSecurityScope: asset.bookmark != nil)
        }
        transport.load(entries: entries, startAt: index)
    }

    private func resolveURL(for asset: SourceAsset) -> URL? {
        if let bookmark = asset.bookmark {
            var stale = false
            #if os(macOS)
            let options: URL.BookmarkResolutionOptions = [.withSecurityScope]
            #else
            let options: URL.BookmarkResolutionOptions = []
            #endif
            if let url = try? URL(resolvingBookmarkData: bookmark,
                                  options: options,
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &stale) {
                return url
            }
        }
        guard !asset.lastKnownPath.isEmpty,
              !asset.lastKnownPath.hasPrefix("bundled://") else { return nil }
        return URL(fileURLWithPath: asset.lastKnownPath)
    }

    // MARK: - UI ticker

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        let snapshot = transport.snapshot()
        isPlaying = snapshot.isPlaying
        if currentIndex != snapshot.currentIndex { currentIndex = snapshot.currentIndex }
        trackTime = snapshot.trackTime
        trackDuration = snapshot.trackDuration
        programTime = snapshot.programTime

        let features = transport.latestFeatures()
        let width = Double(features.stereoWidth)
        levelLeft = clamp(Double(features.rms) * (1 + width * 0.25), 0, 1)
        levelRight = clamp(Double(features.rms) * (1 - width * 0.25) + Double(features.peak) * 0.08, 0, 1)
        bandEnergies = features.bands.map { Double($0) }
        if let analysis = currentAnalysis, analysis.tempo > 0 {
            liveBPM = analysis.tempo
        }
    }

    // MARK: - Derived reads

    var currentInstance: TrackInstance? { playlist.instances[safe: currentIndex] }

    var currentAsset: SourceAsset? {
        guard let instance = currentInstance else { return nil }
        return library.asset(instance.assetID)
    }

    var currentAnalysis: TrackAnalysis? {
        guard let asset = currentAsset else { return nil }
        return trackAnalyses[asset.fingerprint]
    }

    var nextAsset: SourceAsset? {
        let nextIndex = currentIndex + 1
        if let instance = playlist.instances[safe: nextIndex] {
            return library.asset(instance.assetID)
        }
        if playlist.loops, let first = playlist.instances.first {
            return library.asset(first.assetID)
        }
        return nil
    }

    var currentTitle: String {
        currentInstance?.titleOverride ?? currentAsset?.titleOrFilename ?? "NO TRACK LOADED"
    }

    var currentArtist: String {
        currentInstance?.artistOverride ?? currentAsset?.artist ?? "—"
    }

    var currentSection: MusicSection? {
        currentAnalysis?.section(at: trackTime)
    }

    var currentScene: ScoreSceneCue? { score.scene(at: programTime) }

    var currentChapter: ScoreChapterCue? { score.chapter(at: programTime) }

    var analysedCount: Int {
        playlist.instances.filter { instance in
            guard let asset = library.asset(instance.assetID) else { return false }
            return trackAnalyses[asset.fingerprint]?.state == .complete
        }.count
    }

    var programDuration: Double {
        playlist.instances.reduce(0) { total, instance in
            total + (library.asset(instance.assetID)?.duration ?? 0)
        }
    }

    func analysis(for instance: TrackInstance) -> TrackAnalysis? {
        guard let asset = library.asset(instance.assetID) else { return nil }
        return trackAnalyses[asset.fingerprint]
    }

    func asset(for instance: TrackInstance) -> SourceAsset? { library.asset(instance.assetID) }

    func title(forInstance id: UUID) -> String? {
        guard let instance = playlist.instances.first(where: { $0.id == id }) else { return nil }
        return instance.titleOverride ?? library.asset(instance.assetID)?.titleOrFilename
    }

    var filteredLibraryAssets: [SourceAsset] {
        let all = library.assets.values.sorted { $0.titleOrFilename < $1.titleOrFilename }
        guard !filterText.isEmpty else { return all }
        let needle = filterText.lowercased()
        return all.filter {
            $0.titleOrFilename.lowercased().contains(needle) || $0.artist.lowercased().contains(needle)
        }
    }

    var filteredInstances: [TrackInstance] {
        guard !filterText.isEmpty else { return playlist.instances }
        let needle = filterText.lowercased()
        return playlist.instances.filter { instance in
            guard let asset = library.asset(instance.assetID) else { return false }
            return asset.titleOrFilename.lowercased().contains(needle)
                || asset.artist.lowercased().contains(needle)
        }
    }

    // MARK: - Transport actions

    func togglePlayPause() {
        transport.togglePlayPause()
        if transport.snapshot().isPlaying && coordinator.pipeline == .offline {
            coordinator.startPreview(profile: profile)
        }
    }

    func play() {
        transport.play()
        if coordinator.pipeline == .offline { coordinator.startPreview(profile: profile) }
    }

    func pause() { transport.pause() }

    func stop() { transport.stop() }

    func next() { transport.next() }

    func previous() { transport.previous() }

    func skip(to index: Int) {
        transport.skip(to: index)
        currentIndex = index
    }

    func seek(toFraction fraction: Double) {
        guard trackDuration > 0 else { return }
        transport.seek(toTrackTime: clamp(fraction, 0, 1) * trackDuration)
    }

    func setLoops(_ value: Bool) {
        playlist.loops = value
        transport.loops = value
        save()
    }

    func setAutoAdvance(_ value: Bool) {
        playlist.autoAdvance = value
        transport.autoAdvance = value
        save()
    }

    // MARK: - Queue editing

    func moveInstances(from offsets: IndexSet, to destinationIndex: Int) {
        playlist.instances.move(fromOffsets: offsets, toOffset: destinationIndex)
        playlist.touch()
        loadTransportEntries(startAt: currentIndex)
        compileScore()
        save()
    }

    func removeInstance(_ id: UUID) {
        playlist.instances.removeAll { $0.id == id }
        playlist.touch()
        loadTransportEntries(startAt: min(currentIndex, max(0, playlist.instances.count - 1)))
        compileScore()
        save()
    }

    func addToQueue(assetID: UUID) {
        playlist.instances.append(TrackInstance(assetID: assetID))
        playlist.touch()
        loadTransportEntries(startAt: currentIndex)
        compileScore()
        save()
    }

    func setTransition(_ kind: TransitionKind?, for instanceID: UUID) {
        guard let index = playlist.instances.firstIndex(where: { $0.id == instanceID }) else { return }
        playlist.instances[index].transitionPreference = kind
        playlist.touch()
        compileScore()
        save()
    }

    // MARK: - Import

    func importFiles(urls: [URL]) {
        var imported = 0
        var failures: [String] = []
        for url in urls {
            switch importOne(url: url) {
            case .success: imported += 1
            case .failure(let reason): failures.append(reason)
            }
        }
        if imported > 0 {
            playlist.touch()
            loadTransportEntries(startAt: currentIndex)
            statusMessage = "IMPORTED \(imported) TRACK\(imported == 1 ? "" : "S")"
            save()
        }
        if !failures.isEmpty {
            show(.warning, "\(failures.count) file\(failures.count == 1 ? "" : "s") could not be imported",
                 failures.prefix(3).joined(separator: "  ·  "),
                 remedy: "Convert them to a supported format (AAC, ALAC, WAV, AIFF, MP3) and try again. Everything else was imported.")
        }
    }

    private func importOne(url: URL) -> Result<Void, ImportFailure> {
        var scoped = false
        if url.startAccessingSecurityScopedResource() { scoped = true }
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite, duration > 0.5 else {
            return .failure(ImportFailure(reason: "\(url.lastPathComponent): no readable audio"))
        }

        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Unknown artist"
        var album = ""
        for item in asset.commonMetadata {
            guard let key = item.commonKey?.rawValue, let value = item.stringValue else { continue }
            switch key {
            case "title": title = value
            case "artist": artist = value
            case "albumName": album = value
            default: break
            }
        }

        var sampleRate: Double = 44_100
        var channels = 2
        if let track = asset.tracks(withMediaType: .audio).first,
           let description = track.formatDescriptions.first,
           CFGetTypeID(description as CFTypeRef) == CMFormatDescriptionGetTypeID() {
            let formatDescription = description as! CMFormatDescription
            if let basic = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee {
                sampleRate = basic.mSampleRate
                channels = Int(basic.mChannelsPerFrame)
            }
        }

        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0
        let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let fingerprint = "\(size)-\(Int(modified))-\(url.lastPathComponent.hashValue)"

        #if os(macOS)
        let bookmark = try? url.bookmarkData(options: [.withSecurityScope],
                                             includingResourceValuesForKeys: nil,
                                             relativeTo: nil)
        #else
        let bookmark = try? url.bookmarkData(options: [],
                                             includingResourceValuesForKeys: nil,
                                             relativeTo: nil)
        #endif

        if let existing = library.assets.values.first(where: { $0.fingerprint == fingerprint }) {
            playlist.instances.append(TrackInstance(assetID: existing.id))
            return .success(())
        }

        let sourceAsset = SourceAsset(kind: .localFile,
                                      displayName: title,
                                      artist: artist,
                                      album: album,
                                      year: nil,
                                      duration: duration,
                                      sampleRate: sampleRate,
                                      channelCount: channels,
                                      codecDescription: url.pathExtension.uppercased(),
                                      bookmark: bookmark,
                                      lastKnownPath: url.path,
                                      fingerprint: fingerprint,
                                      availability: .ready)
        library.insert(sourceAsset)
        playlist.instances.append(TrackInstance(assetID: sourceAsset.id))
        return .success(())
    }

    private struct ImportFailure: Error { var reason: String }

    // MARK: - Analysis

    func analyzeAll() {
        guard !analysisService.isRunning else { return }
        let jobs: [AnalysisService.Job] = playlist.instances.compactMap { instance in
            guard let asset = library.asset(instance.assetID) else { return nil }
            var demoIndex: Int?
            if asset.kind == .bundledDemo,
               let raw = asset.lastKnownPath.split(separator: "/").last,
               let parsed = Int(raw) { demoIndex = parsed }
            return AnalysisService.Job(assetID: asset.id,
                                       fingerprint: asset.fingerprint,
                                       title: asset.titleOrFilename,
                                       url: demoIndex == nil ? resolveURL(for: asset) : nil,
                                       demoIndex: demoIndex,
                                       needsSecurityScope: asset.bookmark != nil)
        }
        guard !jobs.isEmpty else {
            show(.info, "Nothing to analyse", "The queue is empty.", remedy: "Add tracks first.")
            return
        }

        analysisService.run(jobs: jobs,
                            existing: trackAnalyses,
                            onTrack: { [weak self] fingerprint, analysis in
            guard let self else { return }
            self.trackAnalyses[fingerprint] = analysis
        }, onFinished: { [weak self] completed in
            guard let self else { return }
            self.recomputeProgramAnalysis()
            if self.score.isEmpty {
                self.generateDNA(newVariant: false)
            } else {
                self.compileScore()
            }
            self.save()
            self.statusMessage = completed ? "ANALYSIS COMPLETE" : "ANALYSIS CANCELLED"
        })
    }

    func cancelAnalysis() { analysisService.cancel() }

    private func recomputeProgramAnalysis() {
        let ordered: [TrackAnalysis] = playlist.instances.compactMap { instance in
            guard let asset = library.asset(instance.assetID) else { return nil }
            return trackAnalyses[asset.fingerprint]
        }
        programAnalysis = ProgramAnalyzer.analyze(tracks: ordered, playlistRevision: playlist.revision)
    }

    // MARK: - Direction

    func generateDNA(newVariant: Bool) {
        recomputeProgramAnalysis()
        let ordered: [TrackAnalysis] = playlist.instances.compactMap { instance in
            guard let asset = library.asset(instance.assetID) else { return nil }
            return trackAnalyses[asset.fingerprint]
        }
        let request = ArtDirector.Request(playlistName: playlist.name,
                                          program: programAnalysis,
                                          tracks: ordered,
                                          existing: newVariant ? dna : nil,
                                          newVariant: newVariant)
        dna = ArtDirector.generate(request)
        compileScore()
        save()
        statusMessage = "DNA \(dna.name) · REV \(dna.revision)"
    }

    func compileScore() {
        let inputs: [ScoreCompiler.TrackInput] = playlist.instances.compactMap { instance in
            guard let asset = library.asset(instance.assetID) else { return nil }
            return ScoreCompiler.TrackInput(instanceID: instance.id,
                                            title: instance.titleOverride ?? asset.titleOrFilename,
                                            artist: instance.artistOverride ?? asset.artist,
                                            duration: asset.duration,
                                            analysis: trackAnalyses[asset.fingerprint])
        }
        score = ScoreCompiler.compile(playlistName: playlist.name,
                                      playlistRevision: playlist.revision,
                                      tracks: inputs,
                                      program: programAnalysis,
                                      dna: dna)
        scoreRevision += 1
        pushEngineInputs()
    }

    /// Guided controls apply immediately to the preview; structural changes
    /// (dwell, transition variety) require a recompile, which is why the
    /// inspector marks the score stale rather than silently rewriting it live.
    func updateControls(_ mutate: (inout GuidedControls) -> Void) {
        var controls = dna.controls
        mutate(&controls)
        dna.controls = controls
        pushEngineInputs()
        save()
    }

    func setDirection(_ direction: WorldDirection) {
        dna.direction = direction
        dna.paletteID = direction.rawValue
        dna.name = direction.description
        pushEngineInputs()
        save()
    }

    func setPerformance(_ mode: PerformanceMode) { dna.performance = mode; pushEngineInputs(); save() }
    func setDetail(_ level: DetailLevel) { dna.detail = level; pushEngineInputs(); save() }
    func setColor(_ behavior: ColorBehavior) { dna.color = behavior; pushEngineInputs(); save() }
    func setGlyphProfile(_ glyphProfile: GlyphProfile) { dna.glyphProfile = glyphProfile; pushEngineInputs(); save() }
    func setCamera(_ grammar: CameraGrammar) { dna.cameraGrammar = grammar; pushEngineInputs(); save() }

    func setPhotosensitivitySafe(_ value: Bool) {
        dna.photosensitivitySafe = value
        compileScore()
        save()
    }

    func setReduceMotion(_ value: Bool) {
        dna.reduceMotion = value
        renderer.setScanlines(!value)
        compileScore()
        save()
    }

    func pushEngineInputs() {
        renderer.apply(score: score, dna: dna)
        var analysesByInstance: [UUID: TrackAnalysis] = [:]
        for instance in playlist.instances {
            if let asset = library.asset(instance.assetID),
               let analysis = trackAnalyses[asset.fingerprint] {
                analysesByInstance[instance.id] = analysis
            }
        }
        renderer.apply(analyses: analysesByInstance, order: playlist.instances.map(\.id))
        renderer.setBranding(channelName: playlist.name, broadcastStart: coordinator.startedAt)
    }

    // MARK: - Output and broadcast

    func setProfile(_ newProfile: OutputProfile) {
        profile = newProfile
        renderer.frameRate = newProfile.frameRate
        renderer.setGrid(columns: newProfile.glyphColumns, rows: newProfile.glyphRows)
        save()
    }

    func storeStreamKey() {
        let trimmed = streamKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if KeychainStore.store(key: trimmed, for: destination.keyReference) {
            hasStoredKey = true
            destination.hasStoredKey = true
            streamKeyInput = ""
            statusMessage = "STREAM KEY STORED IN KEYCHAIN"
            save()
        } else {
            show(.error, "The stream key could not be stored",
                 "The keychain refused to save the key. Nothing was written anywhere else.",
                 remedy: "Check that the device is unlocked and try again.")
        }
    }

    func clearStreamKey() {
        KeychainStore.remove(account: destination.keyReference)
        hasStoredKey = false
        destination.hasStoredKey = false
        save()
    }

    @discardableResult
    func runPreflight() -> PreflightReport {
        let context = PreflightService.Context(playlist: playlist,
                                               library: library,
                                               analyses: instanceKeyedAnalyses(),
                                               score: score,
                                               scoreRevision: scoreRevision,
                                               destination: destination,
                                               profile: profile,
                                               hasStoredKey: hasStoredKey || useSimulatedLink,
                                               recordLocally: recordLocally,
                                               freeDiskGB: PreflightService.freeDiskGB(),
                                               engineHealth: coordinator.engineHealth,
                                               photosensitivitySafe: dna.photosensitivitySafe)
        preflight = PreflightService.run(context)
        return preflight
    }

    private func instanceKeyedAnalyses() -> [UUID: TrackAnalysis] {
        var out: [UUID: TrackAnalysis] = [:]
        for instance in playlist.instances {
            if let asset = library.asset(instance.assetID),
               let analysis = trackAnalyses[asset.fingerprint] {
                out[instance.id] = analysis
            }
        }
        return out
    }

    func startBroadcast() {
        let report = runPreflight()
        guard report.blocking.isEmpty else {
            showPreflight = true
            show(.warning, "Preflight found \(report.blocking.count) blocking issue\(report.blocking.count == 1 ? "" : "s")",
                 report.blocking.first?.detail ?? "",
                 remedy: report.blocking.first?.remedy)
            return
        }
        if !isPlaying { play() }
        pushEngineInputs()
        coordinator.goLive(destination: destination,
                           profile: profile,
                           streamKey: KeychainStore.key(for: destination.keyReference),
                           recordLocally: recordLocally,
                           sessionName: playlist.sessionSlug,
                           simulated: useSimulatedLink)
        statusMessage = "OUTBOUND STARTED"
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = true
        #endif
    }

    func stopBroadcast() {
        coordinator.stopSending()
        statusMessage = "OUTBOUND STOPPED"
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = false
        #endif
    }

    // MARK: - Banners

    func show(_ kind: Banner.Kind, _ title: String, _ detail: String, remedy: String?) {
        banner = Banner(kind: kind, title: title, detail: detail, remedy: remedy)
    }

    func dismissBanner() { banner = nil }
}

// MARK: - Small helpers

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
