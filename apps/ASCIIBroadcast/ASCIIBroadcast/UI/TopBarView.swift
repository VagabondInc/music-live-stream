//
//  TopBarView.swift
//  ASCII Broadcast
//
//  Session identity on the left, what the session *is* in the middle, and the
//  two-value broadcast state on the right. The pipeline light never claims the
//  destination is live.
//

import SwiftUI
import Combine

struct TopBarView: View {
    @ObservedObject var model: StudioViewModel
    @ObservedObject var coordinator: BroadcastCoordinator

    var body: some View {
        HStack(spacing: 0) {
            // Identity
            HStack(spacing: 8) {
                BrandMark()
                    .frame(width: 18, height: 14)
                Text("VAGABOND")
                    .font(Theme.mono(11, .semibold))
                    .tracked(1.4)
                    .foregroundStyle(Theme.textPrimary)
                Text("//")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.textFaint)
                Text("ASCII BROADCAST")
                    .font(Theme.mono(11, .medium))
                    .tracked(1.4)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.leading, 10)
            .frame(width: Theme.Metric.sideColumnWidth + 20, alignment: .leading)

            Spacer(minLength: 8)

            // Session
            HStack(spacing: 8) {
                Text("SESSION:")
                    .font(Theme.mono(12, .medium))
                    .tracked(1.6)
                    .foregroundStyle(Theme.textDim)
                Text(model.playlist.sessionSlug)
                    .font(Theme.mono(12, .semibold))
                    .tracked(1.8)
                    .foregroundStyle(Theme.textPrimary)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 8)

            // Output summary + pipeline light
            HStack(spacing: 0) {
                summaryChip("FPS \(model.profile.frameRate)")
                summaryChip(model.profile.resolutionLabel)
                summaryChip("AUDIO 48k")
                summaryChip(model.destination.kind == .localRecordingOnly ? "FILE" : "RTMP")

                HStack(spacing: 7) {
                    Text("PIPELINE // \(coordinator.pipeline.display)")
                        .font(Theme.mono(11, .semibold))
                        .tracked(1.2)
                        .foregroundStyle(Theme.statusColor(coordinator.pipeline))
                    StatusDot(color: Theme.statusColor(coordinator.pipeline),
                              size: 7,
                              pulsing: coordinator.pipeline == .sending || coordinator.pipeline == .connecting)
                }
                .padding(.horizontal, 12)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Local pipeline state: \(coordinator.pipeline.display)")
            }
        }
        .frame(height: Theme.Metric.topBarHeight)
        .background(Theme.panel)
        .overlay(alignment: .bottom) { HairlineDivider(color: Theme.hairline) }
    }

    private func summaryChip(_ text: String) -> some View {
        Text(text)
            .font(Theme.mono(9.5, .medium))
            .tracked(0.8)
            .foregroundStyle(Theme.textDim)
            .padding(.horizontal, 10)
            .frame(height: Theme.Metric.topBarHeight)
            .overlay(alignment: .leading) {
                Rectangle().fill(Theme.hairlineFaint).frame(width: 1, height: 14)
            }
    }
}

/// The angular V mark from the mockup's top-left corner.
struct BrandMark: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            Path { path in
                path.move(to: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: w * 0.30, y: 0))
                path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.42))
                path.addLine(to: CGPoint(x: w * 0.70, y: 0))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: w * 0.74, y: h))
                path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.52))
                path.addLine(to: CGPoint(x: w * 0.26, y: h))
                path.closeSubpath()
            }
            .fill(Theme.textPrimary)
        }
        .accessibilityHidden(true)
    }
}

struct StatusBarView: View {
    @ObservedObject var model: StudioViewModel
    @ObservedObject var coordinator: BroadcastCoordinator
    @State private var clock = Date()

    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 0) {
            navItem("SCENES", "square.grid.2x2")
            navItem("OVERLAYS", "rectangle.stack")
            navItem("AUDIO", "waveform")
            navItem("OUTPUT", "tv")
            navItem("SHORTCUTS", "command")

            Spacer(minLength: 12)

            HStack(spacing: 18) {
                subsystem("ENCODER", healthy: coordinator.engineHealth.dropRate < 0.02)
                subsystem("AUDIO", healthy: coordinator.engineHealth.audioUnderruns == 0)
                subsystem("NETWORK", healthy: coordinator.publisherHealth.lastError == nil)
                subsystem("GPU", healthy: coordinator.engineHealth.qualityTier < 2)
                subsystem("STORAGE", healthy: true)
            }

            Spacer(minLength: 12)

            Text(formatter.string(from: clock))
                .font(Theme.mono(9.5))
                .foregroundStyle(Theme.textDim)
                .padding(.horizontal, 12)
                .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
                    clock = date
                }
        }
        .frame(height: Theme.Metric.statusBarHeight)
        .background(Theme.panel)
        .overlay(alignment: .top) { HairlineDivider(color: Theme.hairline) }
    }

    private func navItem(_ title: String, _ image: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: image)
                .font(.system(size: 9))
                .foregroundStyle(Theme.textFaint)
            Text(title)
                .font(Theme.mono(9, .medium))
                .tracked(0.9)
                .foregroundStyle(Theme.textDim)
        }
        .padding(.horizontal, 11)
        .frame(height: Theme.Metric.statusBarHeight)
        .contentShape(Rectangle())
        .accessibilityAddTraits(.isButton)
    }

    private func subsystem(_ title: String, healthy: Bool) -> some View {
        HStack(spacing: 5) {
            StatusDot(color: healthy ? Theme.green : Theme.amber, size: 5)
            Text(title)
                .font(Theme.mono(9, .medium))
                .tracked(0.9)
                .foregroundStyle(Theme.textDim)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(healthy ? "nominal" : "degraded")")
    }
}
