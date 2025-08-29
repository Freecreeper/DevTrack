import SwiftUI
import CoreData

@main
struct DevTrackApp: App {
    @StateObject private var dataController = DataController()
    @StateObject private var sessionStore = SessionStore()
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataController.container.viewContext)
                .environmentObject(sessionStore)
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}

class DataController: ObservableObject {
    let container = NSPersistentContainer(name: "DevTrack")
    
    init() {
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
    }
}
