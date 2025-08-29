import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct StatsView: View {
    @EnvironmentObject var sessionStore: SessionStore
    
    // Derived data from the last 7 days
    private var weeklyData: [DailyStats] {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -6, to: todayStart)!
        let end = cal.date(byAdding: .day, value: 1, to: todayStart)!
        let sessions = sessionStore.sessions.filter { $0.startDate >= start && $0.startDate < end }
        let df = DateFormatter()
        df.locale = Locale.current
        df.dateFormat = "EEE"
        var result: [DailyStats] = []
        for offset in (0..<7).reversed() {
            let dayStart = cal.date(byAdding: .day, value: -offset, to: todayStart)!
            let next = cal.date(byAdding: .day, value: 1, to: dayStart)!
            let daySessions = sessions.filter { $0.startDate >= dayStart && $0.startDate < next }
            let hours = daySessions.reduce(0.0) { $0 + $1.seconds } / 3600.0
            let projects = Set(daySessions.map { $0.projectName })
            result.append(DailyStats(day: df.string(from: dayStart), hours: hours, projects: projects.count))
        }
        return result
    }
    
    private var projectData: [ProjectTime] {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -6, to: todayStart)!
        let end = cal.date(byAdding: .day, value: 1, to: todayStart)!
        let sessions = sessionStore.sessions.filter { $0.startDate >= start && $0.startDate < end }
        var totals: [String: Double] = [:]
        for s in sessions {
            totals[s.projectName, default: 0] += s.seconds / 3600.0
        }
        let palette: [Color] = [.blue, .green, .orange, .red, .purple, .pink, .teal, .indigo]
        let sorted = totals.sorted { $0.value > $1.value }
        return sorted.enumerated().map { idx, kv in
            ProjectTime(name: kv.key, hours: kv.value, color: palette[idx % palette.count])
        }
    }
    
    var totalHoursThisWeek: Double {
        weeklyData.reduce(0) { $0 + $1.hours }
    }
    
    var averageDailyHours: Double {
        guard !weeklyData.isEmpty else { return 0 }
        return weeklyData.reduce(0) { $0 + $1.hours } / Double(weeklyData.count)
    }
    
    private var maxProjectHours: Double {
        projectData.map { $0.hours }.max() ?? 1
    }
    
    private var mostProductiveDayName: String {
        guard let best = weeklyData.max(by: { $0.hours < $1.hours }), best.hours > 0 else { return "—" }
        return best.day
    }
    
    private var focusedHours: Double {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -6, to: todayStart)!
        let end = cal.date(byAdding: .day, value: 1, to: todayStart)!
        let sessions = sessionStore.sessions.filter { $0.startDate >= start && $0.startDate < end }
        let secs = sessions.filter { $0.seconds >= 1800 }.reduce(0.0) { $0 + $1.seconds }
        return secs / 3600.0
    }
    
    private var averageSessionHours: Double {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -6, to: todayStart)!
        let end = cal.date(byAdding: .day, value: 1, to: todayStart)!
        let sessions = sessionStore.sessions.filter { $0.startDate >= start && $0.startDate < end }
        guard !sessions.isEmpty else { return 0 }
        let totalSecs = sessions.reduce(0.0) { $0 + $1.seconds }
        return (totalSecs / Double(sessions.count)) / 3600.0
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Summary Cards
                HStack(spacing: 16) {
                    StatCard(title: "This Week", value: "\(String(format: "%.1f", totalHoursThisWeek))h", icon: "clock.fill", color: .blue)
                    StatCard(title: "Daily Avg", value: "\(String(format: "%.1f", averageDailyHours))h", icon: "chart.bar.fill", color: .green)
                }
                .padding(.horizontal)
                
                // Weekly Overview Chart
                VStack(alignment: .leading, spacing: 16) {
                    Text("Weekly Overview")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    WeeklyOverviewChartView(weeklyData: weeklyData)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                
                // Project Distribution
                VStack(alignment: .leading, spacing: 16) {
                    Text("Project Distribution")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        ForEach(projectData) { project in
                            HStack {
                                Circle()
                                    .fill(project.color)
                                    .frame(width: 12, height: 12)
                                
                                Text(project.name)
                                    .font(.subheadline)
                                    .frame(width: 120, alignment: .leading)
                                
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color(.systemGray5))
                                            .frame(height: 8)
                                        
                                        Capsule()
                                            .fill(project.color)
                                            .frame(width: CGFloat(project.hours / maxProjectHours) * (geometry.size.width - 100), height: 8)
                                    }
                                }
                                .frame(height: 8)
                                
                                Text("\(String(format: "%.1f", project.hours))h")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Productivity Insights
                VStack(alignment: .leading, spacing: 16) {
                    Text("Productivity Insights")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        InsightRow(icon: "flame.fill", title: "Most Productive Day", value: mostProductiveDayName, color: .red)
                        Divider()
                        InsightRow(icon: "clock.badge.checkmark.fill", title: "Focused Coding", value: "\(String(format: "%.1f", focusedHours))h", color: .green)
                        Divider()
                        InsightRow(icon: "hourglass", title: "Average Session", value: "\(String(format: "%.1f", averageSessionHours))h", color: .blue)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.vertical)
        }
        .navigationTitle("Statistics")
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct InsightRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Weekly Overview (iOS 15 fallback)

struct WeeklyOverviewChartView: View {
    let weeklyData: [DailyStats]
    
    @ViewBuilder
    var body: some View {
#if canImport(Charts)
        if #available(iOS 16.0, *) {
            Chart {
                ForEach(weeklyData) { day in
                    BarMark(
                        x: .value("Day", day.day),
                        y: .value("Hours", day.hours)
                    )
                    .foregroundStyle(LinearGradient(
                        gradient: Gradient(colors: [.blue, .blue.opacity(0.5)]),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .cornerRadius(4)
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        } else {
            FallbackBarListView(weeklyData: weeklyData)
        }
#else
        FallbackBarListView(weeklyData: weeklyData)
#endif
    }
}

struct FallbackBarListView: View {
    let weeklyData: [DailyStats]
    private var maxHours: Double { weeklyData.map { $0.hours }.max() ?? 1 }
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(weeklyData) { day in
                HStack(spacing: 8) {
                    Text(day.day)
                        .font(.caption)
                        .frame(width: 32, alignment: .leading)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.systemGray5))
                                .frame(height: 10)
                            
                            Capsule()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [.blue, Color.blue.opacity(0.5)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: CGFloat(day.hours / maxHours) * geometry.size.width, height: 10)
                        }
                    }
                    .frame(height: 10)
                    
                    Text("\(String(format: "%.1f", day.hours))h")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Data Models

struct DailyStats: Identifiable {
    let id = UUID()
    let day: String
    let hours: Double
    let projects: Int
}

struct ProjectTime: Identifiable {
    let id = UUID()
    let name: String
    let hours: Double
    let color: Color
}

// MARK: - Preview

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            StatsView()
        }
        .environmentObject(SessionStore())
        .preferredColorScheme(.dark)
    }
}
