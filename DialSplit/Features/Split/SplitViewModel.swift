//
//  SplitViewModel.swift
//  DialSplit
//
//  4段階割勘モデル（A=大富豪 / B=富豪 / C=平民 / D=貧民）
//  - B/C/D は1人あたり金額をダイアルで設定
//  - A（最上位）は残余を¥1単位切上で自動計算
//
//  NOTE: @Observable + didSet でプロパティを再代入すると無限再帰になるため
//  @ObservationIgnored バッキングストレージ + 手動 access/withMutation を使用する
//

import SwiftUI

// MARK: - A区分（大富豪）の計算ステータス

enum Split0Status {
    case exact    /// 割り切れた（黄色）
    case rounded  /// 切上あり（青）
    case negative /// マイナス（赤）
}

// MARK: - SplitViewModel

@Observable
final class SplitViewModel {

    // MARK: - Backing storage（observation 追跡を手動管理するため ignore）

    @ObservationIgnored private var _totalRaw:      Int = 0
    @ObservationIgnored private var _persons0:      Int = 1   // A（大富豪）
    @ObservationIgnored private var _persons1:      Int = 0   // B（富豪）
    @ObservationIgnored private var _persons2:      Int = 0   // C（平民）
    @ObservationIgnored private var _persons3:      Int = 0   // D（貧民）
    @ObservationIgnored private var _split1:        Int = 1_000
    @ObservationIgnored private var _split2:        Int = 1_000
    @ObservationIgnored private var _split3:        Int = 1_000
    @ObservationIgnored private var _dialUnitIndex: Int = 2

    // MARK: - Observable properties（クランプ・スナップをセッタで完結）

    var totalRaw: Int {
        get { access(keyPath: \.totalRaw); return _totalRaw }
        set { withMutation(keyPath: \.totalRaw) { _totalRaw = max(0, newValue) }; saveState() }
    }

    /// A（大富豪）人数（min 1）
    var persons0: Int {
        get { access(keyPath: \.persons0); return _persons0 }
        set { withMutation(keyPath: \.persons0) { _persons0 = max(1, newValue) }; saveState() }
    }

    /// B（富豪）人数（min 0）
    var persons1: Int {
        get { access(keyPath: \.persons1); return _persons1 }
        set { withMutation(keyPath: \.persons1) { _persons1 = max(0, newValue) }; saveState() }
    }

    /// C（平民）人数（min 0）
    var persons2: Int {
        get { access(keyPath: \.persons2); return _persons2 }
        set { withMutation(keyPath: \.persons2) { _persons2 = max(0, newValue) }; saveState() }
    }

    /// D（貧民）人数（min 0）
    var persons3: Int {
        get { access(keyPath: \.persons3); return _persons3 }
        set { withMutation(keyPath: \.persons3) { _persons3 = max(0, newValue) }; saveState() }
    }

    /// B（富豪）1人あたり金額
    var split1: Int {
        get { access(keyPath: \.split1); return _split1 }
        set { withMutation(keyPath: \.split1) { _split1 = snap(newValue) }; saveState() }
    }

    /// C（平民）1人あたり金額
    var split2: Int {
        get { access(keyPath: \.split2); return _split2 }
        set { withMutation(keyPath: \.split2) { _split2 = snap(newValue) }; saveState() }
    }

    /// D（貧民）1人あたり金額
    var split3: Int {
        get { access(keyPath: \.split3); return _split3 }
        set { withMutation(keyPath: \.split3) { _split3 = snap(newValue) }; saveState() }
    }

    /// ダイアル単位インデックス: 0=¥100, 1=¥500, 2=¥1,000
    var dialUnitIndex: Int {
        get { access(keyPath: \.dialUnitIndex); return _dialUnitIndex }
        set {
            withMutation(keyPath: \.dialUnitIndex) { _dialUnitIndex = newValue }
            let u = dialUnit
            withMutation(keyPath: \.split1) { _split1 = (_split1 / u) * u }
            withMutation(keyPath: \.split2) { _split2 = (_split2 / u) * u }
            withMutation(keyPath: \.split3) { _split3 = (_split3 / u) * u }
            saveState()
        }
    }

    // MARK: - Computed

    var dialUnit: Int {
        switch _dialUnitIndex {
        case 0:  return 100
        case 1:  return 500
        default: return 1_000
        }
    }

    /// A（大富豪）1人あたり（¥1単位切上・自動計算）
    /// WariKan互換: B/C/D への分配後の残余をAで均等割り、端数はAが+¥1で被る
    var split0: Int {
        let sum0 = totalRaw - persons1 * split1 - persons2 * split2 - persons3 * split3
        let p0   = max(1, persons0)
        let q    = sum0 / p0
        let r    = sum0 % p0
        return r > 0 ? q + 1 : q
    }

    var split0Status: Split0Status {
        let sum0 = totalRaw - persons1 * split1 - persons2 * split2 - persons3 * split3
        let p0   = max(1, persons0)
        if split0 < 0          { return .negative }
        if split0 * p0 == sum0 { return .exact }
        return .rounded
    }

    var totalPersons: Int { persons0 + persons1 + persons2 + persons3 }

    // MARK: - Init & Persistence

    init() {
        let d = UserDefaults.standard

        _totalRaw = d.integer(forKey: "sv_totalRaw")

        let p0 = d.integer(forKey: "sv_persons0")
        _persons0 = p0 > 0 ? p0 : 1
        _persons1 = d.integer(forKey: "sv_persons1")
        _persons2 = d.integer(forKey: "sv_persons2")
        _persons3 = d.integer(forKey: "sv_persons3")

        let s1 = d.integer(forKey: "sv_split1")
        _split1 = s1 > 0 ? s1 : 1_000
        let s2 = d.integer(forKey: "sv_split2")
        _split2 = s2 > 0 ? s2 : 1_000
        let s3 = d.integer(forKey: "sv_split3")
        _split3 = s3 > 0 ? s3 : 1_000

        let duiObj = d.object(forKey: "sv_dialUnitIndex")
        _dialUnitIndex = duiObj != nil ? d.integer(forKey: "sv_dialUnitIndex") : 2
    }

    private func saveState() {
        let d = UserDefaults.standard
        d.set(_totalRaw,      forKey: "sv_totalRaw")
        d.set(_persons0,      forKey: "sv_persons0")
        d.set(_persons1,      forKey: "sv_persons1")
        d.set(_persons2,      forKey: "sv_persons2")
        d.set(_persons3,      forKey: "sv_persons3")
        d.set(_split1,        forKey: "sv_split1")
        d.set(_split2,        forKey: "sv_split2")
        d.set(_split3,        forKey: "sv_split3")
        d.set(_dialUnitIndex, forKey: "sv_dialUnitIndex")
    }

    private func snap(_ value: Int) -> Int {
        let u = dialUnit
        guard u > 0 else { return value }
        return (value / u) * u
    }
}
