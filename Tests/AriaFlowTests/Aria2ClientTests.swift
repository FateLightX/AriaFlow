import Foundation
import Testing
@testable import AriaFlow

@Suite("Aria2 client")
struct Aria2ClientTests {
    @Test("reachability probes bypass cached HTTP responses")
    func reachabilityRequestBypassesCache() {
        let request = Aria2Client.makeReachabilityRequest(
            for: URL(string: "http://127.0.0.1:6800/jsonrpc")!
        )
        #expect(request.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
        #expect(request.timeoutInterval == 1)
    }
}
