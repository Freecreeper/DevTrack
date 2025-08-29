import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("dailyReminder") private var dailyReminder = false
    @AppStorage("dailyReminderTime") private var dailyReminderTimeInterval: Double = Date().timeIntervalSince1970
    @AppStorage("codeTheme") private var codeTheme = "Xcode Dark"
    @AppStorage("autoStartTimer") private var autoStartTimer = false
    @State private var showingExportAlert = false
    @State private var showingImportPicker = false
    @State private var dailyReminderDate: Date = Date()
    
    // Backing Date via Double for broad iOS compatibility (AppStorage doesn't natively support Date on earlier iOS)
    private var dailyReminderTime: Date {
        get { Date(timeIntervalSince1970: dailyReminderTimeInterval) }
        set { dailyReminderTimeInterval = newValue.timeIntervalSince1970 }
    }
    
    // iOS 14+ compatible CSV UTType
    private var csvUTType: UTType {
        UTType(filenameExtension: "csv") ?? .plainText
    }
    
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        NavigationView {
            Form {
                // Appearance Section
                Section(header: Text("APPEARANCE")) {
                    Toggle("Dark Mode", isOn: $isDarkMode)
                    
                    Picker("Code Theme", selection: $codeTheme) {
                        ForEach(["Xcode Dark", "Solarized Dark", "Monokai", "Dracula", "GitHub"], id: \.self) {
                            Text($0)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Notifications Section
                Section(header: Text("NOTIFICATIONS")) {
                    Toggle("Enable Notifications", isOn: $enableNotifications)
                    
                    if enableNotifications {
                        Toggle("Daily Reminder", isOn: $dailyReminder)
                        
                        if dailyReminder {
                            DatePicker(
                                "Reminder Time",
                                selection: $dailyReminderDate,
                                displayedComponents: .hourAndMinute
                            )
                            .onAppear {
                                dailyReminderDate = Date(timeIntervalSince1970: dailyReminderTimeInterval)
                            }
                            .onChange(of: dailyReminderDate) { newValue in
                                dailyReminderTimeInterval = newValue.timeIntervalSince1970
                            }
                        }
                    }
                }
                
                // Timer Section
                Section(header: Text("TIMER")) {
                    Toggle("Auto-start Timer", isOn: $autoStartTimer)
                    
                    NavigationLink(destination: IdleTimerSettingsView()) {
                        HStack {
                            Text("Idle Timeout")
                            Spacer()
                            Text("5 min")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Data Management Section
                Section(header: Text("DATA")) {
                    Button(action: { showingExportAlert = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export Data")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: { showingImportPicker = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import Data")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: showResetConfirmation) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Reset All Data")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.red)
                }
                
                // Support Section
                Section(header: Text("SUPPORT")) {
                    Button(action: { openURL("mailto:support@devtrack.app") }) {
                        HStack {
                            Image(systemName: "envelope")
                            Text("Contact Support")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: { openURL("https://devtrack.app/help") }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("Help & FAQ")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    NavigationLink(destination: AboutView()) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("About DevTrack")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Legal Section
                Section {
                    Button(action: { openURL("https://devtrack.app/privacy") }) {
                        Text("Privacy Policy")
                    }
                    
                    Button(action: { openURL("https://devtrack.app/terms") }) {
                        Text("Terms of Service")
                    }
                }
                
                // App Version
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("DevTrack")
                                .font(.headline)
                            Text("Version \(appVersion) (\(buildNumber))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Settings")
            .alert("Export Data", isPresented: $showingExportAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Export as JSON") { exportData(format: "json") }
                Button("Export as CSV") { exportData(format: "csv") }
            } message: {
                Text("Choose the format to export your data:")
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [UTType.json, csvUTType],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        importData(from: url)
                    }
                case .failure(let error):
                    print("Error selecting file: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showResetConfirmation() {
        let alert = UIAlertController(
            title: "Reset All Data",
            message: "This will delete all your time entries and journal entries. This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { _ in
            // Reset all data
            resetAllData()
        })
        
        // Present the alert
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    private func resetAllData() {
        // Clear sessions
        sessionStore.clearAll()
        
        // Reset preferences
        isDarkMode = false
        enableNotifications = true
        dailyReminder = false
        dailyReminderTimeInterval = Date().timeIntervalSince1970
        codeTheme = "Xcode Dark"
        autoStartTimer = false
        UserDefaults.standard.synchronize()
    }
    
    private func exportData(format: String) {
        let url: URL?
        if format.lowercased() == "json" {
            url = sessionStore.exportJSON()
        } else {
            url = sessionStore.exportCSV()
        }
        guard let shareURL = url else { return }
        shareFile(shareURL)
    }
    
    private func importData(from url: URL) {
        var importedCount = 0
        var errorToShow: Error?
        let shouldStop = url.startAccessingSecurityScopedResource()
        defer { if shouldStop { url.stopAccessingSecurityScopedResource() } }
        do {
            let ext = url.pathExtension.lowercased()
            if ext == "json" {
                importedCount = try sessionStore.importJSON(from: url)
            } else if ext == "csv" {
                importedCount = try sessionStore.importCSV(from: url)
            } else {
                showAlert(title: "Unsupported File", message: "Please select a JSON or CSV file.")
                return
            }
        } catch {
            errorToShow = error
        }
        if let e = errorToShow {
            showAlert(title: "Import Failed", message: e.localizedDescription)
        } else {
            showAlert(title: "Import Complete", message: "Imported \(importedCount) sessions.")
        }
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Helpers
    private func shareFile(_ url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
}

// MARK: - Supporting Views

struct IdleTimerSettingsView: View {
    @AppStorage("idleTimeout") private var idleTimeout = 5
    
    let timeouts = [1, 5, 10, 15, 20, 30, 45, 60]
    
    var body: some View {
        Form {
            Section(header: Text("IDLE TIMEOUT")) {
                Picker("Minutes of Inactivity", selection: $idleTimeout) {
                    ForEach(timeouts, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .pickerStyle(InlinePickerStyle())
            }
            
            Section(footer: Text("The timer will automatically pause after the selected minutes of inactivity.")) {
                // Empty section for footer
            }
        }
        .navigationTitle("Idle Timeout")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .center, spacing: 16) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("DevTrack")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Track your coding journey")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            
            Section(header: Text("ABOUT")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                        .foregroundColor(.secondary)
                }
                
                Button(action: { openURL("https://devtrack.app/changelog") }) {
                    Text("What's New")
                }
                
                Button(action: { openURL("https://devtrack.app/rate") }) {
                    Text("Rate DevTrack")
                }
                
                Button(action: { shareApp() }) {
                    Text("Share DevTrack")
                }
            }
            
            Section(header: Text("CONNECT")) {
                Button(action: { openURL("https://twitter.com/devtrack") }) {
                    HStack {
                        Image(systemName: "at")
                        Text("Twitter")
                    }
                }
                
                Button(action: { openURL("https://github.com/yourusername/devtrack") }) {
                    HStack {
                        Image(systemName: "chevron.left.slash.chevron.right")
                        Text("GitHub")
                    }
                }
            }
            
            Section(footer: Text("© \(Calendar.current.component(.year, from: Date())) DevTrack. All rights reserved.")) {
                // Empty section for footer
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func shareApp() {
        let text = "Check out DevTrack - Track your coding time and journal your development journey!"
        let url = URL(string: "https://devtrack.app")!
        let items: [Any] = [text, url]
        
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(SessionStore())
    }
}
