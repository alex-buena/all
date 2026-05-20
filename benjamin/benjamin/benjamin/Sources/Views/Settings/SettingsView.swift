import SwiftUI

struct SettingsView: View {
    @AppStorage("settings.currencyCode") private var currencyCode = "EUR"
    @AppStorage("settings.remindersEnabled") private var remindersEnabled = false
    @AppStorage("settings.reminderTime") private var reminderTime = Date()
    @AppStorage("settings.reminderWeekday") private var reminderWeekday = 2

    var body: some View {
        Form {
            Section("Currency") {
                Picker("Default currency", selection: $currencyCode) {
                    ForEach(currencies, id: \.code) { currency in
                        Text("\(currency.symbol) \(currency.code)")
                            .tag(currency.code)
                    }
                }
            }

            Section("Reminders") {
                Toggle("Weekly reminder", isOn: $remindersEnabled)
                if remindersEnabled {
                    Picker("Day", selection: $reminderWeekday) {
                        ForEach(weekdayOptions, id: \.value) { weekday in
                            Text(weekday.label).tag(weekday.value)
                        }
                    }
                    DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                }
            }

            Section {
                NavigationLink("Backup") {
                    BackupView()
                }
            }
        }
        .navigationTitle("Settings")
        .onChange(of: remindersEnabled) { _, isEnabled in
            Task { @MainActor in
                if isEnabled {
                    let granted = await ReminderScheduler.requestAuthorization()
                    if granted {
                        await ReminderScheduler.scheduleWeeklyReminder(
                            weekday: reminderWeekday,
                            time: reminderTime
                        )
                    } else {
                        remindersEnabled = false
                    }
                } else {
                    await ReminderScheduler.cancelReminder()
                }
            }
        }
        .onChange(of: reminderWeekday) { _, _ in
            Task {
                guard remindersEnabled else { return }
                await ReminderScheduler.scheduleWeeklyReminder(
                    weekday: reminderWeekday,
                    time: reminderTime
                )
            }
        }
        .onChange(of: reminderTime) { _, _ in
            Task {
                guard remindersEnabled else { return }
                await ReminderScheduler.scheduleWeeklyReminder(
                    weekday: reminderWeekday,
                    time: reminderTime
                )
            }
        }
    }

    private var currencies: [CurrencyOption] {
        [
            CurrencyOption(code: "EUR", symbol: "€"),
            CurrencyOption(code: "USD", symbol: "$"),
            CurrencyOption(code: "GBP", symbol: "£"),
            CurrencyOption(code: "CHF", symbol: "CHF"),
        ]
    }

    private var weekdayOptions: [WeekdayOption] {
        [
            WeekdayOption(value: 2, label: "Monday"),
            WeekdayOption(value: 3, label: "Tuesday"),
            WeekdayOption(value: 4, label: "Wednesday"),
            WeekdayOption(value: 5, label: "Thursday"),
            WeekdayOption(value: 6, label: "Friday"),
            WeekdayOption(value: 7, label: "Saturday"),
            WeekdayOption(value: 1, label: "Sunday"),
        ]
    }
}

private struct CurrencyOption {
    let code: String
    let symbol: String
}

private struct WeekdayOption {
    let value: Int
    let label: String
}
