import XCTest
@testable import MT741

final class PureWacTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PureWac.resetCallSeq()
    }

    func testRealMachineVector() {
        let got = PureWac.compute(
            did: "h782fd8b362d5c88a25d42ca39061493",
            sign: "f0d63595b67a24c70df76e0116ede7d3",
            nowMs: 1_791_163_226_740,
            callSeq: 5,
            hasEnv: 0
        )
        XCTAssertEqual(
            got,
            #"{"uuid":"6bcad39d-6bcc-40ba-80b3-8e908b156ede","body":"QAAAANfKNju5cux6PThXD0ax6/DtC6UljOtiJa1NgEWIOYs0Z5CSn2PIsDnc2aoEN+gw44AqxpLDNhKQ6YtSo2rURls=","has_env":0}"#
        )
        XCTAssertEqual(PureWac.callSeq(fromUUID: "6bcad39d-6bcc-40ba-80b3-8e908b156ede"), 5)
        XCTAssertEqual(
            PureWac.decryptBody(
                uuid: "6bcad39d-6bcc-40ba-80b3-8e908b156ede",
                bodyBase64: "QAAAANfKNju5cux6PThXD0ax6/DtC6UljOtiJa1NgEWIOYs0Z5CSn2PIsDnc2aoEN+gw44AqxpLDNhKQ6YtSo2rURls=",
                nowMs: 1_791_163_226_740
            ),
            "f0d63595b67a24c70df76e0116ede7d3h782fd8b362d5c88a25d42ca39061493"
        )
    }

    func testSigmaBucketEdges() {
        let did = "h66890a18ce48366efbff07e59dc195b"
        let sign = "e0c2d7420f27a1b3c4d5e6f708192a3b"
        let a = PureWac.compute(did: did, sign: sign, nowMs: 1_789_317_120_000, callSeq: 1)
        XCTAssertTrue(a.contains("9b35c1f6-9b33-4035-80ce-9aa9beee9abe"))
        XCTAssertTrue(a.contains("QAAAAH/idldPMLTJc7msAmDjPGMnzStGJjJSnjF/a3ourYSl6vk49H9fLLESfHCxuLctHMpQhbohCfP5oIE6fyk/FWw="))
        let b = PureWac.compute(did: did, sign: sign, nowMs: 1_789_332_479_999, callSeq: 1)
        XCTAssertEqual(PureWac.scrambleIndex(1_789_317_120_000), PureWac.scrambleIndex(1_789_332_479_999))
        XCTAssertEqual(PureWac.scrambleIndex(1_789_332_480_000), PureWac.scrambleIndex(1_789_317_120_000) + 1)
        XCTAssertTrue(b.contains("9e05c63e-9e03-4086-8045-9d5d70e89f8c"))
        let c = PureWac.compute(did: did, sign: sign, nowMs: 1_789_332_480_000, callSeq: 1)
        XCTAssertTrue(c.contains("fdb05445-fdb6-4005-8027-0f26016bfc01"))
        XCTAssertTrue(c.contains("QAAAAEEe/an7mZx/UHjR8mE7Nz0wMIDqfrByp/RGIGyTL1zjN6AtQRzdrldoREFDeqqDywzfdO0TWtA2GIL+a8CR9RY="))
    }

    func testKeyBufferLittleEndian() {
        XCTAssertEqual(
            PureWac.keyBufferHex("b234d948-b232-40f9-8000-8226ba02b387"),
            "9f12ddd5ec49934beb30d1538b52107630186ffcff542ce59ff1809a6f78fefe"
        )
        XCTAssertEqual(
            PureWac.keyBufferHex("e80dd54f-e80b-40c0-80e5-8fdd862be994"),
            "b5a4ca59f738a26ca09dd0cac137eaee6636cfb6f3d321cdd848317518fcd10e"
        )
        XCTAssertEqual(
            PureWac.keyBufferHex("6612dde9-6614-40a6-8082-86b2227867aa"),
            "ab16d6e57649efdda4c4450d941007b841b0f0d5ac0eab74eca3c045f90b319b"
        )
    }

    func testCallSeqIncrementsPerDid() {
        XCTAssertEqual(PureWac.peekCallSeq("h1"), 1)
        XCTAssertEqual(PureWac.nextCallSeq("h1"), 1)
        XCTAssertEqual(PureWac.nextCallSeq("h1"), 2)
        XCTAssertEqual(PureWac.nextCallSeq("h2"), 1)
        XCTAssertEqual(PureWac.peekCallSeq("h1"), 3)
        PureWac.resetCallSeq("h1")
        XCTAssertEqual(PureWac.nextCallSeq("h1"), 1)
        XCTAssertEqual(PureWac.peekCallSeq("h2"), 2)
    }
}
