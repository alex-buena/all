import SwiftData
import SwiftUI

struct BackupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Account.sortOrder), SortDescriptor(\Account.createdAt)]) private var accounts: [Account]
    @Query(sort: \BalanceSnapshot.date) private var snapshots: [BalanceSnapshot]
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportDocument = DataExportDocument(
        payload: DataExportPayload(
            version: DataExportPayload.currentVersion,
            exportedAt: Date(),
            accounts: [],
            snapshots: []
        )
    )
    @State private var pendingImport: DataExportPayload?
    @State private var showsReplaceSheet = false
    @State private var dataAlert: DataAlert?

    var body: some View {
        Form {
            Section("Backup") {
                Button("Export data") {
                    exportDocument = DataExportDocument(payload: DataExportPayload.make(accounts: accounts, snapshots: snapshots))
                    isExporting = true
                }
                .disabled(accounts.isEmpty && snapshots.isEmpty)

                Button("Import data") {
                    isImporting = true
                }
            }
        }
        .navigationTitle("Backup")
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "benjamin-data"
        ) { result in
            if case .failure(let error) = result {
                dataAlert = DataAlert(
                    title: "Export Failed",
                    message: error.localizedDescription
                )
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                handleImport(from: url)
            case .failure(let error):
                dataAlert = DataAlert(
                    title: "Import Failed",
                    message: error.localizedDescription
                )
            }
        }
        .sheet(isPresented: $showsReplaceSheet) {
            ReplaceDataSheet(
                onConfirm: {
                    guard let payload = pendingImport else { return }
                    importPayload(payload)
                },
                onCancel: {
                    pendingImport = nil
                    showsReplaceSheet = false
                }
            )
            .presentationDetents([.medium])
        }
        .alert(item: $dataAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func handleImport(from url: URL) {
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let payload = try DataExportPayload.decode(from: data)
            pendingImport = payload
            showsReplaceSheet = true
        } catch {
            dataAlert = DataAlert(
                title: "Import Failed",
                message: error.localizedDescription
            )
        }
    }

    private func importPayload(_ payload: DataExportPayload) {
        do {
            try DataTransferService.importPayload(payload, into: modelContext, replacingExistingData: true)
            pendingImport = nil
            showsReplaceSheet = false
        } catch {
            dataAlert = DataAlert(
                title: "Import Failed",
                message: error.localizedDescription
            )
        }
    }
}

private struct ReplaceDataSheet: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Replace existing data?")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text("Importing will replace your current accounts and snapshots.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    Button("Replace Data", role: .destructive, action: onConfirm)
                        .buttonStyle(.borderedProminent)
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.bordered)
                }
                .padding(.top, 8)
            }
            .padding()
            .navigationTitle("Confirm Import")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct DataAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
