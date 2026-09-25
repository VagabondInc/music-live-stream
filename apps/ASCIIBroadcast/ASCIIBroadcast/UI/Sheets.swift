//
//  Sheets.swift
//  ASCII Broadcast
//
//  Preflight, first-run, and the inline banner. Every message says what
//  happened, why, whether anything was lost, and the one thing to do next.
//

import SwiftUI

// MARK: - Banner

struct BannerView: View {
    let banner: StudioViewModel.Banner
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(banner.title.uppercased())
                    .font(Theme.mono(10, .semibold))
                    .tracked(0.9)
                    .foregroundStyle(Theme.textPrimary)
                Text(banner.detail)
                    .font(Theme.mono(9.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let remedy = banner.remedy {
                    Text(remedy)
                        .font(Theme.mono(9.5))
                        .foregroundStyle(tint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            IconButton(systemImage: "xmark", accessibilityTitle: "Dismiss message", action: onDismiss)
        }
        .padding(10)
        .background(Theme.panelRaised)
        .overlay(alignment: .leading) { Rectangle().fill(tint).frame(width: 2) }
        .overlay(RoundedRectangle(cornerRadius: Theme.Metric.panelRadius).strokeBorder(tint.opacity(0.45), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.panelRadius))
        .frame(maxWidth: 560)
        .shadow(color: .black.opacity(0.6), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        switch banner.kind {
        case .info: return Theme.cyan
        case .warning: return Theme.amber
        case .error: return Theme.red
        case .success: return Theme.green
        }
    }

    private var icon: String {
        switch banner.kind {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        case .success: return "checkmark.circle"
        }
    }
}

// MARK: - Preflight

struct PreflightSheet: View {
    @ObservedObject var model: StudioViewModel
    @ObservedObject var coordinator: BroadcastCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("PREFLIGHT & OUTPUT")
                    .font(Theme.mono(12, .semibold))
                    .tracked(1.4)
                    .foregroundStyle(Theme.cyanBright)
                Spacer()
                IconButton(systemImage: "xmark", accessibilityTitle: "Close") { dismiss() }
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(Theme.panelRaised)
            .overlay(alignment: .bottom) { HairlineDivider(color: Theme.hairline) }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    destinationSection
                    profileSection
                    checksSection
                    visibilitySection
                }
                .padding(14)
            }

            HStack(spacing: 10) {
                Text(summary)
                    .font(Theme.mono(9.5))
                    .foregroundStyle(model.preflight.blocking.isEmpty ? Theme.green : Theme.amber)
                Spacer()
                Button("RUN CHECKS AGAIN") { model.runPreflight() }
                    .buttonStyle(StudioButtonStyle(tint: Theme.cyan))
                Button(coordinator.pipeline.isTransmitting ? "STOP SENDING" : "START SENDING") {
                    if coordinator.pipeline.isTransmitting { model.stopBroadcast() } else { model.startBroadcast() }
                    dismiss()
                }
                .buttonStyle(StudioButtonStyle(tint: coordinator.pipeline.isTransmitting ? Theme.red : Theme.green))
                .disabled(!model.preflight.blocking.isEmpty && !coordinator.pipeline.isTransmitting)
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(Theme.panel)
            .overlay(alignment: .top) { HairlineDivider(color: Theme.hairline) }
        }
        .frame(minWidth: 560, minHeight: 520)
        .background(Theme.void)
        .onAppear { model.runPreflight() }
    }

    private var summary: String {
        let report = model.preflight
        if report.items.isEmpty { return "NO CHECKS RUN YET" }
        if report.blocking.isEmpty {
            return "READY — \(report.warnings.count) WARNING\(report.warnings.count == 1 ? "" : "S")"
        }
        return "\(report.blocking.count) BLOCKING ISSUE\(report.blocking.count == 1 ? "" : "S")"
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("DESTINATION")
            Picker("", selection: Binding(get: { model.destination.kind },
                                          set: { model.destination.kind = $0; model.save() })) {
                ForEach(DestinationKind.allCases, id: \.self) { kind in
                    Text(kind.description).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            LabeledField(label: "INGEST URL", text: Binding(
                get: { model.destination.ingestURL },
                set: { model.destination.ingestURL = $0 }))
            HStack(spacing: 8) {
                SecureLabeledField(label: "STREAM KEY", text: $model.streamKeyInput,
                                   placeholder: model.destination.hasStoredKey ? "stored in keychain" : "paste key")
                Button("STORE") { model.storeStreamKey() }
                    .buttonStyle(StudioButtonStyle(tint: Theme.cyan))
                Button("CLEAR") { model.clearStreamKey() }
                    .buttonStyle(StudioButtonStyle(tint: Theme.textDim))
            }
            Text("Keys are written to the keychain and never to the session file, diagnostics, or logs.")
                .font(Theme.mono(8.5))
                .foregroundStyle(Theme.textDim)
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("OUTPUT PROFILE")
            HStack(spacing: 8) {
                ForEach(OutputProfile.all, id: \.name) { candidate in
                    Button {
                        model.setProfile(candidate)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.summary)
                                .font(Theme.mono(11, .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("\(candidate.resolutionLabel) · \(candidate.bitrateLabel)")
                                .font(Theme.mono(8.5))
                                .foregroundStyle(Theme.textDim)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(model.profile.name == candidate.name ? Theme.amberWash : Theme.panelRaised)
                        .overlay(RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(model.profile.name == candidate.name ? Theme.amber : Theme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 10) {
                ToggleChip(label: "RECORD LOCALLY", isOn: $model.recordLocally, accent: Theme.red)
                ToggleChip(label: "DRY RUN (NO NETWORK)", isOn: $model.useSimulatedLink, accent: Theme.cyan)
            }
            Text("Grid \(model.profile.glyphColumns)×\(model.profile.glyphRows) characters · H.264 High · AAC-LC \(Int(model.profile.audioSampleRate / 1000)) kHz · keyframe every \(Int(model.profile.keyframeIntervalSeconds))s")
                .font(Theme.mono(8.5))
                .foregroundStyle(Theme.textDim)
        }
    }

    private var checksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("CHECKS")
            ForEach(model.preflight.items) { item in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: icon(for: item.severity))
                        .font(.system(size: 10))
                        .foregroundStyle(color(for: item.severity))
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(Theme.mono(10, .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text(item.detail)
                            .font(Theme.mono(9))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let remedy = item.remedy {
                            Text(remedy)
                                .font(Theme.mono(9))
                                .foregroundStyle(color(for: item.severity))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(9)
                .background(Theme.panel)
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.hairlineFaint, lineWidth: 1))
            }
        }
    }

    private var visibilitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("DESTINATION VISIBILITY")
            Text("This app reports what it is sending. It cannot see your channel page. When you have confirmed the stream is visible on the destination, say so here — the studio will show it as creator-confirmed, never as provider-verified.")
                .font(Theme.mono(9))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button("I CONFIRMED IT IS LIVE") { coordinator.setCreatorReportedLive(true) }
                    .buttonStyle(StudioButtonStyle(tint: Theme.green))
                Button("IT IS NOT LIVE") { coordinator.setCreatorReportedLive(false) }
                    .buttonStyle(StudioButtonStyle(tint: Theme.amber))
            }
            FieldRow(label: "CURRENT", value: coordinator.visibility.display)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(Theme.mono(9.5, .semibold))
            .tracked(1.2)
            .foregroundStyle(Theme.cyan)
    }

    private func icon(for severity: PreflightSeverity) -> String {
        switch severity {
        case .blocking: return "xmark.octagon"
        case .warning: return "exclamationmark.triangle"
        case .info: return "info.circle"
        }
    }

    private func color(for severity: PreflightSeverity) -> Color {
        switch severity {
        case .blocking: return Theme.red
        case .warning: return Theme.amber
        case .info: return Theme.cyan
        }
    }
}

// MARK: - Onboarding

struct OnboardingSheet: View {
    @ObservedObject var model: StudioViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                BrandMark().frame(width: 20, height: 16)
                Text("ASCII BROADCAST")
                    .font(Theme.mono(13, .semibold))
                    .tracked(1.6)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(Theme.panelRaised)
            .overlay(alignment: .bottom) { HairlineDivider(color: Theme.hairline) }

            VStack(alignment: .leading, spacing: 14) {
                Text("Turn a playlist into a broadcast.")
                    .font(Theme.mono(15, .medium))
                    .foregroundStyle(Theme.textPrimary)

                Text("A demo programme is already loaded, so you can see a finished channel before importing anything of your own. Three steps take you from here to air:")
                    .font(Theme.mono(10))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                step("1", "ANALYSE", "Read tempo, sections and energy from every track. Roughly a second per minute of audio, and it only happens once per file.")
                step("2", "GENERATE", "The art director writes a Visual DNA and compiles a score: chapters, scenes, transitions, titles, effects and memory marks.")
                step("3", "SEND", "Preflight checks the programme, then the encoder starts. Local recording runs alongside, so a dropped connection never loses the session.")

                Text("You are responsible for the rights to the music you broadcast. The demo programme is generated by this app, so it is cleared by construction.")
                    .font(Theme.mono(9))
                    .foregroundStyle(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button("ANALYSE THE DEMO PROGRAMME") {
                        model.analyzeAll()
                        dismiss()
                    }
                    .buttonStyle(StudioButtonStyle(tint: Theme.green))
                    Button("LOOK AROUND FIRST") { dismiss() }
                        .buttonStyle(StudioButtonStyle(tint: Theme.textDim))
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
        .frame(minWidth: 520, minHeight: 440)
        .background(Theme.void)
    }

    private func step(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(Theme.mono(11, .bold))
                .foregroundStyle(Theme.void)
                .frame(width: 18, height: 18)
                .background(Theme.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.mono(10, .semibold))
                    .tracked(1.0)
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(Theme.mono(9.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Shared controls

struct StudioButtonStyle: ButtonStyle {
    var tint: Color = Theme.cyan

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.mono(9.5, .semibold))
            .tracked(0.9)
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(configuration.isPressed ? tint.opacity(0.22) : Theme.panelRaised)
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(tint.opacity(0.55), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

struct LabeledField: View {
    var label: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(Theme.label)
                .foregroundStyle(Theme.textDim)
                .frame(width: 84, alignment: .leading)
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(Theme.mono(10))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 7)
                .frame(height: 24)
                .background(Theme.well)
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.hairline, lineWidth: 1))
        }
    }
}

struct SecureLabeledField: View {
    var label: String
    @Binding var text: String
    var placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(Theme.label)
                .foregroundStyle(Theme.textDim)
                .frame(width: 84, alignment: .leading)
            SecureField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(Theme.mono(10))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 7)
                .frame(height: 24)
                .background(Theme.well)
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.hairline, lineWidth: 1))
        }
    }
}
