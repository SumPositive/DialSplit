//
//  SFSymbol.swift
//  DialSplit
//
//  iOS バージョン差で利用できない SF Symbol を、利用可能な代替へ
//  自動でフォールバックさせるヘルパー
//
//  開発環境 (iOS 26 / SF Symbols 7) で追加された新シンボルは、配信先の
//  旧 iOS では描画されず空白になる。`UIImage(systemName:)` は実行中の OS に
//  シンボルが存在しないと nil を返すので、それで可用性を判定する
//

import UIKit

enum SFSymbol {
    /// 現在の OS で `name` のシンボルが利用可能か
    static func isAvailable(_ name: String) -> Bool {
        UIImage(systemName: name) != nil
    }

    /// `preferred` が利用可能ならそれを、無ければ `fallback` を返す
    /// fallback も無効なら preferred をそのまま返す（描画は空白になるが想定外ケース）
    static func resolve(_ preferred: String, fallback: String) -> String {
        isAvailable(preferred) ? preferred : fallback
    }
}
