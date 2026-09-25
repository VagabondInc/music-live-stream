//
//  Components.swift
//  ASCII Broadcast
//
//  Small reusable control-surface parts. Everything is keyboard reachable and
//  carries an accessibility label: Phase 2 §3 requires the control surface to
//  behave like an instrument, not an unlabeled icon grid.
//

import SwiftUI

// MARK: - Panel

struct StudioPanel<Header: View, Content: View>: View {
    var title: String
    var accent: Color = Theme.cyan
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .font(Theme.label)
                    .tracked(1.1)
                    .foregroundStyle(accent)
                Spacer(minLength: 4)
                header()
            }
            .padding(.horizontal, 9)
            .frame(height: Theme.Metric.headerHeight)
            .background(Theme.panelRaised.opacity(0.55))
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .panelChrome()
    }
}

extension StudioPanel where Header == EmptyView {
    init(title: String, accent: Color = Theme.cyan, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, accent: accent, header: { EmptyView() }, content: content)
    }
}

// MARK: - Atoms

struct StatusDot: View {
    var color: Color
    var size: CGFloat = 6
    var pulsing: Bool = false
    @State private var on = true

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .opacity(pulsing ? (on ? 1 : 0.28) : 1)
            .shadow(color: color.opacity(0.7), radius: pulsing ? 3 : 0)
            .onAppear {
                guard pulsing else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { on = false }
            }
            .accessibilityHidden(true)
    }
}

struct TagPill: View {
    var text: String
    var color: Color = Theme.textSecondary
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(Theme.label)
            .tracked(0.9)
            .foregroundStyle(filled ? Theme.void : color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(filled ? color : color.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(color.opacity(filled ? 0 : 0.45), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

struct FieldRow: View {
    var label: String
    var value: String
    var valueColor: Color = Theme.textPrimary
    var mono: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(Theme.label)
                .tracked(0.7)
                .foregroundStyle(Theme.textDim)
            Spacer(minLength: 6)
            Text(value)
                .font(mono ? Theme.value : Theme.body)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label.replacingOccurrences(of: "_", with: " ")): \(value)")
    }
}

/// The segmented bar meters in STREAM_HEALTH.
struct SegmentMeter: View {
    var value: Double              // 0...1
    var segments: Int = 5
    var color: Color = Theme.green
    var emptyColor: Color = Theme.hairlineStrong

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<segments, id: \.self) { index in
                let threshold = Double(index + 1) / Double(segments)
                Rectangle()
                    .fill(value >= threshold - 0.0001 ? color : emptyColor)
                    .frame(width: 3.5, height: CGFloat(5 + index))
            }
        }
        .frame(height: CGFloat(5 + segments), alignment: .bottom)
        .accessibilityHidden(true)
    }
}

struct BarMeter: View {
    var value: Double              // 0...1
    var color: Color = Theme.cyan
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.well)
                Rectangle()
                    .fill(color)
                    .frame(width: max(0, min(1, value)) * proxy.size.width)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 1))
        .accessibilityHidden(true)
    }
}

// MARK: - Controls

/// Compact labelled slider used throughout VISUAL_DNA.
struct MicroSlider: View {
    var label: String
    var systemImage: String
    @Binding var value: Int          // 0...100
    var accent: Color = Theme.cyan
    var onCommit: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 9))
                .foregroundStyle(Theme.textDim)
                .frame(width: 12)
            Text(label)
                .font(Theme.label)
                .tracked(0.7)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 52, alignment: .leading)

            GeometryReader { proxy in
                let fraction = CGFloat(value) / 100.0
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.well).frame(height: 3)
                    Capsule().fill(accent.opacity(0.85))
                        .frame(width: max(2, fraction * proxy.size.width), height: 3)
                    Circle()
                        .fill(accent)
                        .frame(width: 9, height: 9)
                        .offset(x: max(0, min(proxy.size.width - 9, fraction * proxy.size.width - 4.5)))
                }
                .frame(height: 16)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let next = Int((drag.location.x / max(1, proxy.size.width)) * 100)
                            value = max(0, min(100, next))
                        }
                        .onEnded { _ in onCommit() }
                )
            }
            .frame(height: 16)

            Text(String(format: "%02d", value))
                .font(Theme.value)
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 22, alignment: .trailing)
        }
        .frame(height: 19)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(100, value + 5)
            case .decrement: value = max(0, value - 5)
            default: break
            }
            onCommit()
        }
    }
}

/// Value pill rows (WORLD / PERFORMANCE / DETAIL / COLOR).
struct EnumPickerRow<T: Hashable & CaseIterable & CustomStringConvertible>: View where T.AllCases == [T] {
    var label: String
    var systemImage: String
    @Binding var selection: T
    var onCommit: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 9))
                .foregroundStyle(Theme.textDim)
                .frame(width: 12)
            Text(label)
                .font(Theme.label)
                .tracked(0.7)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 78, alignment: .leading)

            Menu {
                ForEach(T.allCases, id: \.self) { option in
                    Button(option.description) {
                        selection = option
                        onCommit()
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selection.description)
                        .font(Theme.value)
                        .tracked(0.6)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 2)
                }
                .padding(.horizontal, 7)
                .frame(height: 19)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.panelRaised)
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Theme.hairline, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
            .menuIndicator(.hidden)
            .accessibilityLabel(label)
        }
        .frame(height: 21)
    }
}

struct DisclosureRow<Content: View>: View {
    var title: String
    @Binding var expanded: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.14)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Theme.textDim)
                    Text(title)
                        .font(Theme.label)
                        .tracked(0.9)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(Theme.textFaint)
                }
                .padding(.horizontal, 9)
                .frame(height: 22)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                content()
                    .padding(.horizontal, 9)
                    .padding(.bottom, 8)
            }
            Rectangle().fill(Theme.hairlineFaint).frame(height: 1)
        }
    }
}

/// Small square icon button used in panel headers.
struct IconButton: View {
    var systemImage: String
    var accessibilityTitle: String
    var tint: Color = Theme.textDim
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 18, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(accessibilityTitle)
        .accessibilityLabel(accessibilityTitle)
    }
}

struct TabStrip: View {
    var items: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button {
                    selection = index
                } label: {
                    Text(item)
                        .font(Theme.label)
                        .tracked(1.0)
                        .foregroundStyle(selection == index ? Theme.cyanBright : Theme.textDim)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(selection == index ? Theme.panelRaised : Color.clear)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(selection == index ? Theme.cyan : Color.clear)
                                .frame(height: 1.5)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == index ? [.isSelected] : [])
            }
        }
        .background(Theme.void)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }
}

struct ToggleChip: View {
    var label: String
    @Binding var isOn: Bool
    var accent: Color = Theme.green

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .font(Theme.label)
                    .tracked(0.8)
                    .foregroundStyle(isOn ? Theme.textPrimary : Theme.textDim)
                StatusDot(color: isOn ? accent : Theme.textFaint, size: 5)
            }
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(Theme.panelRaised)
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(isOn ? accent.opacity(0.5) : Theme.hairline, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "on" : "off")
        .accessibilityAddTraits(.isButton)
    }
}

struct HairlineDivider: View {
    var color: Color = Theme.hairlineFaint
    var body: some View { Rectangle().fill(color).frame(height: 1) }
}
