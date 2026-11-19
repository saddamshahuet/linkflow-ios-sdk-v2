import XCTest
@testable import LinkFlowSDK

// MARK: - 2.2.0: deep link hold / release

final class DeepLinkHoldQueueTests: XCTestCase {

    func testNotHeldByDefaultSoLinksAreDeliveredImmediately() {
        let queue = DeepLinkHoldQueue<String>()
        XCTAssertFalse(queue.isHeld)
        XCTAssertFalse(queue.offer(.direct, "a"))
        XCTAssertEqual(queue.count, 0)
    }

    func testHeldLinksAreReleasedInArrivalOrder() {
        let queue = DeepLinkHoldQueue<String>()
        queue.hold()
        XCTAssertTrue(queue.offer(.deferred, "deferred"))
        XCTAssertTrue(queue.offer(.direct, "direct"))
        XCTAssertEqual(queue.release(), ["deferred", "direct"])
        XCTAssertFalse(queue.isHeld)
        XCTAssertEqual(queue.count, 0)
    }

    func testOnlyTheLatestLinkOfEachKindIsKept() {
        let queue = DeepLinkHoldQueue<String>()
        queue.hold()
        queue.offer(.direct, "first")
        queue.offer(.deferred, "deferred")
        queue.offer(.direct, "second")
        queue.offer(.direct, "third")
        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(queue.release(), ["deferred", "third"])
    }

    func testReleaseWithoutHoldIsANoOp() {
        let queue = DeepLinkHoldQueue<String>()
        XCTAssertEqual(queue.release(), [])
        XCTAssertFalse(queue.offer(.deferred, "x"))
    }
}

// MARK: - 2.2.0: organic installs and match info

final class ResolveResponse22Tests: XCTestCase {

    func testOrganicInstallIdAndTokenAreParsed() {
        let parsed = ParsedAttribution(json: [
            "attributed": false,
            "installId": "i-1",
            "installToken": "t-1",
            "match": ["method": "organic", "confidence": 0],
        ])
        XCTAssertFalse(parsed.attributed)
        XCTAssertEqual(parsed.installID, "i-1")
        XCTAssertEqual(parsed.installToken, "t-1")
        XCTAssertEqual(parsed.match, ParsedMatch(method: "organic", confidence: 0))
        XCTAssertEqual(parsed.category, .organic)
        XCTAssertFalse(parsed.carriesDeepLink)
    }

    func testPre22OrganicResponseHasNoInstallIdOrMatch() {
        let parsed = ParsedAttribution(json: ["attributed": false, "message": "No matching click found"])
        XCTAssertNil(parsed.installID)
        XCTAssertNil(parsed.installToken)
        XCTAssertNil(parsed.match)
    }

    func testAttributedResponseCarriesMatchAndDeepLink() throws {
        let body = #"{"attributed":true,"installId":"i","attributionMethod":"click_token","confidence":1,"deepLinkValue":"app://p/1","deepLinkParams":"{\"sku\":\"A\"}","match":{"method":"click_token","confidence":1.0}}"#
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any])
        let parsed = ParsedAttribution(json: json)
        XCTAssertEqual(parsed.category, .attributed)
        XCTAssertEqual(parsed.match?.method, "click_token")
        XCTAssertEqual(parsed.match?.confidence, 1.0)
        XCTAssertEqual(parsed.deepLinkParams["sku"] as? String, "A")
        XCTAssertTrue(parsed.carriesDeepLink)
    }

    func testMalformedMatchIsIgnored() {
        XCTAssertNil(ParsedMatch(json: ["confidence": 0.5]))
        XCTAssertNil(ParsedMatch(json: "organic"))
        XCTAssertNil(ParsedMatch(json: nil))
        XCTAssertEqual(ParsedMatch(json: ["method": "probabilistic"])?.confidence, nil)
    }

    func testAttributedResultWithoutLinkIsNotADeferredDeepLink() {
        XCTAssertFalse(ParsedAttribution(json: ["attributed": true]).carriesDeepLink)
    }
}

// MARK: - 2.2.0: diagnostics

final class Diagnostics22Tests: XCTestCase {

    private func sample() -> LinkFlowDiagnostics {
        LinkFlowDiagnostics(
            sdkVersion: "2.2.0",
            apiHost: LinkFlowDiagnostics.host(of: "https://user:pw@go.example.com:8443/p?q=1"),
            appKeyConfigured: true,
            consentState: "granted",
            advertisingIDConsent: false,
            launchPendingConsent: false,
            hasInstallID: true,
            hasInstallToken: true,
            customerUserIDSet: true,
            attributionComplete: true,
            lastResolveAt: Date(timeIntervalSince1970: 0),
            lastResolveResult: .networkError,
            lastMatchMethod: nil,
            queuedEventCount: 3,
            deepLinksHeld: true,
            heldDeepLinkCount: 1,
            attributionCallbackSet: false)
    }

    func testHostIsReducedToTheHostName() {
        XCTAssertEqual(sample().apiHost, "go.example.com")
        XCTAssertEqual(LinkFlowDiagnostics.host(of: LinkFlowConfig.defaultAPIBaseURL), "thelinkflow.app")
        XCTAssertNil(LinkFlowDiagnostics.host(of: "not a url"))
    }

    func testDictionaryUsesCrossPlatformKeysAndNoIdentifiers() {
        let dict = sample().dictionary
        XCTAssertEqual(dict["platform"] as? String, "ios")
        XCTAssertEqual(dict["lastResolveResult"] as? String, "network_error")
        XCTAssertEqual(dict["lastResolveAt"] as? String, "1970-01-01T00:00:00.000Z")
        XCTAssertEqual(dict["queuedEventCount"] as? Int, 3)
        XCTAssertEqual(dict["hasInstallId"] as? Bool, true)
        XCTAssertNil(dict["lastMatchMethod"])
        for forbidden in ["installId", "installToken", "appKey", "customerUserId", "advertisingId", "vendorId", "clickToken"] {
            XCTAssertNil(dict[forbidden], "diagnostics must not expose \(forbidden)")
        }
        for case let value as String in dict.values {
            XCTAssertFalse(value.contains("://"), "no URL in diagnostics: \(value)")
        }
    }

    func testConsentState() {
        XCTAssertEqual(LinkFlowDiagnostics.consentState(requireConsent: true, consent: nil), "pending")
        XCTAssertEqual(LinkFlowDiagnostics.consentState(requireConsent: true, consent: LinkFlowConsent(attribution: true)), "granted")
        XCTAssertEqual(LinkFlowDiagnostics.consentState(requireConsent: true, consent: LinkFlowConsent(attribution: false)), "denied")
        XCTAssertEqual(LinkFlowDiagnostics.consentState(requireConsent: false, consent: LinkFlowConsent(attribution: true)), "not_required")
    }

    func testResolveOutcomeIsPersistedForDiagnostics() {
        let suite = "linkflow-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LinkFlowStore(defaults: defaults, service: suite)

        store.recordResolve(.organic, matchMethod: "organic", at: Date(timeIntervalSince1970: 10))
        XCTAssertEqual(store.lastResolveResult, "organic")
        XCTAssertEqual(store.lastMatchMethod, "organic")
        XCTAssertEqual(store.lastResolveAt, Date(timeIntervalSince1970: 10))

        // A failed retry updates the category but keeps the last known match method.
        store.recordResolve(.networkError)
        XCTAssertEqual(store.lastResolveResult, "network_error")
        XCTAssertEqual(store.lastMatchMethod, "organic")
    }
}
