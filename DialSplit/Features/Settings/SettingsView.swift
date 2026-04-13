//
//  SettingsView.swift
//  DialSplit
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    private let panelLabels = ["大富豪", "富豪", "平民"]

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("名前") {
                    ForEach(0..<3, id: \.self) { index in
                        HStack {
                            Text(panelLabels[index])
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)
                            TextField(
                                panelLabels[index],
                                text: Binding(
                                    get: { settings.name(for: index) },
                                    set: { settings.setName($0, for: index) }
                                )
                            )
                            .multilineTextAlignment(.trailing)
                        }
                    }
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
