import XCTest
@testable import MT741

final class BangcleBlobTests: XCTestCase {
    func testMurmur3Fixtures() {
        XCTAssertEqual(MurmurHash3.x64_128("hello"), "ba70054aab329b58bc7d0d75e2e5b3b3")
        XCTAssertEqual(MurmurHash3.x64_128(""), "7cf366b401a16715098268307e1fa337")
        XCTAssertEqual(
            MurmurHash3.x64_128("0123456789abcdef0123456789abcdef_bsdk_"),
            "b67bf71a086445574e8c2f20c1ed4d71"
        )
        XCTAssertEqual(BangcleBlob.xorHexNibbles("0123456789abcdef"), "1032547698badcfe")
        XCTAssertEqual(BangcleBlob.xorHexNibbles(BangcleBlob.xorHexNibbles("cb2987e543a150f6")), "cb2987e543a150f6")
    }

    func testDecryptHarCWBAndDU() {
        let cwb = "cb2987e543a150f68dcb2987e543a10f93bb287265cd391af854fbe7605d298a614b0054878ff31df421ba9e796ebc614e4686a78ac15deea7d2e4ae969513025c9251ffcdcd99afd2bc1ac44a1a3297afec4888773663302820e639aeb716062066a5b544bbad259d92f051ec13140ef0824390f9da425c857ac057a3bc4ab4a0fb1efe251f9f435e0723a7b891cbae23e356e5c44700efa131aad7574aa5f24547428b259dce784ee6a3afb889d1f2d38725723ad60fe21fd4075dc0ec576948157590c5d35f2691efdf65e69087c4e66f5e31d4c4f4c9915065c3eb2ba057fafbf61ef90b340dddda696ef237055c9fa2757a71bef754157cc2efe865a89b2a9928fd3fbc4d8d4779b2a2b2c8afb4787f2c6e432a4b3c1c9595e0ff7dc267ec0cbf47408c0379d4be5f6ee5174ccfa6ab89062352d2063a361f4f4adb3161a9bdf684c9b4d8404b9cabcec3d8f9d581529a058093c1193da4e309446f28191d0afb460bf43385b716eb0d8c244964583ecff0ae812b76917b91e57dc1819f9c2463e07b9a4a08bf08a6234647ac9d"
        let du = "cca1fd2ad0ef4af61c52f2aeb8a53dc0a02c2d3152c548232ae361610a878790191d7a56dc9a138c1aeccf1e28ceb77dcb49258992ea75788077fe8aa02fe8296aa897f2ed3c5a8187f321da1bcb76be59812f068cc613002093de1e7206a2b7e9845b730521f2c07fc9a740814e93dc0d49f2363638ccd4ddefa5c37c628f3e9036df3c8780f332a54c5be37727b8efba612bb1e98824bb88c8166118a9f620ab1476a08d9fd749b09505d2b8e85492aaabcd6c232f2e3a2c4dfaab82d6a9151614f499a9652bea225666770161fc3c10d17dcf1d670410a4cc1773ffada2370fd53ebec7cb06f7ebf2bb0f53f854fe"
        XCTAssertEqual(BangcleBlob.did(from: cwb), "h463f41b3f65bfa6dd312863db5daabf")
        XCTAssertEqual(BangcleBlob.hp(from: cwb), "0")
        XCTAssertEqual(BangcleBlob.did(from: du), "h463f41b3f65bfa6dd312863db5daabf")
        XCTAssertEqual(BangcleBlob.hp(from: du), "bid-2550189502971-aabf-de1d")
        XCTAssertEqual(
            CookieBridge.uaDeviceId(h5Did: BangcleBlob.did(from: cwb)),
            "463f41b3f65bfa6dd312863db5daabf"
        )
        XCTAssertEqual(
            CookieBridge.sanitizeBsDeviceCookie(BangcleBlob.hp(from: du)),
            "bid-2550189502971-aabf-de1d"
        )
        XCTAssertEqual(CookieBridge.sanitizeBsDeviceCookie("0"), "")
        XCTAssertEqual(CookieBridge.sanitizeBsDeviceCookie(BangcleBlob.hp(from: cwb)), "")
    }

    func testRejectsGarbageBlob() {
        XCTAssertEqual(BangcleBlob.did(from: ""), "")
        XCTAssertEqual(BangcleBlob.did(from: "zzzz"), "")
        XCTAssertEqual(BangcleBlob.hp(from: "aa"), "")
    }
}
