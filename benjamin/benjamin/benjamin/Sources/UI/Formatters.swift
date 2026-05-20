import Foundation

enum Formatters {
    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let signedCurrencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+" + (formatter.positivePrefix ?? "")
        return formatter
    }()

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    private static let signedPercentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        formatter.positivePrefix = "+" + (formatter.positivePrefix ?? "")
        return formatter
    }()

    static func dateString(_ date: Date) -> String {
        self.date.string(from: date)
    }

    static func relativeDateString(_ date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)

        if target == today {
            return "Today"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), target == yesterday {
            return "Yesterday"
        }
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: today), target > weekAgo {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"
            return weekdayFormatter.string(from: date)
        }
        return self.date.string(from: date)
    }

    static func currencyString(_ value: Decimal, showsSign: Bool = false) -> String {
        let formatter = showsSign ? signedCurrencyFormatter : currencyFormatter
        return formatter.string(from: value as NSDecimalNumber) ?? "0"
    }

    static func percentString(_ value: Double, showsSign: Bool = false) -> String {
        let formatter = showsSign ? signedPercentFormatter : percentFormatter
        return formatter.string(from: NSNumber(value: value)) ?? "0%"
    }
}
