import SwiftUI

class TimerManager: ObservableObject {
    @Published var isRunning = false
    @Published var elapsedTime: TimeInterval = 0
    private var timer: Timer?
    
    func start() {
        isRunning = true
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
    @State private var projectName = ""
    @State private var showProjectInput = false
    
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
                        // Placeholder for recent sessions
                        Text("No recent sessions")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .center)
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
                        
                        Button("Save Session") {
                            // TODO: Save session to CoreData
                            showProjectInput = false
                            timerManager.reset()
                        }
                        .disabled(projectName.isEmpty)
                        .padding()
                        .background(projectName.isEmpty ? Color.gray : Color.blue)
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
        }
    }
}

struct TimeTrackerView_Previews: PreviewProvider {
    static var previews: some View {
        TimeTrackerView()
            .environmentObject(TimerManager())
    }
}
