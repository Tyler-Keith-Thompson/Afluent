#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    import Afluent
    import Foundation
    import OHHTTPStubs
    import OHHTTPStubsSwift
    import Testing

    final class URLSessionAdditionsTests {
        init() async throws {
            stub(condition: { _ in true }) { req in
                Issue.record("Unexpected request made: \(req)")
                return HTTPStubsResponse(error: URLError(.badServerResponse))
            }
        }

        deinit {
            HTTPStubs.removeAllStubs()
        }

        @Test func URLSessionDeferredTaskPerformsURLRequestWithURL() async throws {
            let url = try #require(URL(string: "https://www.google.com"))
            let expectedData = withUnsafeBytes(of: UUID()) { Data($0) }
            stub(condition: isAbsoluteURLString(url.absoluteString)) { _ in
                HTTPStubsResponse(data: expectedData, statusCode: 200, headers: nil)
            }

            let actualData = try await URLSession.shared.deferredDataTask(from: url)
                .map(\.data)
                .execute()

            #expect(actualData == expectedData)
        }

        @Test func URLSessionDeferredTaskPerformsURLRequestWithRequest() async throws {
            let url = try #require(URL(string: "https://www.google.com"))
            let expectedRequest = URLRequest(url: url)
            let expectedData = withUnsafeBytes(of: UUID()) { Data($0) }
            stub(condition: isAbsoluteURLString(url.absoluteString)) {
                #expect(expectedRequest == $0)
                return HTTPStubsResponse(data: expectedData, statusCode: 200, headers: nil)
            }

            let actualData = try await URLSession.shared.deferredDataTask(for: expectedRequest)
                .map(\.data)
                .execute()

            #expect(actualData == expectedData)
        }
    }
#endif
