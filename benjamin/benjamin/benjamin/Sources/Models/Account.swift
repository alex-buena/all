import Foundation
import SwiftData

@Model
final class Account {
    var name: String
    var currentBalance: Decimal
    var lastUpdatedAt: Date?
    var createdAt: Date
    var sortOrder: Int = 0
    @Relationship(deleteRule: .cascade, inverse: \BalanceSnapshot.account)
    var snapshots: [BalanceSnapshot] = []

    init(name: String, sortOrder: Int = 0) {
        self.name = name
        self.currentBalance = 0
        self.lastUpdatedAt = nil
        self.createdAt = Date()
        self.sortOrder = sortOrder
    }
}
