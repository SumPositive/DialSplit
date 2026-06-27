//
//  SplitLogicTests.swift
//  DialSplitTests
//
//  Layer 1: 割勘の核心ロジック（SplitViewModel）
//  金額はすべて最小通貨単位（minor）の整数で扱い、通貨ロケールに依存しない
//

import Testing
@testable import DialSplit

@MainActor
struct SplitLogicTests {

    // MARK: - split0（A の自動計算）

    @Test("割り切れる時は商をそのまま、status は exact")
    func exactDivision() {
        let vm = SplitViewModel.makeForTest(totalRaw: 60_000, persons0: 3)
        #expect(vm.split0 == 20_000)
        #expect(vm.split0Status == .exact)
    }

    @Test("端数が出る時は A が最小単位で切り上げ、status は rounded")
    func roundedUp() {
        // 86,500 ÷ 6 = 14,416.66… → 切上 14,417
        let vm = SplitViewModel.makeForTest(totalRaw: 86_500, persons0: 6)
        #expect(vm.split0 == 14_417)
        #expect(vm.split0Status == .rounded)
    }

    @Test("切り上げ前の実数値を保持する")
    func realMinor() {
        let vm = SplitViewModel.makeForTest(totalRaw: 86_500, persons0: 6)
        #expect(vm.split0RealMinor == 86_500.0 / 6.0)
    }

    @Test("B/C/D の負担を差し引いた残余を A が均等割り")
    func subtractsBCD() {
        // total 30,000 から B(2人×5,000=10,000) を引いて 20,000 を A(2人) で割る → 10,000
        let vm = SplitViewModel.makeForTest(
            totalRaw: 30_000, persons0: 2,
            persons1: 2, split1: 5_000
        )
        #expect(vm.split0 == 10_000)
        #expect(vm.split0Status == .exact)
    }

    @Test("B/C/D の合計が total を超えると A は negative")
    func negative() {
        let vm = SplitViewModel.makeForTest(
            totalRaw: 1_000, persons0: 1,
            persons1: 1, split1: 5_000
        )
        #expect(vm.split0 < 0)
        #expect(vm.split0Status == .negative)
    }

    // MARK: - パラメータ網羅

    @Test("status 判定の境界", arguments: [
        (10_000, 2, 0, 0, Split0Status.exact),    // 5,000 ちょうど
        (10_001, 2, 0, 0, Split0Status.rounded),  // 5,000.5 → 切上
        (10_000, 4, 0, 0, Split0Status.exact),    // 2,500
        (10_002, 4, 0, 0, Split0Status.rounded),  // 2,500.5 → 切上
    ])
    func statusBoundary(total: Int, p0: Int, p1: Int, s1: Int, expected: Split0Status) {
        let vm = SplitViewModel.makeForTest(
            totalRaw: total, persons0: p0, persons1: p1, split1: s1
        )
        #expect(vm.split0Status == expected)
    }

    // MARK: - クランプ

    @Test("persons0 は最低 1 にクランプされる")
    func persons0Clamp() {
        let vm = SplitViewModel.makeForTest(totalRaw: 1_000, persons0: 1)
        vm.persons0 = 0
        #expect(vm.persons0 == 1)
    }

    @Test("totalRaw は 0 未満にならない")
    func totalClamp() {
        let vm = SplitViewModel.makeForTest(totalRaw: 1_000)
        vm.totalRaw = -500
        #expect(vm.totalRaw == 0)
    }

    @Test("金額は 0 未満にならない")
    func splitClamp() {
        let vm = SplitViewModel.makeForTest(totalRaw: 1_000, persons1: 1, split1: 500)
        vm.split1 = -100
        #expect(vm.split1 == 0)
    }

    // MARK: - dialUnit 変更時のスナップ

    @Test("dialUnit を変えると split が新ステップで切り捨て丸めされる")
    func dialUnitSnap() {
        let vm = SplitViewModel.makeForTest(
            totalRaw: 100_000, persons1: 1, split1: 2_550, dialUnit: 10
        )
        vm.dialUnit = 1_000
        // 2,550 → 1,000 単位に切り捨て → 2,000
        #expect(vm.split1 == 2_000)
    }

    // MARK: - adjustA（A を起点に B/C/D を比例縮小）

    @Test("A 目標額を上げると B/C/D が比例縮小する")
    func adjustAReduces() {
        let vm = SplitViewModel.makeForTest(
            totalRaw: 30_000, persons0: 1,
            persons1: 1, persons2: 1,
            split1: 10_000, split2: 10_000
        )
        // A を 20,000 に → 残余 10,000 を B,C(計 20,000) から比例縮小 → 半分
        vm.adjustA(20_000)
        #expect(vm.split1 == 5_000)
        #expect(vm.split2 == 5_000)
    }

    @Test("A が total 以上を占めると B/C/D はゼロ")
    func adjustAZeroesBCD() {
        let vm = SplitViewModel.makeForTest(
            totalRaw: 10_000, persons0: 1,
            persons1: 1, split1: 5_000
        )
        vm.adjustA(10_000)
        #expect(vm.split1 == 0)
    }

    @Test("B/C/D が存在しなければ adjustA は無変更")
    func adjustANoop() {
        let vm = SplitViewModel.makeForTest(totalRaw: 10_000, persons0: 2)
        vm.adjustA(3_000)
        #expect(vm.split1 == 0)
        #expect(vm.split2 == 0)
        #expect(vm.split3 == 0)
    }
}
