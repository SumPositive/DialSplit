//
//  AZTenkey をシートとして出すための薄い層。
//
//  AZTenkeyView 自体はただの View なので、画面へ直接埋め込むこともできる。
//  シートで使いたい時だけこちらを通す。
//

import SwiftUI

/// テンキーが必要としている高さを親へ伝えるためのキー。
/// 式や丸めの行が出入りすると値が変わる
struct AZTenkeyHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if 0 < next { value = next }
    }
}

/// テンキーをシートとして出す。
///
/// ナビゲーションバーにタイトルと閉じるボタンを置き、
/// 中身の増減に合わせて detent を変える（下端が固定なので上へ伸びる）。
/// 確定したらシートを閉じる。
struct AZTenkeySheet: View {
    let config: AZTenkeyConfig

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 中身から伝わってくる必要な高さ。
    /// 0 で開くとナビゲーションバーぶんだけの潰れた状態が一瞬見えるので、
    /// 計測が届くまでは同じ計算式で求めた概算を使う
    @State private var sheetHeight: CGFloat?

    /// 計測前に使う高さ。式の行はまだ無いので、その分を除いて見積もる
    private var estimatedHeight: CGFloat {
        AZTenkeyView.height(
            dynamicTypeSize: dynamicTypeSize,
            isCompact: AZTenkeyView.isCompactScreen,
            hasStatusRow: false
        )
    }

    var body: some View {
        // 確定したらシートを閉じる。閉じる責務は View 本体ではなくここが持つ
        let sheetConfig = config.replacingOnConfirm { value in
            config.onConfirm(value)
            dismiss()
        }

        return NavigationStack {
            AZTenkeyView(config: sheetConfig)
                .navigationTitle(config.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.down")
                                .imageScale(.large)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .accessibilityLabel(Text("azTenkey.close"))
                        .accessibilityIdentifier("sheet.close")
                    }
                }
        }
        .onPreferenceChange(AZTenkeyHeightKey.self) { height in
            guard 0 < height else { return }
            sheetHeight = height
        }
        .presentationDetents([.height((sheetHeight ?? estimatedHeight) + Self.navigationBarHeight)])
        .presentationDragIndicator(.visible)
        // ナビゲーションバーとホームインジケータ側までテンキーと同じ地で塗る。
        // 既定のシート背景のままだと、この2箇所が半透明になって背後が透ける
        .presentationBackground(Color(uiColor: .systemGroupedBackground))
    }

    /// inline のナビゲーションバーぶん。detent は中身＋バーで決まる
    private static let navigationBarHeight: CGFloat = 50
}
