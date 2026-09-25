//
//  ProgramPanelView.swift
//  ASCII Broadcast
//
//  The program monitor: what is going out, what scene it belongs to, and the
//  honest state strip underneath.
//

import SwiftUI

struct ProgramPanelView: View {
    @ObservedObject var model: StudioViewModel
    @ObservedObject var coordinator: BroadcastCoordinator

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            ProgramFrameView(renderer: model.renderer,
                             isPlaying: model.isPlaying,
                             isSending: coordinator.pipeline.isTransmitting)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(Theme.void)
            statusStrip
        }
        .panelChrome()
    }

    private var sceneLabel: String {
        guard let scene = model.currentScene else { return "SCENE —" }
        return "SCENE \(String(format: "%02d", scene.index + 1))"
    }

    private var episodeTitle: String {
        model.currentScene?.episodeTitle.uppercased() ?? "FREE RUNNING"
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            StatusDot(color: model.isPlaying ? Theme.cyanBright : Theme.textFaint,
                      size: 6,
                      pulsing: model.isPlaying)
            Text("PROGRAM")
                .font(Theme.mono(11, .semibold))
                .tracked(1.3)
                .foregroundStyle(Theme.cyanBright)
            Text("//")
                .font(Theme.mono(11))
                .foregroundStyle(Theme.textFaint)
            Text(sceneLabel)
                .font(Theme.mono(11, .medium))
                .tracked(1.1)
                .foregroundStyle(Theme.textSecondary)
            Text("//")
                .font(Theme.mono(11))
                .foregroundStyle(Theme.textFaint)
            Text(episodeTitle)
                .font(Theme.mono(11, .medium))
                .tracked(1.1)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 8)

            if coordinator.pipeline.isTransmitting {
                HStack(spacing: 5) {
                    StatusDot(color: Theme.red, size: 5, pulsing: true)
                    Text("LIVE")
                        .font(Theme.mono(9.5, .bold))
                        .tracked(1.0)
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Theme.red.opacity(0.22))
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.red.opacity(0.6), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .accessibilityLabel("Sending to destination")
            } else {
                TagPill(text: "PREVIEW", color: Theme.cyanDim)
            }

            IconButton(systemImage: "arrow.up.left.and.arrow.down.right",
                       accessibilityTitle: "Full screen program") {
                model.statusMessage = "FULL SCREEN — PRESS ESC TO RETURN"
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Theme.panelRaised.opacity(0.55))
        .overlay(alignment: .bottom) { HairlineDivider(color: Theme.hairline) }
    }

    private var statusStrip: some View {
        HStack(spacing: 18) {
            strip("WORLD", model.dna.direction.description)
            strip("GLYPHS", model.dna.glyphProfile.description)
            strip("RENDER", coordinator.engineHealth.qualityTier == 0 ? "REALTIME" : "REALTIME / TIER \(coordinator.engineHealth.qualityTier)")
            Spacer(minLength: 8)
            HStack(spacing: 10) {
                Text("TC \(Timecode.broadcast(model.programTime, fps: model.profile.frameRate))")
                    .font(Theme.mono(10, .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(Timecode.clock(model.trackDuration))
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.textDim)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(Theme.panel)
        .overlay(alignment: .top) { HairlineDivider(color: Theme.hairline) }
    }

    private func strip(_ label: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Text("\(label):")
                .font(Theme.mono(9, .medium))
                .tracked(0.8)
                .foregroundStyle(Theme.textDim)
            Text(value)
                .font(Theme.mono(9.5, .medium))
                .tracked(0.8)
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}
