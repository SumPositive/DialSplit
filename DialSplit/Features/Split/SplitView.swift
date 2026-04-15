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

struct SplitView: View {
    @Environment(AppSettings.self) private var settings
    @State private var vm = SplitViewModel()
    @State private var showSettings = false
    private let cardSideMargin: CGFloat = 16
    // iPadでは、iPhone Pro Max相当の幅を上限にして中央カラム表示
    private let maxContentWidth: CGFloat = 430

    var body: some View {
        @Bindable var vm = vm

        ZStack {
            LeatherBackground()

            VStack(spacing: 0) {
                HeaderBar(showSettings: $showSettings)

                GeometryReader { proxy in
                    let cardWidth = min(max(0, proxy.size.width - cardSideMargin * 2), maxContentWidth)
                    ScrollView {
                        VStack(spacing: 10) {
                            // 合計金額パネル
                            TotalAmountPanel(totalRaw: $vm.totalRaw, totalPersons: vm.totalPersons, dialUnit: vm.dialUnit)
                                .frame(width: cardWidth)
                                .padding(.top, 14)

                            LeatherDivider()
                                .frame(width: cardWidth)

                            // A（大富豪）パネル — 金額は自動計算の表示専用
                            Panel0View(
                                name:     settings.name(for: 0),
                                persons0: $vm.persons0,
                                split0:   vm.split0,
                                status:   vm.split0Status,
                                totalRaw: vm.totalRaw,
                                panelWidth: cardWidth
                            )
                            .frame(width: cardWidth)
                            .padding(.bottom, 20)

                            // B（富豪）パネル
                            PanelSubView(
                                name:     settings.name(for: 1),
                                persons:  $vm.persons1,
                                split:    $vm.split1,
                                dialUnit: vm.dialUnit,
                                panelWidth: cardWidth
                            )
                            .frame(width: cardWidth)

                            // C（平民）パネル
                            PanelSubView(
                                name:     settings.name(for: 2),
                                persons:  $vm.persons2,
                                split:    $vm.split2,
                                dialUnit: vm.dialUnit,
                                panelWidth: cardWidth
                            )
                            .frame(width: cardWidth)

                            // D（貧民）パネル
                            PanelSubView(
                                name:     settings.name(for: 3),
                                persons:  $vm.persons3,
                                split:    $vm.split3,
                                dialUnit: vm.dialUnit,
                                panelWidth: cardWidth
                            )
                            .frame(width: cardWidth)

                            // ダイアル単位セグメント（通常フロー末尾）
                            DialUnitSegment(dialUnit: $vm.dialUnit)
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
                                dialStyle: settings.dialStyle
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

    var body: some View {
        BrassFrame {
            HStack(alignment: .center, spacing: 16) {
                // 左: タイトル行 + 金額行
                VStack(alignment: .leading, spacing: 4) {
                    // 1行目: 「合計」＋人数
                    HStack(spacing: 6) {
                        Text("合計")
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                        Text(localizedPeople(totalPersons))
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(secondaryTextColor)
                    }
                    // 2行目: 大きな金額（タップでテンキー）
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
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture {
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
                .frame(maxWidth: .infinity, alignment: .leading)

                // 右: ダイアル（縦センター）
                AZDialView(
                    value: $totalRaw,
                    min: 0, max: 999_900,
                    step: dialUnit, stepperStep: 0,
                    style: settings.dialStyle, dialWidth: 180
                )
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity)
        .sheet(item: $numpadConfig) { NumpadView(config: $0) }
    }
}

// MARK: - ダイアル単位セグメント

private struct DialUnitSegment: View {
    @Binding var dialUnit: Int

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
                        dialUnit = units[i]
                    } label: {
                        Text(labels[i])
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(isSelected ? .primary : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isSelected ? .white.opacity(0.90) : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                Capsule()
                    .fill(.black.opacity(0.11))
            )
        }
        .onAppear {
            if !units.contains(dialUnit), let fallback = units.first(where: { $0 == defaultUnit }) ?? units.last {
                dialUnit = fallback
            }
        }
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

    private var brightnessText: String {
        panelBrightness > 0 ? "+\(panelBrightness)" : "\(panelBrightness)"
    }

    private var textColorText: String {
        let value = normalizedTextHueValue(textHue)
        if value == -20 { return "黒" }
        if value == -10 { return "白" }
        return "\(value)°"
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("パネルスタイル")
                .font(.caption.bold())
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                Text("パネルの明るさ \(brightnessText)")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 130, alignment: .leading)

                AZDialView(
                    value: $panelBrightness,
                    min: -40, max: 40,
                    step: 1, stepperStep: 0,
                    style: dialStyle,
                    dialWidth: 160
                )
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 8) {
                Text("文字の色 \(textColorText)")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 130, alignment: .leading)

                AZDialView(
                    value: $textHue,
                    min: -20, max: 360,
                    step: 10, stepperStep: 0,
                    style: dialStyle,
                    dialWidth: 160
                )
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 8) {
                Text("濃淡 \(textTone)")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 130, alignment: .leading)

                AZDialView(
                    value: $textTone,
                    min: 0, max: 100,
                    step: 5, stepperStep: 0,
                    style: dialStyle,
                    dialWidth: 160
                )
                .frame(maxWidth: .infinity)
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
    }
}
