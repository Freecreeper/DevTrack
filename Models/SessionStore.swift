import Foundation
import SwiftUI

struct CodingSession: Identifiable, Codable {
    let id: UUID
    var projectName: String
    var seconds: TimeInterval
    var startDate: Date
    var note: String
    
    enum CodingKeys: String, CodingKey { case id, projectName, seconds, startDate, note }
    
    init(id: UUID = UUID(), projectName: String, seconds: TimeInterval, startDate: Date, note: String) {
        self.id = id
        self.projectName = projectName
        self.seconds = seconds
        self.startDate = startDate
        self.note = note
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.projectName = try container.decode(String.self, forKey: .projectName)
        self.seconds = try container.decode(TimeInterval.self, forKey: .seconds)
        self.startDate = try container.decode(Date.self, forKey: .startDate)
        self.note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [CodingSession] = []
    @Published var deepLinkSessionId: UUID?
    
    init() {
        load()
    }
    
    // MARK: - CRUD
    @discardableResult
    func addSession(projectName: String, seconds: TimeInterval, date: Date, note: String) -> CodingSession {
        let session = CodingSession(projectName: projectName, seconds: seconds, startDate: date, note: note)
        sessions.insert(session, at: 0)
        save()
        return session
    }
    
    func updateSession(id: UUID, projectName: String? = nil, seconds: TimeInterval? = nil, startDate: Date? = nil, note: String? = nil) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        if let projectName = projectName { sessions[idx].projectName = projectName }
        if let seconds = seconds { sessions[idx].seconds = seconds }
        if let startDate = startDate { sessions[idx].startDate = startDate }
        if let note = note { sessions[idx].note = note }
        save()
    }
    
    func deleteSession(id: UUID) {
        if let idx = sessions.firstIndex(where: { $0.id == id }) {
            sessions.remove(at: idx)
            save()
        }
    }
    
    func clearAll() {
        sessions.removeAll()
        save()
    }
    
    // MARK: - Export/Import
    func exportJSON() -> URL? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let data = try encoder.encode(sessions)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("DevTrack-Sessions.json")
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            print("SessionStore exportJSON error: \(error.localizedDescription)")
            return nil
        }
    }
    
    func exportCSV() -> URL? {
        let formatter = ISO8601DateFormatter()
        func csvEscape(_ s: String) -> String {
            var t = s.replacingOccurrences(of: "\"", with: "\"\"")
            t = t.replacingOccurrences(of: "\n", with: " ")
            return "\"" + t + "\""
        }
        var lines = ["id,projectName,seconds,startDate,note"]
        for s in sessions {
            let row = [
                csvEscape(s.id.uuidString),
                csvEscape(s.projectName),
                csvEscape(String(s.seconds)),
                csvEscape(formatter.string(from: s.startDate)),
                csvEscape(s.note)
            ].joined(separator: ",")
            lines.append(row)
        }
        let csv = lines.joined(separator: "\n")
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("DevTrack-Sessions.csv")
            try csv.data(using: .utf8)?.write(to: url, options: [.atomic])
            return url
        } catch {
            print("SessionStore exportCSV error: \(error.localizedDescription)")
            return nil
        }
    }
    
    @discardableResult
    func importJSON(from url: URL) throws -> Int {
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([CodingSession].self, from: data)
        let count = decoded.count
        // Append to existing, newest first
        sessions = decoded + sessions
        dedupeAndSort()
        save()
        return count
    }
    
    @discardableResult
    func importCSV(from url: URL) throws -> Int {
        let text = try String(contentsOf: url, encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        guard !lines.isEmpty else { return 0 }
        let formatter = ISO8601DateFormatter()
        var imported: [CodingSession] = []
        for (i, lineSub) in lines.enumerated() {
            if i == 0 { continue } // skip header
            let fields = parseCSVLine(String(lineSub))
            guard fields.count >= 5 else { continue }
            let id = UUID(uuidString: fields[0]) ?? UUID()
            let name = fields[1]
            let secs = TimeInterval(fields[2]) ?? 0
            let date = formatter.date(from: fields[3]) ?? Date()
            let note = fields[4]
            imported.append(CodingSession(id: id, projectName: name, seconds: secs, startDate: date, note: note))
        }
        let count = imported.count
        sessions = imported + sessions
        dedupeAndSort()
        save()
        return count
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                if inQuotes && i + 1 < chars.count && chars[i+1] == "\"" {
                    current.append("\"")
                    i += 1
                } else {
                    inQuotes.toggle()
                }
            } else if c == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(c)
            }
            i += 1
        }
        result.append(current)
        return result
    }
    
    private func dedupeAndSort() {
        var seen = Set<UUID>()
        var unique: [CodingSession] = []
        for s in sessions {
            if !seen.contains(s.id) {
                unique.append(s)
                seen.insert(s.id)
            }
        }
        sessions = unique.sorted(by: { $0.startDate > $1.startDate })
    }
    
    // MARK: - Persistence
    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("sessions.json")
    }
    
    private func load() {
        do {
            let url = fileURL
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([CodingSession].self, from: data)
            self.sessions = decoded
        } catch {
            print("SessionStore load error: \(error.localizedDescription)")
        }
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("SessionStore save error: \(error.localizedDescription)")
        }
    }
}
