import SwiftUI
import SwiftData

struct SnapshotEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Account.sortOrder), SortDescriptor(\Account.createdAt)]) private var accounts: [Account]
    @State private var selectedDate = Date()
    @State private var isDatePickerPresented = false
    @State private var isAccountPickerPresented = false
    @State private var currentAccountIndex = 0
    @State private var amountEntry = ""
    @State private var entryByKey: [EntryKey: String] = [:]

    var body: some View {
        VStack(spacing: 0) {
            accountTitle
                .padding(.top, 24)
            amountDisplay
                .padding(.top, 12)
            if showsEmptyHint {
                Text("No entry for this day")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            Spacer(minLength: 24)

            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 16) {
                    keypad
                    nextButtonRow
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(dateButtonTitle) {
                    isDatePickerPresented = true
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: finishEntryFlow) {
                    Image(systemName: "checkmark")
                }
                .disabled(accounts.isEmpty)
            }
        }
        .sheet(isPresented: $isDatePickerPresented) {
            SnapshotDatePickerSheet(
                selectedDate: $selectedDate,
                onDone: { isDatePickerPresented = false }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $isAccountPickerPresented) {
            AccountPickerSheet(
                accounts: accounts,
                currentAccountIndex: currentAccountIndex,
                entryValueForAccount: entryValueForAccount,
                onSelect: { index in
                    selectAccount(at: index)
                    isAccountPickerPresented = false
                },
                onDone: { isAccountPickerPresented = false }
            )
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            loadCurrentEntry()
        }
        .onChange(of: currentAccountIndex) { _, _ in
            loadCurrentEntry()
        }
        .onChange(of: selectedDate) { oldValue, _ in
            commitCurrentEntry(for: oldValue)
            loadCurrentEntry()
        }
        .onChange(of: amountEntry) { _, _ in
            commitCurrentEntry()
        }
        .onChange(of: accounts.count) { _, _ in
            clampCurrentAccountIndex()
        }
    }

    private var dateButtonTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: selectedDate)
    }

    private var accountTitle: some View {
        Button(action: { isAccountPickerPresented = true }) {
            HStack(spacing: 4) {
                Text(currentAccount?.name ?? "Account")
                    .font(.headline)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func selectAccount(at index: Int) {
        guard index != currentAccountIndex else { return }
        commitCurrentEntry()
        currentAccountIndex = index
    }

    private func entryValueForAccount(_ account: Account) -> String? {
        if account.persistentModelID == currentAccount?.persistentModelID {
            if !amountEntry.isEmpty, let value = decimalValue(from: amountEntry) {
                return formattedCurrency(value)
            } else if !amountEntry.isEmpty {
                return amountEntry
            }
        }
        let key = EntryKey(accountID: account.persistentModelID, day: selectedDay)
        if let entry = entryByKey[key], !entry.isEmpty {
            if let value = decimalValue(from: entry) {
                return formattedCurrency(value)
            }
            return entry
        }
        if let snapshot = snapshotFor(account: account, on: selectedDay) {
            return formattedCurrency(snapshot.amount)
        }
        return nil
    }

    private var amountDisplay: some View {
        VStack(spacing: 4) {
            Text(formattedAmountEntry)
                .font(.system(size: 36, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            
            if let lastValue = lastSnapshotValue {
                Button(action: { fillWithLastValue(lastValue) }) {
                    HStack(spacing: 4) {
                        Text("Last:")
                            .foregroundStyle(.secondary)
                        Text(formattedCurrency(lastValue))
                            .foregroundStyle(.primary)
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var keypad: some View {
        LazyVGrid(columns: keypadColumns, spacing: keypadRowSpacing) {
            ForEach(keypadKeys, id: \.self) { key in
                Button(action: { handleKeyTap(key) }) {
                    keypadLabel(for: key)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(GlassCircleButtonStyle())
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .frame(minWidth: keypadButtonMinSize, minHeight: keypadButtonMinSize)
            }
        }
        .frame(maxWidth: keypadMaxWidth)
    }

    private var keypadKeys: [KeypadKey] {
        [
            .digit("1"), .digit("2"), .digit("3"),
            .digit("4"), .digit("5"), .digit("6"),
            .digit("7"), .digit("8"), .digit("9"),
            .decimal, .digit("0"), .delete,
        ]
    }

    private var keypadColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: keypadButtonMinSize), spacing: keypadColumnSpacing), count: 3)
    }

    private var keypadButtonMinSize: CGFloat {
        76
    }

    private var keypadRowSpacing: CGFloat {
        16
    }

    private var keypadColumnSpacing: CGFloat {
        24
    }

    private var keypadMaxWidth: CGFloat {
        300
    }

    private var isLastAccount: Bool {
        currentAccountIndex >= accounts.count - 1
    }

    private var nextButtonRow: some View {
        HStack {
            Spacer()
            if isLastAccount {
                Button(action: finishEntryFlow) {
                    HStack(spacing: 6) {
                        Text("Done")
                        Image(systemName: "checkmark")
                            .font(.caption)
                    }
                }
                .buttonStyle(GlassRoundedButtonStyle())
            } else {
                Button(action: goToNextAccount) {
                    HStack(spacing: 6) {
                        Text("Next")
                        Image(systemName: "arrow.right")
                            .font(.caption)
                    }
                }
                .buttonStyle(GlassRoundedButtonStyle())
            }
        }
        .padding(.top, 4)
    }

    private var currentAccount: Account? {
        guard accounts.indices.contains(currentAccountIndex) else { return nil }
        return accounts[currentAccountIndex]
    }

    private func commitCurrentEntry() {
        commitCurrentEntry(for: selectedDay)
    }

    private func commitCurrentEntry(for day: Date) {
        guard let account = currentAccount else { return }
        let dayKey = Calendar.current.startOfDay(for: day)
        let key = EntryKey(accountID: account.persistentModelID, day: dayKey)
        entryByKey[key] = amountEntry
    }

    private func finishEntryFlow() {
        commitCurrentEntry()
        let snapshotDate = selectedDay
        for account in accounts {
            let key = EntryKey(accountID: account.persistentModelID, day: snapshotDate)
            guard let entry = entryByKey[key],
                  let value = decimalValue(from: entry) else { continue }
            if let existing = snapshotFor(account: account, on: snapshotDate) {
                existing.amount = value
            } else {
                let snapshot = BalanceSnapshot(date: snapshotDate, amount: value, account: account)
                modelContext.insert(snapshot)
            }
            if account.lastUpdatedAt == nil || snapshotDate >= (account.lastUpdatedAt ?? snapshotDate) {
                account.currentBalance = value
                account.lastUpdatedAt = snapshotDate
            }
        }
        try? modelContext.save()
        dismiss()
    }

    private func goToNextAccount() {
        commitCurrentEntry()
        guard !accounts.isEmpty, currentAccountIndex < accounts.count - 1 else { return }
        currentAccountIndex += 1
    }

    private func loadCurrentEntry() {
        guard let account = currentAccount else {
            amountEntry = ""
            return
        }
        let key = EntryKey(accountID: account.persistentModelID, day: selectedDay)
        if let entry = entryByKey[key] {
            amountEntry = entry
            return
        }
        if let existing = snapshotFor(account: account, on: selectedDay) {
            amountEntry = amountString(from: existing.amount)
        } else {
            amountEntry = ""
        }
    }

    private func clampCurrentAccountIndex() {
        guard currentAccountIndex >= accounts.count else { return }
        currentAccountIndex = max(0, accounts.count - 1)
    }

    private func handleKeyTap(_ key: KeypadKey) {
        switch key {
        case .digit(let value):
            if amountEntry == "0" {
                amountEntry = value
            } else {
                amountEntry.append(value)
            }
        case .decimal:
            let separator = decimalSeparator
            guard !amountEntry.contains(separator) else { return }
            amountEntry = amountEntry.isEmpty ? "0\(separator)" : amountEntry + separator
        case .delete:
            guard !amountEntry.isEmpty else { return }
            amountEntry.removeLast()
        }
    }

    private func decimalValue(from entry: String) -> Decimal? {
        let normalized = entry.replacingOccurrences(of: decimalSeparator, with: ".")
        return Decimal(string: normalized)
    }

    private func amountString(from value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 6
        formatter.locale = Locale.current
        return formatter.string(from: value as NSDecimalNumber) ?? "0"
    }

    private var selectedDay: Date {
        Calendar.current.startOfDay(for: selectedDate)
    }

    private var showsEmptyHint: Bool {
        guard let account = currentAccount else { return false }
        return amountEntry.isEmpty && snapshotFor(account: account, on: selectedDay) == nil
    }

    private func snapshotFor(account: Account, on day: Date) -> BalanceSnapshot? {
        account.snapshots.first { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    private var lastSnapshotValue: Decimal? {
        guard let account = currentAccount else { return nil }
        let latestSnapshot = account.snapshots
            .filter { !Calendar.current.isDate($0.date, inSameDayAs: selectedDay) }
            .max(by: { $0.date < $1.date })
        return latestSnapshot?.amount
    }

    private func fillWithLastValue(_ value: Decimal) {
        amountEntry = amountString(from: value)
    }

    private func formattedCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.locale = Locale.current
        return formatter.string(from: value as NSDecimalNumber) ?? "0"
    }

    private var decimalSeparator: String {
        Locale.current.decimalSeparator ?? "."
    }

    private var formattedAmountEntry: String {
        guard !amountEntry.isEmpty else { return "0" }
        let separator = decimalSeparator
        let parts = amountEntry.split(separator: Character(separator), maxSplits: 1, omittingEmptySubsequences: false)
        let integerPart = String(parts.first ?? "0")
        let fractionPart = parts.count > 1 ? String(parts[1]) : nil

        let formattedInteger = formattedIntegerPart(integerPart)
        if let fractionPart {
            return formattedInteger + separator + fractionPart
        }
        return formattedInteger
    }

    private func formattedIntegerPart(_ value: String) -> String {
        let digits = value.isEmpty ? "0" : value
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale.current
        return formatter.string(from: NSDecimalNumber(string: digits)) ?? digits
    }
}

private enum KeypadKey: Hashable {
    case digit(String)
    case decimal
    case delete
}

private struct SnapshotDatePickerSheet: View {
    @Binding var selectedDate: Date
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(Formatters.dateString(selectedDate))
                    .font(.headline)

                DatePicker("Snapshot date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
            }
            .padding()
            .navigationTitle("Snapshot Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
    }
}

private struct AccountPickerSheet: View {
    let accounts: [Account]
    let currentAccountIndex: Int
    let entryValueForAccount: (Account) -> String?
    let onSelect: (Int) -> Void
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                    Button(action: { onSelect(index) }) {
                        HStack {
                            Text(account.name)
                            Spacer()
                            if let entryValue = entryValueForAccount(account) {
                                Text(entryValue)
                                    .foregroundStyle(.secondary)
                            }
                            if index == currentAccountIndex {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
    }
}

private struct EntryKey: Hashable {
    let accountID: PersistentIdentifier
    let day: Date
}

@ViewBuilder
private func keypadLabel(for key: KeypadKey) -> some View {
    switch key {
    case .digit(let value):
        Text(value)
            .font(.system(size: 24, weight: .medium))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .decimal:
        Text(Locale.current.decimalSeparator ?? ".")
            .font(.system(size: 24, weight: .medium))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .delete:
        Image(systemName: "delete.left")
            .font(.system(size: 24, weight: .medium))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SnapshotEntryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SnapshotEntryView()
        }
        .modelContainer(previewContainer)
    }

    private static var previewContainer: ModelContainer = {
        let schema = Schema([Account.self, BalanceSnapshot.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        context.insert(Account(name: "Checking"))
        context.insert(Account(name: "Savings"))
        return container
    }()
}
