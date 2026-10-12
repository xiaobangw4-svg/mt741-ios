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
        XCTAssertTrue(js.contains("hookGCS()"))
        XCTAssertTrue(js.contains("bumpPx"))
        XCTAssertTrue(js.contains("isProbe"))
        XCTAssertTrue(js.contains("width: bumpPx(st.width)"))
        XCTAssertFalse(js.contains("new Proxy"))
        XCTAssertFalse(js.contains("try { hookScriptSrc(); }"))
        XCTAssertFalse(js.contains("try { hookBeforeLoad(); }"))
        XCTAssertFalse(js.contains("try { hookFetch(); }"))
        XCTAssertTrue(js.contains("Object.defineProperty"))
        XCTAssertTrue(js.contains("__esModule"))
        XCTAssertTrue(js.contains("Window.prototype"))
        XCTAssertTrue(js.contains("installStyleTotalSetter"))
        XCTAssertTrue(js.contains("__mt741esMod"))
        XCTAssertTrue(js.contains("hookKeys()"))
        XCTAssertTrue(js.contains("hookJSON()"))
        XCTAssertTrue(js.contains("isCwbFields"))
        XCTAssertTrue(js.contains("liftField142"))
        XCTAssertTrue(js.contains("liftCwbArray"))
        XCTAssertTrue(js.contains("Object.keys"))
        XCTAssertTrue(js.contains("JSON.stringify"))
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
        XCTAssertEqual(StyleTotalPatch.statusLabel(wrapped: 0, from: 0, patched: true, bump: 0, gcs: true), "Style脚本在")
        XCTAssertEqual(StyleTotalPatch.statusLabel(wrapped: 0, from: 0, patched: true, bump: 1, gcs: true), "Style脚本在")
        XCTAssertEqual(
            StyleTotalPatch.statusLabel(fromJSON: #"{"patched":true,"wrapped":1,"from":0}"#),
            "Style抬位"
        )
        XCTAssertEqual(
            StyleTotalPatch.statusLabel(wrapped: 0, from: 0, patched: true, rewritten: true),
            "Style抬位"
        )
        XCTAssertEqual(
            StyleTotalPatch.statusLabel(fromJSON: #"{"patched":true,"rewritten":true,"from":1}"#),
            "Style抬位"
        )
        XCTAssertEqual(StyleTotalPatch.statusLabel(fromJSON: "nope"), "Style未挂")
        XCTAssertEqual(
            StyleTotalPatch.statusLabel(fromJSON: #"{"patched":true,"rewritten":true,"wasm":false}"#),
            "wasm未起"
        )
    }

    func testNativeSDKPatchRewritesOfficialLoop() {
        let src = "prefix;" + StyleTotalPatch.loopFrom + ";"
            + StyleTotalSDK.wasmBaseFrom + ";"
            + StyleTotalSDK.wasmScriptFrom + ";suffix"
        let out = StyleTotalSDK.patch(src)
        XCTAssertEqual(out.hits, 1)
        XCTAssertTrue(StyleTotalSDK.wasmBaseTo.contains(StyleTotalSDK.wasmCDN))
        XCTAssertTrue(StyleTotalSDK.wasmScriptTo.contains(StyleTotalSDK.remoteURL.absoluteString))
        XCTAssertTrue(out.text.contains("_h<10000"))
        XCTAssertTrue(out.text.contains(StyleTotalSDK.wasmCDN))
        XCTAssertTrue(out.text.contains(StyleTotalSDK.remoteURL.absoluteString))
        XCTAssertFalse(out.text.contains(StyleTotalPatch.loopFrom))
        XCTAssertFalse(out.text.contains(StyleTotalSDK.wasmBaseFrom))
        XCTAssertFalse(out.text.contains(#"p="undefined"!=typeof document"#))
        XCTAssertEqual(StyleTotalSDK.patch("no loop here").hits, 0)
        XCTAssertEqual(StyleTotalSDK.patch("prefix;" + StyleTotalPatch.loopFrom + ";suffix").hits, 0)
    }

    func testContentRuleIdentifierIsStableForRemoval() {
        XCTAssertEqual(StyleTotalSDK.ruleIdentifier, "mt741-block-bs-h5")
        XCTAssertTrue(StyleTotalSDK.contentRuleJSON.contains("bs_h5"))
    }

    func testBootstrapMarksRewrittenAndKeepsPatchedLoop() {
        let src = "x" + StyleTotalPatch.loopFrom + StyleTotalSDK.wasmBaseFrom + StyleTotalSDK.wasmScriptFrom + "y"
        let patched = StyleTotalSDK.patch(src).text
        let boot = StyleTotalSDK.bootstrap(patchedSDK: patched, hits: 1)
        XCTAssertTrue(boot.contains("__mt741sdkRewritten=true"))
        XCTAssertTrue(boot.contains("_h<10000"))
        XCTAssertTrue(boot.contains(StyleTotalSDK.remoteURL.absoluteString))
        XCTAssertTrue(boot.contains(StyleTotalSDK.wasmCDN))
        XCTAssertTrue(boot.contains("document.createElement('script')"))
        XCTAssertFalse(boot.contains("s.text="))
        XCTAssertTrue(boot.contains("currentScript"))
        XCTAssertTrue(boot.contains("data-mt741-sdk"))
        XCTAssertTrue(boot.contains("__mt741currentScript"))
        XCTAssertTrue(boot.contains("__mt741csAtBoot"))
        XCTAssertTrue(boot.contains("__mt741wasmFetch"))
        XCTAssertTrue(boot.contains("stub"))
        XCTAssertTrue(StyleTotalSDK.jsonString("a\"b").contains("\\\""))
    }
}
