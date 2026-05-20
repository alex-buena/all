import Foundation
import SwiftData

@Model
final class BalanceSnapshot {
    var date: Date
    var amount: Decimal
    var account: Account

    init(date: Date, amount: Decimal, account: Account) {
        self.date = date
        self.amount = amount
        self.account = account
    }
}
