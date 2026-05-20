import SwiftUI
import Foundation

struct SnapshotRowView: View {
    let snapshot: BalanceSnapshot
    var previousAmount: Decimal?
    var showsTrend: Bool = false
    var showsDelta: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.account.name)
                    .font(.headline)
                Text(Formatters.dateString(snapshot.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 6) {
                    if showsTrend, let indicator = trendIndicator {
                        Image(systemName: indicator)
                            .font(.caption)
                    }
                    Text(Formatters.currencyString(snapshot.amount))
                        .font(.headline)
                }
                .foregroundStyle(trendColor)

                if showsDelta, let deltaLine {
                    Text(deltaLine)
                        .font(.caption)
                        .foregroundStyle(deltaColor)
                }
            }
        }
    }

    private var trend: TrendDirection? {
        guard let previousAmount else { return nil }
        if snapshot.amount > previousAmount {
            return .up
        }
        if snapshot.amount < previousAmount {
            return .down
        }
        return nil
    }

    private var trendIndicator: String? {
        switch trend {
        case .up:
            return "arrow.up.right"
        case .down:
            return "arrow.down.right"
        case .none:
            return nil
        }
    }

    private var trendColor: Color {
        guard showsTrend, let trend else { return .primary }
        switch trend {
        case .up:
            return .green.opacity(0.65)
        case .down:
            return .red.opacity(0.65)
        }
    }

    private var deltaLine: String? {
        guard let previousAmount else { return nil }
        let delta = snapshot.amount - previousAmount
        let deltaString = Formatters.currencyString(delta, showsSign: true)
        guard previousAmount != 0 else {
            return deltaString
        }
        let percentValue = (delta as NSDecimalNumber).doubleValue
            / (previousAmount as NSDecimalNumber).doubleValue
        let percentString = Formatters.percentString(percentValue, showsSign: true)
        return "\(deltaString) / \(percentString)"
    }

    private var deltaColor: Color {
        guard showsTrend else { return .secondary }
        switch trend {
        case .up:
            return .green.opacity(0.5)
        case .down:
            return .red.opacity(0.5)
        case .none:
            return .secondary
        }
    }
}

private enum TrendDirection {
    case up
    case down
}
