//
//  URLSessionAdditionsTests.swift
//
//
//  Created by Tyler Thompson on 10/29/23.
//

import Afluent
import Foundation
import OHHTTPStubs
import OHHTTPStubsSwift
import XCTest

final class URLSessionAdditionsTests: XCTestCase {
    override func setUp() async throws {
        stub(condition: { _ in true }) { req in
            XCTFail("Unexpected request made: \(req)")
            return HTTPStubsResponse(error: URLError(.badServerResponse))
        }
    }

    override func tearDown() {
        HTTPStubs.removeAllStubs()
    }

    func testURLSessionDeferredTaskPerformsURLRequestWithURL() async throws {
        let url = try XCTUnwrap(URL(string: "https://www.google.com"))
        let expectedData = withUnsafeBytes(of: UUID()) { Data($0) }
        stub(condition: isAbsoluteURLString(url.absoluteString)) { _ in
            HTTPStubsResponse(data: expectedData, statusCode: 200, headers: nil)
        }

        let actualData = try await URLSession.shared.deferredDataTask(from: url)
            .map(\.data)
            .execute()

        XCTAssertEqual(actualData, expectedData)
    }

    func testURLSessionDeferredTaskPerformsURLRequestWithRequest() async throws {
        let url = try XCTUnwrap(URL(string: "https://www.google.com"))
        let expectedRequest = URLRequest(url: url)
        let expectedData = withUnsafeBytes(of: UUID()) { Data($0) }
        stub(condition: isAbsoluteURLString(url.absoluteString)) {
            XCTAssertEqual(expectedRequest, $0)
            return HTTPStubsResponse(data: expectedData, statusCode: 200, headers: nil)
        }

        let actualData = try await URLSession.shared.deferredDataTask(for: expectedRequest)
            .map(\.data)
            .execute()

        XCTAssertEqual(actualData, expectedData)
    }
}
