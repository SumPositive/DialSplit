import SwiftUI
import AZDecimal

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("パネル数") {
                    Stepper("\(settings.panelCount) パネル", value: $settings.panelCount, in: 1...3)
                }

                Section("パネル名") {
                    ForEach(0..<settings.panelCount, id: \.self) { index in
                        HStack {
                            Text("パネル \(index + 1)")
                                .foregroundStyle(.secondary)
                            TextField(
                                "名前",
                                text: Binding(
                                    get: { settings.name(for: index) },
                                    set: { settings.setName($0, for: index) }
                                )
                            )
                            .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section("丸め") {
                    Picker("丸めモード", selection: $settings.roundType) {
                        Text("四捨五入").tag(AZDecimalConfig.RoundType.r54)
                        Text("切り捨て").tag(AZDecimalConfig.RoundType.truncate)
                        Text("切り上げ").tag(AZDecimalConfig.RoundType.rup)
                        Text("銀行丸め").tag(AZDecimalConfig.RoundType.r55)
                    }
                    .pickerStyle(.menu)
                }

                Section("デザイン") {
                    Picker("レザー", selection: $settings.leatherStyle) {
                        ForEach(LeatherStyle.allCases, id: \.self) { style in
                            Text(style.localizedName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}
