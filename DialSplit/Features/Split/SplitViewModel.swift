import SwiftUI
import AZDecimal

@Observable
final class SplitViewModel {
    var persons: [Int]

    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
        self.persons = Array(repeating: 1, count: settings.panelCount)
    }

    func perPerson(totalAmount: AZDecimal) -> AZDecimal {
        let total = persons.reduce(0, +)
        guard total > 0, !totalAmount.isZero else { return .zero }
        let divisor = AZDecimal("\(total)")
        return (totalAmount / divisor).rounded(settings.roundConfig)
    }

    func syncCount() {
        let count = settings.panelCount
        while persons.count < count { persons.append(1) }
        if persons.count > count { persons = Array(persons.prefix(count)) }
    }
}
