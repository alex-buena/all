import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Account.sortOrder), SortDescriptor(\Account.createdAt)]) private var accounts: [Account]
    @State private var editorMode: AccountEditorMode?

    var body: some View {
        List {
            if accounts.isEmpty {
                Text("No accounts yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(accounts) { account in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(account.name)
                            .font(.headline)
                        Text(Formatters.currencyString(account.currentBalance))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button("Edit") {
                            editorMode = .edit(account)
                        }
                        .tint(.blue)
                    }
                }
                .onMove(perform: moveAccounts)
                .onDelete(perform: deleteAccounts)
            }
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorMode = .add
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editorMode) { mode in
            switch mode {
            case .add:
                AccountEditorView(title: "Add Account", initialName: "") { name in
                    addAccount(named: name)
                }
            case .edit(let account):
                AccountEditorView(title: "Edit Account", initialName: account.name) { name in
                    updateAccount(account, name: name)
                }
            }
        }
    }

    private func addAccount(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(Account(name: trimmed, sortOrder: nextSortOrder()))
        try? modelContext.save()
    }

    private func updateAccount(_ account: Account, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        account.name = trimmed
        try? modelContext.save()
    }

    private func deleteAccounts(at offsets: IndexSet) {
        var remaining = accounts
        remaining.remove(atOffsets: offsets)
        for index in offsets {
            modelContext.delete(accounts[index])
        }
        resequenceAccounts(remaining)
        try? modelContext.save()
    }

    private func moveAccounts(from source: IndexSet, to destination: Int) {
        var updated = accounts
        updated.move(fromOffsets: source, toOffset: destination)
        resequenceAccounts(updated)
        try? modelContext.save()
    }

    private func resequenceAccounts(_ orderedAccounts: [Account]) {
        for (index, account) in orderedAccounts.enumerated() {
            account.sortOrder = index
        }
    }

    private func nextSortOrder() -> Int {
        (accounts.map(\.sortOrder).max() ?? -1) + 1
    }
}

private enum AccountEditorMode: Identifiable {
    case add
    case edit(Account)

    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let account):
            return String(describing: account.persistentModelID)
        }
    }
}

private struct AccountEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    let title: String
    let onSave: (String) -> Void

    init(title: String, initialName: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Account name", text: $name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
