//
//  SplitView.swift
//  DialSplit
//

import SwiftUI
import AZDial

struct SplitView: View {
    @Environment(AppSettings.self) private var settings
    @State private var vm = SplitViewModel()
    @State private var showSettings = false

    var body: some View {
        @Bindable var vm = vm

        ZStack {
            LeatherBackground()

            VStack(spacing: 0) {
                HeaderBar(showSettings: $showSettings)

                ScrollView {
                    VStack(spacing: 10) {
                        // 合計金額パネル
                        TotalAmountPanel(totalRaw: $vm.totalRaw)
                            .padding(.horizontal, 16)
                            .padding(.top, 14)

                        LeatherDivider()
                            .padding(.horizontal, 24)

                        // A（大富豪）パネル — 自動計算
                        Panel0View(
                            name:     settings.name(for: 0),
                            persons0: $vm.persons0,
                            split0:   vm.split0,
                            status:   vm.split0Status,
                            totalRaw: vm.totalRaw
                        )
                        .padding(.horizontal, 16)

                        // B（富豪）パネル
                        PanelSubView(
                            name:     settings.name(for: 1),
                            persons:  $vm.persons1,
                            split:    $vm.split1,
                            dialUnit: vm.dialUnit
                        )
                        .padding(.horizontal, 16)

                        // C（平民）パネル
                        PanelSubView(
                            name:     settings.name(for: 2),
                            persons:  $vm.persons2,
                            split:    $vm.split2,
                            dialUnit: vm.dialUnit
                        )
                        .padding(.horizontal, 16)

                        // D（貧民）パネル
                        PanelSubView(
                            name:     settings.name(for: 3),
                            persons:  $vm.persons3,
                            split:    $vm.split3,
                            dialUnit: vm.dialUnit
                        )
                        .padding(.horizontal, 16)

                        // ダイアル単位セグメント
                        DialUnitSegment(selectedIndex: $vm.dialUnitIndex)
                            .padding(.horizontal, 24)
                            .padding(.top, 6)

                        // サマリー
                        SummaryRow(
                            totalPersons: vm.totalPersons,
                            totalRaw:     vm.totalRaw
                        )
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
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
        HStack {
            Text("DialSplit")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)

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
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.35))
    }
}

// MARK: - 合計金額パネル

private struct TotalAmountPanel: View {
    @Binding var totalRaw: Int
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var cs
    @State private var numpadConfig: NumpadConfig?

    private var amountColor: Color {
        cs == .dark ? .yellow.opacity(0.95) : Color(red: 0.50, green: 0.35, blue: 0.00)
    }

    var body: some View {
        BrassFrame {
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("合計金額")
                        .font(.caption.bold())
                        .foregroundStyle(cs == .dark ? .white.opacity(0.70) : Color(.secondaryLabel))
                    Text(totalRaw == 0 ? "¥ ---" : "¥ \(totalRaw.formatted())")
                        .font(.largeTitle.bold().monospacedDigit())
                        .foregroundStyle(totalRaw == 0 ? (cs == .dark ? .white.opacity(0.40) : Color(.tertiaryLabel)) : amountColor)
                        .shadow(color: .black.opacity(cs == .dark ? 0.6 : 0.1), radius: 2)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            numpadConfig = NumpadConfig(
                                title: "合計金額",
                                initialValue: totalRaw,
                                maxValue: 999_900,
                                minValue: 0,
                                step: 100,
                                isAmount: true,
                                onConfirm: { totalRaw = $0 }
                            )
                        }
                }
                .frame(maxWidth: .infinity)

                AZDialView(
                    value: $totalRaw,
                    min: 0, max: 999_900,
                    step: 100, stepperStep: 0,
                    style: settings.dialStyle, dialWidth: 180
                )
            }
            .padding(14)
        }
        .sheet(item: $numpadConfig) { NumpadView(config: $0) }
    }
}

// MARK: - ダイアル単位セグメント

private struct DialUnitSegment: View {
    @Binding var selectedIndex: Int
    private let labels = ["¥100", "¥500", "¥1,000"]

    var body: some View {
        VStack(spacing: 5) {
            Text("金額ダイアル 単位")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))

            Picker("単位", selection: $selectedIndex) {
                ForEach(0..<labels.count, id: \.self) { i in
                    Text(labels[i]).tag(i)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

// MARK: - サマリー行

private struct SummaryRow: View {
    let totalPersons: Int
    let totalRaw: Int

    var body: some View {
        HStack {
            Text("合計 \(totalPersons)人")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(totalRaw == 0 ? "---" : "¥ \(totalRaw.formatted())")
                .font(.callout.bold().monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
