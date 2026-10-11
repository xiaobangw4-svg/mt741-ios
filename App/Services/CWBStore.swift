import Combine
import Foundation

final class CWBStore: ObservableObject {
    @Published var cwb: String = ""
    @Published var contentHh: String = ""
    @Published var sourceURL: String = ""

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
