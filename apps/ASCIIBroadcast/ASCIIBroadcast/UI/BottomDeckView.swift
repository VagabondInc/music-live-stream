//
//  BottomDeckView.swift
//  ASCII Broadcast
//
//  NOW_PLAYING · TRANSPORT + TIME & SYNC · OUTBOUND_STATE · STREAM_HEALTH ·
//  the stop control and its output fields. Everything a creator needs to reach
//  without leaving the room.
//

import SwiftUI

struct BottomDeckView: View {
    @ObservedObject var model: StudioViewModel
    @ObservedObject var coordinator: BroadcastCoordinator

    var body: some View {
        HStack(spacing: Theme.Metric.gutter) {
            NowPlayingPanel(model: model)
                .frame(width: Theme.Metric.sideColumnWidth)
            TransportPanel(model: model)
                .frame(minWidth: 380, maxWidth: .infinity)
            OutboundPanel(model: model, coordinator: coordinator)
                .frame(width: 236)
            StreamHealthPanel(model: model, coordinator: coordinator)
                .frame(width: 268)
            OutputControlPanel(model: model, coordinator: coordinator)
                .frame(width: 262)
        }
        .frame(height: Theme.Metric.bottomDeckHeight)
    }
}

// MARK: - Now playing

struct NowPlayingPanel: View {
    @ObservedObject var model: StudioViewModel

    var body: some View {
        StudioPanel(title: "NOW_PLAYING") {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 9) {
                    ArtworkTile(renderer: model.renderer)
                        .frame(width: 58, height: 52)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(String(format: "%02d", model.currentIndex + 1))
                                .font(Theme.mono(12, .semibold))
                                .foregroundStyle(Theme.amber)
                            Text("//")
                                .font(Theme.mono(11))
                                .foregroundStyle(Theme.textFaint)
                            Text(model.currentTitle.uppercased())
                                .font(Theme.mono(12, .semibold))
                                .tracked(0.8)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                        }
                        Text(model.currentArtist.uppercased())
                            .font(Theme.mono(9.5))
                            .tracked(0.9)
                            .foregroundStyle(Theme.textDim)

                        ScrubBar(fraction: model.trackDuration > 0 ? model.trackTime / model.trackDuration : 0) { fraction in
                            model.seek(toFraction: fraction)
                        }
                        .frame(height: 9)

                        HStack {
                            Spacer()
                            Text("\(Timecode.clock(model.trackTime)) / \(Timecode.clock(model.trackDuration))")
                                .font(Theme.mono(9))
                                .foregroundStyle(Theme.textDim)
                        }
                    }
                }
                .padding(.horizontal, 9)
                .padding(.top, 9)

                Spacer(minLength: 4)

                HStack(spacing: 8) {
                    ArtworkTile(renderer: model.renderer, dim: true)
                        .frame(width: 30, height: 24)
                    TagPill(text: "NEXT", color: Theme.textDim)
                    Text("//")
                        .font(Theme.mono(9))
                        .foregroundStyle(Theme.textFaint)
                    Text((model.nextAsset?.titleOrFilename ?? "END OF PROGRAM").uppercased())
                        .font(Theme.mono(10, .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(Timecode.clock(model.nextAsset?.duration ?? 0))
                        .font(Theme.mono(9.5))
                        .foregroundStyle(Theme.textDim)
                }
                .padding(.horizontal, 9)
                .frame(height: 34)
                .background(Theme.panelRaised.opacity(0.55))
                .overlay(alignment: .top) { HairlineDivider(color: Theme.hairline) }
            }
        }
    }
}

/// A live thumbnail of the program image, standing in for cover art.
struct ArtworkTile: View {
    let renderer: ProgramRenderer
    var dim: Bool = false

    var body: some View {
        ProgramCanvasView(renderer: renderer, isPlaying: true)
            .opacity(dim ? 0.55 : 1)
            .overlay(Rectangle().strokeBorder(Theme.hairlineStrong, lineWidth: 1))
            .clipShape(Rectangle())
            .accessibilityHidden(true)
    }
}

struct ScrubBar: View {
    var fraction: Double
    var onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.well)
                Rectangle()
                    .fill(Theme.cyan)
                    .frame(width: max(0, min(1, fraction)) * proxy.size.width)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                onSeek(value.location.x / max(1, proxy.size.width))
            })
        }
        .frame(height: 4)
        .accessibilityLabel("Track position")
        .accessibilityValue("\(Int(fraction * 100)) percent")
    }
}

// MARK: - Transport

struct TransportPanel: View {
    @ObservedObject var model: StudioViewModel

    var body: some View {
        StudioPanel(title: "TRANSPORT") {
            IconButton(systemImage: "xmark.circle", accessibilityTitle: "Stop playback") {
                model.stop()
            }
        } content: {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        transportButton("backward.fill", "Previous track") { model.previous() }
                        transportButton(model.isPlaying ? "pause.fill" : "play.fill",
                                        model.isPlaying ? "Pause" : "Play",
                                        emphasised: true) { model.togglePlayPause() }
                        transportButton("stop.fill", "Stop") { model.stop() }
                        transportButton("forward.fill", "Next track") { model.next() }
                    }
                    HStack(spacing: 8) {
                        ToggleChip(label: "LOOP", isOn: Binding(
                            get: { model.playlist.loops },
                            set: { model.setLoops($0) }), accent: Theme.cyan)
                        ToggleChip(label: "AUTO ADVANCE", isOn: Binding(
                            get: { model.playlist.autoAdvance },
                            set: { model.setAutoAdvance($0) }), accent: Theme.green)
                    }
                }
                .padding(.leading, 12)

                Spacer(minLength: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text("TIME & SYNC")
                        .font(Theme.mono(8.5, .semibold))
                        .tracked(1.0)
                        .foregroundStyle(Theme.textDim)
                    Text(Timecode.broadcast(model.programTime, fps: model.profile.frameRate))
                        .font(Theme.mono(25, .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    HStack(spacing: 6) {
                        Text("/ \(Timecode.clock(model.trackDuration))")
                            .font(Theme.mono(10))
                            .foregroundStyle(Theme.textDim)
                    }
                    HStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Text("BPM")
                                .font(Theme.mono(9, .medium))
                                .foregroundStyle(Theme.textDim)
                            Text(model.liveBPM > 0 ? String(format: "%.0f", model.liveBPM) : "—")
                                .font(Theme.mono(12, .medium))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        Rectangle().fill(Theme.hairline).frame(width: 1, height: 12)
                        Text(meterLabel)
                            .font(Theme.mono(11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.trailing, 8)

                VStack(spacing: 6) {
                    IconButton(systemImage: "timer", accessibilityTitle: "Tap tempo") {
                        model.statusMessage = "TEMPO FROM ANALYSIS — TAP OVERRIDE COMING IN PHASE 3"
                    }
                    .frame(width: 26, height: 26)
                    .background(Theme.panelRaised)
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.hairline, lineWidth: 1))

                    IconButton(systemImage: "link", accessibilityTitle: "Sync source") {
                        model.statusMessage = "SYNC SOURCE: PROGRAM AUDIO CLOCK"
                    }
                    .frame(width: 26, height: 26)
                    .background(Theme.panelRaised)
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.hairline, lineWidth: 1))
                }
                .padding(.trailing, 12)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var meterLabel: String {
        guard let analysis = model.currentAnalysis else { return "4/4" }
        return "\(analysis.meterNumerator)/\(analysis.meterDenominator)"
    }

    private func transportButton(_ image: String,
                                 _ title: String,
                                 emphasised: Bool = false,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: image)
                .font(.system(size: emphasised ? 15 : 13, weight: .medium))
                .foregroundStyle(emphasised ? Theme.amber : Theme.textSecondary)
                .frame(width: emphasised ? 46 : 42, height: 38)
                .background(Theme.panelRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(emphasised ? Theme.amber.opacity(0.8) : Theme.hairline, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - Outbound state

struct OutboundPanel: View {
    @ObservedObject var model: StudioViewModel
    @ObservedObject var coordinator: BroadcastCoordinator

    var body: some View {
        StudioPanel(title: "OUTBOUND_STATE") {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: coordinator.pipeline.isTransmitting ? "dot.radiowaves.left.and.right" : "wifi.slash")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.statusColor(coordinator.pipeline))
                    Text(coordinator.pipeline.display)
                        .font(Theme.mono(13, .semibold))
                        .tracked(1.0)
                        .foregroundStyle(Theme.statusColor(coordinator.pipeline))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Local pipeline: \(coordinator.pipeline.display)")

                Text(coordinator.statusLine)
                    .font(Theme.mono(8.5))
                    .foregroundStyle(Theme.textDim)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HairlineDivider()

                Text("DESTINATION")
                    .font(Theme.mono(8.5, .semibold))
                    .tracked(1.0)
                    .foregroundStyle(Theme.textDim)

                HStack(spacing: 7) {
                    DestinationGlyph(kind: model.destination.kind)
                        .frame(width: 22, height: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.destination.kind.description)
                            .font(Theme.mono(10, .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(coordinator.visibility.display)
                            .font(Theme.mono(8))
                            .tracked(0.6)
                            .foregroundStyle(visibilityColor)
                            .lineLimit(1)
                    }
                }
                .accessibilityElement(children: .combine)

                Spacer(minLength: 0)

                HStack {
                    Spacer()
                    Button {
                        model.showPreflight = true
                        model.runPreflight()
                    } label: {
                        Text("CONFIGURE…")
                            .font(Theme.mono(9, .medium))
                            .tracked(0.8)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 10)
                            .frame(height: 22)
                            .background(Theme.panelRaised)
                            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.hairline, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(9)
        }
    }

    private var visibilityColor: Color {
        switch coordinator.visibility {
        case .providerConfirmedLive: return Theme.green
        case .creatorReportedLive:   return Theme.cyan
        case .providerError:         return Theme.red
        case .providerReportedNotLive: return Theme.amber
        case .unknown:               return Theme.textDim
        }
    }
}

struct DestinationGlyph: View {
    var kind: DestinationKind

    var body: some View {
        switch kind {
        case .youTubeRTMPS:
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.red)
                .overlay(
                    Triangle()
                        .fill(Color.white)
                        .rotationEffect(.degrees(90))
                        .frame(width: 6, height: 7)
                )
        case .customRTMPS:
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Theme.cyan, lineWidth: 1)
                .overlay(Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.cyan))
        case .localRecordingOnly:
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Theme.textDim, lineWidth: 1)
                .overlay(Image(systemName: "internaldrive")
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.textDim))
        }
    }
}

// MARK: - Stream health

struct StreamHealthPanel: View {
    @ObservedObject var model: StudioViewModel
    @ObservedObject var coordinator: BroadcastCoordinator

    var body: some View {
        StudioPanel(title: "STREAM_HEALTH") {
            VStack(spacing: 5) {
                HStack(spacing: 12) {
                    FieldRow(label: "RESOLUTION", value: model.profile.summary)
                    FieldRow(label: "BITRATE", value: bitrateText, valueColor: Theme.textPrimary)
                }
                HStack(spacing: 12) {
                    FieldRow(label: "FRAMES DROPPED",
                             value: String(format: "%.2f%%", coordinator.engineHealth.dropRate * 100),
                             valueColor: coordinator.engineHealth.dropRate > 0.01 ? Theme.amber : Theme.textPrimary)
                    HStack(spacing: 6) {
                        Text("NETWORK")
                            .font(Theme.label)
                            .foregroundStyle(Theme.textDim)
                        Spacer(minLength: 4)
                        StatusDot(color: networkColor, size: 5)
                        Text(networkWord)
                            .font(Theme.value)
                            .foregroundStyle(networkColor)
                    }
                }

                HairlineDivider()

                HStack(spacing: 12) {
                    meterRow("NETWORK", value: networkQuality, color: networkColor)
                    meterRow("AUDIO LOCK", value: audioLock, color: Theme.green)
                }
                HStack(spacing: 12) {
                    meterRow("ENCODER", value: encoderQuality, color: Theme.green)
                    HStack(spacing: 6) {
                        Text("Q3")
                            .font(Theme.label)
                            .foregroundStyle(Theme.textDim)
                        BarMeter(value: 1 - Double(coordinator.engineHealth.qualityTier) / 3.0, color: Theme.green)
                    }
                }
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Text("CPU")
                            .font(Theme.label)
                            .foregroundStyle(Theme.textDim)
                        Text("\(Int(cpuFraction * 100))%")
                            .font(Theme.value)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 30, alignment: .trailing)
                        BarMeter(value: cpuFraction, color: cpuFraction > 0.85 ? Theme.amber : Theme.green)
                    }
                    HStack(spacing: 6) {
                        Text("\(Int(gpuFraction * 100))%")
                            .font(Theme.value)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 30, alignment: .trailing)
                        BarMeter(value: gpuFraction, color: Theme.green)
                    }
                }
                FieldRow(label: "STORAGE",
                         value: String(format: "%.0f GB", PreflightService.freeDiskGB()),
                         valueColor: Theme.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(9)
        }
    }

    private func meterRow(_ label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(Theme.label)
                .foregroundStyle(Theme.textDim)
            Spacer(minLength: 4)
            SegmentMeter(value: value, segments: 5, color: color)
        }
    }

    private var bitrateText: String {
        let measured = coordinator.measuredBitrate
        if measured > 1000 { return String(format: "%.1f Mbps", measured / 1_000_000) }
        return model.profile.bitrateLabel
    }

    private var networkQuality: Double {
        guard coordinator.pipeline.isTransmitting else { return 0.2 }
        let dropped = Double(coordinator.publisherHealth.droppedPackets)
        return clamp(1 - dropped / 200.0, 0.2, 1)
    }

    private var networkColor: Color {
        switch networkQuality {
        case ..<0.4: return Theme.red
        case ..<0.75: return Theme.amber
        default: return Theme.green
        }
    }

    private var networkWord: String {
        switch networkQuality {
        case ..<0.4: return "POOR"
        case ..<0.75: return "FAIR"
        default: return "GOOD"
        }
    }

    private var encoderQuality: Double {
        clamp(1 - coordinator.engineHealth.dropRate * 20, 0.2, 1)
    }

    private var audioLock: Double {
        coordinator.engineHealth.audioUnderruns == 0 ? 1 : 0.6
    }

    private var cpuFraction: Double {
        let budget = 1000.0 / Double(max(1, model.profile.frameRate))
        return clamp(coordinator.engineHealth.meanFrameMilliseconds / budget, 0.05, 1)
    }

    private var gpuFraction: Double {
        clamp(cpuFraction * 1.2, 0.05, 1)
    }
}

// MARK: - Output control

struct OutputControlPanel: View {
    @ObservedObject var model: StudioViewModel
    @ObservedObject var coordinator: BroadcastCoordinator
    @State private var revealKeyField = false

    var body: some View {
        VStack(spacing: Theme.Metric.gutter) {
            Button(action: primaryAction) {
                HStack(spacing: 8) {
                    Image(systemName: isSending ? "stop.fill" : "dot.radiowaves.left.and.right")
                        .font(.system(size: 12, weight: .bold))
                    Text(isSending ? "STOP SENDING" : "START SENDING")
                        .font(Theme.mono(13, .bold))
                        .tracked(1.2)
                }
                .foregroundStyle(isSending ? Theme.textPrimary : Theme.void)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(isSending ? Theme.red.opacity(0.28) : Theme.green)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(isSending ? Theme.red : Theme.greenBright, lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [.command, .shift])
            .accessibilityLabel(isSending ? "Stop sending" : "Start sending")

            VStack(spacing: 4) {
                FieldRow(label: "ENCODER", value: "asciibroadcast", valueColor: Theme.textSecondary)
                FieldRow(label: "VIDEO", value: "h264_vt", valueColor: Theme.textSecondary)
                FieldRow(label: "AUDIO", value: "aac_44k", valueColor: Theme.textSecondary)
                FieldRow(label: "RTMP", value: model.destination.ingestURL, valueColor: Theme.textSecondary)
                HStack(spacing: 6) {
                    Text("KEY")
                        .font(Theme.label)
                        .foregroundStyle(Theme.textDim)
                    Spacer(minLength: 4)
                    if revealKeyField {
                        SecureField("paste stream key", text: $model.streamKeyInput)
                            .textFieldStyle(.plain)
                            .font(Theme.mono(9))
                            .foregroundStyle(Theme.textPrimary)
                            .onSubmit { model.storeStreamKey() }
                    } else {
                        Text(model.destination.redactedKey)
                            .font(Theme.mono(9))
                            .foregroundStyle(Theme.textDim)
                            .lineLimit(1)
                    }
                    IconButton(systemImage: revealKeyField ? "eye.slash" : "eye",
                               accessibilityTitle: revealKeyField ? "Hide key field" : "Enter stream key") {
                        revealKeyField.toggle()
                        if !revealKeyField { model.storeStreamKey() }
                    }
                    IconButton(systemImage: "gearshape", accessibilityTitle: "Output settings") {
                        model.showPreflight = true
                        model.runPreflight()
                    }
                }
                HStack(spacing: 6) {
                    ToggleChip(label: "RECORD", isOn: $model.recordLocally, accent: Theme.red)
                    ToggleChip(label: "DRY RUN", isOn: $model.useSimulatedLink, accent: Theme.cyan)
                    Spacer(minLength: 0)
                }
                .padding(.top, 2)
            }
            .padding(9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .panelChrome()
        }
    }

    private var isSending: Bool {
        coordinator.pipeline.isTransmitting || coordinator.pipeline == .connecting
    }

    private func primaryAction() {
        if isSending {
            model.stopBroadcast()
        } else {
            model.startBroadcast()
        }
    }
}
