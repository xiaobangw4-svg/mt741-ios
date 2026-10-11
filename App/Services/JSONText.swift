import Foundation

enum JSONText {
    static func string(_ any: Any?) -> String {
        if let s = any as? String { return s }
        if let n = any as? NSNumber { return n.stringValue }
        if let i = any as? Int { return String(i) }
        if let i = any as? Int64 { return String(i) }
        return ""
    }

    static func int(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let n = any as? NSNumber { return n.intValue }
        if let s = any as? String { return Int(s) }
        return nil
    }

    static func object(_ any: Any?) -> [String: Any] {
        any as? [String: Any] ?? [:]
    }

    static func array(_ any: Any?) -> [[String: Any]] {
        if let rows = any as? [[String: Any]] { return rows }
        if let rows = any as? [Any] {
            return rows.compactMap { $0 as? [String: Any] }
        }
        return []
    }
}
