//
//  AZTenkeyFormat の DialSplit 向け設定。
//
//  Numpad 本体はアプリ固有の通貨実装を知らないので、
//  MoneyFormat との橋渡しはこのファイルだけが持つ。
//  他アプリへ持っていく時は、このファイルを差し替える。
//

import Foundation

extension AZTenkeyFormat {
    /// DialSplit の金額入力用。値は通貨の最小単位の整数で受け渡す
    static var dialSplitAmount: AZTenkeyFormat {
        .currency(
            locale: MoneyFormat.effectiveLocale,
            fractionDigits: MoneyFormat.fractionDigits,
            minorUnitScale: MoneyFormat.minorUnitScale,
            display: { MoneyFormat.localizedAmount($0) }
        )
    }

    /// DialSplit の人数入力用。通貨の桁は使わない
    static var dialSplitCount: AZTenkeyFormat {
        .plain(locale: MoneyFormat.effectiveLocale)
    }
}
