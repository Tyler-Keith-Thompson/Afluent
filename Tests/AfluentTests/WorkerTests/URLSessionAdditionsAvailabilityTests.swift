//
//  URLSessionAdditionsAvailabilityTests.swift
//  Afluent
//

// The library's own condition for the URLSession additions. URLSessionAdditionsTests needs
// OHHTTPStubs, so it runs only on Apple platforms; this one pins that the API exists on Linux too.
#if canImport(Darwin) || canImport(FoundationNetworking)
    import Afluent
    import Foundation
    #if canImport(FoundationNetworking)
        import FoundationNetworking
    #endif
    import Testing

    struct URLSessionAdditionsAvailabilityTests {
        @Test("deferredDataTask(from:) and deferredDataTask(for:) exist wherever URLSession does, and make no request until executed")
        func deferredDataTasksExist() throws {
            let url = try #require(URL(string: "https://example.com"))

            // Units of work are lazy: building them sends nothing, so this needs no network.
            _ = URLSession.shared.deferredDataTask(from: url)
            _ = URLSession.shared.deferredDataTask(for: URLRequest(url: url))
        }
    }
#endif
