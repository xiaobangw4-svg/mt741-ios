import Foundation

struct BurstLog: Equatable {
    private(set) var lines: [String]
    var cap: Int

    init(hint: String = "", cap: Int = 200) {
        self.lines = hint.isEmpty ? [] : [hint]
        self.cap = max(1, cap)
    }

    var text: String { lines.joined(separator: "\n") }

    mutating func append(_ line: String, at date: Date = Date()) {
        let stamp = Self.stamp(date)
        let parts = line.split(separator: "\n", omittingEmptySubsequences: false)
        if let first = parts.first {
            lines.append("[\(stamp)] \(first)")
            lines.append(contentsOf: parts.dropFirst().map(String.init))
        } else {
            lines.append("[\(stamp)]")
        }
        if lines.count > cap {
            lines.removeFirst(lines.count - cap)
        }
    }

    mutating func reset(_ hint: String) {
        lines = hint.isEmpty ? [] : [hint]
    }

    static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}
