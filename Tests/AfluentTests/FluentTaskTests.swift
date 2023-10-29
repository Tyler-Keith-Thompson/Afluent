import XCTest
import Combine
@testable import Afluent

final class AfluentTests: XCTestCase {
    func testDeferredTaskDoesNotExecuteImmediately() async throws {
        let notFiredExpectation = expectation(description: "did not fire")
        notFiredExpectation.isInverted = true
        
        _ = DeferredTask {
            notFiredExpectation.fulfill()
        }
        
        await fulfillment(of: [notFiredExpectation], timeout: 0.001)
    }
    
    func testDeferredTaskExecutesWhenAskedTo() async throws {
        let firedExpectation = expectation(description: "did not fire")
        
        try DeferredTask {
            firedExpectation.fulfill()
        }.run()
        
        await fulfillment(of: [firedExpectation], timeout: 0.001)
    }
}
