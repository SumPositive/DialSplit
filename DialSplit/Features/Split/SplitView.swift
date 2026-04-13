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

                        // 大富豪パネル（自動計算・切上表示）
                        Panel0View(
                            name:     settings.name(for: 0),
                            persons0: $vm.persons0,
                            split0:   vm.split0,
                            status:   vm.split0Status,
                            totalRaw: vm.totalRaw
                        )
                        .padding(.horizontal, 16)

                        // 富豪パネル
                        PanelSubView(
                            name:     settings.name(for: 1),
                            persons:  $vm.persons1,
                            split:    $vm.split1,
                            dialUnit: vm.dialUnit
                        )
                        .padding(.horizontal, 16)

                        // 平民パネル
                        PanelSubView(
                            name:     settings.name(for: 2),
                            persons:  $vm.persons2,
                            split:    $vm.split2,
                            dialUnit: vm.dialUnit
                        )
                        .padding(.horizontal, 16)

                        // ダイアル単位セグメント（富豪/平民の金額ダイアルのstepを切り替え）
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

    var body: some View {
        BrassFrame {
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("合計金額")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.7))
                    Text(totalRaw == 0 ? "¥ ---" : "¥ \(totalRaw.formatted())")
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(.yellow.opacity(0.95))
                        .shadow(color: .black.opacity(0.6), radius: 2)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                AZDialView(
                    value: $totalRaw,
                    min: 0, max: 999_900,
                    step: 100, stepperStep: 100,
                    style: .brass, dialWidth: 180
                )
            }
            .padding(14)
        }
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
