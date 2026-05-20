import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @Query(sort: [SortDescriptor(\Account.sortOrder), SortDescriptor(\Account.createdAt)]) private var accounts: [Account]
    @Query(sort: \BalanceSnapshot.date) private var snapshots: [BalanceSnapshot]
    @State private var isSnapshotSheetPresented = false
    @State private var path: [HomeDestination] = []
    @State private var selectedGraphIndex: Int?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                VStack(spacing: 16) {
                    totalSummary
                    NetWorthGraph(
                        dataPoints: graphDataPoints,
                        lineColor: .green,
                        selectedIndex: $selectedGraphIndex
                    )
                    .frame(height: 96)
                    .padding(.horizontal, 8)
                }
                .padding(.vertical, 16)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 40, trailing: 0))
                .listRowSeparator(.hidden)

                Section {
                    Button(action: { path.append(.entries) }) {
                        HStack(spacing: 6) {
                            Text("Recent Entries")
                                .font(.headline)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .padding(.top, 8)

                    if latestSnapshots.isEmpty {
                        Text("No entries yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(groupedSnapshots, id: \.date) { group in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(Formatters.relativeDateString(group.date))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, group.date == groupedSnapshots.first?.date ? 4 : 12)
                                    .padding(.bottom, 8)

                                VStack(spacing: 0) {
                                    ForEach(Array(group.snapshots.enumerated()), id: \.element.id) { index, snapshot in
                                        SnapshotRowView(
                                            snapshot: snapshot,
                                            previousAmount: previousSnapshot(for: snapshot)?.amount,
                                            showsTrend: true,
                                            showsDelta: true
                                        )
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)

                                        if index < group.snapshots.count - 1 {
                                            Divider()
                                                .padding(.leading, 12)
                                        }
                                    }
                                }
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .listSectionSeparator(.hidden)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Accounts") {
                            path.append(.accounts)
                        }
                        Button("Settings") {
                            path.append(.settings)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                GlassEffectContainer(spacing: 12) {
                    HStack {
                        Spacer()
                        Button(action: { isSnapshotSheetPresented = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .frame(width: 56, height: 56)
                        }
                        .buttonStyle(GlassCircleButtonStyle())
                        Spacer()
                    }
                }
                .padding(.bottom, 4)
            }
            .sheet(isPresented: $isSnapshotSheetPresented) {
                NavigationStack {
                    SnapshotEntryView()
                }
                .presentationDetents([.large])
            }
            .onChange(of: appState.showSnapshotEntry) { _, shouldShow in
                guard shouldShow else { return }
                isSnapshotSheetPresented = true
                appState.showSnapshotEntry = false
            }
            .onAppear {
                if appState.showSnapshotEntry {
                    isSnapshotSheetPresented = true
                    appState.showSnapshotEntry = false
                }
            }
            .navigationDestination(for: HomeDestination.self) { destination in
                switch destination {
                case .accounts:
                    AccountsView()
                case .entries:
                    EntriesView()
                case .settings:
                    SettingsView()
                }
            }
        }
    }

    private var totalSummary: some View {
        VStack(spacing: 8) {
            Text("Total Net Worth")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(displayedAmountText)
                .font(.system(size: 44, weight: .semibold))
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.15), value: selectedGraphIndex)
        }
        .frame(maxWidth: .infinity)
    }

    private var displayedAmountText: String {
        if let selectedIndex = selectedGraphIndex,
           selectedIndex < graphDataPoints.count {
            let dataPoint = graphDataPoints[selectedIndex]
            return Formatters.currencyString(Decimal(dataPoint.value))
        }
        return totalAmountText
    }

    private var totalAmount: Decimal {
        accounts.reduce(Decimal(0)) { $0 + $1.currentBalance }
    }

    private var totalAmountText: String {
        Formatters.currencyString(totalAmount)
    }

    private var graphDataPoints: [GraphDataPoint] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: snapshots) { snapshot in
            calendar.startOfDay(for: snapshot.date)
        }
        var dataPoints = grouped
            .map { date, items in
                GraphDataPoint(
                    date: date,
                    value: Double(truncating: NSDecimalNumber(decimal: items.reduce(Decimal(0)) { $0 + $1.amount }))
                )
            }
            .sorted { $0.date < $1.date }

        if dataPoints.isEmpty && !accounts.isEmpty {
            let total = Double(truncating: NSDecimalNumber(decimal: totalAmount))
            dataPoints = [
                GraphDataPoint(date: Date(), value: total),
                GraphDataPoint(date: Date(), value: total)
            ]
        } else if dataPoints.count == 1 {
            dataPoints.append(GraphDataPoint(date: dataPoints[0].date, value: dataPoints[0].value))
        }

        if dataPoints.count > 12 {
            dataPoints = Array(dataPoints.suffix(12))
        }

        return dataPoints
    }

    private var graphValues: [Double] {
        graphDataPoints.map { $0.value }
    }

    private var latestSnapshots: [BalanceSnapshot] {
        Array(snapshots.sorted { $0.date > $1.date }.prefix(20))
    }

    private var groupedSnapshots: [SnapshotDateGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: latestSnapshots) { snapshot in
            calendar.startOfDay(for: snapshot.date)
        }
        return grouped
            .map { SnapshotDateGroup(
                date: $0.key,
                snapshots: $0.value.sorted {
                    if $0.account.sortOrder != $1.account.sortOrder {
                        return $0.account.sortOrder < $1.account.sortOrder
                    }
                    return $0.account.createdAt < $1.account.createdAt
                }
            )}
            .sorted { $0.date > $1.date }
    }

    private func previousSnapshot(for snapshot: BalanceSnapshot) -> BalanceSnapshot? {
        snapshot.account.snapshots
            .filter { $0.date < snapshot.date }
            .max { $0.date < $1.date }
    }
}

private enum HomeDestination: Hashable {
    case accounts
    case entries
    case settings
}

private struct SnapshotDateGroup {
    let date: Date
    let snapshots: [BalanceSnapshot]
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .modelContainer(previewContainer)
            .environmentObject(AppState())
    }

    private static var previewContainer: ModelContainer = {
        let schema = Schema([Account.self, BalanceSnapshot.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let checking = Account(name: "Checking")
        checking.currentBalance = 1200.50
        let savings = Account(name: "Savings")
        savings.currentBalance = 3400.00
        context.insert(checking)
        context.insert(savings)
        return container
    }()
}
