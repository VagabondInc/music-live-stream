//
//  InspectorView.swift
//  ASCII Broadcast
//
//  VISUAL_DNA. Guided controls only: nine sliders and six choices that always
//  produce a coherent show. No node graph, no shader parameters, nothing that
//  can be set to a state the engine cannot render well.
//

import SwiftUI

struct InspectorView: View {
    @ObservedObject var model: StudioViewModel
    @State private var showRationale = false

    var body: some View {
        StudioPanel(title: "VISUAL_DNA") {
            IconButton(systemImage: "circle.dashed", accessibilityTitle: "Generate a new variant") {
                model.generateDNA(newVariant: true)
            }
        } content: {
            ScrollView {
                VStack(spacing: 0) {
                    presetRow
                    HairlineDivider(color: Theme.hairline)

                    VStack(spacing: 5) {
                        EnumPickerRow(label: "WORLD", systemImage: "point.3.connected.trianglepath.dotted",
                                      selection: Binding(get: { model.dna.direction },
                                                         set: { model.setDirection($0) }))
                        EnumPickerRow(label: "PERFORMANCE", systemImage: "waveform.path.ecg",
                                      selection: Binding(get: { model.dna.performance },
                                                         set: { model.setPerformance($0) }))
                        EnumPickerRow(label: "DETAIL", systemImage: "square.grid.3x3",
                                      selection: Binding(get: { model.dna.detail },
                                                         set: { model.setDetail($0) }))
                        EnumPickerRow(label: "COLOR", systemImage: "circle.lefthalf.filled",
                                      selection: Binding(get: { model.dna.color },
                                                         set: { model.setColor($0) }))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 8)

                    HairlineDivider(color: Theme.hairline)

                    VStack(spacing: 7) {
                        glyphDensityRow
                        MicroSlider(label: "MOTION", systemImage: "waveform",
                                    value: binding(\.motion), accent: Theme.cyan) { model.compileScore() }
                        MicroSlider(label: "GLITCH", systemImage: "barcode",
                                    value: binding(\.glitch),
                                    accent: model.dna.controls.glitch > 45 ? Theme.red : Theme.cyan) { model.compileScore() }
                        MicroSlider(label: "TITLES", systemImage: "textformat",
                                    value: binding(\.titles), accent: Theme.cyan) { model.compileScore() }
                        MicroSlider(label: "CAMERA", systemImage: "camera",
                                    value: binding(\.camera), accent: Theme.cyan)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 9)

                    HairlineDivider(color: Theme.hairline)

                    DisclosureRow(title: "ATMOSPHERE", expanded: section("ATMOSPHERE")) {
                        VStack(spacing: 7) {
                            MicroSlider(label: "DENSITY", systemImage: "cloud",
                                        value: binding(\.atmosphere), accent: Theme.cyan)
                            MicroSlider(label: "DRIFT", systemImage: "wind",
                                        value: binding(\.paletteDrift), accent: Theme.cyan)
                            Text("Atmosphere adds depth haze and particulate. It is the first thing the engine sheds when frame time gets tight.")
                                .font(Theme.mono(8.5))
                                .foregroundStyle(Theme.textDim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 4)
                    }

                    DisclosureRow(title: "SCENE BEHAVIOR", expanded: section("SCENE_FAMILIES")) {
                        VStack(alignment: .leading, spacing: 7) {
                            MicroSlider(label: "DWELL", systemImage: "clock",
                                        value: binding(\.sceneDwell), accent: Theme.cyan) { model.compileScore() }
                            ForEach(SceneFamily.allCases, id: \.self) { family in
                                HStack(spacing: 6) {
                                    Text(family.description)
                                        .font(Theme.mono(9))
                                        .foregroundStyle(Theme.textSecondary)
                                    Spacer(minLength: 4)
                                    Text(String(format: "%.0f%%", (model.dna.weightedFamilies[family] ?? 0) * 100))
                                        .font(Theme.mono(9))
                                        .foregroundStyle(Theme.textDim)
                                }
                            }
                            Text("Weights come from the programme's energy and tempo. Lock the families to keep them through a regeneration.")
                                .font(Theme.mono(8.5))
                                .foregroundStyle(Theme.textDim)
                                .fixedSize(horizontal: false, vertical: true)
                            ToggleChip(label: "LOCK FAMILIES", isOn: Binding(
                                get: { model.dna.lockedFamilies },
                                set: { model.dna.lockedFamilies = $0; model.save() }), accent: Theme.amber)
                        }
                        .padding(.top, 4)
                    }

                    DisclosureRow(title: "TRANSITIONS", expanded: section("TRANSITIONS")) {
                        VStack(alignment: .leading, spacing: 7) {
                            MicroSlider(label: "VARIETY", systemImage: "arrow.left.arrow.right",
                                        value: binding(\.transitionVariety), accent: Theme.cyan) { model.compileScore() }
                            Text("\(model.score.transitions.count) transitions compiled. Track changes always resolve on a musical boundary when one is close enough.")
                                .font(Theme.mono(8.5))
                                .foregroundStyle(Theme.textDim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 4)
                    }

                    DisclosureRow(title: "COLOR PALETTE", expanded: section("COLOR_PALETTE")) {
                        VStack(alignment: .leading, spacing: 8) {
                            PaletteStrip(direction: model.dna.direction)
                            EnumPickerRow(label: "GLYPH SET", systemImage: "character.cursor.ibeam",
                                          selection: Binding(get: { model.dna.glyphProfile },
                                                             set: { model.setGlyphProfile($0) }))
                            ToggleChip(label: "COLOR-BLIND SAFE", isOn: Binding(
                                get: { model.dna.colorBlindSafe },
                                set: { model.dna.colorBlindSafe = $0; model.pushEngineInputs(); model.save() }),
                                       accent: Theme.cyan)
                        }
                        .padding(.top, 4)
                    }

                    DisclosureRow(title: "ADVANCED", expanded: section("ADVANCED")) {
                        VStack(alignment: .leading, spacing: 7) {
                            EnumPickerRow(label: "CAMERA", systemImage: "video",
                                          selection: Binding(get: { model.dna.cameraGrammar },
                                                             set: { model.setCamera($0) }))
                            FieldRow(label: "SEED", value: String(model.dna.seed))
                            FieldRow(label: "REVISION", value: "\(model.dna.revision)")
                            FieldRow(label: "SCORE REV", value: "\(model.score.revision) / DNA \(model.score.dnaRevision)")
                            ToggleChip(label: "REDUCE MOTION", isOn: Binding(
                                get: { model.dna.reduceMotion },
                                set: { model.setReduceMotion($0) }), accent: Theme.amber)
                            Button {
                                model.generateDNA(newVariant: false)
                            } label: {
                                Text("REGENERATE FROM ANALYSIS")
                                    .font(Theme.mono(9, .medium))
                                    .foregroundStyle(Theme.cyanBright)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 22)
                                    .background(Theme.panelRaised)
                                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.cyanDim, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 4)
                    }

                    safetyRow

                    if showRationale {
                        Text(model.dna.rationale.isEmpty ? model.programAnalysis.rationale : model.dna.rationale)
                            .font(Theme.mono(9))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.well)
                    }
                }
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<GuidedControls, Int>) -> Binding<Int> {
        Binding(
            get: { model.dna.controls[keyPath: keyPath] },
            set: { newValue in model.updateControls { $0[keyPath: keyPath] = newValue } }
        )
    }

    private func section(_ key: String) -> Binding<Bool> {
        Binding(
            get: { model.inspectorSections.contains(key) },
            set: { isOpen in
                if isOpen { model.inspectorSections.insert(key) }
                else { model.inspectorSections.remove(key) }
            }
        )
    }

    private var presetRow: some View {
        HStack(spacing: 8) {
            Text("PRESET")
                .font(Theme.label)
                .tracked(0.9)
                .foregroundStyle(Theme.textDim)
            Menu {
                ForEach(WorldDirection.allCases, id: \.self) { direction in
                    Button(direction.description) { model.setDirection(direction) }
                }
                Divider()
                Button("Regenerate from analysis") { model.generateDNA(newVariant: false) }
                Button("New variant") { model.generateDNA(newVariant: true) }
            } label: {
                HStack {
                    Text(model.dna.name)
                        .font(Theme.mono(10, .medium))
                        .tracked(0.8)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Theme.textDim)
                }
                .padding(.horizontal, 8)
                .frame(height: 21)
                .background(Theme.panelRaised)
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.hairline, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
            .menuIndicator(.hidden)
            .accessibilityLabel("Visual preset")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
    }

    /// GLYPHS uses the mockup's segmented density readout rather than a line.
    private var glyphDensityRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "textformat.size")
                .font(.system(size: 9))
                .foregroundStyle(Theme.textDim)
                .frame(width: 12)
            Text("GLYPHS")
                .font(Theme.label)
                .tracked(0.7)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 52, alignment: .leading)
            HStack(spacing: 2) {
                ForEach(0..<7, id: \.self) { index in
                    let threshold = Double(index + 1) / 7.0
                    Rectangle()
                        .fill(Double(model.dna.controls.glyphDensity) / 100.0 >= threshold - 0.07
                              ? (index >= 5 ? Theme.green : Theme.textSecondary)
                              : Theme.hairlineStrong)
                        .frame(height: 11)
                        .onTapGesture {
                            model.updateControls { $0.glyphDensity = Int(threshold * 100) }
                        }
                }
            }
            Text("\(model.dna.controls.glyphDensity)")
                .font(Theme.value)
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 22, alignment: .trailing)
        }
        .frame(height: 19)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Glyph density")
        .accessibilityValue("\(model.dna.controls.glyphDensity) percent")
    }

    private var safetyRow: some View {
        HStack(spacing: 8) {
            Button {
                model.setPhotosensitivitySafe(!model.dna.photosensitivitySafe)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: model.dna.photosensitivitySafe ? "checkmark.square.fill" : "square")
                        .font(.system(size: 11))
                        .foregroundStyle(model.dna.photosensitivitySafe ? Theme.green : Theme.textDim)
                    Text("PHOTOSENSITIVITY_SAFE")
                        .font(Theme.mono(9.5, .medium))
                        .tracked(0.9)
                        .foregroundStyle(model.dna.photosensitivitySafe ? Theme.greenBright : Theme.textDim)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Photosensitivity safeguards")
            .accessibilityValue(model.dna.photosensitivitySafe ? "on" : "off")

            Spacer(minLength: 4)

            IconButton(systemImage: "info.circle", accessibilityTitle: "About photosensitivity safeguards") {
                showRationale.toggle()
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 9)
    }
}

struct PaletteStrip: View {
    var direction: WorldDirection

    var body: some View {
        let palette = Palette.authored(for: direction)
        HStack(spacing: 2) {
            ForEach(PaletteRole.allCases, id: \.self) { role in
                let rgb = palette.color(role)
                Rectangle()
                    .fill(Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: 1))
                    .frame(height: 14)
            }
        }
        .overlay(Rectangle().strokeBorder(Theme.hairline, lineWidth: 1))
        .accessibilityLabel("Palette preview for \(direction.description)")
    }
}
