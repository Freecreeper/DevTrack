import SwiftUI

struct JournalEntry: Identifiable {
    let id = UUID()
    var title: String
    var content: String
    var date: Date
    var tags: [String]
}

class JournalStore: ObservableObject {
    @Published var entries: [JournalEntry] = []
    
    init() {
        // Sample data
        let entry1 = JournalEntry(
            title: "Implemented Authentication",
            content: "Today I set up Firebase authentication with email/password and Google Sign-In. Faced some issues with the Google Sign-In flow but resolved it by updating the URL schemes in Info.plist.",
            date: Date().addingTimeInterval(-86400), // Yesterday
            tags: ["Authentication", "Firebase", "iOS"]
        )
        
        let entry2 = JournalEntry(
            title: "Fixed Memory Leaks",
            content: "Used Instruments to identify and fix memory leaks in the main view controller. The issue was with strong reference cycles in closures. Added [weak self] to break the retain cycles.",
            date: Date().addingTimeInterval(-172800), // 2 days ago
            tags: ["Memory Management", "Debugging", "Performance"]
        )
        
        entries = [entry1, entry2]
    }
    
    func addEntry(_ entry: JournalEntry) {
        entries.insert(entry, at: 0)
    }
    
    func deleteEntry(at indexSet: IndexSet) {
        entries.remove(atOffsets: indexSet)
    }
}

struct JournalView: View {
    @StateObject private var journalStore = JournalStore()
    @State private var isAddingEntry = false
    @State private var searchText = ""
    
    var filteredEntries: [JournalEntry] {
        if searchText.isEmpty {
            return journalStore.entries
        } else {
            return journalStore.entries.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if journalStore.entries.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Journal Entries Yet")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("Tap the + button to add your first journal entry")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    List {
                        ForEach(filteredEntries) { entry in
                            NavigationLink(destination: JournalDetailView(entry: entry)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.title)
                                        .font(.headline)
                                    Text(entry.content)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                    HStack {
                                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Spacer()
                                        ForEach(entry.tags.prefix(2), id: \.self) { tag in
                                            Text(tag)
                                                .font(.caption2)
                                                .padding(4)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .onDelete(perform: deleteEntry)
                    }
                    .listStyle(InsetGroupedListStyle())
                    .searchable(text: $searchText, prompt: "Search entries...")
                }
            }
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isAddingEntry = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingEntry) {
                AddJournalEntryView(journalStore: journalStore)
            }
        }
    }
    
    private func deleteEntry(at offsets: IndexSet) {
        journalStore.deleteEntry(at: offsets)
    }
}

struct AddJournalEntryView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var journalStore: JournalStore
    
    @State private var title = ""
    @State private var content = ""
    @State private var tags = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Entry Details")) {
                    TextField("Title", text: $title)
                    ZStack(alignment: .topLeading) {
                        if content.isEmpty {
                            Text("Write about your coding session, challenges, or anything you want to remember...")
                                .foregroundColor(Color(.placeholderText))
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        TextEditor(text: $content)
                            .frame(minHeight: 200)
                    }
                }
                
                Section(header: Text("Tags")) {
                    TextField("e.g., Swift, Debugging, ProjectX", text: $tags)
                        .font(.subheadline)
                }
            }
            .navigationTitle("New Journal Entry")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    let newEntry = JournalEntry(
                        title: title,
                        content: content,
                        date: Date(),
                        tags: tags.components(separatedBy: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                    )
                    journalStore.addEntry(newEntry)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(title.isEmpty || content.isEmpty)
            )
        }
    }
}

struct JournalDetailView: View {
    let entry: JournalEntry
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(entry.date.formatted(date: .complete, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !entry.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(entry.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(10)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 16)
                
                Divider()
                
                Text(entry.content)
                    .font(.body)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct JournalView_Previews: PreviewProvider {
    static var previews: some View {
        JournalView()
    }
}
