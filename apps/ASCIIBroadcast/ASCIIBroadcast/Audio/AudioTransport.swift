//
//  AudioTransport.swift
//  ASCII Broadcast
//
//  Owns playback and the single program PCM bus. Everything downstream —
//  speakers, feature analysis, and the AAC encoder — branches from the same
//  signal, so the visuals can never be responding to different audio from the
//  one the viewer hears (Phase 2 §6).
//
//  The program sample clock is authoritative: video cadence derives from it,
//  never from a UI timer.
//

import Foundation
import AVFoundation

#if os(iOS)
import UIKit
#endif

struct TransportSnapshot {
    var isPlaying: Bool = false
    var programTime: Double = 0
    var trackTime: Double = 0
    var trackDuration: Double = 0
    var currentIndex: Int = 0
    var epoch: Int = 0
    var sampleRate: Double = 48_000
    var isDemo: Bool = false
    var underruns: Int = 0
}

final class AudioTransport {

    struct Entry {
        var id: UUID
        var url: URL?
        var demoIndex: Int?
        var duration: Double
        var title: String
        var artist: String
        var needsSecurityScope: Bool = false
    }

    // MARK: - Public

    /// Called on the main queue after the transport moves to a new track.
    var onTrackChanged: ((Int) -> Void)?
    /// Called on the main queue when the program reaches the end and is not looping.
    var onProgramEnded: (() -> Void)?
    /// Program bus tap for the broadcast pipeline. Called on the audio thread:
    /// the receiver must copy and return immediately.
    var pcmSink: ((AVAudioPCMBuffer) -> Void)?

    /// Format of the program bus as it is actually tapped.
    private(set) var tapFormat: AVAudioFormat?

    /// Called on the main queue when a source cannot be decoded.
    var onSourceFailure: ((UUID, String) -> Void)?

    var loops: Bool = true
    var autoAdvance: Bool = true

    private(set) var entries: [Entry] = []

    // MARK: - Engine

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var sourceNode: AVAudioSourceNode?
    private var demoSynth: DemoSynthesizer?
    private var graphIsDemo = false
    private var engineRunning = false

    private let processingFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!

    // MARK: - Analysis

    private let extractor = FeatureExtractor(sampleRate: 48_000)
    private var analysisBufferLeft = [Float](repeating: 0, count: FeatureExtractor.fftSize)
    private var analysisBufferRight = [Float](repeating: 0, count: FeatureExtractor.fftSize)
    private var analysisFill = 0

    // MARK: - Shared state

    private let stateLock = NSLock()
    private var state = TransportSnapshot()
    private var latestFrame = FeatureFrame()
    private var currentEntryIndex = 0
    private var trackStartProgramTime: Double = 0
    private var seekOffset: Double = 0
    private var demoFramePosition: Int64 = 0
    private var accessedURLs: [URL] = []

    // MARK: - Lifecycle

    init() {
        configureSession()
        state.sampleRate = processingFormat.sampleRate
    }

    deinit {
        releaseSecurityScopes()
    }

    private func configureSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            // Non-fatal: preview still works, the failure is surfaced in health.
            NSLog("ASCIIBroadcast: audio session configuration failed — \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - Loading

    func load(entries newEntries: [Entry], startAt index: Int = 0) {
        stop()
        releaseSecurityScopes()
        entries = newEntries
        currentEntryIndex = clamp(index, 0, max(0, newEntries.count - 1))
        trackStartProgramTime = 0
        seekOffset = 0
        demoFramePosition = 0

        stateLock.lock()
        state.programTime = 0
        state.trackTime = 0
        state.currentIndex = currentEntryIndex
        state.trackDuration = entries.indices.contains(currentEntryIndex) ? entries[currentEntryIndex].duration : 0
        state.epoch += 1
        state.isDemo = entries.first?.demoIndex != nil
        stateLock.unlock()
    }

    // MARK: - Transport commands

    func play() {
        guard !entries.isEmpty else { return }
        let entry = entries[clamp(currentEntryIndex, 0, entries.count - 1)]
        let wantsDemo = entry.demoIndex != nil

        if !engineRunning || graphIsDemo != wantsDemo {
            rebuildGraph(demo: wantsDemo)
        }
        guard engineRunning else { return }

        if wantsDemo {
            // The source node is always rendering; playback is a state flag.
            stateLock.lock(); state.isPlaying = true; stateLock.unlock()
        } else {
            scheduleCurrentFile(from: seekOffset)
            player.play()
            stateLock.lock(); state.isPlaying = true; stateLock.unlock()
        }
    }

    func pause() {
        stateLock.lock(); state.isPlaying = false; stateLock.unlock()
        if !graphIsDemo { player.pause() }
    }

    func stop() {
        stateLock.lock()
        state.isPlaying = false
        stateLock.unlock()
        if engineRunning {
            player.stop()
            engine.stop()
        }
        if let sourceNode {
            engine.detach(sourceNode)
            self.sourceNode = nil
        }
        engineRunning = false
    }

    func togglePlayPause() {
        snapshot().isPlaying ? pause() : play()
    }

    func next() { advance(by: 1, userInitiated: true) }
    func previous() {
        // Standard behaviour: restart the track unless we are near its start.
        if snapshot().trackTime > 3 {
            seek(toTrackTime: 0)
        } else {
            advance(by: -1, userInitiated: true)
        }
    }

    func skip(to index: Int) {
        guard entries.indices.contains(index) else { return }
        let wasPlaying = snapshot().isPlaying
        applyTrackChange(to: index, resetProgramTime: false)
        if wasPlaying { play() }
    }

    func seek(toTrackTime time: Double) {
        let wasPlaying = snapshot().isPlaying
        seekOffset = max(0, time)
        if graphIsDemo {
            demoFramePosition = Int64(seekOffset * processingFormat.sampleRate)
        } else {
            player.stop()
            if wasPlaying {
                scheduleCurrentFile(from: seekOffset)
                player.play()
            }
        }
        stateLock.lock()
        state.trackTime = seekOffset
        state.epoch += 1
        stateLock.unlock()
    }

    // MARK: - State access

    func snapshot() -> TransportSnapshot {
        stateLock.lock()
        defer { stateLock.unlock() }
        return state
    }

    func latestFeatures() -> FeatureFrame {
        stateLock.lock()
        defer { stateLock.unlock() }
        return latestFrame
    }

    var currentEntry: Entry? {
        entries.indices.contains(currentEntryIndex) ? entries[currentEntryIndex] : nil
    }

    // MARK: - Graph

    private func rebuildGraph(demo: Bool) {
        if engineRunning {
            player.stop()
            engine.stop()
        }
        engine.mainMixerNode.removeTap(onBus: 0)
        if let sourceNode {
            engine.detach(sourceNode)
            self.sourceNode = nil
        }
        if engine.attachedNodes.contains(player) == false {
            engine.attach(player)
        }

        if demo {
            let index = entries.indices.contains(currentEntryIndex)
                ? (entries[currentEntryIndex].demoIndex ?? 0) : 0
            let track = DemoProgram.tracks[clamp(index, 0, DemoProgram.tracks.count - 1)]
            let synth = DemoSynthesizer(sampleRate: processingFormat.sampleRate, track: track)
            demoSynth = synth

            let node = AVAudioSourceNode(format: processingFormat) { [weak self] silence, _, frameCount, audioBufferList in
                guard let self else { return noErr }
                let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
                let count = Int(frameCount)

                self.stateLock.lock()
                let playing = self.state.isPlaying
                self.stateLock.unlock()

                guard playing, buffers.count >= 1 else {
                    silence.pointee = true
                    for buffer in buffers {
                        memset(buffer.mData, 0, Int(buffer.mDataByteSize))
                    }
                    return noErr
                }

                let left = buffers[0].mData?.assumingMemoryBound(to: Float.self)
                let right = buffers.count > 1
                    ? buffers[1].mData?.assumingMemoryBound(to: Float.self)
                    : left
                guard let leftPointer = left, let rightPointer = right else { return noErr }

                self.demoSynth?.render(left: leftPointer, right: rightPointer,
                                       count: count, startFrame: self.demoFramePosition)
                self.demoFramePosition += Int64(count)
                return noErr
            }
            sourceNode = node
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: processingFormat)
        } else {
            engine.connect(player, to: engine.mainMixerNode, format: nil)
        }

        installTap()
        graphIsDemo = demo

        do {
            engine.prepare()
            try engine.start()
            engineRunning = true
        } catch {
            engineRunning = false
            NSLog("ASCIIBroadcast: audio engine failed to start — \(error.localizedDescription)")
        }
    }

    private func installTap() {
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        tapFormat = format.channelCount > 0 ? format : processingFormat
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.consume(buffer: buffer)
        }
    }

    /// Runs on the audio tap thread. Preallocated buffers only: no allocation,
    /// no file access, no database writes, no blocking work.
    private func consume(buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }
        pcmSink?(buffer)
        let sampleRate = buffer.format.sampleRate
        let channelCount = Int(buffer.format.channelCount)

        stateLock.lock()
        let playing = state.isPlaying
        stateLock.unlock()

        var produced: FeatureFrame?
        let size = FeatureExtractor.fftSize

        var consumed = 0
        while consumed < frameCount {
            let take = min(size - analysisFill, frameCount - consumed)
            for offset in 0..<take {
                analysisBufferLeft[analysisFill + offset] = channels[0][consumed + offset]
                analysisBufferRight[analysisFill + offset] = channelCount > 1
                    ? channels[1][consumed + offset]
                    : channels[0][consumed + offset]
            }
            analysisFill += take
            consumed += take

            if analysisFill == size {
                analysisFill = 0
                let time = stateSnapshotProgramTime()
                analysisBufferLeft.withUnsafeBufferPointer { leftBuffer in
                    analysisBufferRight.withUnsafeBufferPointer { rightBuffer in
                        guard let leftBase = leftBuffer.baseAddress, let rightBase = rightBuffer.baseAddress else { return }
                        produced = extractor.process(leftBase, count: size, time: time, rightChannel: rightBase)
                    }
                }
            }
        }

        stateLock.lock()
        if let produced { latestFrame = produced }
        if playing {
            state.programTime += Double(frameCount) / sampleRate
            state.trackTime = state.programTime - trackStartProgramTime + seekOffset
            state.sampleRate = sampleRate
        }
        let trackTime = state.trackTime
        let duration = state.trackDuration
        stateLock.unlock()

        if playing, duration > 0, trackTime >= duration - 0.02 {
            DispatchQueue.main.async { [weak self] in
                self?.advance(by: 1, userInitiated: false)
            }
        }
    }

    private func stateSnapshotProgramTime() -> Double {
        stateLock.lock()
        defer { stateLock.unlock() }
        return state.programTime
    }

    // MARK: - Track movement

    private func advance(by delta: Int, userInitiated: Bool) {
        guard !entries.isEmpty else { return }
        var nextIndex = currentEntryIndex + delta
        if nextIndex >= entries.count {
            if loops {
                nextIndex = 0
            } else {
                pause()
                onProgramEnded?()
                return
            }
        }
        if nextIndex < 0 { nextIndex = loops ? entries.count - 1 : 0 }
        guard userInitiated || autoAdvance else { pause(); return }
        applyTrackChange(to: nextIndex, resetProgramTime: false)
        if snapshot().isPlaying || !userInitiated { play() }
    }

    private func applyTrackChange(to index: Int, resetProgramTime: Bool) {
        currentEntryIndex = clamp(index, 0, max(0, entries.count - 1))
        seekOffset = 0
        demoFramePosition = 0
        let entry = entries[currentEntryIndex]

        if let demoIndex = entry.demoIndex {
            let track = DemoProgram.tracks[clamp(demoIndex, 0, DemoProgram.tracks.count - 1)]
            demoSynth?.setTrack(track)
            if !graphIsDemo { rebuildGraph(demo: true) }
        } else if graphIsDemo {
            rebuildGraph(demo: false)
        }

        stateLock.lock()
        if resetProgramTime { state.programTime = 0 }
        trackStartProgramTime = state.programTime
        state.trackTime = 0
        state.trackDuration = entry.duration
        state.currentIndex = currentEntryIndex
        state.epoch += 1
        stateLock.unlock()

        extractor.reset()
        let changedIndex = currentEntryIndex
        DispatchQueue.main.async { [weak self] in
            self?.onTrackChanged?(changedIndex)
        }
    }

    // MARK: - File scheduling

    private func scheduleCurrentFile(from offset: Double) {
        guard let entry = currentEntry, let url = entry.url else { return }
        var scoped = false
        if entry.needsSecurityScope {
            scoped = url.startAccessingSecurityScopedResource()
            if scoped { accessedURLs.append(url) }
        }
        do {
            let file = try AVAudioFile(forReading: url)
            let sampleRate = file.processingFormat.sampleRate
            let startFrame = AVAudioFramePosition(offset * sampleRate)
            let remaining = AVAudioFrameCount(max(0, file.length - startFrame))
            guard remaining > 0 else { return }
            player.scheduleSegment(file,
                                   startingFrame: startFrame,
                                   frameCount: remaining,
                                   at: nil,
                                   completionCallbackType: .dataPlayedBack) { _ in }
        } catch {
            let message = "This file could not be decoded (\(error.localizedDescription)). "
                + "Your playlist and rights note are saved. Locate the file or skip this track."
            let id = entry.id
            DispatchQueue.main.async { [weak self] in
                self?.onSourceFailure?(id, message)
            }
        }
    }

    private func releaseSecurityScopes() {
        for url in accessedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        accessedURLs.removeAll()
    }
}
