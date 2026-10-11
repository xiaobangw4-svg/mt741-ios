import XCTest
@testable import MT741

final class StyleTotalPatchTests: XCTestCase {
    func testScriptWrapsStyleTotalAndForcesLayout() {
        let js = StyleTotalPatch.javaScript
        XCTAssertTrue(js.contains("StyleTotal"))
        XCTAssertTrue(js.contains("offsetWidth"))
        XCTAssertTrue(js.contains("10000"))
        XCTAssertTrue(js.contains("window.getComputedStyle"))
        XCTAssertTrue(js.contains("__mt741hookStyle"))
        XCTAssertTrue(js.contains("__mt741liftStyle"))
        XCTAssertTrue(js.contains("e << 8"))
        XCTAssertTrue(js.contains("void u.offsetWidth"))
        XCTAssertTrue(js.contains("_h<10000"))
        XCTAssertTrue(StyleTotalPatch.loopFrom.contains("getComputedStyle(u)"))
        XCTAssertTrue(StyleTotalPatch.loopTo.contains("_h<10000"))
        XCTAssertFalse(js.contains("delete Object.prototype.StyleTotal"))
        XCTAssertTrue(js.contains("hookStyleTotalAssign()"))
        XCTAssertTrue(js.contains("hookScriptSrc()"))
        XCTAssertTrue(js.contains("HTMLScriptElement.prototype"))
        XCTAssertTrue(js.contains("xhr.open('GET', url, false)"))
        XCTAssertTrue(js.contains("bs_h5"))
        XCTAssertTrue(js.contains("Object.defineProperty"))
        XCTAssertEqual(H5PageStart.scripts.count, 3)
        XCTAssertTrue(H5PageStart.scripts[0].contains("__mt741hookStyle"))
        XCTAssertTrue(H5PageStart.scripts[1].contains("__mt741hookCWB"))
    }

    func testLiftKeepsFiveDigitHash() {
        XCTAssertEqual(StyleTotalPatch.lift(28160, token: "0a140a64006401ff"), 28160)
        XCTAssertEqual(StyleTotalPatch.lift(10000, token: "ffff"), 10000)
        XCTAssertEqual(StyleTotalPatch.cwbClass(28160), 800)
    }

    func testLiftRaisesFourDigitHashWithTokenSeeds() {
        let token = "0a140a64006401ff"
        let raw: UInt32 = 6550
        XCTAssertEqual(StyleTotalPatch.cwbClass(raw), 768)
        let got = StyleTotalPatch.lift(raw, token: token)
        XCTAssertEqual(got, UInt32(6550 + 10000) + ((UInt32(0x0A) << 8) | 0x14))
        XCTAssertEqual(got, UInt32(19130))
        XCTAssertEqual(String(got).count, 5)
        XCTAssertEqual(StyleTotalPatch.cwbClass(got), 800)
    }

    func testCollapsedZeroVariesWithWidthSeed() {
        var seen = Set<UInt32>()
        for e in 0..<32 {
            let token = String(format: "%02x00000000000100", e)
            let got = StyleTotalPatch.lift(0, token: token)
            XCTAssertEqual(got, UInt32(10_000) + (UInt32(e) << 8))
            XCTAssertEqual(StyleTotalPatch.cwbClass(got), 800)
            seen.insert(got)
        }
        XCTAssertEqual(seen.count, 32)
        XCTAssertNotEqual(StyleTotalPatch.lift(0, token: "0100000000000100"), UInt32(10000))
    }

    func testShortTokenTreatsMissingBytesAsZero() {
        XCTAssertEqual(StyleTotalPatch.lift(12, token: ""), UInt32(10012))
        XCTAssertEqual(StyleTotalPatch.lift(12, token: "0a"), UInt32(10012) + (UInt32(0x0A) << 8))
        XCTAssertEqual(StyleTotalPatch.hexPair("zz", offset: 0), 0)
    }

    func testStatusLabelFromProbeJSON() {
        XCTAssertEqual(StyleTotalPatch.statusLabel(wrapped: 0, from: 0, patched: false), "Style未挂")
        XCTAssertEqual(StyleTotalPatch.statusLabel(wrapped: 0, from: 0, patched: true), "Style脚本在")
        XCTAssertEqual(StyleTotalPatch.statusLabel(wrapped: 1, from: 0, patched: true), "Style抬位")
        XCTAssertEqual(StyleTotalPatch.statusLabel(wrapped: 0, from: 1, patched: true), "Style抬位")
        XCTAssertEqual(
            StyleTotalPatch.statusLabel(fromJSON: #"{"patched":true,"wrapped":1,"from":0}"#),
            "Style抬位"
        )
        XCTAssertEqual(StyleTotalPatch.statusLabel(fromJSON: "nope"), "Style未挂")
    }
}
