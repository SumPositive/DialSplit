//
//  テンキーが値を表示するための書式。
//
//  アプリ側の通貨まわりの実装（DialSplit なら MoneyFormat）へ直接依存すると
//  他アプリへ持っていけないので、必要な4つだけをここへ切り出して注入する。
//

import Foundation

/// テンキーの値表示に必要な書式一式。
///
/// 金額を扱う場合、値は「通貨の最小単位」の整数で受け渡す。
/// 円なら 1 = 1円、ドルなら 1 = 1セント。`minorUnitScale` がその倍率にあたる。
struct AZTenkeyFormat {
    /// 数値の区切りや小数記号に使うロケール
    var locale: Locale
    /// 通貨の小数桁数（円なら 0、ドルなら 2）。金額以外では 0
    var fractionDigits: Int
    /// 最小単位から通貨単位へ直す倍率（円なら 1、ドルなら 100）。金額以外では 1
    var minorUnitScale: Int
    /// 確定値を画面へ出すときの文字列化。通貨記号の有無や位置もここで決める
    var display: (Int) -> String

    /// 通貨として扱わない、ただの整数（人数など）向けの書式
    static func plain(locale: Locale = .current) -> AZTenkeyFormat {
        AZTenkeyFormat(
            locale: locale,
            fractionDigits: 0,
            minorUnitScale: 1,
            display: { "\($0)" }
        )
    }

    /// 通貨として扱う書式。
    /// - Parameters:
    ///   - locale: 桁区切りと通貨記号に使うロケール
    ///   - fractionDigits: 通貨の小数桁数
    ///   - minorUnitScale: 最小単位から通貨単位への倍率
    ///   - display: 最小単位の整数を通貨表記へ直す処理
    static func currency(
        locale: Locale,
        fractionDigits: Int,
        minorUnitScale: Int,
        display: @escaping (Int) -> String
    ) -> AZTenkeyFormat {
        AZTenkeyFormat(
            locale: locale,
            fractionDigits: fractionDigits,
            minorUnitScale: minorUnitScale,
            display: display
        )
    }
}
