//
//  SettingsView.swift
//  DialSplit
//

import SwiftUI
import AZDial
import StoreKit
import Observation
import UIKit

#if canImport(GoogleMobileAds)
@preconcurrency import GoogleMobileAds
#endif

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showAbout = false
    @State private var showSupportSheet = false

    private let aboutURLJa = URL(string: "https://docs.azukid.com/jp/sumpo/DialSplit/dialsplit.html")

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v).\(b)"
    }

    private let tiers: [(label: String, placeholderKey: String)] = [
        ("A", "大富豪"),
        ("B", "富豪"),
        ("C", "平民"),
        ("D", "貧民"),
    ]

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                // MARK: プリセット
                Section("プリセット") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(NamePreset.all) { preset in
                                PresetChip(
                                    preset: preset,
                                    isSelected: settings.panelNames == preset.names
                                )
                                .onTapGesture { settings.panelNames = preset.names }
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 2)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                }

                // MARK: 区別名称
                Section("区別") {
                    ForEach(0..<tiers.count, id: \.self) { index in
                        HStack {
                            Text(tiers[index].label)
                                .font(.headline.bold())
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .center)
                            TextField(
                                NSLocalizedString(tiers[index].placeholderKey, comment: ""),
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

                // MARK: 背景デザイン
                Section("背景") {
                    Picker("デザイン", selection: $settings.leatherStyle) {
                        ForEach(LeatherStyle.allCases, id: \.self) { style in
                            Text(style.localizedName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: サポート
                Section("サポート") {
                    Button(String(localized: "このアプリについて")) {
                        showAbout = true
                    }
                    Button(String(localized: "開発者を応援")) {
                        showSupportSheet = true
                    }
                }

                // MARK: バージョン（最下部）
                Section {
                    HStack {
                        Spacer()
                        Text(versionString)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .alert(String(localized: "このアプリについて"), isPresented: $showAbout) {
                Button(String(localized: "開く")) {
                    if let url = aboutURLJa {
                        openURL(url)
                    }
                }
                Button(String(localized: "閉じる"), role: .cancel) {}
            } message: {
                Text("DialSplit v\(versionString)")
            }
            .sheet(isPresented: $showSupportSheet) {
                SupportDeveloperSheet()
            }
        }
    }
}

// MARK: - 開発者応援（StoreKit / AdMob）

@Observable
@MainActor
private final class TipStore {
    static let shared = TipStore()

    private let productIds = ["Tips_1", "Tips_5"]
    var products: [Product] = []
    var isLoadingProducts = false
    var isPurchasing = false

    private init() {}

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        let loaded = (try? await Product.products(for: productIds)) ?? []
        products = loaded.sorted { $0.price < $1.price }
    }

    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            if case .success(let verification) = result,
               case .verified(let transaction) = verification {
                await transaction.finish()
                return true
            }
        } catch {}
        return false
    }
}

private struct SupportDeveloperSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showTipSheet = false
    @State private var showAdSheet = false
    @State private var showAdThanks = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(String(localized: "このアプリの開発を応援していただけると励みになります。"))
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)

                Button(String(localized: "投げ銭　寄付する")) {
                    showTipSheet = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .frame(maxWidth: .infinity)

                Button(String(localized: "広告を見て応援する")) {
                    showAdSheet = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.brown)
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle(String(localized: "開発者を応援"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "閉じる")) { dismiss() }
                }
            }
            .sheet(isPresented: $showTipSheet) {
                TipSheetView()
            }
            .sheet(isPresented: $showAdSheet) {
                AdSupportSheet {
                    showAdThanks = true
                }
            }
            .alert(String(localized: "ありがとうございます！"), isPresented: $showAdThanks) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(String(localized: "広告をご覧いただきありがとうございます。これからも改善を続けてまいります！"))
            }
        }
    }
}

private struct TipSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = TipStore.shared
    @State private var showThanks = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.pink)

                Text(String(localized: "このアプリの開発を応援していただけると励みになります。"))
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if store.isLoadingProducts {
                    ProgressView()
                } else if store.products.isEmpty {
                    Text(String(localized: "現在ご利用いただけません。"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 12) {
                        ForEach(store.products, id: \.id) { product in
                            Button {
                                Task {
                                    if await store.purchase(product) {
                                        showThanks = true
                                    }
                                }
                            } label: {
                                Text(product.displayPrice)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.pink)
                            .disabled(store.isPurchasing)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle(String(localized: "投げ銭　寄付する"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "閉じる")) { dismiss() }
                }
            }
            .task { await store.loadProducts() }
            .alert(String(localized: "ありがとうございます！"), isPresented: $showThanks) {
                Button("OK") { dismiss() }
            } message: {
                Text(String(localized: "応援いただきありがとうございます。これからも改善を続けてまいります！"))
            }
        }
    }
}

private struct AdSupportSheet: View {
    let onRewardEarned: () -> Void

    var body: some View {
#if canImport(GoogleMobileAds)
        AdMobRewardedSheet(onRewardEarned: onRewardEarned)
#else
        NavigationStack {
            VStack(spacing: 16) {
                Text(String(localized: "AdMob未導入"))
                    .font(.headline)
                Text(String(localized: "GoogleMobileAds パッケージを追加すると広告応援機能が有効になります。"))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
            .padding()
        }
#endif
    }
}

#if canImport(GoogleMobileAds)

#if DEBUG
private let ADMOB_REWARD_UNIT_ID = "ca-app-pub-3940256099942544/1712485313"
#else
private let ADMOB_REWARD_UNIT_ID = "ca-app-pub-7576639777972199/4693657810"
#endif

private struct AdMobRewardedSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var loader = RewardedAdLoader(adUnitID: ADMOB_REWARD_UNIT_ID)
    let onRewardEarned: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(String(localized: "動画広告"))
                    .font(.headline)

                Text(String(localized: "最後まで視聴すると閉じる【×】ボタンが現れます"))
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if loader.isLoading {
                    ProgressView(String(localized: "広告を読み込み中..."))
                } else {
                    Button(String(localized: "広告を再生する")) {
                        if let root = UIApplication.topMostViewController() {
                            loader.present(from: root)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!loader.isReady)
                }

                if loader.errorMessage != nil {
                    Button(String(localized: "再読み込み")) {
                        loader.loadAd()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding()
            .navigationTitle(String(localized: "広告を見て応援する"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "閉じる")) { dismiss() }
                }
            }
            .onAppear {
                loader.onRewardEarned = { _ in
                    onRewardEarned()
                }
            }
        }
    }
}

@MainActor
private final class RewardedAdLoader: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published private(set) var isLoading = false
    @Published private(set) var isReady = false
    @Published private(set) var errorMessage: String?

    var onRewardEarned: ((AdReward) -> Void)?
    private let adUnitID: String
    nonisolated(unsafe) private var rewardedAd: RewardedAd?

    init(adUnitID: String) {
        self.adUnitID = adUnitID
        super.init()
        loadAd()
    }

    func loadAd() {
        isLoading = true
        isReady = false
        errorMessage = nil
        let request = Request()

        RewardedAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            guard let self else { return }
            self.rewardedAd = ad
            if let ad { ad.fullScreenContentDelegate = self }
            MainActor.assumeIsolated { [weak self] in
                guard let self else { return }
                self.isLoading = false
                if error != nil {
                    self.errorMessage = String(localized: "現在、特典付きの広告がありません。後ほどお試しください")
                    self.rewardedAd = nil
                } else if self.rewardedAd != nil {
                    self.isReady = true
                }
            }
        }
    }

    func present(from root: UIViewController) {
        guard let rewardedAd else { return }
        let ad = rewardedAd
        isReady = false
        ad.present(from: root) { [weak self] in
            guard let self else { return }
            self.onRewardEarned?(ad.adReward)
        }
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        MainActor.assumeIsolated { [weak self] in
            guard let self else { return }
            self.rewardedAd = nil
            self.loadAd()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        MainActor.assumeIsolated { [weak self] in
            guard let self else { return }
            self.errorMessage = String(localized: "現在、特典付きの広告がありません。後ほどお試しください")
            self.rewardedAd = nil
            self.loadAd()
        }
    }
}

private extension UIApplication {
    static func topMostViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow })?.rootViewController }
            .first
    ) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topMostViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return topMostViewController(base: presented)
        }
        return base
    }
}

#endif

// MARK: - プリセットチップ

private struct PresetChip: View {
    let preset: NamePreset
    let isSelected: Bool

    @Environment(\.colorScheme) private var cs

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(preset.names, id: \.self) { name in
                Text(name)
                    .font(.caption2.bold())
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            isSelected
                ? Color.accentColor.opacity(cs == .dark ? 0.20 : 0.12)
                : Color(.secondarySystemFill)
        )
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
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
