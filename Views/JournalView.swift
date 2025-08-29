import SwiftUI

struct JournalEntry: Identifiable {
    let id = UUID()
    var title: String
    var content: String
    var date: Date
    var tags: [String]
}

// MARK: - Session Detail View

struct JournalSessionDetailView: View {
    let session: CodingSession
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.projectName.isEmpty ? "Untitled" : session.projectName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text(session.startDate.formatted(date: .complete, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Duration: \(formatDuration(session.seconds))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 16)
                
                Divider()
                
                Text(session.note.isEmpty ? "(No details)" : session.note)
                    .font(.body)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
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
    @EnvironmentObject var sessionStore: SessionStore
    @State private var searchText = ""
    @State private var selectedSessionId: UUID?
    
    var filteredSessions: [CodingSession] {
        if searchText.isEmpty {
            return sessionStore.sessions
        } else {
            return sessionStore.sessions.filter {
                $0.projectName.localizedCaseInsensitiveContains(searchText) ||
                $0.note.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if sessionStore.sessions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Journal Entries Yet")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("Start a timer, then save with a journal entry to see it here.")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    List {
                        ForEach(filteredSessions) { s in
                            NavigationLink(
                                destination: JournalSessionDetailView(session: s),
                                tag: s.id,
                                selection: $selectedSessionId
                            ) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(s.projectName.isEmpty ? "Untitled" : s.projectName)
                                        .font(.headline)
                                    Text(s.note.isEmpty ? "(No details)" : s.note)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                    HStack {
                                        Text(s.startDate.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Text(formatDuration(s.seconds))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 4)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .searchable(text: $searchText, prompt: "Search notes...")
                }
            }
            .navigationTitle("Journal")
            .onAppear {
                if let id = sessionStore.deepLinkSessionId {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        selectedSessionId = id
                        sessionStore.deepLinkSessionId = nil
                    }
                }
            }
            .onChange(of: sessionStore.deepLinkSessionId) { id in
                guard let id = id else { return }
                DispatchQueue.main.async {
                    selectedSessionId = id
                    sessionStore.deepLinkSessionId = nil
                }
            }
        }
    }
    
    private func deleteEntry(at offsets: IndexSet) {
        // Legacy: journal entries are no longer used here.
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
            .environmentObject(SessionStore())
    }
}
