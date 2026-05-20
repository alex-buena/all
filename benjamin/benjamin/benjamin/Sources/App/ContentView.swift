import SwiftUI
import SwiftData

public struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Query(sort: [SortDescriptor(\Account.sortOrder), SortDescriptor(\Account.createdAt)]) private var accounts: [Account]

    public init() {}

    public var body: some View {
        if hasCompletedOnboarding && !accounts.isEmpty {
            HomeView()
        } else {
            OnboardingView(accounts: accounts) {
                hasCompletedOnboarding = true
            }
        }
    }
}

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var accountName = ""
    @FocusState private var isNameFocused: Bool
    let accounts: [Account]
    var onFinish: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Add Account") {
                    TextField("Account name", text: $accountName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .focused($isNameFocused)
                        .onSubmit(addAccount)
                    if showsDuplicateHint {
                        Text("That account already exists.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button("Add another account", action: addAccount)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canAddAccount)
                }

                Section("Your Accounts") {
                    if accounts.isEmpty {
                        Text("No accounts yet. Add your first one above.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(accounts) { account in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.name)
                                    .font(.headline)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Get Started")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish", action: onFinish)
                        .disabled(accounts.isEmpty)
                }
            }
            .onAppear {
                if accounts.isEmpty {
                    isNameFocused = true
                }
            }
        }
    }

    private var accountNameTrimmed: String {
        accountName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedAccountName: String {
        accountNameTrimmed.lowercased()
    }

    private var showsDuplicateHint: Bool {
        !normalizedAccountName.isEmpty && !canAddAccount
    }

    private var canAddAccount: Bool {
        guard !normalizedAccountName.isEmpty else { return false }
        return !accounts.contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedAccountName }
    }

    private func addAccount() {
        let trimmedName = accountNameTrimmed
        guard canAddAccount else { return }
        let account = Account(name: trimmedName, sortOrder: nextSortOrder())
        modelContext.insert(account)
        try? modelContext.save()
        accountName = ""
        isNameFocused = true
    }

    private func nextSortOrder() -> Int {
        (accounts.map(\.sortOrder).max() ?? -1) + 1
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .modelContainer(previewContainer)
            .environmentObject(AppState())
    }

    private static var previewContainer: ModelContainer = {
        let schema = Schema([Account.self, BalanceSnapshot.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()
}
