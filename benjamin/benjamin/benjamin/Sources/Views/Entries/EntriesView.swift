import SwiftUI
import SwiftData

struct EntriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BalanceSnapshot.date) private var snapshots: [BalanceSnapshot]
    @Query(sort: [SortDescriptor(\Account.sortOrder), SortDescriptor(\Account.createdAt)]) private var accounts: [Account]
    @State private var selectedAccountID: PersistentIdentifier?
    @State private var dateRange: EntryRange = .all
    @State private var sortOrder: EntrySort = .newest

    var body: some View {
        List {
            filterChips

            Section("All Entries") {
                if filteredSnapshots.isEmpty {
                    Text("No entries for the current filters.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredSnapshots) { snapshot in
                        SnapshotRowView(snapshot: snapshot)
                    }
                    .onDelete(perform: deleteSnapshots)
                }
            }
        }
        .navigationTitle("Entries")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    accountMenu
                } label: {
                    filterChip(label: "Account", value: selectedAccountLabel)
                }

                Menu {
                    rangeMenu
                } label: {
                    filterChip(label: "Range", value: dateRange.label)
                }

                Menu {
                    sortMenu
                } label: {
                    filterChip(label: "Sort", value: sortOrder.label)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var accountMenu: some View {
        Button("All Accounts") {
            selectedAccountID = nil
        }
        ForEach(accounts) { account in
            Button(account.name) {
                selectedAccountID = account.persistentModelID
            }
        }
    }

    @ViewBuilder
    private var rangeMenu: some View {
        ForEach(EntryRange.allCases) { range in
            Button(range.label) {
                dateRange = range
            }
        }
    }

    @ViewBuilder
    private var sortMenu: some View {
        ForEach(EntrySort.allCases) { sort in
            Button(sort.label) {
                sortOrder = sort
            }
        }
    }

    private func filterChip(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Image(systemName: "chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var selectedAccountLabel: String {
        guard let selectedID = selectedAccountID else {
            return "All"
        }
        return accounts.first { $0.persistentModelID == selectedID }?.name ?? "All"
    }

    private var filteredSnapshots: [BalanceSnapshot] {
        var items = snapshots

        if let selectedID = selectedAccountID {
            items = items.filter { $0.account.persistentModelID == selectedID }
        }

        if let startDate = dateRange.startDate {
            items = items.filter { $0.date >= startDate }
        }

        switch sortOrder {
        case .newest:
            items.sort { $0.date > $1.date }
        case .oldest:
            items.sort { $0.date < $1.date }
        case .amountHigh:
            items.sort { $0.amount > $1.amount }
        case .amountLow:
            items.sort { $0.amount < $1.amount }
        }

        return items
    }

    private func deleteSnapshots(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredSnapshots[index])
        }
        try? modelContext.save()
    }
}

private enum EntryRange: String, CaseIterable, Identifiable {
    case all
    case last30
    case last90
    case yearToDate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:
            return "All time"
        case .last30:
            return "Last 30 days"
        case .last90:
            return "Last 90 days"
        case .yearToDate:
            return "Year to date"
        }
    }

    var startDate: Date? {
        let calendar = Calendar.current
        switch self {
        case .all:
            return nil
        case .last30:
            return calendar.date(byAdding: .day, value: -30, to: Date())
        case .last90:
            return calendar.date(byAdding: .day, value: -90, to: Date())
        case .yearToDate:
            let year = calendar.component(.year, from: Date())
            return calendar.date(from: DateComponents(year: year))
        }
    }
}

private enum EntrySort: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case amountHigh
    case amountLow

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest:
            return "Newest first"
        case .oldest:
            return "Oldest first"
        case .amountHigh:
            return "Amount high to low"
        case .amountLow:
            return "Amount low to high"
        }
    }
}
