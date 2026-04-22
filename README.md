# 割勘 DialSplit

iOS 向けのダイアル式割り勘計算アプリです。SwiftUI で開発しています。

**User Guide**
[English](https://azukid.com/en/sumpo/DialSplit/dialsplit.html) / [日本語](https://azukid.com/jp/sumpo/DialSplit/dialsplit.html)

![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)
[![App Store](https://img.shields.io/badge/App%20Store-Download-blue)](https://apps.apple.com/app/id467941202)

## 概要

DialSplit は、人数と金額をダイアルで調整しながら割り勘配分を決めるアプリです。2011 年に公開した「割勘」を、SwiftUI と Swift Package ベースで再構築しています。

合計金額と A/B/C/D 各パネルの人数を設定すると、B/C/D の金額をもとに A パネルの金額を自動計算します。金額表示は端末の通貨ロケールに従い、小数通貨は最小通貨単位で扱います。

## 機能

- [AZDial](https://github.com/SumPositive/AZDial) によるダイアル入力
- [AZCalc](https://github.com/SumPositive/AZCalc) による BCD 十進演算
- A/B/C/D の表示名称とプリセット切り替え
- 合計金額、人数、各パネル金額のテンキー直接入力
- 人数ロックと全操作ロック
- ダイアル設定シートによる操作感の調整
- 外観モード: 自動、ライト、ダーク
- 背景: モノトーン、ブラウンレザー、ブラックレザー
- 金額ダイアルステップのカスタム設定
- パネル明るさ、文字色、濃淡の調整
- 投げ銭（StoreKit 2）と広告視聴による開発者支援

## 構成

```text
DialSplit/
├── App/              — アプリ起点、AppSettings、通貨表示設定
├── Features/
│   ├── Split/        — メイン割り勘画面、パネル表示、計算 ViewModel
│   └── Settings/     — 設定画面、開発者支援画面
└── Components/       — BrassFrame、LeatherBackground、NumpadView
```

**主な依存関係**
- [AZDial](https://github.com/SumPositive/AZDial) — SwiftUI ダイアルコントロール
- [AZCalc](https://github.com/SumPositive/AZCalc) — BCD 十進演算

## 必要環境

- iOS 17.0+
- Xcode 26+
- Swift 6

## リリース履歴

| バージョン | 公開日 | 内容 |
|---|---|---|
| 2.1.0 | 2026-04-22 | 人数ロック、全操作ロック、ダイアル設定、外観モード、背景設定、金額ダイアルステップ設定、通貨ロケール対応を追加 |
| 2.0.1 | 2026-04-17 | 開発者支援機能を追加 |
| 2.0.0 | 2026-04-16 | SwiftUI 版として再構築 |

## ライセンス

本リポジトリのソースコードは参照目的で公開しています。
著作権は SumPositive に帰属します。
無断での複製、改変、再配布、商用利用を禁止します。
