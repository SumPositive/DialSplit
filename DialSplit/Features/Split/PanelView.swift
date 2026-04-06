import SwiftUI
import AZCalc
import AZDial

struct PanelView: View {
    @Environment(AppSettings.self) private var settings
    let index: Int
    @Binding var persons: Int
    let perPerson: AZDecimal

    var body: some View {
        BrassFrame {
            HStack(spacing: 14) {
                // Name & result
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.name(for: index))
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.70))
                        .lineLimit(1)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("¥")
                            .font(.callout)
                            .foregroundStyle(.yellow.opacity(0.7))
                        Text(perPerson.isZero ? "---" : perPerson.formatted())
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(.yellow.opacity(0.95))
                            .shadow(color: .black.opacity(0.6), radius: 2)
                            .minimumScaleFactor(0.55)
                    }

                    Text("\(persons)人")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Persons dial
                AZDialView(
                    value: $persons,
                    min: 1,
                    max: 99,
                    step: 1,
                    stepperStep: 1,
                    style: .brass,
                    dialWidth: 160
                )
            }
            .padding(12)
        }
    }
}
