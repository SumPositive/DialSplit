# AZTenkey — 四則演算つきテンキー

金額や個数を入力するためのテンキー。数字キーに加えて `÷ × − +` を持ち、
`78,500 ÷ 3` のような計算をその場でしてから確定できる。

シート専用ではなく、ただの View なので画面へ直接埋め込める。
シートで出したい時は同梱の `AZTenkeySheet` を通す。

## 移植のしかた

このフォルダを丸ごとコピーし、`AZTenkeyFormat+DialSplit.swift` を
移植先向けに書き換える。あとは文字列カタログに 8 キーを足すだけ。

## ファイル

| ファイル | 役割 | 移植時 |
|---|---|---|
| `AZTenkeyView.swift` | テンキー本体。ただの View | そのまま |
| `AZTenkeyCalculator.swift` | 演算子・丸め方法・計算規則。View に依存しない | そのまま |
| `AZTenkeyFormat.swift` | 値の見せ方の注入口 | そのまま |
| `AZTenkeySheet.swift` | シートとして出すための薄い層 | そのまま |
| `AZTenkeyFormat+DialSplit.swift` | アプリ固有の書式 | **差し替える** |

## 使い方

### シートで出す

```swift
@State private var tenkeyConfig: AZTenkeyConfig?

.sheet(item: $tenkeyConfig) { AZTenkeySheet(config: $0) }

// 開くとき
tenkeyConfig = AZTenkeyConfig(
    title: "人数",
    initialValue: persons,
    maxValue: 99,
    minValue: 1,
    format: .dialSplitCount,
    onConfirm: { persons = $0 }
)
```

`AZTenkeySheet` はナビゲーションバーにタイトルと閉じるボタンを置き、
確定したらシートを閉じる。中身の増減に合わせて detent も変える。

### 画面へ直接置く

```swift
AZTenkeyView(config: AZTenkeyConfig(
    title: "金額",
    initialValue: amount,
    maxValue: 999_999,
    minValue: 0,
    format: .dialSplitAmount,
    onConfirm: { amount = $0 }   // 閉じる処理は要らない
))
```

埋め込んだ場合、確定しても View は消えない（`onConfirm` が呼ばれるだけ）。
閉じたり画面を移したりは置いた側で決める。
必要な高さは `preferredHeight` で取れるほか、`AZTenkeyHeightKey` でも
親へ伝わるので、`onPreferenceChange` で受け取れる。

## 書式の差し替え

値は **通貨の最小単位の整数** で受け渡す（円なら 1 = 1円、ドルなら 1 = 1セント）。
アプリ固有の通貨実装との橋渡しは `AZTenkeyFormat+DialSplit.swift` だけが持つので、
移植先ではこのファイルを書き換える。

```swift
extension AZTenkeyFormat {
    static var myAppAmount: AZTenkeyFormat {
        .currency(
            locale: MoneyFormat.effectiveLocale,
            fractionDigits: MoneyFormat.fractionDigits,
            minorUnitScale: MoneyFormat.minorUnitScale,
            display: { MoneyFormat.localizedAmount($0) }
        )
    }
}
```

通貨として扱わない整数（人数など）は `.plain()` でよい。

## 必要な依存

### AZPicker

丸め方法の選択に `AZDropdownPicker` と `AZPickerStyle` を使う。
sumpo のアプリ群には共通で入っているので前提としている。
無い環境へ持っていくなら `roundingPicker` を標準の `Menu` に置き換える。

### 文字列カタログ

以下のキーを移植先の `Localizable.xcstrings` に用意する。
DialSplit には 8 言語（de/en/es/fr/it/ja/ko/zh-Hant）で入っているので、
そこからコピーするのが早い。

| キー | ja |
|---|---|
| `azTenkey.rounding.up` | 切り上げ |
| `azTenkey.rounding.halfUp` | 四捨五入（既定） |
| `azTenkey.rounding.bankers` | 偶数丸め |
| `azTenkey.rounding.down` | 切り捨て |
| `azTenkey.error.divideByZero` | 0では割れません |
| `azTenkey.error.outOfRange` | 計算結果が入力できる範囲を超えています |
| `azTenkey.close` | 閉じる |
| `azTenkey.done` | 完了 |

### UserDefaults

丸め方法の選択を `azTenkey.rounding` に保存し、次に開いた時も引き継ぐ。
キーは `AZTenkeyView.roundingStorageKey` の1箇所で決めている。

## 設計メモ

**計算途中は `Decimal` のまま持ち、確定時に一度だけ整数へ丸める。**
都度丸めると `78,500 ÷ 3 × 3` が元へ戻らなくなる。

**金額の式表示は通貨単位へ直して見せる。**
内部値は最小単位なので、そのまま出すとドルで「7850000 ÷ 3」になってしまう。
ただし乗除算の右辺は金額ではなく「何倍・何分割か」なので、通貨へは直さない。

**シートでは、式や丸めの行が増えると高さ自体を変えて上へ伸ばす。**
シートは下端が固定なので、こうするとテンキーの位置が動かない。
高さの内訳は `preferredHeight` にある。行の見積もり（`statusRowHeight`）は
実測ではないので、フォントを変えたらここも調整する。

**文字サイズ設定に追従する。**
文字は Font 指定なので自動で伸びるが、キーの高さや余白は伸びない。
`@Environment(\.dynamicTypeSize)` から `uiScale` を作り、寸法に掛けている。
アクセシビリティサイズまで素直に追うと画面へ収まらなくなるので、
伸びしろは 1.26 倍で頭打ちにし、金額表示だけはさらに抑えて 1.12 倍にしてある。
アプリ固有の文字サイズ設定型には依存していない（環境値だけを見る）。

**キーの反応を最優先にしている。**
押下時のフェードを消す `AZTenkeyKeyStyle`、`.transaction` によるアニメーション停止、
ハプティクスジェネレータの使い回しと `prepare()` の3点。
キーパッド上に余計なジェスチャは置かない（取りこぼしの原因になる）。

**シートのバウンスは容認している。**
標準シートで下スワイプ閉じを許す以上、指に追従するのが iOS の正しい挙動。
止めるにはビュー階層を辿って UIKit のパンジェスチャを触ることになり、
OS 更新で壊れうるコードを抱えることになるので、そこまではしていない。
