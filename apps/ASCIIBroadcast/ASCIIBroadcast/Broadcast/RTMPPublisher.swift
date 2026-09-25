//
//  RTMPPublisher.swift
//  ASCII Broadcast
//
//  A narrow RTMP/RTMPS publisher: handshake, chunking, AMF0 command exchange,
//  and timestamped FLV media. It owns the transport session only — it never
//  owns a codec, so there is exactly one encoder owner in the pipeline.
//
//  STATUS: implemented against the RTMP 1.0 specification and YouTube's
//  documented RTMPS ingest. It has not yet been validated against a live
//  ingest endpoint on device; that is Stage 4 in the Phase 2 roadmap and is
//  the gate before any "verified" claim.
//

import Foundation
import Network

final class RTMPPublisher {

    enum State: Equatable {
        case idle
        case connecting
        case handshaking
        case connected          // RTMP connect succeeded
        case publishing         // NetStream.Publish.Start received
        case failed(String)
    }

    // MARK: - Callbacks (delivered on the publisher queue)

    var onStateChange: ((State) -> Void)?
    var onLog: ((String) -> Void)?

    // MARK: - Public state

    private(set) var state: State = .idle {
        didSet { if oldValue != state { onStateChange?(state) } }
    }

    private let healthLock = NSLock()
    private var healthStorage = PublisherHealth()
    var health: PublisherHealth {
        healthLock.lock(); defer { healthLock.unlock() }
        return healthStorage
    }

    // MARK: - Private

    private let queue = DispatchQueue(label: "com.vagabond.asciibroadcast.rtmp")
    private var connection: NWConnection?
    private var inboundBuffer = Data()
    private var handshakeStage = 0
    private var c1Payload = Data()

    private var outChunkSize = 4096
    private var inChunkSize = 128
    private var windowAckSize: UInt32 = 2_500_000
    private var bytesReceived: UInt32 = 0
    private var lastAckSent: UInt32 = 0

    private var transactionCounter: Double = 1
    private var createStreamTransaction: Double = 0
    private var messageStreamID: UInt32 = 1

    private var app = ""
    private var tcURL = ""
    private var streamKey = ""

    private var inboundMessages: [UInt32: InboundMessage] = [:]
    private var lastOutboundTimestamp: [UInt32: UInt32] = [:]

    /// Bounded send queue. Audio and video that has aged past the live window
    /// is dropped rather than replayed as a delayed backlog.
    private var pendingBytes = 0
    private let maximumPendingBytes = 3_000_000

    private struct InboundMessage {
        var typeID: UInt8 = 0
        var length: Int = 0
        var timestamp: UInt32 = 0
        var streamID: UInt32 = 0
        var payload = Data()
    }

    // MARK: - Lifecycle

    func connect(urlString: String, streamKey key: String) {
        queue.async { [weak self] in
            self?.performConnect(urlString: urlString, streamKey: key)
        }
    }

    private func performConnect(urlString: String, streamKey key: String) {
        guard let url = URL(string: urlString),
              let host = url.host else {
            state = .failed("The ingest URL could not be parsed. Check the destination and try again.")
            return
        }
        let secure = (url.scheme?.lowercased() == "rtmps")
        let port = UInt16(url.port ?? (secure ? 443 : 1935))
        // rtmp(s)://host/app[/more] — everything after the host is the app path.
        app = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
        tcURL = urlString
        streamKey = key

        let parameters: NWParameters
        if secure {
            let tls = NWProtocolTLS.Options()
            sec_protocol_options_set_tls_server_name(tls.securityProtocolOptions, host)
            parameters = NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
        } else {
            parameters = NWParameters(tls: nil, tcp: NWProtocolTCP.Options())
        }

        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host),
                                           port: NWEndpoint.Port(rawValue: port) ?? 443)
        let connection = NWConnection(to: endpoint, using: parameters)
        self.connection = connection
        resetSessionState()
        state = .connecting

        connection.stateUpdateHandler = { [weak self] newState in
            guard let self else { return }
            switch newState {
            case .ready:
                self.startHandshake()
                self.receiveLoop()
            case .failed(let error):
                self.fail("The connection to the ingest server failed (\(error.localizedDescription)). Your programme is still running locally.")
            case .cancelled:
                if case .failed = self.state {} else { self.state = .idle }
            case .waiting(let error):
                self.onLog?("waiting: \(error.localizedDescription)")
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.state == .publishing {
                self.sendCommand(name: "FCUnpublish", transaction: self.nextTransaction(),
                                 commandObject: .null, arguments: [.string(self.streamKey)],
                                 chunkStreamID: 3, messageStreamID: 0)
                self.sendCommand(name: "deleteStream", transaction: self.nextTransaction(),
                                 commandObject: .null, arguments: [.number(Double(self.messageStreamID))],
                                 chunkStreamID: 3, messageStreamID: 0)
            }
            self.connection?.cancel()
            self.connection = nil
            self.state = .idle
            self.updateHealth { $0.connected = false }
        }
    }

    private func resetSessionState() {
        inboundBuffer.removeAll(keepingCapacity: true)
        inboundMessages.removeAll()
        lastOutboundTimestamp.removeAll()
        handshakeStage = 0
        inChunkSize = 128
        bytesReceived = 0
        lastAckSent = 0
        transactionCounter = 1
        pendingBytes = 0
        updateHealth {
            $0.connected = false
            $0.bytesSent = 0
            $0.droppedPackets = 0
            $0.queueDepth = 0
            $0.lastError = nil
        }
    }

    private func fail(_ message: String) {
        state = .failed(message)
        updateHealth { $0.connected = false; $0.lastError = message }
        connection?.cancel()
        connection = nil
    }

    // MARK: - Handshake

    private func startHandshake() {
        state = .handshaking
        var c0c1 = Data([0x03])
        var c1 = Data()
        c1.append(AMF0.bigEndian(UInt32(0)))            // time
        c1.append(AMF0.bigEndian(UInt32(0)))            // zero
        var generator = SeededGenerator(seed: UInt64(Date().timeIntervalSince1970 * 1000))
        for _ in 0..<1528 { c1.append(UInt8(generator.index(256))) }
        c1Payload = c1
        c0c1.append(c1)
        write(c0c1)
    }

    private func processHandshake() -> Bool {
        // S0 (1) + S1 (1536) + S2 (1536)
        if handshakeStage == 0 {
            guard inboundBuffer.count >= 1 + 1536 else { return false }
            let s1 = inboundBuffer.subdata(in: 1..<(1 + 1536))
            inboundBuffer.removeSubrange(0..<(1 + 1536))
            write(s1)                                    // C2 echoes S1
            handshakeStage = 1
        }
        if handshakeStage == 1 {
            guard inboundBuffer.count >= 1536 else { return false }
            inboundBuffer.removeSubrange(0..<1536)       // S2, not validated further
            handshakeStage = 2
            sendConnect()
        }
        return handshakeStage == 2
    }

    // MARK: - Commands

    private func nextTransaction() -> Double {
        transactionCounter += 1
        return transactionCounter
    }

    private func sendConnect() {
        let object: AMF0Value = .object([
            ("app", .string(app)),
            ("type", .string("nonprivate")),
            ("flashVer", .string("FMLE/3.0 (compatible; ASCIIBroadcast/0.1)")),
            ("tcUrl", .string(tcURL)),
            ("fpad", .boolean(false)),
            ("capabilities", .number(239)),
            ("audioCodecs", .number(3191)),
            ("videoCodecs", .number(252)),
            ("videoFunction", .number(1))
        ])
        sendCommand(name: "connect", transaction: 1, commandObject: object,
                    arguments: [], chunkStreamID: 3, messageStreamID: 0)
        sendSetChunkSize(UInt32(outChunkSize))
    }

    private func sendCommand(name: String,
                             transaction: Double,
                             commandObject: AMF0Value,
                             arguments: [AMF0Value],
                             chunkStreamID: UInt32,
                             messageStreamID: UInt32) {
        var values: [AMF0Value] = [.string(name), .number(transaction), commandObject]
        values.append(contentsOf: arguments)
        let payload = AMF0.encodeSequence(values)
        writeMessage(typeID: 20, chunkStreamID: chunkStreamID,
                     messageStreamID: messageStreamID, timestamp: 0, payload: payload)
    }

    private func sendSetChunkSize(_ size: UInt32) {
        writeMessage(typeID: 1, chunkStreamID: 2, messageStreamID: 0,
                     timestamp: 0, payload: AMF0.bigEndian(size))
    }

    private func sendWindowAckSize(_ size: UInt32) {
        writeMessage(typeID: 5, chunkStreamID: 2, messageStreamID: 0,
                     timestamp: 0, payload: AMF0.bigEndian(size))
    }

    private func sendAcknowledgement(_ sequence: UInt32) {
        writeMessage(typeID: 3, chunkStreamID: 2, messageStreamID: 0,
                     timestamp: 0, payload: AMF0.bigEndian(sequence))
    }

    private func beginPublish() {
        sendCommand(name: "releaseStream", transaction: nextTransaction(),
                    commandObject: .null, arguments: [.string(streamKey)],
                    chunkStreamID: 3, messageStreamID: 0)
        sendCommand(name: "FCPublish", transaction: nextTransaction(),
                    commandObject: .null, arguments: [.string(streamKey)],
                    chunkStreamID: 3, messageStreamID: 0)
        createStreamTransaction = nextTransaction()
        sendCommand(name: "createStream", transaction: createStreamTransaction,
                    commandObject: .null, arguments: [],
                    chunkStreamID: 3, messageStreamID: 0)
    }

    private func sendPublish() {
        sendCommand(name: "publish", transaction: nextTransaction(),
                    commandObject: .null,
                    arguments: [.string(streamKey), .string("live")],
                    chunkStreamID: 4, messageStreamID: messageStreamID)
    }

    // MARK: - Media

    func sendMetadata(_ payload: Data) {
        queue.async { [weak self] in
            guard let self, self.state == .publishing else { return }
            self.writeMessage(typeID: 18, chunkStreamID: 4,
                              messageStreamID: self.messageStreamID,
                              timestamp: 0, payload: payload)
        }
    }

    func sendVideo(_ payload: Data, timestampMilliseconds: UInt32) {
        queue.async { [weak self] in
            guard let self, self.state == .publishing else { return }
            guard self.admit(bytes: payload.count) else { return }
            self.writeMessage(typeID: 9, chunkStreamID: 6,
                              messageStreamID: self.messageStreamID,
                              timestamp: timestampMilliseconds, payload: payload)
        }
    }

    func sendAudio(_ payload: Data, timestampMilliseconds: UInt32) {
        queue.async { [weak self] in
            guard let self, self.state == .publishing else { return }
            guard self.admit(bytes: payload.count) else { return }
            self.writeMessage(typeID: 8, chunkStreamID: 5,
                              messageStreamID: self.messageStreamID,
                              timestamp: timestampMilliseconds, payload: payload)
        }
    }

    /// Back pressure: never let the network stall audio. Once the queue passes
    /// its budget we drop new packets and record it in health.
    private func admit(bytes: Int) -> Bool {
        if pendingBytes + bytes > maximumPendingBytes {
            updateHealth { $0.droppedPackets += 1 }
            return false
        }
        return true
    }

    // MARK: - Chunk writing

    private func writeMessage(typeID: UInt8,
                              chunkStreamID: UInt32,
                              messageStreamID: UInt32,
                              timestamp: UInt32,
                              payload: Data) {
        var data = Data()
        let extended = timestamp >= 0x00FF_FFFF
        let headerTimestamp: UInt32 = extended ? 0x00FF_FFFF : timestamp

        // Type 0 header: full message description.
        data.append(UInt8(truncatingIfNeeded: chunkStreamID & 0x3F))
        data.append(AMF0.bigEndian24(headerTimestamp))
        data.append(AMF0.bigEndian24(UInt32(payload.count)))
        data.append(typeID)
        // Message stream id is little endian in RTMP.
        data.append(UInt8(truncatingIfNeeded: messageStreamID))
        data.append(UInt8(truncatingIfNeeded: messageStreamID >> 8))
        data.append(UInt8(truncatingIfNeeded: messageStreamID >> 16))
        data.append(UInt8(truncatingIfNeeded: messageStreamID >> 24))
        if extended { data.append(AMF0.bigEndian(timestamp)) }

        var offset = 0
        while offset < payload.count {
            if offset > 0 {
                // Type 3 continuation.
                data.append(UInt8(truncatingIfNeeded: 0xC0 | (chunkStreamID & 0x3F)))
                if extended { data.append(AMF0.bigEndian(timestamp)) }
            }
            let take = min(outChunkSize, payload.count - offset)
            data.append(payload.subdata(in: offset..<(offset + take)))
            offset += take
        }

        lastOutboundTimestamp[chunkStreamID] = timestamp
        write(data)
    }

    private func write(_ data: Data) {
        guard let connection else { return }
        pendingBytes += data.count
        updateHealth { $0.queueDepth = self.pendingBytes }
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            self.pendingBytes = max(0, self.pendingBytes - data.count)
            if let error {
                self.fail("Sending to the ingest server failed (\(error.localizedDescription)). Reconnecting.")
            } else {
                self.updateHealth {
                    $0.bytesSent += data.count
                    $0.queueDepth = self.pendingBytes
                }
            }
        })
    }

    // MARK: - Receiving

    private func receiveLoop() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.inboundBuffer.append(data)
                self.bytesReceived &+= UInt32(data.count)
                if self.bytesReceived &- self.lastAckSent > self.windowAckSize / 2 {
                    self.lastAckSent = self.bytesReceived
                    self.sendAcknowledgement(self.bytesReceived)
                }
                self.drainInbound()
            }
            if let error {
                self.fail("The ingest connection dropped (\(error.localizedDescription)).")
                return
            }
            if isComplete {
                self.fail("The ingest server closed the connection.")
                return
            }
            self.receiveLoop()
        }
    }

    private func drainInbound() {
        if handshakeStage < 2 {
            guard processHandshake() else { return }
        }
        while parseOneChunk() {}
    }

    /// Returns true when a chunk was consumed and parsing should continue.
    private func parseOneChunk() -> Bool {
        let bytes = [UInt8](inboundBuffer)
        guard bytes.count >= 1 else { return false }

        var cursor = 0
        let first = bytes[cursor]
        let format = (first & 0xC0) >> 6
        var chunkStreamID = UInt32(first & 0x3F)
        cursor += 1

        if chunkStreamID == 0 {
            guard bytes.count >= cursor + 1 else { return false }
            chunkStreamID = UInt32(bytes[cursor]) + 64
            cursor += 1
        } else if chunkStreamID == 1 {
            guard bytes.count >= cursor + 2 else { return false }
            chunkStreamID = UInt32(bytes[cursor + 1]) * 256 + UInt32(bytes[cursor]) + 64
            cursor += 2
        }

        var message = inboundMessages[chunkStreamID] ?? InboundMessage()
        var timestampField: UInt32 = message.timestamp

        switch format {
        case 0:
            guard bytes.count >= cursor + 11 else { return false }
            timestampField = readUInt24(bytes, cursor)
            message.length = Int(readUInt24(bytes, cursor + 3))
            message.typeID = bytes[cursor + 6]
            message.streamID = UInt32(bytes[cursor + 7])
                | (UInt32(bytes[cursor + 8]) << 8)
                | (UInt32(bytes[cursor + 9]) << 16)
                | (UInt32(bytes[cursor + 10]) << 24)
            cursor += 11
        case 1:
            guard bytes.count >= cursor + 7 else { return false }
            timestampField = readUInt24(bytes, cursor)
            message.length = Int(readUInt24(bytes, cursor + 3))
            message.typeID = bytes[cursor + 6]
            cursor += 7
        case 2:
            guard bytes.count >= cursor + 3 else { return false }
            timestampField = readUInt24(bytes, cursor)
            cursor += 3
        default:
            break
        }

        if timestampField == 0x00FF_FFFF {
            guard bytes.count >= cursor + 4 else { return false }
            timestampField = (UInt32(bytes[cursor]) << 24) | (UInt32(bytes[cursor + 1]) << 16)
                | (UInt32(bytes[cursor + 2]) << 8) | UInt32(bytes[cursor + 3])
            cursor += 4
        }
        message.timestamp = timestampField

        guard message.length >= 0, message.length < 8_000_000 else {
            inboundBuffer.removeAll()
            return false
        }
        let remaining = message.length - message.payload.count
        let take = min(remaining, inChunkSize)
        guard take >= 0, bytes.count >= cursor + take else { return false }

        if take > 0 {
            message.payload.append(contentsOf: bytes[cursor..<(cursor + take)])
            cursor += take
        }
        inboundBuffer.removeSubrange(0..<cursor)

        if message.payload.count >= message.length {
            let complete = message
            inboundMessages[chunkStreamID] = InboundMessage()
            handle(message: complete)
        } else {
            inboundMessages[chunkStreamID] = message
        }
        return !inboundBuffer.isEmpty
    }

    private func readUInt24(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        guard offset + 2 < bytes.count else { return 0 }
        return (UInt32(bytes[offset]) << 16) | (UInt32(bytes[offset + 1]) << 8) | UInt32(bytes[offset + 2])
    }

    private func handle(message: InboundMessage) {
        switch message.typeID {
        case 1:                                        // Set Chunk Size
            if message.payload.count >= 4 {
                let value = message.payload.withUnsafeBytes { raw -> UInt32 in
                    let pointer = raw.bindMemory(to: UInt8.self)
                    return (UInt32(pointer[0]) << 24) | (UInt32(pointer[1]) << 16)
                        | (UInt32(pointer[2]) << 8) | UInt32(pointer[3])
                }
                inChunkSize = Int(max(128, min(value, 65_536)))
            }
        case 5:                                        // Window Acknowledgement Size
            if message.payload.count >= 4 {
                windowAckSize = message.payload.withUnsafeBytes { raw -> UInt32 in
                    let pointer = raw.bindMemory(to: UInt8.self)
                    return (UInt32(pointer[0]) << 24) | (UInt32(pointer[1]) << 16)
                        | (UInt32(pointer[2]) << 8) | UInt32(pointer[3])
                }
            }
            sendWindowAckSize(windowAckSize)
        case 6:                                        // Set Peer Bandwidth
            sendWindowAckSize(windowAckSize)
        case 4:                                        // User Control
            if message.payload.count >= 6 {
                let eventType = (UInt16(message.payload[0]) << 8) | UInt16(message.payload[1])
                if eventType == 6 {                    // PingRequest -> PingResponse
                    var response = Data([0x00, 0x07])
                    response.append(message.payload.subdata(in: 2..<6))
                    writeMessage(typeID: 4, chunkStreamID: 2, messageStreamID: 0,
                                 timestamp: 0, payload: response)
                }
            }
        case 20:                                       // AMF0 command
            handleCommand(AMF0.decodeSequence(message.payload))
        default:
            break
        }
    }

    private func handleCommand(_ values: [AMF0Value]) {
        guard let name = values.first?.stringValue else { return }
        switch name {
        case "_result":
            let transaction = values.count > 1 ? (values[1].numberValue ?? 0) : 0
            if transaction == 1 {
                state = .connected
                updateHealth { $0.connected = true }
                beginPublish()
            } else if transaction == createStreamTransaction {
                if values.count > 3, let streamID = values[3].numberValue {
                    messageStreamID = UInt32(max(0, streamID))
                }
                sendPublish()
            }
        case "_error":
            let description = values.count > 3
                ? (values[3].property("description")?.stringValue ?? "The server rejected the request.")
                : "The server rejected the request."
            fail("The destination refused the stream: \(description) Check the stream key in Output settings.")
        case "onStatus":
            let info = values.count > 3 ? values[3] : (values.last ?? .null)
            let code = info.property("code")?.stringValue ?? ""
            onLog?("onStatus \(code)")
            if code == "NetStream.Publish.Start" {
                state = .publishing
                updateHealth { $0.connected = true }
            } else if code.contains("Failed") || code.contains("Rejected") || code.contains("BadName") {
                let description = info.property("description")?.stringValue ?? code
                fail("The destination rejected publishing: \(description)")
            }
        default:
            break
        }
    }

    // MARK: - Health

    private func updateHealth(_ mutate: (inout PublisherHealth) -> Void) {
        healthLock.lock()
        mutate(&healthStorage)
        healthLock.unlock()
    }

    func noteReconnectAttempt() {
        updateHealth { $0.reconnectAttempts += 1 }
    }
}
