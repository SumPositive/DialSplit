//
//  AdMobBanner.swift
//  DialSplit
//
//  AdMob の共有インフラ（広告ユニット ID / NPA リクエスト / バナー表示）
//  メイン画面上部のバナー帯で使う
//

import SwiftUI

#if canImport(GoogleMobileAds)
@preconcurrency import GoogleMobileAds

enum AdMobConfig {
    #if DEBUG
    static let bannerUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let rewardUnitID = "ca-app-pub-3940256099942544/1712485313"
    #else
    static let bannerUnitID = "ca-app-pub-7576639777972199/9670679914"
    static let rewardUnitID = "ca-app-pub-7576639777972199/7862774227"
    #endif
}

// 非パーソナライズ広告（NPA）リクエスト
@MainActor
func nonPersonalizedAdRequest() -> Request {
    let request = Request()
    let extras = Extras()
    extras.additionalParameters = ["npa": "1"]
    request.register(extras)
    return request
}

struct AdMobBannerRepresentable: UIViewControllerRepresentable {
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
        bannerView.load(nonPersonalizedAdRequest())
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

/// メイン画面上部のバナー帯（標準バナー 320x50）
struct HeaderBannerView: View {
    /// 縦方向の余裕。.compact は iPhone 横向きのように画面が低い状態を指す
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// 画面が再描画されてもバナーを作り直さないための固定トークン。
    /// 1バナーにつき1リクエストに保ち、無効トラフィックを避ける
    @State private var reloadToken = UUID()

    var body: some View {
        // fastlane snapshot 撮影時は広告を出さない（App Store スクショに広告を映さない）
        if SnapshotSupport.isRunningSnapshot {
            EmptyView()
        } else {
            heightAwareBody
        }
    }

    /// 画面の高さが足りないときだけ広告と帯を畳む。
    ///
    /// 判定は向きではなく verticalSizeClass で行う。.compact になるのは
    /// iPhone の横向きのように縦が詰まった状態だけで、iPad は横向きでも
    /// .regular のままなので広告はそのまま出る（Split View や Slide Over も同様）。
    private var isHeightConstrained: Bool {
        verticalSizeClass == .compact
    }

    /// 高さが足りないときは高さ0にして帯ごと畳む。
    /// 50pt＋上下余白の帯が、低い画面ではダイヤル面を大きく圧迫するため。
    ///
    /// バナー自体は破棄せず畳むだけにする。作り直すと再リクエストが飛び、
    /// 回転を往復するたびに無効トラフィックとみなされ得るため。
    private var heightAwareBody: some View {
        bannerBody
            .frame(height: isHeightConstrained ? 0 : nil)
            .opacity(isHeightConstrained ? 0 : 1)
            .clipped()
            // 畳んでいる間は広告に触れないようにする
            .allowsHitTesting(!isHeightConstrained)
            .accessibilityHidden(isHeightConstrained)
    }

    private var bannerBody: some View {
        AdMobBannerRepresentable(
            adUnitID: AdMobConfig.bannerUnitID,
            size: CGSize(width: 320, height: 50),
            onReceiveAd: {},
            onFailToReceiveAd: { _ in
                // 配信できなかった場合も画面には何も出さない（帯だけが残る）
            },
            reloadToken: reloadToken
        )
        // 広告サイズと表示領域を一致させる
        .frame(width: 320, height: 50)
        .frame(maxWidth: .infinity)
        // 下のタップできる要素（ヘッダーの歯車・ダイヤル面）との間を空ける。
        // 誤タップを防ぐだけでなく、広告がアプリの操作面と地続きに
        // 見えないようにするためにも要る
        // （Vitalinで間隔が狭く誤タップを招くとして配信停止された経緯を踏まえた対応）
        .padding(.vertical, 20)
        // 広告の載る面だけ地を一段沈め、アプリのUIではないと分かるようにする。
        // 角丸や左右余白を付けるとアプリのカードに見えてしまうため、
        // 画面端まで届く帯にし、コンテンツ側の区切り線だけで面を分ける
        .background(AdBandNoiseBackground())
        .overlay(alignment: .bottom) {
            // 広告帯とコンテンツの境に引く区切り線。面の境界だけを示す細さに留める
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(height: 0.5)
        }
    }
}

/// 広告帯の地。砂嵐（ホワイトノイズ）風の粒を敷き、
/// アプリのなめらかな面と質感で区別できるようにする。
///
/// 粒はアプリ起動後に一度だけ UIImage へ焼き、以後はその1枚を敷き詰めるだけ。
/// 毎フレーム粒を描き直すと広告の隣で CPU を使い続けるため、絵は静止させる。
private struct AdBandNoiseBackground: View {
    var body: some View {
        // レザー地が透けると広告面がアプリの一部に見えるため、不透明な地で塗る
        Color(uiColor: .systemBackground)
            .overlay {
                Color(uiColor: .tertiarySystemFill)
            }
            .overlay {
                Image(uiImage: AdBandNoiseImage.shared)
                    .resizable(resizingMode: .tile)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .clipped()
    }
}

/// 砂嵐の粒を焼き付けた繰り返しタイル画像。
/// 生成は初回アクセス時の一度きりで、以後は全画面で同じ1枚を使い回す
private enum AdBandNoiseImage {
    /// タイル1辺の長さ。大きすぎると画像が重くなり、小さすぎると繰り返しに気付かれる
    static let tileSize: CGFloat = 96

    /// 粒の密度。側辺の2乗をこの値で割った数だけ粒を置く。
    /// 小さくするほど粒が詰まって、きめの細かい砂目になる
    static let density: CGFloat = 4

    /// 粒1つの大きさの範囲（pt）。
    /// 1pt前後に抑えると、粒の粗さではなく面の質感として見える
    static let dotSizeRange: ClosedRange<CGFloat> = 0.5...1.0

    /// 粒の濃さの範囲。これを上げると砂目がはっきりし、下げると地に溶ける
    static let dotAlphaRange: ClosedRange<CGFloat> = 0.06...0.13

    static let shared: UIImage = makeTile()

    private static func makeTile() -> UIImage {
        let side = tileSize
        let format = UIGraphicsImageRendererFormat.preferred()
        // 粒は1pt前後の点なので、等倍で焼けば十分（画像サイズも小さく保てる）
        format.scale = 1
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let image = renderer.image { context in
            let cg = context.cgContext
            // 描き直しても同じ模様になるよう、固定の種から粒を置く
            var rng = NoiseGenerator(seed: 0xA5A5_1234)
            let count = Int(side * side / density)
            for _ in 0..<max(count, 0) {
                let x = rng.cgFloat(in: 0...side)
                let y = rng.cgFloat(in: 0...side)
                let dotSide = rng.cgFloat(in: dotSizeRange)
                // 明暗どちらの粒も置いて、ざらつきを均等に見せる
                let isBright = rng.next() % 2 == 0
                let base: UIColor = isBright ? .white : .black
                // 粒の濃さはこの値だけで決める（重ねて薄める処理は入れない）。
                // これより薄いと実寸では地の色と溶けて砂目に見えない
                cg.setFillColor(base.withAlphaComponent(rng.cgFloat(in: dotAlphaRange)).cgColor)
                cg.fill(CGRect(x: x, y: y, width: dotSide, height: dotSide))
            }
        }
        // ダークモードでも同じ粒を使う（明暗両方の粒を含むため反転の必要がない）
        return image.withRenderingMode(.alwaysOriginal)
    }
}

/// 砂嵐の粒を毎回同じ配置にするための擬似乱数（SplitMix64）
private struct NoiseGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func cgFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        CGFloat.random(in: range, using: &self)
    }
}

#else

/// GoogleMobileAds 未導入時は空ビュー
struct HeaderBannerView: View {
    var body: some View { EmptyView() }
}

#endif
