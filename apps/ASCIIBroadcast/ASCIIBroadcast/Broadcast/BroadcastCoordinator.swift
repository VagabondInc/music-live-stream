//
//  BroadcastCoordinator.swift
//  ASCII Broadcast
//
//  Owns the outbound half of the studio: the frame pump, the encoders, the
//  link, and the recorder.
//
//  Two values, never merged (Phase 2 §2):
//    • `pipeline`   — what this machine is doing.
//    • `visibility` — what the destination says it is showing.
//  The app will say "SENDING" on its own authority and will never claim
//  "LIVE — PROVIDER VERIFIED" without a provider answer.
//

import Foundation
import AVFoundation
import CoreMedia
import QuartzCore

final class BroadcastCoordinator: ObservableObject {

    // MARK: - Published state (main queue only)

    @Published private(set) var pipeline: LocalPipelineState = .offline
    @Published private(set) var visibility: DestinationVisibility = .unknown
    @Published private(set) var publisherHealth = PublisherHealth()
    @Published private(set) var engineHealth = EngineHealth()
    @Published private(set) var statusLine: String = "OFFLINE — PREVIEW ONLY"
    @Published private(set) var startedAt: Date?
    @Published private(set) var recordingURL: URL?
    @Published private(set) var recordingSeconds: Double = 0
    @Published private(set) var measuredBitrate: Double = 0
    @Published private(set) var sentFrames: Int = 0
    @Published var lastError: String?
    @Published var lastNotice: String?

    // MARK: - Collaborators

    private let renderer: ProgramRenderer
    private let transport: AudioTransport
    private let videoEncoder = VideoEncoder()
    private let audioEncoder = AudioEncoder()
    private let recorder = LocalRecorder()
    private var link: MediaLink?

    private var offscreen: OffscreenFrameRenderer?
    private var profile = OutputProfile.p1080
    private var destination = Destination()
    private var recordLocally = false

    private let pumpQueue = DispatchQueue(label: "com.vagabond.asciibroadcast.pump", qos: .userInitiated)
    private var pump: DispatchSourceTimer?
    private var frameIndex: Int64 = 0
    private var sentVideoConfiguration = false
    private var sentAudioConfiguration = false
    private var pendingVideoConfiguration: Data?

    private var reconnectAttempt = 0
    private var reconnectWorkItem: DispatchWorkItem?
    private var journal: [RecoveryJournalEntry] = []

    private let stateLock = NSLock()
    private var epoch = 0

    // MARK: - Init

    init(renderer: ProgramRenderer, transport: AudioTransport) {
        self.renderer = renderer
        self.transport = transport
        wireEncoders()
        transport.pcmSink = { [weak self] buffer in
            guard let self else { return }
            self.audioEncoder.append(buffer)
            self.recorder.append(pcm: buffer)
        }
    }

    private func wireEncoders() {
        videoEncoder.onDecoderConfiguration = { [weak self] configuration in
            guard let self else { return }
            self.pendingVideoConfiguration = configuration
            if !self.sentVideoConfiguration {
                self.link?.sendVideo(FLV.videoSequenceHeader(avcC: configuration), timestampMilliseconds: 0)
                self.sentVideoConfiguration = true
            }
        }
        videoEncoder.onPacket = { [weak self] packet in
            guard let self, let link = self.link else { return }
            if !self.sentVideoConfiguration, let configuration = self.pendingVideoConfiguration {
                link.sendVideo(FLV.videoSequenceHeader(avcC: configuration), timestampMilliseconds: 0)
                self.sentVideoConfiguration = true
            }
            link.sendVideo(FLV.videoFrame(packet.data, isKeyframe: packet.isKeyframe),
                           timestampMilliseconds: packet.timestampMilliseconds)
            DispatchQueue.main.async { self.sentFrames += 1 }
        }
        videoEncoder.onError = { [weak self] message in
            self?.report(error: message)
        }
        audioEncoder.onPacket = { [weak self] packet in
            guard let self, let link = self.link else { return }
            if !self.sentAudioConfiguration {
                link.sendAudio(FLV.audioSequenceHeader(audioSpecificConfig: self.audioEncoder.audioSpecificConfig),
                               timestampMilliseconds: 0)
                self.sentAudioConfiguration = true
            }
            link.sendAudio(FLV.audioFrame(packet.data), timestampMilliseconds: packet.timestampMilliseconds)
        }
        audioEncoder.onError = { [weak self] message in
            self?.report(error: message)
        }
        recorder.onError = { [weak self] message in
            self?.report(error: message)
        }
    }

    // MARK: - Public control

    var isRecording: Bool { recorder.isRecording }

    var elapsed: TimeInterval { startedAt.map { Date().timeIntervalSince($0) } ?? 0 }

    var elapsedTimecode: String { Timecode.elapsed(elapsed) }

    /// Preview only: renders and measures, sends nothing.
    func startPreview(profile newProfile: OutputProfile) {
        profile = newProfile
        configureRenderer()
        startPump(sending: false)
        setPipeline(.previewing, status: "PREVIEWING — NOT SENDING")
    }

    func stopPreview() {
        guard !pipeline.isTransmitting else { return }
        stopPump()
        setPipeline(.offline, status: "OFFLINE")
    }

    /// Begin sending. `report` must already have no blocking items.
    func goLive(destination newDestination: Destination,
                profile newProfile: OutputProfile,
                streamKey: String?,
                recordLocally shouldRecord: Bool,
                sessionName: String,
                simulated: Bool) {
        guard !pipeline.isTransmitting else { return }
        destination = newDestination
        profile = newProfile
        recordLocally = shouldRecord
        epoch += 1
        reconnectAttempt = 0
        sentVideoConfiguration = false
        sentAudioConfiguration = false
        pendingVideoConfiguration = nil
        frameIndex = 0
        sentFrames = 0

        configureRenderer()

        let inputFormat = transport.tapFormat
            ?? AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!

        do {
            try videoEncoder.start(profile: profile)
            try audioEncoder.start(inputFormat: inputFormat, profile: profile)
        } catch {
            report(error: error.localizedDescription)
            setPipeline(.error, status: "ENCODER ERROR")
            return
        }

        if shouldRecord {
            let url = LocalRecorder.defaultRecordingURL(sessionName: sessionName)
            do {
                try recorder.start(url: url, profile: profile, inputFormat: inputFormat)
                DispatchQueue.main.async { self.recordingURL = url }
            } catch {
                // Recording is a safety net, not a gate: report and continue.
                report(error: error.localizedDescription)
            }
        }

        let useSimulated = simulated || destination.kind == .localRecordingOnly
        let newLink: MediaLink = useSimulated ? SimulatedPublisher() : RTMPPublisher()
        newLink.onLinkStateChange = { [weak self] state in
            self?.handleLink(state: state)
        }
        link = newLink

        startedAt = Date()
        setPipeline(.connecting, status: useSimulated ? "CONNECTING — LOCAL PIPELINE" : "CONNECTING TO \(destination.kind.description)")
        appendJournal(event: "session.start", detail: destination.kind.description)

        if useSimulated {
            newLink.startLink(urlString: destination.ingestURL, streamKey: "simulated")
        } else {
            guard let key = streamKey, !key.isEmpty else {
                report(error: BroadcastError.missingStreamKey.localizedDescription)
                setPipeline(.error, status: "NO STREAM KEY")
                return
            }
            newLink.startLink(urlString: destination.ingestURL, streamKey: key)
        }

        startPump(sending: true)
    }

    func stopSending(reason: String = "Stopped by creator") {
        guard pipeline.isTransmitting || pipeline == .connecting || pipeline == .error else { return }
        setPipeline(.stopping, status: "STOPPING")
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil

        link?.stopLink()
        link = nil
        videoEncoder.stop()
        audioEncoder.stop()
        appendJournal(event: "session.stop", detail: reason)

        if recorder.isRecording {
            recorder.finish { [weak self] url in
                guard let self else { return }
                self.recordingURL = url
                if let url {
                    self.lastNotice = "Recording saved to \(url.lastPathComponent)."
                }
            }
        }

        // The preview keeps running: stopping the stream should not blank the room.
        startPump(sending: false)
        setPipeline(.previewing, status: "PREVIEWING — NOT SENDING")
        DispatchQueue.main.async {
            self.visibility = .unknown
            self.startedAt = nil
        }
    }

    /// The creator's own answer to "is it actually live?". Never inferred.
    func setCreatorReportedLive(_ isLive: Bool) {
        DispatchQueue.main.async {
            self.visibility = isLive ? .creatorReportedLive : .providerReportedNotLive
        }
        appendJournal(event: "visibility.creator", detail: isLive ? "live" : "not live")
    }

    func requestKeyframe() { videoEncoder.requestKeyframe() }

    var recoveryJournal: [RecoveryJournalEntry] { journal }

    // MARK: - Renderer configuration

    private func configureRenderer() {
        renderer.frameRate = profile.frameRate
        renderer.setGrid(columns: profile.glyphColumns, rows: profile.glyphRows)
        if let offscreen {
            offscreen.resize(width: profile.width, height: profile.height)
        } else {
            offscreen = OffscreenFrameRenderer(width: profile.width, height: profile.height)
        }
    }

    // MARK: - Frame pump

    private func startPump(sending: Bool) {
        stopPump()
        let interval = 1.0 / Double(max(1, profile.frameRate))
        let timer = DispatchSource.makeTimerSource(queue: pumpQueue)
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in
            self?.tick(sending: sending)
        }
        timer.resume()
        pump = timer
    }

    private func stopPump() {
        pump?.cancel()
        pump = nil
    }

    private func tick(sending: Bool) {
        let frame = renderer.frame()
        var health = renderer.health

        if sending, let offscreen {
            if let pixelBuffer = offscreen.render(frame: frame, using: renderer) {
                let presentationTime = CMTime(value: frameIndex, timescale: CMTimeScale(profile.frameRate))
                let duration = CMTime(value: 1, timescale: CMTimeScale(profile.frameRate))
                frameIndex += 1
                videoEncoder.encode(pixelBuffer: pixelBuffer, presentationTime: presentationTime, duration: duration)
                recorder.append(pixelBuffer: pixelBuffer, presentationTime: presentationTime)
            } else {
                health.droppedFrames += 1
            }
        }

        let linkHealth = link?.linkHealth ?? PublisherHealth()
        let recordingElapsed = recorder.isRecording ? recorder.elapsed : 0
        health.droppedFrames += videoEncoder.droppedFrames

        // Publish at 4 Hz: the studio does not need 30 Hz numbers, and the
        // main queue should not be woken for every frame.
        if frameIndex % Int64(max(1, profile.frameRate / 4)) == 0 || !sending {
            DispatchQueue.main.async {
                self.engineHealth = health
                self.publisherHealth = linkHealth
                self.measuredBitrate = linkHealth.measuredBitrate
                self.recordingSeconds = recordingElapsed
            }
        }
    }

    // MARK: - Link state

    private func handleLink(state: RTMPPublisher.State) {
        switch state {
        case .idle:
            break
        case .connecting, .handshaking:
            setPipeline(.connecting, status: "CONNECTING")
        case .connected:
            setPipeline(.connecting, status: "HANDSHAKE COMPLETE — OPENING STREAM")
        case .publishing:
            reconnectAttempt = 0
            sentVideoConfiguration = false
            sentAudioConfiguration = false
            videoEncoder.requestKeyframe()
            sendMetadata()
            setPipeline(.sending, status: "SENDING — DESTINATION HAS NOT CONFIRMED")
            appendJournal(event: "link.publishing", detail: destination.ingestURL)
        case .failed(let message):
            appendJournal(event: "link.failed", detail: message)
            report(error: message)
            scheduleReconnect(after: message)
        }
    }

    private func sendMetadata() {
        let payload = FLV.onMetaData(width: profile.width,
                                     height: profile.height,
                                     frameRate: profile.frameRate,
                                     videoBitrate: profile.videoBitrate,
                                     audioBitrate: profile.audioBitrate,
                                     audioSampleRate: profile.audioSampleRate,
                                     encoder: "ASCII Broadcast 0.1")
        link?.sendMetadata(payload)
    }

    /// Reconnect with backoff while the programme keeps playing and recording.
    /// A dropped socket must never stop the music.
    private func scheduleReconnect(after message: String) {
        guard pipeline.isTransmitting || pipeline == .connecting else { return }
        guard destination.kind != .localRecordingOnly else { return }
        guard reconnectAttempt < 8 else {
            setPipeline(.error, status: "DISCONNECTED — RECONNECT GAVE UP")
            DispatchQueue.main.async {
                self.lastError = "Reconnection failed eight times. The programme is still playing and recording locally. Press Stop Sending, check the network, then start again."
            }
            return
        }
        reconnectAttempt += 1
        let delay = min(30.0, pow(2.0, Double(reconnectAttempt - 1)) * 2.0)
        setPipeline(.reconnecting, status: "RECONNECTING — ATTEMPT \(reconnectAttempt) IN \(Int(delay))s")

        let work = DispatchWorkItem { [weak self] in
            guard let self, self.pipeline == .reconnecting else { return }
            let key = KeychainStore.key(for: self.destination.keyReference)
            let newLink: MediaLink = RTMPPublisher()
            newLink.onLinkStateChange = { [weak self] state in self?.handleLink(state: state) }
            self.link = newLink
            self.sentVideoConfiguration = false
            self.sentAudioConfiguration = false
            self.videoEncoder.requestKeyframe()
            newLink.startLink(urlString: self.destination.ingestURL, streamKey: key ?? "")
        }
        reconnectWorkItem = work
        pumpQueue.asyncAfter(deadline: .now() + delay, execute: work)
    }

    // MARK: - Plumbing

    private func setPipeline(_ state: LocalPipelineState, status: String) {
        DispatchQueue.main.async {
            self.pipeline = state
            self.statusLine = status
        }
    }

    private func report(error message: String) {
        DispatchQueue.main.async {
            self.lastError = message
        }
    }

    private func appendJournal(event: String, detail: String) {
        let entry = RecoveryJournalEntry(code: "\(event)#\(epoch)", message: detail)
        stateLock.lock()
        journal.append(entry)
        if journal.count > 400 { journal.removeFirst(journal.count - 400) }
        stateLock.unlock()
    }
}
