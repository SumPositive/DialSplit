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
