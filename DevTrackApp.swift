import SwiftUI

@main
struct DevTrackApp: App {
    @StateObject private var dataController = DataController()
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataController.container.viewContext)
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
