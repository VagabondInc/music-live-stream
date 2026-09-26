//
//  ASCIIBroadcastApp.swift
//  ASCII Broadcast
//
//  Native iOS / iPadOS / macOS studio. One scene, one control surface, dark
//  by construction: the room is dark when you are broadcasting.
//

import SwiftUI
import AVFoundation

@main
struct ASCIIBroadcastApp: App {

    init() {
        configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            StudioView()
                .frame(minWidth: 1180, minHeight: 760)
                .background(Theme.void)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1672, height: 941)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Broadcast") {
                Text("Start or stop sending: ⇧⌘↩")
            }
        }
        #endif
    }

    /// iOS needs an explicit session so playback survives the screen locking
    /// and so the app keeps rendering while it is in the background.
    private func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredSampleRate(48_000)
            try session.setPreferredIOBufferDuration(0.010)
            try session.setActive(true)
        } catch {
            NSLog("ASCIIBroadcast: audio session setup failed — \(error.localizedDescription)")
        }
        #endif
    }
}
