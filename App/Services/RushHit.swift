import Foundation

struct RushHit: Equatable {
    var code: Int?
    var message: String = ""
    var priorityRecordId: String = ""
    var orderId: String = ""
    var userVerifyStatus: Int?
    var hasGain: Bool = false

    var isHit: Bool { code == 2000 }
    var needsYidun: Bool {
        code == 4025 || userVerifyStatus == 1 || (isHit && !priorityRecordId.isEmpty)
    }

    static func parse(_ raw: String) -> RushHit {
        guard
            let data = raw.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return RushHit(message: raw)
        }
        let code = AuthClient.jsonCode(obj)
        let dataObj = obj["data"] as? [String: Any] ?? [:]
        func text(_ key: String) -> String {
            let v = dataObj[key] ?? obj[key]
            if let s = v as? String { return s }
            if let n = v as? NSNumber { return n.stringValue }
            return ""
        }
        let verify = dataObj["userVerifyStatus"] as? Int
            ?? (dataObj["userVerifyStatus"] as? NSNumber)?.intValue
        let gain = (dataObj["hasGain"] as? Bool)
            ?? ((dataObj["hasGain"] as? NSNumber)?.boolValue ?? false)
        return RushHit(
            code: code,
            message: (obj["message"] as? String) ?? "",
            priorityRecordId: text("priorityRecordId").isEmpty ? text("priorityUserRecordId") : text("priorityRecordId"),
            orderId: text("orderId"),
            userVerifyStatus: verify,
            hasGain: gain
        )
    }

    static func best(from shots: [BurstShot]) -> RushHit? {
        let hits = shots.map { parse($0.body.isEmpty ? $0.error : $0.body) }
        if let hit = hits.first(where: { $0.isHit }) { return hit }
        if let yidun = hits.first(where: { $0.code == 4025 }) { return yidun }
        return hits.first(where: { $0.code != nil })
    }
}
