import SwiftUI
import CoreData

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var timerManager = TimerManager()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TimeTrackerView()
                .environmentObject(timerManager)
                .tabItem {
                    Label("Track", systemImage: "timer")
                }
                .tag(0)
            
            JournalView()
                .tabItem {
                    Label("Journal", systemImage: "book")
                }
                .tag(1)
            
            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .accentColor(.blue)
    }
}

struct ContentView_Previews: PreviewProvider {
    static let dataController = DataController()
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, dataController.container.viewContext)
            .environmentObject(SessionStore())
    }
}
