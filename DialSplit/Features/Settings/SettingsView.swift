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
    @State private var showTipSheet = false
    @State private var showAdSheet = false
    @State private var showAdThanks = false
    @State private var showDialSettings = false

    private var aboutURL: URL? {
        let isEnglish = Locale.preferredLanguages.first?.hasPrefix("en") == true
        let path = isEnglish
            ? "https://docs.azukid.com/en/sumpo/DialSplit/dialsplit.html"
            : "https://docs.azukid.com/jp/sumpo/DialSplit/dialsplit.html"
        return URL(string: path)
    }

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v).\(b)"
    }

    private let tiers: [(label: String, placeholderKey: String)] = [
        ("A", "preset.name.vip"),
        ("B", "preset.name.high"),
        ("C", "preset.name.mid"),
        ("D", "preset.name.low"),
    ]

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                // MARK: 区分
                Section(String(localized: "settings.section.category")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "settings.presetDisplayNames"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)

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
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                            .padding(.leading, 2)
                            .padding(.trailing, 2)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))

                    HStack {
                        Text(String(localized: "settings.section.category"))
                        Spacer()
                        Text(String(localized: "settings.displayName"))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

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

                // MARK: 表示・操作
                Section(String(localized: "settings.section.displayControls")) {
                    Button {
                        showDialSettings = true
                    } label: {
                        HStack {
                            Text(String(localized: "settings.dialSettings"))
                            Spacer()
                            Text(settings.dialStyle.label)
                                .foregroundStyle(.secondary)
                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "settings.appearanceMode.title"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Picker("settings.appearanceMode.title", selection: $settings.appearanceMode) {
                            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                                Text(mode.localizedName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 2)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "settings.background.title"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Picker("settings.design.picker", selection: $settings.leatherStyle) {
                            ForEach(LeatherStyle.allCases, id: \.self) { style in
                                Text(style.localizedName).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 2)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "settings.amountDialStep"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(0..<5, id: \.self) { index in
                            HStack {
                                Text(String(format: NSLocalizedString("settings.stepFormat", comment: ""), index + 1))
                                Spacer()
                                Picker(
                                    String(format: NSLocalizedString("settings.stepFormat", comment: ""), index + 1),
                                    selection: Binding(
                                        get: { settings.amountDialSteps[index] },
                                        set: { settings.setAmountDialStep($0, at: index) }
                                    )
                                ) {
                                    ForEach(MoneyFormat.dialStepDefinitionOptions, id: \.self) { step in
                                        Text(MoneyFormat.localizedAmount(step)).tag(step)
                                    }
                                }
                                .labelsHidden()
                            }
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 2)
                }

                // MARK: サポート
                Section("settings.section.support") {
                    Button(String(localized: "settings.aboutApp")) {
                        if let url = aboutURL {
                            openURL(url)
                        }
                    }
                }

                // MARK: 開発者を応援
                Section(String(localized: "settings.section.supportDeveloper")) {
                    Button(String(localized: "support.tip.title")) {
                        showTipSheet = true
                    }
                    Button(String(localized: "support.ad.title")) {
                        showAdSheet = true
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
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
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
            .sheet(isPresented: $showDialSettings) {
                NavigationStack {
                    AZDialSettingsView(
                        tuning: $settings.dialTuning,
                        style: $settings.dialStyle
                    )
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("common.done") {
                                showDialSettings = false
                            }
                        }
                    }
                }
            }
            .alert(String(localized: "support.thanksTitle"), isPresented: $showAdThanks) {
                Button("common.ok", role: .cancel) {}
            } message: {
                Text(String(localized: "support.ad.thanksMessage"))
            }
            .preferredColorScheme(settings.appearanceMode.colorScheme)
        }
    }
}

// MARK: - 開発者応援（StoreKit / AdMob）

@Observable
@MainActor
private final class TipStore {
    static let shared = TipStore()

    private let productIds = ["DialSplit_Tips_1", "DialSplit_Tips_5"]
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

private struct TipSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = TipStore.shared
    @State private var showThanks = false
    @State private var activeThrow: CoinThrow? = nil
    @State private var targetScale: CGFloat = 1.0

    private struct CoinThrow: Identifiable {
        let id = UUID()
        let buttonIndex: Int
        let color: Color
        let product: Product
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    sheetContent(geo: geo)
                    if let t = activeThrow {
                        let startX = t.buttonIndex == 0
                            ? geo.size.width * 0.33
                            : geo.size.width * 0.67
                        TossedCoin(
                            key: t.id,
                            start: CGPoint(x: startX, y: geo.size.height - 130),
                            end: CGPoint(x: geo.size.width * 0.5, y: 90),
                            color: t.color
                        ) {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.35)) {
                                targetScale = 1.22
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                withAnimation(.spring) { targetScale = 1.0 }
                            }
                            let product = t.product
                            activeThrow = nil
                            Task { if await store.purchase(product) { showThanks = true } }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "support.tip.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.close")) { dismiss() }
                }
            }
            .task { await store.loadProducts() }
            .alert(String(localized: "support.thanksTitle"), isPresented: $showThanks) {
                Button("common.ok") { dismiss() }
            } message: {
                Text(String(localized: "support.tip.thanksMessage"))
            }
        }
    }

    @ViewBuilder
    private func sheetContent(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            developerTarget
                .padding(.top, 32)

            TossArcHint()
                .frame(height: 52)
                .padding(.horizontal, 56)
                .padding(.top, 6)

            Text(String(localized: "support.tip.message"))
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
                .padding(.top, 16)

            Spacer()
            coinSection
                .padding(.bottom, 56)
        }
    }

    private var developerTarget: some View {
        ZStack {
            Circle()
                .fill(.teal.opacity(0.10))
                .frame(width: 108, height: 108)
            Circle()
                .stroke(.teal.opacity(0.22), lineWidth: 1.5)
                .frame(width: 108, height: 108)
            Image(systemName: "person.fill")
                .font(.system(size: 50))
                .foregroundStyle(.teal)
            Image(systemName: "heart.fill")
                .font(.system(size: 18))
                .foregroundStyle(.pink)
                .offset(x: 24, y: -24)
        }
        .scaleEffect(targetScale)
    }

    @ViewBuilder
    private var coinSection: some View {
        if store.isLoadingProducts {
            ProgressView()
        } else if store.products.isEmpty {
            Text(String(localized: "support.unavailable"))
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 40) {
                ForEach(Array(store.products.enumerated()), id: \.element.id) { index, product in
                    let isLarge = index == store.products.count - 1
                    let coinColor: Color = isLarge
                        ? Color(red: 0.90, green: 0.72, blue: 0.18)
                        : Color(red: 0.72, green: 0.45, blue: 0.20)
                    CoinButtonView(
                        price: product.displayPrice,
                        label: isLarge
                            ? String(localized: "support.tip.large")
                            : String(localized: "support.tip.small"),
                        color: coinColor,
                        disabled: activeThrow != nil || store.isPurchasing
                    ) {
                        activeThrow = CoinThrow(
                            buttonIndex: index,
                            color: coinColor,
                            product: product
                        )
                    }
                }
            }
        }
    }
}

// MARK: - コインボタン

private struct CoinButtonView: View {
    let price: String
    let label: String
    let color: Color
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [color.opacity(0.18), color.opacity(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [color, color.opacity(0.45)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                    Circle()
                        .stroke(color.opacity(0.25), lineWidth: 1)
                        .padding(10)
                    Text(price)
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(color)
                }
                .frame(width: 100, height: 100)
                .shadow(color: color.opacity(0.35), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(CoinPressStyle())
            .disabled(disabled)
            .opacity(disabled ? 0.5 : 1.0)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CoinPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

// MARK: - 軌跡ヒント（点線アーク）

private struct TossArcHint: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            for (startRatio, controlRatio) in [(0.25, 0.82), (0.75, 0.18)] as [(Double, Double)] {
                var p = Path()
                p.move(to: CGPoint(x: w * startRatio, y: h))
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.5, y: 0),
                    control: CGPoint(x: w * controlRatio, y: h * 0.12)
                )
                ctx.stroke(p, with: .color(.secondary.opacity(0.28)),
                           style: StrokeStyle(lineWidth: 1.5, dash: [3, 5]))
            }
        }
    }
}

// MARK: - 飛ぶコイン

private struct TossedCoin: View {
    let key: UUID
    let start: CGPoint
    let end: CGPoint
    let color: Color
    let onLanded: () -> Void

    private struct KF {
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0
        var rotation: Double = 0
        var scale: CGFloat = 1
        var opacity: Double = 1
    }

    @State private var fire = false
    private let duration: Double = 0.65

    private var dx: CGFloat { end.x - start.x }
    private var dy: CGFloat { end.y - start.y }
    private var bulge: CGFloat { dx >= 0 ? 45 : -45 }

    var body: some View {
        Circle()
            .fill(LinearGradient(
                colors: [color.opacity(0.95), color.opacity(0.70)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .overlay(
                ZStack {
                    Circle().stroke(.white.opacity(0.28), lineWidth: 1.5).padding(5)
                    Text(verbatim: "¥").font(.title3.bold()).foregroundStyle(.white)
                }
            )
            .shadow(color: color.opacity(0.55), radius: 10, x: 0, y: 4)
            .frame(width: 50, height: 50)
            .keyframeAnimator(initialValue: KF(), trigger: fire) { content, v in
                content
                    .offset(x: v.offsetX, y: v.offsetY)
                    .rotationEffect(.degrees(v.rotation))
                    .scaleEffect(v.scale)
                    .opacity(v.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.offsetX) {
                    LinearKeyframe(0, duration: 0.01)
                    CubicKeyframe(dx * 0.5 + bulge, duration: duration * 0.5)
                    CubicKeyframe(dx, duration: duration * 0.5)
                }
                KeyframeTrack(\.offsetY) {
                    LinearKeyframe(0, duration: 0.01)
                    CubicKeyframe(dy * 0.30, duration: duration * 0.40)
                    CubicKeyframe(dy, duration: duration * 0.60)
                }
                KeyframeTrack(\.rotation) {
                    LinearKeyframe(0, duration: 0.01)
                    LinearKeyframe(540, duration: duration)
                }
                KeyframeTrack(\.scale) {
                    LinearKeyframe(1.0, duration: duration * 0.88)
                    LinearKeyframe(0.4, duration: duration * 0.12)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1.0, duration: duration * 0.82)
                    LinearKeyframe(0.0, duration: duration * 0.18)
                }
            }
            .position(start)
            .allowsHitTesting(false)
            .onAppear {
                fire = true
                DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) {
                    onLanded()
                }
            }
            .id(key)
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
                Text(String(localized: "admob.notLinked"))
                    .font(.headline)
                Text(String(localized: "admob.packageMessage"))
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
private let ADMOB_BANNER_UNIT_ID = "ca-app-pub-3940256099942544/2435281174"
#else
private let ADMOB_REWARD_UNIT_ID = "ca-app-pub-7576639777972199/7862774227"
private let ADMOB_BANNER_UNIT_ID = "ca-app-pub-7576639777972199/9670679914"
#endif

private struct AdMobRewardedSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var loader = RewardedAdLoader(adUnitID: ADMOB_REWARD_UNIT_ID)
    let onRewardEarned: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                AdMobBannerView(
                    adUnitID: ADMOB_BANNER_UNIT_ID,
                    size: CGSize(width: 300, height: 250)
                )

                Text(String(localized: "support.ad.videoTitle"))
                    .font(.headline)

                Text(String(localized: "support.ad.closeHint"))
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if loader.isLoading {
                    ProgressView(String(localized: "support.ad.loading"))
                } else {
                    Button(String(localized: "support.ad.play")) {
                        if let root = UIApplication.topMostViewController() {
                            loader.present(from: root)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!loader.isReady)

                    Label {
                        Text(String(localized: "support.ad.soundWarning"))
                            .font(.footnote.weight(.semibold))
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .foregroundStyle(.red)
                }

                if loader.errorMessage != nil {
                    Button(String(localized: "common.reload")) {
                        loader.loadAd()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding()
            .navigationTitle(String(localized: "support.ad.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.close")) { dismiss() }
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

private struct AdMobBannerView: View {
    let adUnitID: String
    let size: CGSize

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var reloadToken = UUID()

    var body: some View {
        VStack(spacing: 8) {
            AdMobBannerRepresentable(
                adUnitID: adUnitID,
                size: size,
                onReceiveAd: {
                    isLoading = false
                    errorMessage = nil
                },
                onFailToReceiveAd: { _ in
                    isLoading = false
                    errorMessage = String(localized: "support.ad.noRewardedAd")
                },
                reloadToken: reloadToken
            )
            .id(reloadToken)
            .frame(width: size.width, height: size.height)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(uiColor: .tertiarySystemBackground))
            )

            if isLoading {
                ProgressView(String(localized: "support.ad.loading"))
                    .font(.caption)
            } else if errorMessage != nil {
                Button(String(localized: "common.reload")) {
                    reloadToken = UUID()
                    isLoading = true
                    errorMessage = nil
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

private struct AdMobBannerRepresentable: UIViewControllerRepresentable {
    let adUnitID: String
    let size: CGSize
    let onReceiveAd: () -> Void
    let onFailToReceiveAd: (Error) -> Void
    let reloadToken: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator(onReceiveAd: onReceiveAd, onFailToReceiveAd: onFailToReceiveAd)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        viewController.view.backgroundColor = .clear

        let bannerView = BannerView(adSize: adSizeFor(cgSize: size))
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = viewController
        bannerView.delegate = context.coordinator
        bannerView.translatesAutoresizingMaskIntoConstraints = false

        viewController.view.addSubview(bannerView)
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor),
        ])

        context.coordinator.bannerView = bannerView
        bannerView.load(Request())
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.bannerView?.rootViewController = uiViewController
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        weak var bannerView: BannerView?
        private let onReceiveAd: () -> Void
        private let onFailToReceiveAd: (Error) -> Void

        init(onReceiveAd: @escaping () -> Void, onFailToReceiveAd: @escaping (Error) -> Void) {
            self.onReceiveAd = onReceiveAd
            self.onFailToReceiveAd = onFailToReceiveAd
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            onReceiveAd()
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            onFailToReceiveAd(error)
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
                    self.errorMessage = String(localized: "support.ad.noRewardedAd")
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
            self.errorMessage = String(localized: "support.ad.noRewardedAd")
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
