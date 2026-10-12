import Combine
import Foundation

final class CWBStore: ObservableObject {
    static let officialLength = 800

    @Published var cwb: String = ""
    @Published var contentHh: String = ""
    @Published var sourceURL: String = ""

    var lengthText: String {
        cwb.isEmpty ? "CWB空" : "CWB \(cwb.count)/\(Self.officialLength)"
    }

    func reset() {
        cwb = ""
        contentHh = ""
        sourceURL = ""
    }

    func ingest(_ body: Any) {
        let parsed = CWBHook.parse(body)
        guard !parsed.cwb.isEmpty else { return }
        cwb = parsed.cwb
        if !parsed.hh.isEmpty {
            contentHh = parsed.hh
        }
        if !parsed.url.isEmpty {
            sourceURL = parsed.url
        }
    }
}
