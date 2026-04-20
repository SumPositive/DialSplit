//
//  SplitView.swift
//  DialSplit
//

import SwiftUI
import AZDial

private func isEnglishUI() -> Bool {
    Locale.preferredLanguages.first?.hasPrefix("en") == true
}

private func localizedPeople(_ count: Int) -> String {
    let format = NSLocalizedString("%lld人短", comment: "")
    return String(format: format, locale: Locale.current, count)
}

private func localizedAmount(_ value: Int, placeholder: String = "---", spaced: Bool = false) -> String {
    if value == 0 {
        return isEnglishUI() ? (spaced ? "$ \(placeholder)" : "$\(placeholder)") : "¥ \(placeholder)"
    }
    if isEnglishUI() {
        return spaced ? "$ \(value.formatted())" : "$\(value.formatted())"
    }
    return spaced ? "¥ \(value.formatted())" : "¥\(value.formatted())"
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
        .accessibilityValue(isLocked ? String(localized: "ロック中") : String(localized: "アンロック中"))
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
                            DialUnitSegment(dialUnit: $vm.dialUnit, isLocked: isAllLocked)
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
            Text("割勘")
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

    private var showsCentSuffix: Bool {
        isEnglishUI() && totalRaw > 0
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

                    Text("合計")
                        .font(.subheadline.bold())
                        .foregroundStyle(cs == .dark ? .white.opacity(0.62) : Color(.secondaryLabel))
                        .lineLimit(1)
                        .frame(width: nameW, alignment: .center)

                    Spacer(minLength: 4)

                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(localizedAmount(totalRaw, spaced: true))
                            .font(.largeTitle.bold().monospacedDigit())
                        if showsCentSuffix {
                            Text(".00")
                                .font(.title3.bold().monospacedDigit())
                        }
                    }
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
                            title: String(localized: "合計金額"),
                            initialValue: totalRaw,
                            maxValue: 999_900,
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
                        accessibilityLabel: String(localized: "人数ロック"),
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
                        min: 0, max: 999_900,
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
    let isLocked: Bool

    private var units: [Int] {
        isEnglishUI() ? [1, 5, 10, 50, 100] : [1, 10, 100, 500, 1_000]
    }

    private var labels: [String] {
        isEnglishUI() ? ["$1", "$5", "$10", "$50", "$100"] : ["¥1", "¥10", "¥100", "¥500", "¥1,000"]
    }

    private var selectedIndex: Int {
        units.firstIndex(of: dialUnit) ?? (units.count - 1)
    }

    private var defaultUnit: Int {
        isEnglishUI() ? 5 : 500
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("金額ダイアルステップ")
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
                            .font(.subheadline.bold().monospacedDigit())
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
    let dialStyle: DialStyle
    let dialTuning: AZDialInteractionTuning
    let isLocked: Bool

    private var brightnessText: String {
        panelBrightness > 0 ? "+\(panelBrightness)" : "\(panelBrightness)"
    }

    private var textColorText: String {
        let value = normalizedTextHueValue(textHue)
        if value == -20 { return String(localized: "黒") }
        if value == -10 { return String(localized: "白") }
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
                    Text("パネルスタイル")
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
                        Text("\(String(localized: "パネルの明るさ")) \(brightnessText)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
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

                    HStack(spacing: 8) {
                        Text("\(String(localized: "文字の色")) \(textColorText)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 130, alignment: .leading)

                        AZDialView(
                            value: $textHue,
                            min: -20, max: 360,
                            step: 10, stepperStep: 0,
                            style: dialStyle,
                            dialWidth: 160,
                            tuning: dialTuning
                        )
                        .frame(maxWidth: .infinity)
                        .allowsHitTesting(!isLocked)
                        .opacity(isLocked ? 0.45 : 1)
                    }

                    HStack(spacing: 8) {
                        Text("\(String(localized: "濃淡")) \(textTone)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 130, alignment: .leading)

                        AZDialView(
                            value: $textTone,
                            min: 0, max: 100,
                            step: 5, stepperStep: 0,
                            style: dialStyle,
                            dialWidth: 160,
                            tuning: dialTuning
                        )
                        .frame(maxWidth: .infinity)
                        .allowsHitTesting(!isLocked)
                        .opacity(isLocked ? 0.45 : 1)
                    }
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
