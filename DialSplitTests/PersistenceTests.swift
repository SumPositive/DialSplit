//
//  PersistenceTests.swift
//  DialSplitTests
//
//  Layer 2: 永続化と通貨単位の移行（SplitViewModel.init / saveState）
//  注入した一時 UserDefaults suite を使い、本番設定を汚さない
//

import Testing
import Foundation
@testable import DialSplit

@MainActor
struct PersistenceTests {

    /// 毎回ユニークな空 suite を作る
    private func makeSuite() -> UserDefaults {
        UserDefaults(suiteName: "DialSplitPersistTest-\(UUID().uuidString)")!
    }

    // MARK: - 新規インストールのデフォルト（JPY 環境でのみ実行）

    @Test("空 suite では JPY のデフォルト値で初期化される",
          .enabled(if: MoneyFormat.currencyCode == "JPY"))
    func freshInstallDefaultsJPY() {
        let vm = SplitViewModel(defaults: makeSuite())
        #expect(vm.totalRaw == 10_000)
        #expect(vm.persons0 == 1)
        #expect(vm.persons1 == 2)
        #expect(vm.split1 == 2_500)
        #expect(vm.split2 == 1_000)
        #expect(vm.split3 == 1_000)
        #expect(vm.dialUnit == MoneyFormat.defaultDialStep)
    }

    // MARK: - 最小通貨単位への移行

    @Test("storageVersion 未設定なら保存値に scale を掛けて移行する")
    func minorUnitMigration() {
        let suite = makeSuite()
        // 旧データ（version キーなし = version 0）を直接書き込む
        suite.set(2_500, forKey: "sv_split1")
        suite.set(50_000, forKey: "sv_totalRaw")

        let vm = SplitViewModel(defaults: suite)
        let scale = MoneyFormat.minorUnitScale
        #expect(vm.split1 == 2_500 * scale)
        #expect(vm.totalRaw == 50_000 * scale)
        // 移行後はバージョンが 1 に更新される
        #expect(suite.integer(forKey: "sv_moneyStorageVersion") == 1)
    }

    @Test("移行済み(version=1)の値は二重に scale 倍されない")
    func noDoubleMigration() {
        let suite = makeSuite()
        suite.set(1, forKey: "sv_moneyStorageVersion")
        suite.set(3_333, forKey: "sv_split1")

        let vm = SplitViewModel(defaults: suite)
        #expect(vm.split1 == 3_333)
    }

    // MARK: - 旧 dialUnitIndex からの移行

    @Test("sv_dialUnitIndex から実値 dialUnit へ移行する")
    func legacyDialUnitIndexMigration() {
        let suite = makeSuite()
        // 旧形式: index 1 = 500（version キーなし）
        suite.set(1, forKey: "sv_dialUnitIndex")

        let vm = SplitViewModel(defaults: suite)
        #expect(vm.dialUnit == 500 * MoneyFormat.minorUnitScale)
    }

    // MARK: - 異常値の補正

    @Test("persons0 が 0 で保存されていても 1 に補正")
    func persons0Floor() {
        let suite = makeSuite()
        suite.set(1, forKey: "sv_moneyStorageVersion")
        suite.set(0, forKey: "sv_persons0")

        let vm = SplitViewModel(defaults: suite)
        #expect(vm.persons0 == 1)
    }

    @Test("dialUnit が範囲外ならデフォルトへ補正")
    func dialUnitOutOfRange() {
        let suite = makeSuite()
        suite.set(1, forKey: "sv_moneyStorageVersion")
        suite.set(MoneyFormat.maxMinorValue + 1, forKey: "sv_dialUnit")

        let vm = SplitViewModel(defaults: suite)
        #expect(vm.dialUnit == MoneyFormat.defaultDialStep)
    }

    // MARK: - 通貨（地域）変更にともなう再スケール

    /// 現在の通貨と異なる最小単位で保存されていた状況を作る。
    /// JPY 環境なら「以前ドルで保存した」、USD 環境なら「以前円で保存した」を再現する
    private var otherScale: Int {
        MoneyFormat.minorUnitScale == 1 ? 100 : 1
    }

    @Test("保存時と最小単位が違えば金額を換算して読み戻す")
    func rescalesAmountsWhenCurrencyChanged() {
        let suite = makeSuite()
        let stored = otherScale
        let current = MoneyFormat.minorUnitScale

        // 「前回の通貨」での 10,000 単位ぶんを保存しておく
        suite.set(1, forKey: "sv_moneyStorageVersion")
        suite.set(stored, forKey: "sv_moneyMinorUnitScale")
        suite.set(10_000 * stored, forKey: "sv_totalRaw")
        suite.set(2_500 * stored, forKey: "sv_split1")

        let vm = SplitViewModel(defaults: suite)

        // 同じ「金額」を表す、現在の通貨の最小単位へ揃っていること
        #expect(vm.totalRaw == 10_000 * current)
        #expect(vm.split1 == 2_500 * current)
    }

    @Test("換算後は現在の最小単位が保存し直される")
    func storesCurrentScaleAfterRescale() {
        let suite = makeSuite()
        suite.set(1, forKey: "sv_moneyStorageVersion")
        suite.set(otherScale, forKey: "sv_moneyMinorUnitScale")
        suite.set(10_000 * otherScale, forKey: "sv_totalRaw")

        _ = SplitViewModel(defaults: suite)
        #expect(suite.integer(forKey: "sv_moneyMinorUnitScale") == MoneyFormat.minorUnitScale)

        // 二重に換算されないこと（もう一度読んでも値が変わらない）
        let vm2 = SplitViewModel(defaults: suite)
        #expect(vm2.totalRaw == 10_000 * MoneyFormat.minorUnitScale)
    }

    @Test("最小単位が同じなら換算しない")
    func keepsAmountsWhenScaleUnchanged() {
        let suite = makeSuite()
        suite.set(1, forKey: "sv_moneyStorageVersion")
        suite.set(MoneyFormat.minorUnitScale, forKey: "sv_moneyMinorUnitScale")
        suite.set(77_000, forKey: "sv_totalRaw")

        let vm = SplitViewModel(defaults: suite)
        #expect(vm.totalRaw == 77_000)
    }

    @Test("最小単位の記録が無い保存データは換算しない")
    func skipsRescaleWithoutStoredScale() {
        let suite = makeSuite()
        // sv_moneyMinorUnitScale を持たない、移行済みの古いデータ
        suite.set(1, forKey: "sv_moneyStorageVersion")
        suite.set(77_000, forKey: "sv_totalRaw")

        let vm = SplitViewModel(defaults: suite)
        #expect(vm.totalRaw == 77_000)
    }

    @Test("ダイアル単位は換算後もっとも近い候補へ寄せる")
    func snapsDialUnitToCandidate() {
        let suite = makeSuite()
        suite.set(1, forKey: "sv_moneyStorageVersion")
        suite.set(otherScale, forKey: "sv_moneyMinorUnitScale")
        suite.set(500 * otherScale, forKey: "sv_dialUnit")

        let vm = SplitViewModel(defaults: suite)
        // 単純換算では刻みとして半端になりうるので、候補のどれかに収まっていること
        #expect(MoneyFormat.dialStepCandidates.contains(vm.dialUnit))
    }

    // MARK: - 保存→再読込の往復

    @Test("変更した値は再 init で復元される")
    func saveLoadRoundTrip() {
        let suite = makeSuite()

        let vm1 = SplitViewModel(defaults: suite)
        vm1.totalRaw = 77_000
        vm1.persons0 = 3
        vm1.persons1 = 1
        vm1.split1 = 4_000

        // 同じ suite で作り直す → 永続化された値が読み戻る
        let vm2 = SplitViewModel(defaults: suite)
        #expect(vm2.totalRaw == 77_000)
        #expect(vm2.persons0 == 3)
        #expect(vm2.persons1 == 1)
        #expect(vm2.split1 == 4_000)
    }
}
