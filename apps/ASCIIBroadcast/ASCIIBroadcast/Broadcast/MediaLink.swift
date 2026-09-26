//
//  MediaLink.swift
//  ASCII Broadcast
//
//  The coordinator talks to a link, not to a protocol implementation. That
//  keeps the two-value state machine honest: "local pipeline" and "destination
//  visibility" stay separable whether the link is a real RTMPS session or the
//  simulated one used for local-only sessions and rehearsals.
//

import Foundation

protocol MediaLink: AnyObject {
    var linkHealth: PublisherHealth { get }
    var onLinkStateChange: ((RTMPPublisher.State) -> Void)? { get set }

    func startLink(urlString: String, streamKey: String)
    func sendMetadata(_ payload: Data)
    func sendVideo(_ payload: Data, timestampMilliseconds: UInt32)
    func sendAudio(_ payload: Data, timestampMilliseconds: UInt32)
    func stopLink()
}

extension RTMPPublisher: MediaLink {
    var linkHealth: PublisherHealth { health }

    var onLinkStateChange: ((RTMPPublisher.State) -> Void)? {
        get { onStateChange }
        set { onStateChange = newValue }
    }

    func startLink(urlString: String, streamKey: String) {
        connect(urlString: urlString, streamKey: streamKey)
    }

    func stopLink() { stop() }
}

/// Accepts the full encoded stream and measures it, without a network.
/// Used for local-recording-only sessions and for rehearsing a programme
/// before a key exists. It reports the same health record so the studio shows
/// real numbers rather than a decorative animation.
final class SimulatedPublisher: MediaLink {

    private let queue = DispatchQueue(label: "com.vagabond.asciibroadcast.simulated")
    private let lock = NSLock()
    private var healthStorage = PublisherHealth()
    private var windowStart = Date()
    private var windowBytes = 0
    private var state: RTMPPublisher.State = .idle {
        didSet { if oldValue != state { onLinkStateChange?(state) } }
    }

    var onLinkStateChange: ((RTMPPublisher.State) -> Void)?

    var linkHealth: PublisherHealth {
        lock.lock(); defer { lock.unlock() }
        return healthStorage
    }

    func startLink(urlString: String, streamKey: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.healthStorage = PublisherHealth()
            self.windowStart = Date()
            self.windowBytes = 0
            self.lock.unlock()
            self.state = .connecting
        }
        queue.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            self.state = .connected
            self.lock.lock(); self.healthStorage.connected = true; self.lock.unlock()
        }
        queue.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            self?.state = .publishing
        }
    }

    func sendMetadata(_ payload: Data) { count(bytes: payload.count) }

    func sendVideo(_ payload: Data, timestampMilliseconds: UInt32) { count(bytes: payload.count) }

    func sendAudio(_ payload: Data, timestampMilliseconds: UInt32) { count(bytes: payload.count) }

    func stopLink() {
        queue.async { [weak self] in
            guard let self else { return }
            self.lock.lock(); self.healthStorage.connected = false; self.lock.unlock()
            self.state = .idle
        }
    }

    private func count(bytes: Int) {
        lock.lock()
        healthStorage.bytesSent += bytes
        windowBytes += bytes
        let elapsed = Date().timeIntervalSince(windowStart)
        if elapsed >= 1 {
            healthStorage.measuredBitrate = Double(windowBytes) * 8 / elapsed
            windowBytes = 0
            windowStart = Date()
        }
        lock.unlock()
    }
}
