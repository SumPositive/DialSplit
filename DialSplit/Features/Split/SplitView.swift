//
//  SplitView.swift
//  DialSplit
//

import SwiftUI
import AZDial

private func localizedPeople(_ count: Int) -> String {
    let format = NSLocalizedString("format.people.long", comment: "")
    return String(format: format, locale: Locale.current, count)
}

private func localizedAmount(_ value: Int, placeholder: String = "---") -> String {
    MoneyFormat.localizedAmount(value, placeholder: placeholder)
}

struct LockToggleButton: View {
    @Binding var isLocked: Bool
    let lockedSystemImage: String
    let unlockedSystemImage: String
    let accessibilityLabel: String
    var size: CGFloat = 36
    var symbolSize: CGFloat = 18

    var body: some View {
        Button {
            isLocked.toggle()
        } label: {
            Image(systemName: isLocked ? lockedSystemImage : unlockedSystemImage)
                .font(.system(size: symbolSize, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isLocked ? Color.red.opacity(0.90) : Color.secondary.opacity(0.78))
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isLocked ? String(localized: "lock.locked") : String(localized: "lock.unlocked"))
    }
}

struct SplitView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    @State private var vm = SplitViewModel()
    @State private var showSettings = false
    @State private var isPeopleLocked = false
    @State private var isAllLocked = false
    private let cardSideMargin: CGFloat = 16
    // iPadでは、iPhone Pro Max相当の幅を上限にして中央カラム表示
    private let maxContentWidth: CGFloat = 430

    private var settingsSheetColorScheme: ColorScheme? {
        settings.appearanceMode.colorScheme ?? colorScheme
    }

    var body: some View {
        @Bindable var vm = vm

        ZStack {
            LeatherBackground()

            VStack(spacing: 0) {
                HeaderBar(showSettings: $showSettings)

                GeometryReader { proxy in
                    let cardWidth = min(max(0, proxy.size.width - cardSideMargin * 2), maxContentWidth)
                    let totalPanelWidth = min(cardWidth + 20, max(0, proxy.size.width - 4))
                    let panelAWidth = min(cardWidth + 6, max(0, proxy.size.width - 12))
                    ScrollView {
                        VStack(spacing: 8) {
                            // 合計金額パネル
                            TotalAmountPanel(
                                totalRaw: $vm.totalRaw,
                                totalPersons: vm.totalPersons,
                                dialUnit: vm.dialUnit,
                                panelWidth: cardWidth,
                                isPeopleLocked: $isPeopleLocked,
                                isAllLocked: isAllLocked
                            )
                            .frame(width: totalPanelWidth)
                            .padding(.top, 14)
                            .shadow(color: .black.opacity(0.40), radius: 24, x: 0, y: 14)
                            .shadow(color: .black.opacity(0.18), radius: 7, x: 0, y: 3)

                            // A（大富豪）パネル — 金額は自動計算の表示専用
                            Panel0View(
                                name:     settings.name(for: 0),
                                persons0: $vm.persons0,
                                split0:   vm.split0,
                                status:   vm.split0Status,
                                totalRaw: vm.totalRaw,
                                panelWidth: cardWidth,
                                isPeopleLocked: isPeopleLocked || isAllLocked,
                                isAllLocked: $isAllLocked
                            )
                            .frame(width: panelAWidth)
                            .shadow(color: .black.opacity(0.24), radius: 14, x: 0, y: 8)
                            .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 2)

                            // B（富豪）パネル
                            PanelSubView(
                                name:     settings.name(for: 1),
                                persons:  $vm.persons1,
                                split:    $vm.split1,
                                dialUnit: vm.dialUnit,
                                panelWidth: cardWidth,
                                isPeopleLocked: isPeopleLocked || isAllLocked,
                                isAmountLocked: isAllLocked
                            )
                            .frame(width: cardWidth)

                            // C（平民）パネル
                            PanelSubView(
                                name:     settings.name(for: 2),
                                persons:  $vm.persons2,
                                split:    $vm.split2,
                                dialUnit: vm.dialUnit,
                                panelWidth: cardWidth,
                                isPeopleLocked: isPeopleLocked || isAllLocked,
                                isAmountLocked: isAllLocked
                            )
                            .frame(width: cardWidth)

                            // D（貧民）パネル
                            PanelSubView(
                                name:     settings.name(for: 3),
                                persons:  $vm.persons3,
                                split:    $vm.split3,
                                dialUnit: vm.dialUnit,
                                panelWidth: cardWidth,
                                isPeopleLocked: isPeopleLocked || isAllLocked,
                                isAmountLocked: isAllLocked
                            )
                            .frame(width: cardWidth)

                            // ダイアル単位セグメント（通常フロー末尾）
                            DialUnitSegment(
                                dialUnit: $vm.dialUnit,
                                units: settings.amountDialSteps,
                                isLocked: isAllLocked
                            )
                            .frame(width: cardWidth)
                            .padding(.top, 6)
                            .padding(.bottom, 2)

                            PanelStyleSegment(
                                panelBrightness: Binding(
                                    get: { settings.panelBrightness },
                                    set: { settings.panelBrightness = min(40, max(-40, $0)) }
                                ),
                                textHue: Binding(
                                    get: { settings.textHue },
                                    set: { settings.textHue = normalizedTextHueValue($0) }
                                ),
                                textTone: Binding(
                                    get: { settings.textTone },
                                    set: { settings.textTone = min(100, max(0, $0)) }
                                ),
                                leatherStyle: Binding(
                                    get: { settings.leatherStyle },
                                    set: { settings.leatherStyle = $0 }
                                ),
                                dialStyle: settings.dialStyle,
                                dialTuning: settings.dialTuning,
                                isLocked: isAllLocked
                            )
                            .frame(width: cardWidth)
                            .padding(.bottom, 4)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .safeAreaPadding(.bottom, 28)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(settings)
                .preferredColorScheme(settingsSheetColorScheme)
        }
    }
}

// MARK: - ヘッダー

private struct HeaderBar: View {
    @Binding var showSettings: Bool

    var body: some View {
        ZStack {
            Text("app.title")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)

            HStack {
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.5), radius: 1)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.35))
    }
}

// MARK: - 合計金額パネル

private struct TotalAmountPanel: View {
    @Binding var totalRaw: Int
    let totalPersons: Int
    let dialUnit: Int
    let panelWidth: CGFloat
    @Binding var isPeopleLocked: Bool
    let isAllLocked: Bool
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var cs
    @State private var numpadConfig: NumpadConfig?

    private var amountColor: Color {
        linkedTextColor(hue: settings.textHue, tone: settings.textTone, for: cs)
    }

    private var secondaryTextColor: Color {
        amountColor.opacity(cs == .dark ? 0.66 : 0.72)
    }

    private let hPad: CGFloat = 16
    private let hGap: CGFloat = 8

    private var innerWidth: CGFloat {
        max(220, panelWidth - hPad * 2)
    }

    private var personsDialW: CGFloat {
        min(115, max(84, innerWidth * 0.32))
    }

    private var personsTextW: CGFloat {
        min(76, max(52, personsDialW * 0.66))
    }

    private var nameW: CGFloat {
        min(110, max(62, innerWidth * 0.26))
    }

    private var amountTextW: CGFloat {
        max(88, innerWidth - personsTextW - nameW - (hGap * 3 + 4))
    }

    private var totalDialW: CGFloat {
        let target = innerWidth * (2.0 / 3.0)
        let maxFittable = max(96, innerWidth - personsDialW)
        return min(max(96, target), maxFittable)
    }

    var body: some View {
        BrassFrame {
            VStack(spacing: 0) {
                // 情報行（ABCD同様: 人数 / 区分名 / 金額）
                HStack(alignment: .firstTextBaseline, spacing: hGap) {
                    Text(localizedPeople(totalPersons))
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .allowsTightening(true)
                        .frame(width: personsTextW, alignment: .trailing)

                    Text("split.total")
                        .font(.subheadline.bold())
                        .foregroundStyle(cs == .dark ? .white.opacity(0.62) : Color(.secondaryLabel))
                        .lineLimit(1)
                        .frame(width: nameW, alignment: .center)

                    Spacer(minLength: 4)

                    Text(localizedAmount(totalRaw))
                        .font(.largeTitle.bold().monospacedDigit())
                    .foregroundStyle(totalRaw == 0
                        ? secondaryTextColor.opacity(cs == .dark ? 0.75 : 0.70)
                        : amountColor)
                    .shadow(color: .black.opacity(cs == .dark ? 0.6 : 0.1), radius: 2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(width: amountTextW, alignment: .trailing)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !isAllLocked else { return }
                        numpadConfig = NumpadConfig(
                            title: String(localized: "split.totalAmount"),
                            initialValue: totalRaw,
                            maxValue: MoneyFormat.maxMinorValue,
                            minValue: 0,
                            isAmount: true,
                            onConfirm: { totalRaw = $0 }
                        )
                    }
                }
                .padding(.horizontal, hPad)
                .padding(.top, 16)
                .padding(.bottom, 4)

                LeatherDivider()

                // ダイアル行（人数ダイアルなし / 金額ダイアルのみ・サイズ維持）
                HStack(spacing: hGap) {
                    LockToggleButton(
                        isLocked: Binding(
                            get: { isPeopleLocked || isAllLocked },
                            set: { newValue in
                                guard !isAllLocked else { return }
                                isPeopleLocked = newValue
                            }
                        ),
                        lockedSystemImage: "lock.fill",
                        unlockedSystemImage: "lock.open",
                        accessibilityLabel: String(localized: "lock.people"),
                        size: 44,
                        symbolSize: 22
                    )
                    .frame(width: personsTextW, height: 44, alignment: .center)
                    .offset(x: 8)
                    .disabled(isAllLocked)
                    Color.clear
                        .frame(width: max(0, personsDialW - personsTextW), height: 1)
                    Spacer(minLength: 0)
                    AZDialView(
                        value: $totalRaw,
                        min: 0, max: MoneyFormat.maxMinorValue,
                        step: dialUnit, stepperStep: 0,
                        style: settings.dialStyle,
                        dialWidth: totalDialW,
                        tuning: settings.dialTuning
                    )
                    .frame(width: totalDialW)
                    .allowsHitTesting(!isAllLocked)
                    .opacity(isAllLocked ? 0.45 : 1)
                }
                .padding(.horizontal, hPad)
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .sheet(item: $numpadConfig) { NumpadView(config: $0) }
    }
}

// MARK: - ダイアル単位セグメント

private struct DialUnitSegment: View {
    @Binding var dialUnit: Int
    let units: [Int]
    let isLocked: Bool

    private var labels: [String] {
        units.map { MoneyFormat.localizedAmountValue($0) }
    }

    private var selectedIndex: Int {
        units.firstIndex(of: dialUnit) ?? (units.count - 1)
    }

    private var defaultUnit: Int {
        units.contains(MoneyFormat.defaultDialStep) ? MoneyFormat.defaultDialStep : (units.first ?? MoneyFormat.defaultDialStep)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("settings.amountDialStep")
                .font(.caption.bold())
                .foregroundStyle(.primary)

            HStack(spacing: 6) {
                ForEach(0..<labels.count, id: \.self) { i in
                    let isSelected = i == selectedIndex
                    Button {
                        guard !isLocked else { return }
                        dialUnit = units[i]
                    } label: {
                        Text(labels[i])
                            .font(.headline.bold().monospacedDigit())
                            .foregroundStyle(
                                isSelected
                                    ? Color(red: 1.0, green: 0.9647, blue: 0.8784)
                                    : .primary.opacity(0.82)
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                Group {
                                    if isSelected {
                                        Capsule()
                                            .fill(Color(red: 0.4196, green: 0.3059, blue: 0.1176))
                                    }
                                }
                            )
                            .overlay(
                                Group {
                                    if isSelected {
                                        Capsule()
                                            .stroke(.white.opacity(0.18), lineWidth: 1.2)
                                    }
                                }
                            )
                            .shadow(
                                color: isSelected ? .black.opacity(0.25) : .clear,
                                radius: isSelected ? 4 : 0,
                                x: 0,
                                y: isSelected ? 1 : 0
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isLocked)
                }
            }
            .padding(4)
            .background(
                Capsule()
                    .fill(.black.opacity(0.22))
            )
        }
        .onAppear {
            if !isLocked, !units.contains(dialUnit), let fallback = units.first(where: { $0 == defaultUnit }) ?? units.last {
                dialUnit = fallback
            }
        }
        .onChange(of: units) { _, newUnits in
            guard !isLocked, !newUnits.contains(dialUnit), let fallback = newUnits.first else { return }
            dialUnit = fallback
        }
        .opacity(isLocked ? 0.55 : 1)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                // ① ブラー層（背景を透かす）
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)

                // ② 上部スペキュラ（光が当たるハイライト）
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.30),
                                .white.opacity(0.06),
                                .clear,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // ③ ガラス縁（上が明るく・下が暗い）
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.75),
                                .white.opacity(0.20),
                                .black.opacity(0.15),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
        )
        // ④ 手前に浮かせるシャドウ（大＋小の2層）
        .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 7)
        .shadow(color: .black.opacity(0.12), radius:  3, x: 0, y: 1)
    }
}

// MARK: - パネルスタイル

private struct PanelStyleSegment: View {
    @Binding var panelBrightness: Int
    @Binding var textHue: Int
    @Binding var textTone: Int
    @Binding var leatherStyle: LeatherStyle
    let dialStyle: DialStyle
    let dialTuning: AZDialInteractionTuning
    let isLocked: Bool

    private var brightnessText: String {
        panelBrightness > 0 ? "+\(panelBrightness)" : "\(panelBrightness)"
    }

    private var textColorText: String {
        let value = normalizedTextHueValue(textHue)
        if value == -20 { return String(localized: "color.black") }
        if value == -10 { return String(localized: "color.white") }
        return "\(value)°"
    }

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("panel.style.title")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text("\(String(localized: "panel.brightness")) \(brightnessText)")
                            .font(.footnote.bold())
                            .foregroundStyle(.primary)
                            .frame(width: 130, alignment: .leading)

                        AZDialView(
                            value: $panelBrightness,
                            min: -40, max: 40,
                            step: 1, stepperStep: 0,
                            style: dialStyle,
                            dialWidth: 160,
                            tuning: dialTuning
                        )
                        .frame(maxWidth: .infinity)
                        .allowsHitTesting(!isLocked)
                        .opacity(isLocked ? 0.45 : 1)
                    }

                    TextColorPickerView(textHue: $textHue, textTone: $textTone, leatherStyle: $leatherStyle)
                        .allowsHitTesting(!isLocked)
                        .opacity(isLocked ? 0.45 : 1)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(0.24), lineWidth: 1)
            }
        )
        .clipped()
    }
}

// MARK: - 文字色ピッカー

private struct TextColorPickerView: View {
    @Binding var textHue: Int
    @Binding var textTone: Int
    @Binding var leatherStyle: LeatherStyle
    @Environment(\.colorScheme) private var cs

    private let hueStops: [Int] = [-20, -10, 0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330]
    private let toneStops: [Int] = [0, 20, 40, 60, 80, 100]

    private var selectedHue: Int { normalizedTextHueValue(textHue) }
    private var nearestTone: Int {
        toneStops.min(by: { abs($0 - textTone) < abs($1 - textTone) }) ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // 色（hue）
            Text(String(localized: "panel.textColor"))
                .font(.footnote.bold())
                .foregroundStyle(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(hueStops, id: \.self) { hue in
                        TextColorSwatch(
                            color: linkedTextColor(hue: hue, tone: max(50, textTone), for: cs),
                            isSelected: selectedHue == hue
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                textHue = hue
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }

            // 濃淡（tone）
            Text(String(localized: "panel.tone"))
                .font(.footnote.bold())
                .foregroundStyle(.primary)
                .padding(.top, 2)

            HStack(spacing: 0) {
                ForEach(toneStops, id: \.self) { tone in
                    TextColorSwatch(
                        color: linkedTextColor(hue: textHue, tone: tone, for: cs),
                        isSelected: nearestTone == tone
                    )
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            textTone = tone
                        }
                    }
                }
            }

            // 背景
            Text(String(localized: "settings.background.title"))
                .font(.footnote.bold())
                .foregroundStyle(.primary)
                .padding(.top, 2)

            Picker("settings.background.title", selection: $leatherStyle) {
                ForEach(LeatherStyle.allCases, id: \.self) { style in
                    Text(style.localizedName).tag(style)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

private struct TextColorSwatch: View {
    let color: Color
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 34, height: 34)
            .overlay(
                Circle()
                    .strokeBorder(
                        isSelected ? Color.white : Color.secondary.opacity(0.25),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )
            .overlay(
                Circle()
                    .strokeBorder(.black.opacity(isSelected ? 0.2 : 0), lineWidth: 1.5)
                    .padding(3)
            )
            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
            .scaleEffect(isSelected ? 1.14 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
    }
}
