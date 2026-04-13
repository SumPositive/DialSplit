//
//  SettingsView.swift
//  DialSplit
//

import SwiftUI
import AZDial

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    private let tiers: [(label: String, placeholder: String)] = [
        ("A", "大富豪"),
        ("B", "富豪"),
        ("C", "平民"),
        ("D", "貧民"),
    ]

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                // MARK: 区別名称
                Section("区別") {
                    ForEach(0..<tiers.count, id: \.self) { index in
                        HStack {
                            Text(tiers[index].label)
                                .font(.headline.bold())
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .center)
                            TextField(
                                tiers[index].placeholder,
                                text: Binding(
                                    get: { settings.name(for: index) },
                                    set: { settings.setName($0, for: index) }
                                )
                            )
                            .multilineTextAlignment(.trailing)
                        }
                    }
                }

                // MARK: ダイアルスタイル
                Section("ダイアルスタイル") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(DialStyle.allBuiltin, id: \.id) { style in
                                DialStyleCell(
                                    style: style,
                                    isSelected: style.id == settings.dialStyle.id
                                )
                                .onTapGesture { settings.dialStyle = style }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 2)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                }

                // MARK: レザーデザイン
                Section("レザー") {
                    Picker("デザイン", selection: $settings.leatherStyle) {
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

// MARK: - ダイアルスタイル選択セル

private struct DialStyleCell: View {
    let style: DialStyle
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            AZDialSurface(offset: 0, tickGap: 10, style: style)
                .frame(width: 64, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                            lineWidth: isSelected ? 2.5 : 1
                        )
                )
                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)

            Text(style.label)
                .font(.caption2)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
        }
        .frame(width: 64)
        .contentShape(Rectangle())
    }
}
