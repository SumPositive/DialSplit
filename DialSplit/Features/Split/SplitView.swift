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
    /// 新しい iOS でのみ利用可能なシンボルの旧 iOS 用フォールバック
    var lockedFallbackImage: String? = nil
    var unlockedFallbackImage: String? = nil
    let accessibilityLabel: String
    var size: CGFloat = 36
    var symbolSize: CGFloat = 18
    var onToggle: ((Bool) -> Void)? = nil

    private var resolvedSymbol: String {
        if isLocked {
            return lockedFallbackImage.map { SFSymbol.resolve(lockedSystemImage, fallback: $0) } ?? lockedSystemImage
        } else {
            return unlockedFallbackImage.map { SFSymbol.resolve(unlockedSystemImage, fallback: $0) } ?? unlockedSystemImage
        }
    }

    var body: some View {
        Button {
            isLocked.toggle()
            onToggle?(isLocked)
        } label: {
            Image(systemName: resolvedSymbol)
                .font(.system(size: symbolSize, weight: .bold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(isLocked
                    ? Color(red: 0.95, green: 0.45, blue: 0.05)
                    : Color.secondary.opacity(0.78))
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
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var vm = SplitViewModel()
    @State private var showSettings = false
    @State private var showPanelStyle = false
    @State private var isPeopleLocked = false
    @State private var isAllLocked = false
    private let cardSideMargin: CGFloat = 16
    // iPhoneでは iPhone Pro Max 相当(430)を上限に中央カラム表示。
    // iPad(regular幅)は少しだけ広げる程度に留め(横に伸ばしすぎると中身がスカスカ)、
    // 間延びは縦中央寄せ側で解消する。
    private var maxContentWidth: CGFloat {
        hSizeClass == .regular ? 520 : 430
    }

    private var settingsSheetColorScheme: ColorScheme? {
        settings.appearanceMode.colorScheme ?? colorScheme
    }

    var body: some View {
        @Bindable var vm = vm

        ZStack {
            LeatherBackground()

            VStack(spacing: 0) {
                // 広告帯は画面最上部（ヘッダーの上）に置き、アプリの操作面と分ける
                HeaderBannerView()

                // タイトル行はスクロール領域の外に置く。
                // 重ねて浮かせるとパネルが下を通って透けるため、場所を分けて解決する
                HeaderBar(showSettings: $showSettings, showPanelStyle: $showPanelStyle)

                GeometryReader { proxy in
                    let cardWidth = min(max(0, proxy.size.width - cardSideMargin * 2), maxContentWidth)
                    let totalPanelWidth = min(cardWidth + 20, max(0, proxy.size.width - 4))
                    let panelAWidth = min(cardWidth + 6, max(0, proxy.size.width - 12))
                    ScrollView(.vertical, showsIndicators: false) {
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
                            .shadow(color: .black.opacity(0.40), radius: 24, x: 0, y: 14)
                            .shadow(color: .black.opacity(0.18), radius: 7, x: 0, y: 3)

                            // A（大富豪）パネル — 金額は自動計算の表示専用
                            Panel0View(
                                name:     settings.name(for: 0),
                                persons0: $vm.persons0,
                                split0:   vm.split0,
                                split0RealMinor: vm.split0RealMinor,
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
                                isLocked: isAllLocked,
                                onUpdateStep: { index, newValue in
                                    let oldValue = settings.amountDialSteps[index]
                                    settings.setAmountDialStep(newValue, at: index)
                                    Telemetry.event(.stepEdited(index: index, oldValue: oldValue, newValue: newValue))
                                }
                            )
                            .frame(width: cardWidth)
                            .padding(.top, 6)
                            .padding(.bottom, 2)
                        }
                        .frame(maxWidth: .infinity)
                        // タイトル行と最初のパネル（影が大きい）が接しないよう間を空ける
                        .padding(.top, 6)
                    }
                    .safeAreaPadding(.bottom, 28)
                }
                .animation(.easeInOut(duration: 0.25), value: isAllLocked)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(settings)
                .preferredColorScheme(settingsSheetColorScheme)
        }
        .sheet(isPresented: $showPanelStyle) {
            PanelStyleSheet(
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
                dialTuning: settings.dialTuning
            )
            .environment(settings)
            .preferredColorScheme(settingsSheetColorScheme)
            .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - ヘッダー

private struct HeaderBar: View {
    @Binding var showSettings: Bool
    @Binding var showPanelStyle: Bool

    /// タイトル行の固定高さ。文字サイズ設定によらず一定に保ち、
    /// ダイヤル面の位置が設定で動かないようにする。
    /// 44pt は歯車ボタンの推奨タップ領域と同じ寸法でもある
    private static let barHeight: CGFloat = 44

    /// 44pt のタップ枠に .title3（約22pt）の記号を中央置きしたときの片側余白。
    /// この分を負の余白で戻し、アイコンの右端を画面端から20ptに保つ
    private static let iconInset: CGFloat = 11

    var body: some View {
        ZStack {
            Text("app.title")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.55))
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                // タイトルは文字サイズ設定に追従させず、常に標準サイズで表示する
                .dynamicTypeSize(.large)
                // 言語によっては標準サイズでも収まらないため、行を増やさず縮めて収める
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                // 左右のアイコンに被らない幅に収める（両側のタップ枠ぶんを空ける）
                .padding(.horizontal, Self.barHeight - Self.iconInset)

            HStack {
                Button {
                    showPanelStyle = true
                } label: {
                    headerIcon("paintpalette.fill")
                }
                .buttonStyle(.plain)
                // タップ枠を広げた分だけアイコンが内側へ寄るため、その差を戻して
                // 見た目の左端位置を歯車の右端と揃える
                .padding(.leading, -Self.iconInset)
                .accessibilityLabel(Text("panel.style.title"))
                .accessibilityIdentifier("openPanelStyleButton")

                Spacer()

                Button {
                    Telemetry.event(.settingsOpened)
                    showSettings = true
                } label: {
                    headerIcon("gearshape.fill")
                }
                .buttonStyle(.plain)
                // タップ枠を広げた分だけアイコンが内側へ寄るため、その差を戻して
                // 見た目の右端位置を従来どおりに保つ
                .padding(.trailing, -Self.iconInset)
                .accessibilityIdentifier("openSettingsButton")
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .frame(height: Self.barHeight)
        // スクロール領域の外にあるためパネルは下を通らない。
        // 地を敷かずレザー背景をそのまま見せ、帯が乗ったようには見せない
        .contentShape(Rectangle())
    }

    /// ヘッダー左右のアイコン。左右で見た目とタップ領域を揃える
    private func headerIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.title3)
            // タイトルと同じく、文字サイズ設定で記号が大きくならないようにする。
            // 44pt の枠からはみ出させないための固定でもある
            .dynamicTypeSize(.large)
            .foregroundStyle(.white.opacity(0.85))
            .shadow(color: .black.opacity(0.5), radius: 1)
            // アイコンだけだとタップ領域が狭いため、行の高さいっぱいまで広げる
            .frame(width: Self.barHeight, height: Self.barHeight)
            .contentShape(Rectangle())
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
                        lockedSystemImage: "figure.child.and.lock.fill",
                        unlockedSystemImage: "figure.child.and.lock.open.fill",
                        accessibilityLabel: String(localized: "lock.people"),
                        size: 44,
                        symbolSize: 28,
                        onToggle: { locked in
                            Telemetry.event(.peopleLockToggled(locked: locked))
                        }
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
                        step: dialUnit,
                        stepperStep: settings.showDialStepper ? dialUnit : 0,
                        stepperPosition: .bottom,
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
    let onUpdateStep: (Int, Int) -> Void

    @State private var openIndex: Int? = nil
    @State private var anchorFrames: [Int: CGRect] = [:]

    private var defaultUnit: Int {
        units.contains(MoneyFormat.defaultDialStep) ? MoneyFormat.defaultDialStep : (units.first ?? MoneyFormat.defaultDialStep)
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<units.count, id: \.self) { index in
                stepButton(at: index)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.black.opacity(0.22))
        )
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .allowsHitTesting(!isLocked)
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
        .padding(.vertical, 10)
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

    @ViewBuilder
    private func stepButton(at index: Int) -> some View {
        let value = units[index]
        let isSelected = dialUnit == value
        let selectedBg = Color(red: 0.4196, green: 0.3059, blue: 0.1176)
        let selectedFg = Color(red: 1.0, green: 0.9647, blue: 0.8784)
        let selectedBorder = Color.white.opacity(0.18)
        let unselectedFg = Color.primary.opacity(0.82)

        Text(MoneyFormat.localizedAmountValue(value))
            .font(.subheadline.monospacedDigit())
            .fontWeight(.bold)
            .foregroundStyle(isSelected ? selectedFg : unselectedFg)
            .lineLimit(1)
            .minimumScaleFactor(0.50)
            .allowsTightening(true)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? selectedBg : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? selectedBorder : Color.clear, lineWidth: 1.25)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isLocked else { return }
                dialUnit = value
                Telemetry.event(.stepSelected(value: value))
            }
            .onLongPressGesture(minimumDuration: 0.4) {
                guard !isLocked else { return }
                openIndex = index
                Telemetry.event(.stepLongPressed(index: index))
            }
            .azDropdownPopover(
                isPresented: Binding(
                    get: { openIndex == index },
                    set: { newValue in if !newValue { openIndex = nil } }
                ),
                anchorFrame: Binding(
                    get: { anchorFrames[index] ?? .zero },
                    set: { anchorFrames[index] = $0 }
                )
            ) {
                stepEditPopover(at: index)
            }
    }

    @ViewBuilder
    private func stepEditPopover(at index: Int) -> some View {
        let currentValue = units[index]
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(MoneyFormat.dialStepDefinitionOptions, id: \.self) { opt in
                        Button {
                            onUpdateStep(index, opt)
                            openIndex = nil
                        } label: {
                            AZDropdownOptionButton(
                                isSelected: opt == currentValue,
                                minWidth: 140
                            ) {
                                Text(MoneyFormat.localizedAmount(opt))
                            }
                        }
                        .buttonStyle(.plain)
                        .id(opt)
                    }
                }
                .padding(8)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 320)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        proxy.scrollTo(currentValue, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - パネルスタイル

private struct PanelStyleSheet: View {
    @Binding var panelBrightness: Int
    @Binding var textHue: Int
    @Binding var textTone: Int
    @Binding var leatherStyle: LeatherStyle
    let dialStyle: DialStyle
    let dialTuning: AZDialInteractionTuning
    @Environment(\.dismiss) private var dismiss

    private var brightnessText: String {
        panelBrightness > 0 ? "+\(panelBrightness)" : "\(panelBrightness)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
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
                }

                TextColorPickerView(textHue: $textHue, textTone: $textTone, leatherStyle: $leatherStyle)

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("panel.style.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    SheetCloseButton { dismiss() }
                }
            }
        }
    }
}

// MARK: - 文字色ピッカー

private struct TextColorPickerView: View {
    @Binding var textHue: Int
    @Binding var textTone: Int
    @Binding var leatherStyle: LeatherStyle
    @Environment(\.colorScheme) private var cs
    @State private var isLeatherStyleExpanded = false

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

            // 設定画面と揃えて、背景もブラス調のドロップダウンPickerで選ぶ
            AZDropdownPicker(
                options: LeatherStyle.allCases,
                selection: $leatherStyle,
                isExpanded: $isLeatherStyleExpanded,
                minWidth: 0,
                fillsWidth: true,
                style: .brassDropdown
            ) { style in
                Text(style.localizedName)
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .zIndex(isLeatherStyleExpanded ? 60 : 0)
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

// MARK: - ブラス調 AZPickerStyle

extension AZPickerStyle {
    /// 真鍮×ブラウンの旧デザインに寄せたピッカースタイル
    static var brass: AZPickerStyle {
        var s = AZPickerStyle()
        s.cornerRadius = 14
        s.panelBackground = .black.opacity(0.22)
        s.optionBackground = .clear
        s.selectedBackgroundColor = brassSelectedBackground
        s.selectedForegroundColor = brassSelectedForeground
        s.selectedBorderColor = .white.opacity(0.18)
        s.unselectedForegroundColor = .primary.opacity(0.82)
        s.unselectedBorderColor = .clear
        s.panelBorderOpacity = 0
        s.shadowOpacity = 0
        s.optionFont = .subheadline.monospacedDigit()
        s.optionWeight = .bold
        return s
    }

    /// ブラス調のままドロップダウンで使えるようにしたピッカースタイル
    static var brassDropdown: AZPickerStyle {
        var s = AZPickerStyle.brass
        // 折りたたみボタンをラジオの選択中と同じ「濃い茶の塗り×クリーム色の字」にして、
        // 半透明の黒に暗い茶字が乗って読めなくなるのを避ける
        s.panelBackground = brassSelectedBackground
        s.dropdownSelectedValueColor = brassSelectedForeground
        // 候補一覧の背景に使われるため、透明のままでは下が透けてしまう
        s.optionBackground = Color(.secondarySystemGroupedBackground)
        // 候補一覧は標準背景なので、未選択の枠線と文字色も標準へ戻して読みやすくする
        s.unselectedBorderColor = nil
        s.unselectedForegroundColor = nil
        s.dropdownOptionAlignment = .center
        s.dropdownOptionStackAlignment = .center
        s.dropdownOptionTextAlignment = .center
        return s
    }

    /// 真鍮調の選択中の塗り
    private static let brassSelectedBackground = Color(red: 0.4196, green: 0.3059, blue: 0.1176)
    /// 真鍮調の選択中の文字色
    private static let brassSelectedForeground = Color(red: 1.0, green: 0.9647, blue: 0.8784)
}
