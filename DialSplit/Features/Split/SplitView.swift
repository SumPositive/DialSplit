import SwiftUI
import AZDecimal
import AZDial

struct SplitView: View {
    @Environment(AppSettings.self) private var settings
    @State private var viewModel: SplitViewModel?
    @State private var totalRaw: Int = 0   // stored as integer (JPY)
    @State private var showSettings = false

    private var totalAmount: AZDecimal { AZDecimal("\(totalRaw)") }

    var body: some View {
        ZStack {
            LeatherBackground()

            VStack(spacing: 0) {
                HeaderBar(showSettings: $showSettings)

                ScrollView {
                    VStack(spacing: 12) {
                        // Total amount panel
                        TotalAmountPanel(totalRaw: $totalRaw)
                            .padding(.horizontal, 16)
                            .padding(.top, 14)

                        LeatherDivider()
                            .padding(.horizontal, 24)

                        // Split panels
                        if let vm = viewModel {
                            let perPerson = vm.perPerson(totalAmount: totalAmount)
                            ForEach(0..<settings.panelCount, id: \.self) { index in
                                PanelView(
                                    index: index,
                                    persons: Binding(
                                        get: { index < vm.persons.count ? vm.persons[index] : 1 },
                                        set: { if index < vm.persons.count { vm.persons[index] = $0 } }
                                    ),
                                    perPerson: perPerson
                                )
                                .padding(.horizontal, 16)
                            }

                            // Summary row
                            SummaryRow(
                                totalAmount: totalAmount,
                                totalPersons: vm.persons.prefix(settings.panelCount).reduce(0, +)
                            )
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(settings)
        }
        .onAppear {
            if viewModel == nil {
                viewModel = SplitViewModel(settings: settings)
            }
            viewModel?.syncCount()
        }
        .onChange(of: settings.panelCount) { _, _ in
            viewModel?.syncCount()
        }
    }
}

// MARK: - Header

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

// MARK: - Total Amount Panel

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
                }
                .frame(maxWidth: .infinity)

                AZDialView(
                    value: $totalRaw,
                    min: 0,
                    max: 999900,
                    step: 100,
                    stepperStep: 100,
                    style: .brass,
                    dialWidth: 180
                )
            }
            .padding(14)
        }
    }
}

// MARK: - Summary Row

private struct SummaryRow: View {
    let totalAmount: AZDecimal
    let totalPersons: Int

    var body: some View {
        HStack {
            Text("合計 \(totalPersons)人")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(totalAmount.isZero ? "---" : totalAmount.formatted())
                .font(.callout.bold().monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
