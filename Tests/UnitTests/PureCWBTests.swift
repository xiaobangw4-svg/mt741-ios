import XCTest
@testable import MT741

final class PureCWBTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PureWac.resetCallSeq()
    }

    func testSerializePostMatchesBangcle() {
        XCTAssertEqual(PureCWB.serializePost(#"{"actParam":"abc","v":"0003"}"#), "actParam=abc;v=0003;")
        XCTAssertEqual(PureCWB.serializePost(#"{"v":"0003","actParam":"abc"}"#), "actParam=abc;v=0003;")
        let plain = RushPlain(amount: "1", itemPriorityActId: "103783", deviceId: "ABCDEF-DEVICE-ID", userId: "9")
        let body = RushCrypto.rushBody(plain: plain)
        let ser = PureCWB.serializePost(body)
        XCTAssertTrue(ser.hasPrefix("actParam="))
        XCTAssertTrue(ser.hasSuffix("v=0003;"))
        XCTAssertFalse(ser.contains(" "))
    }

    func testSM4RoundTrip() {
        let keys = PureCWB.Keys.make()
        let plain = #"[ "10001", "h1" ]"#
        let enc = SM4.encryptCBCHex(plain, keyHex: keys.smk1, ivHex: keys.smk1)
        XCTAssertNotNil(enc)
        XCTAssertEqual(SM4.decryptCBCHex(enc ?? "", keyHex: keys.smk1, ivHex: keys.smk1), plain)
        XCTAssertEqual(keys.smi, BangcleBlob.xorHexNibbles(keys.smk))
        XCTAssertEqual(keys.smk1, MurmurHash3.x64_128(keys.smk + "_bsdk_", seed: 27))
    }

    func testSignDecryptsToFourteenFields() {
        let keys = PureCWB.Keys(
            smk: "0123456789abcdef0123456789abcdef",
            smk1: MurmurHash3.x64_128("0123456789abcdef0123456789abcdef_bsdk_", seed: 27),
            smi: BangcleBlob.xorHexNibbles("0123456789abcdef0123456789abcdef")
        )
        let identity = PureCWB.Identity(
            did: "h463f41b3f65bfa6dd312863db5daabf",
            startId: "mv9e6oop_500vluxp9tu_4",
            userId: "1210173951",
            pageURL: HeaderBuilder.referer,
            userAgent: CookieBridge.userAgent(h5Did: "h463f41b3f65bfa6dd312863db5daabf"),
            bsDeviceId: "bid-2550189502971-aabf-de1d"
        )
        let body = RushCrypto.rushBody(plain: RushPlain(
            amount: "1",
            itemPriorityActId: "107631",
            deviceId: "DEV",
            userId: "1210173951"
        ))
        let packet = PureCWB.sign(
            bodyJSON: body,
            identity: identity,
            keys: keys,
            nowMs: 1_792_059_916_065,
            randomId: "2913985b195cf0d4411d7f73e0b338c6",
            liftStyle: true
        )
        XCTAssertNotNil(packet)
        let cwb = packet!.cwb
        XCTAssertGreaterThanOrEqual(cwb.count, 768)
        XCTAssertEqual(cwb.count % 32, 0)
        XCTAssertEqual(BangcleBlob.did(from: cwb), identity.did)
        XCTAssertEqual(BangcleBlob.hp(from: cwb), "0")
        XCTAssertEqual(BangcleBlob.startId(from: cwb), identity.startId)
        XCTAssertEqual(BangcleBlob.userId(from: cwb), identity.userId)
        XCTAssertEqual(BangcleBlob.wasmVersion(from: cwb), "v1.1.7.4")
        XCTAssertEqual(packet!.hh.count, 32)
        XCTAssertEqual(packet!.ext142, StyleTotalPatch.hashForSign("2913985b195cf0d4411d7f73e0b338c6"))
        XCTAssertGreaterThanOrEqual(String(packet!.ext142).count, 5)
        XCTAssertTrue(packet!.field141.contains("\"has_env\":0"))
        XCTAssertEqual(packet!.dU.prefix(32), keys.smi.prefix(32))
        XCTAssertEqual(BangcleBlob.did(from: packet!.dU), identity.did)
        XCTAssertEqual(BangcleBlob.hp(from: packet!.dU), identity.bsDeviceId)
        XCTAssertEqual(cwb.prefix(32), keys.smi.prefix(32))
        let arr = BangcleBlob.decryptJSONArray(cwb)
        XCTAssertEqual(arr?.count, 14)
        XCTAssertEqual(String(describing: arr?[13] ?? ""), String(packet!.ext142))
    }

    func testEmptyDidRefuses() {
        let keys = PureCWB.Keys.make()
        let packet = PureCWB.sign(
            bodyJSON: #"{"actParam":"x","v":"0003"}"#,
            identity: PureCWB.Identity(did: "", startId: "", userId: "1"),
            keys: keys
        )
        XCTAssertNil(packet)
    }

    func testShortUAAndBid() {
        let ua = CookieBridge.userAgent(h5Did: "h463f41b3f65bfa6dd312863db5daabf")
        let short = PureCWB.shortUA(ua)
        XCTAssertTrue(short.hasPrefix("mozilla/5.0 (iphone"))
        XCTAssertLessThanOrEqual(short.count, 50)
        XCTAssertFalse(short.contains(")"))
        let bid = PureCWB.generateBid(did: "h463f41b3f65bfa6dd312863db5daabf", nowMs: 1_255_018_950_297)
        XCTAssertTrue(bid.hasPrefix("bid-"))
        XCTAssertTrue(bid.contains("aabf"))
        XCTAssertEqual(CookieBridge.sanitizeBsDeviceCookie(bid), bid)
    }
}
