import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DataExportPayload: Codable {
    static let currentVersion = 1

    var version: Int
    var exportedAt: Date
    var accounts: [DataExportAccount]
    var snapshots: [DataExportSnapshot]

    static func make(accounts: [Account], snapshots: [BalanceSnapshot]) -> DataExportPayload {
        let exportAccounts = accounts.map { account in
            DataExportAccount(
                id: String(describing: account.persistentModelID),
                name: account.name,
                currentBalance: DataTransferService.decimalString(from: account.currentBalance),
                lastUpdatedAt: account.lastUpdatedAt,
                createdAt: account.createdAt,
                sortOrder: account.sortOrder
            )
        }

        let exportSnapshots = snapshots.map { snapshot in
            DataExportSnapshot(
                accountID: String(describing: snapshot.account.persistentModelID),
                date: snapshot.date,
                amount: DataTransferService.decimalString(from: snapshot.amount)
            )
        }

        return DataExportPayload(
            version: currentVersion,
            exportedAt: Date(),
            accounts: exportAccounts,
            snapshots: exportSnapshots
        )
    }

    static func decode(from data: Data) throws -> DataExportPayload {
        let payload = try DataTransferCoding.decoder.decode(DataExportPayload.self, from: data)
        guard payload.version <= currentVersion else {
            throw DataTransferError.unsupportedVersion(payload.version)
        }
        return payload
    }

    func encodedData() throws -> Data {
        try DataTransferCoding.encoder.encode(self)
    }
}

struct DataExportAccount: Codable {
    var id: String
    var name: String
    var currentBalance: String
    var lastUpdatedAt: Date?
    var createdAt: Date
    var sortOrder: Int
}

struct DataExportSnapshot: Codable {
    var accountID: String
    var date: Date
    var amount: String
}

enum DataTransferService {
    static func importPayload(
        _ payload: DataExportPayload,
        into context: ModelContext,
        replacingExistingData: Bool
    ) throws {
        if replacingExistingData {
            let existingSnapshots = try context.fetch(FetchDescriptor<BalanceSnapshot>())
            for snapshot in existingSnapshots {
                context.delete(snapshot)
            }
            let existingAccounts = try context.fetch(FetchDescriptor<Account>())
            for account in existingAccounts {
                context.delete(account)
            }
        }

        var accountLookup: [String: Account] = [:]
        for exported in payload.accounts {
            let account = Account(name: exported.name, sortOrder: exported.sortOrder)
            account.currentBalance = try decimal(from: exported.currentBalance)
            account.lastUpdatedAt = exported.lastUpdatedAt
            account.createdAt = exported.createdAt
            context.insert(account)
            accountLookup[exported.id] = account
        }

        for exported in payload.snapshots {
            guard let account = accountLookup[exported.accountID] else { continue }
            let amount = try decimal(from: exported.amount)
            let snapshot = BalanceSnapshot(date: exported.date, amount: amount, account: account)
            context.insert(snapshot)
        }

        try context.save()
    }

    static func decimalString(from value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    static func decimal(from string: String) throws -> Decimal {
        guard let value = Decimal(string: string) else {
            throw DataTransferError.invalidDecimal(string)
        }
        return value
    }
}

enum DataTransferError: LocalizedError {
    case invalidFile
    case unsupportedVersion(Int)
    case invalidDecimal(String)

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "That file couldn’t be read."
        case .unsupportedVersion(let version):
            return "This file uses a newer data format (v\(version))."
        case .invalidDecimal:
            return "One of the values in the file isn’t a valid number."
        }
    }
}

enum DataTransferCoding {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

struct DataExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var payload: DataExportPayload

    init(payload: DataExportPayload) {
        self.payload = payload
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw DataTransferError.invalidFile
        }
        payload = try DataExportPayload.decode(from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try payload.encodedData()
        return FileWrapper(regularFileWithContents: data)
    }
}
