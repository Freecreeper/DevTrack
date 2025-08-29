import SwiftUI

class TimerManager: ObservableObject {
    @Published var isRunning = false
    @Published var elapsedTime: TimeInterval = 0
    private var timer: Timer?
    @Published var startDate: Date?

    func start() {
        isRunning = true
        startDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.elapsedTime += 1
        }
    }
    
    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func reset() {
        stop()
        elapsedTime = 0
        startDate = nil
    }
    
    var timeString: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

struct TimeTrackerView: View {
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var sessionStore: SessionStore
    @State private var projectName = ""
    @State private var showProjectInput = false
    @State private var journalText = ""

    // Editing
    @State private var isEditing = false
    @State private var editingId: UUID? = nil
    @State private var editProjectName = ""
    @State private var editNote = ""
    @State private var editDate = Date()
    
    private var isJournalEmpty: Bool {
        journalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var recentSessions: [CodingSession] {
        Array(sessionStore.sessions.prefix(10))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Timer Display
                ZStack {
                    Circle()
                        .stroke(lineWidth: 10)
                        .opacity(0.3)
                        .foregroundColor(.blue)
                    
                    Circle()
                        .trim(from: 0.0, to: 0.7)
                        .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                        .foregroundColor(.blue)
                        .rotationEffect(Angle(degrees: 270))
                    
                    VStack {
                        Text(timerManager.timeString)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .padding()
                        
                        Text(projectName.isEmpty ? "No Project" : projectName)
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 280, height: 280)
                .padding(.top, 40)
                
                // Controls
                HStack(spacing: 40) {
                    Button(action: {
                        if timerManager.isRunning {
                            timerManager.stop()
                            showProjectInput = true
                        } else {
                            timerManager.start()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .frame(width: 70, height: 70)
                                .foregroundColor(timerManager.isRunning ? .red : .green)
                            
                            Image(systemName: timerManager.isRunning ? "stop.fill" : "play.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                    
                    if !timerManager.isRunning && timerManager.elapsedTime > 0 {
                        Button(action: {
                            timerManager.reset()
                            projectName = ""
                        }) {
                            ZStack {
                                Circle()
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.gray.opacity(0.2))
                                
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .padding(.top, 30)
                
                Spacer()
                
                // Recent Sessions
                VStack(alignment: .leading) {
                    Text("Recent Sessions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    List {
                        if recentSessions.isEmpty {
                            Text("No recent sessions")
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(recentSessions) { s in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(s.projectName)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        Text(s.startDate, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(format(seconds: s.seconds))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        sessionStore.deleteSession(id: s.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        editingId = s.id
                                        editProjectName = s.projectName
                                        editNote = s.note
                                        editDate = s.startDate
                                        isEditing = true
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
                .padding(.top)
            }
            .navigationTitle("DevTrack")
            .sheet(isPresented: $showProjectInput) {
                NavigationView {
                    VStack {
                        TextField("Project Name", text: $projectName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Journal (required)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: $journalText)
                                .frame(minHeight: 120)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.2))
                                )
                                .padding(.bottom, 8)
                        }
                        .padding(.horizontal)
                        
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.secondary)
                            Text((timerManager.startDate ?? Date()), style: .date)
                            Text((timerManager.startDate ?? Date()), style: .time)
                            Spacer()
                        }
                        .font(.caption)
                        .padding(.horizontal)
                        
                        Button("Save Session") {
                            // Persist session
                            sessionStore.addSession(projectName: projectName.isEmpty ? "Untitled" : projectName,
                                                    seconds: timerManager.elapsedTime,
                                                    date: timerManager.startDate ?? Date(),
                                                    note: journalText.trimmingCharacters(in: .whitespacesAndNewlines))
                            showProjectInput = false
                            timerManager.reset()
                            projectName = ""
                            journalText = ""
                        }
                        .disabled(isJournalEmpty)
                        .padding()
                        .background(isJournalEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding()
                    }
                    .navigationTitle("Save Session")
                    .navigationBarItems(trailing: Button("Cancel") {
                        showProjectInput = false
                    })
                }
            }
            .sheet(isPresented: $isEditing) {
                NavigationView {
                    VStack {
                        TextField("Project Name", text: $editProjectName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Journal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextEditor(text: $editNote)
                                .frame(minHeight: 120)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.2))
                                )
                        }
                        .padding(.horizontal)
                        
                        DatePicker("Start", selection: $editDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .padding()
                        
                        Button("Save Changes") {
                            if let id = editingId {
                                sessionStore.updateSession(id: id,
                                                          projectName: editProjectName.isEmpty ? "Untitled" : editProjectName,
                                                          startDate: editDate,
                                                          note: editNote)
                            }
                            isEditing = false
                            editingId = nil
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding()
                    }
                    .navigationTitle("Edit Session")
                    .navigationBarItems(trailing: Button("Cancel") {
                        isEditing = false
                        editingId = nil
                    })
                }
            }
        }
    }
    
    private func format(seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm %02ds", minutes, secs)
        }
    }
  }

struct TimeTrackerView_Previews: PreviewProvider {
    static var previews: some View {
        TimeTrackerView()
            .environmentObject(TimerManager())
            .environmentObject(SessionStore())
    }
}
