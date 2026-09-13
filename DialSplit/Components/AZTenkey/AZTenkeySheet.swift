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
    /// 中身から伝わってくる必要な高さ。確定するまでは概算で開く
    @State private var sheetHeight: CGFloat = 0

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
            sheetHeight = height
        }
        .presentationDetents([.height(sheetHeight + Self.navigationBarHeight)])
        .presentationDragIndicator(.visible)
        // ナビゲーションバーとホームインジケータ側までテンキーと同じ地で塗る。
        // 既定のシート背景のままだと、この2箇所が半透明になって背後が透ける
        .presentationBackground(Color(uiColor: .systemGroupedBackground))
    }

    /// inline のナビゲーションバーぶん。detent は中身＋バーで決まる
    private static let navigationBarHeight: CGFloat = 50
}
