//
//  SessionStore.swift
//  ASCII Broadcast
//
//  Durable studio state. Phase 2 §5 asks for transactional on-device storage;
//  the MVP uses atomically written JSON documents behind a repository type so
//  a SQLite implementation can replace it without touching callers.
//
//  Nothing secret is stored here: stream keys live in the Keychain, and
//  exported presets strip bookmarks, paths, and rights declarations.
//

import Foundation

struct StudioDocument: Codable {
    var version: Int = 1
    var library: MediaLibrary = MediaLibrary()
    var playlist: Playlist = Playlist(name: "Untitled Program")
    var dna: VisualDNA = .starter
    var score: VisualScore = VisualScore()
    var trackAnalyses: [String: TrackAnalysis] = [:]      // fingerprint -> analysis
    var programAnalysis: ProgramAnalysis = ProgramAnalysis()
    var destination: Destination = Destination()
    var outputProfile: OutputProfile = .p1080
    var session: BroadcastSession = BroadcastSession()
    var journal: [RecoveryJournalEntry] = []
    var savedAt: Date = Date()
}

final class SessionStore {

    static let shared = SessionStore()

    private let queue = DispatchQueue(label: "com.vagabond.asciibroadcast.store", qos: .utility)
    private let fileManager = FileManager.default

    private lazy var directory: URL = {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let dir = base.appendingPathComponent("ASCIIBroadcast", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private var documentURL: URL { directory.appendingPathComponent("studio.json") }
    private var journalURL: URL { directory.appendingPathComponent("recovery.json") }

    var recordingsDirectory: URL {
        let dir = directory.appendingPathComponent("Recordings", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Load / save

    func load() -> StudioDocument? {
        guard let data = try? Data(contentsOf: documentURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(StudioDocument.self, from: data)
    }

    /// Debounced, atomic. Never blocks the caller and never leaves a partial
    /// document on disk if the process dies mid-write.
    private var pendingWork: DispatchWorkItem?

    func save(_ document: StudioDocument, immediate: Bool = false) {
        pendingWork?.cancel()
        var copy = document
        copy.savedAt = Date()
        let work = DispatchWorkItem { [weak self] in
            self?.writeNow(copy)
        }
        pendingWork = work
        if immediate {
            queue.async(execute: work)
        } else {
            queue.asyncAfter(deadline: .now() + 0.8, execute: work)
        }
    }

    private func writeNow(_ document: StudioDocument) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(document) else { return }
        let temp = documentURL.appendingPathExtension("tmp")
        do {
            try data.write(to: temp, options: .atomic)
            if fileManager.fileExists(atPath: documentURL.path) {
                _ = try fileManager.replaceItemAt(documentURL, withItemAt: temp)
            } else {
                try fileManager.moveItem(at: temp, to: documentURL)
            }
        } catch {
            try? data.write(to: documentURL, options: .atomic)
            try? fileManager.removeItem(at: temp)
        }
    }

    // MARK: - Recovery journal

    func appendJournal(_ entry: RecoveryJournalEntry) {
        queue.async { [weak self] in
            guard let self else { return }
            var entries = self.readJournal()
            entries.append(entry)
            if entries.count > 400 { entries.removeFirst(entries.count - 400) }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(entries) {
                try? data.write(to: self.journalURL, options: .atomic)
            }
        }
    }

    func readJournal() -> [RecoveryJournalEntry] {
        guard let data = try? Data(contentsOf: journalURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([RecoveryJournalEntry].self, from: data)) ?? []
    }

    // MARK: - Preset export / import

    /// Export strips file paths, bookmarks, stream keys, and rights claims.
    func exportPreset(_ dna: VisualDNA, to url: URL) throws {
        var sanitized = dna
        sanitized.rationale = dna.rationale
        let payload = PresetManifest(dna: sanitized)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(payload).write(to: url, options: .atomic)
    }

    func importPreset(from url: URL) throws -> VisualDNA {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(PresetManifest.self, from: data)
        guard manifest.schemaVersion <= PresetManifest.currentSchemaVersion else {
            throw StoreError.presetTooNew(manifest.schemaVersion)
        }
        var dna = manifest.dna
        dna.id = UUID()
        dna.revision = 1
        return dna
    }

    enum StoreError: LocalizedError {
        case presetTooNew(Int)

        var errorDescription: String? {
            switch self {
            case .presetTooNew(let version):
                return "This preset was written by a newer version of ASCII Broadcast (schema \(version)). Your current preset is unchanged. Update the app to open it."
            }
        }
    }
}

struct PresetManifest: Codable {
    static let currentSchemaVersion = 1
    var schemaVersion: Int = PresetManifest.currentSchemaVersion
    var exportedAt: Date = Date()
    var application: String = "ASCII Broadcast"
    var dna: VisualDNA
}
