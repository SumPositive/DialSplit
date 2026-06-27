//
//  AdMobBanner.swift
//  DialSplit
//
//  AdMob の共有インフラ（広告ユニット ID / NPA リクエスト / バナー表示）
//  設定画面の応援バナーと、メイン画面フッターのバナーで共用する
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

struct AdMobBannerView: View {
    let adUnitID: String
    let size: CGSize

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var reloadToken = UUID()

    var body: some View {
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
        // ローディング/エラーはバナー領域に重ねて表示（行を増やさない）
        .overlay {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if errorMessage != nil {
                Button(String(localized: "common.reload")) {
                    reloadToken = UUID()
                    isLoading = true
                    errorMessage = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
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

/// メイン画面フッター用バナー（標準バナー 320x50）
struct FooterBannerView: View {
    var body: some View {
        AdMobBannerView(
            adUnitID: AdMobConfig.bannerUnitID,
            size: CGSize(width: 320, height: 50)
        )
    }
}

#else

/// GoogleMobileAds 未導入時は空ビュー
struct FooterBannerView: View {
    var body: some View { EmptyView() }
}

#endif
