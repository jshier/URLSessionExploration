//
//  StressTests.swift
//  URLSessionExplorationTests
//
//  Created by Jon Shier on 4/15/18.
//  Copyright © 2018 Jon Shier. All rights reserved.
//

@testable
import URLSessionExploration
import XCTest

final class StressTests: XCTestCase {
    func test1000Requests() {
        // Given
        let manager = SessionManager()
        let indicies = (0..<1000).map { $0 }
        let requests = indicies.map(Requestable.init)
        let expectations = indicies.map { expectation(description: "Request \($0) should finish.") }
        var results: [Result<Data>] = []

        // When
        for i in indicies {
            manager.request(requests[i]).response { (result) in
                results.append(result)
                expectations[i].fulfill()
            }
        }

        waitForExpectations(timeout: 60, handler: nil)

        // Then
        XCTAssertEqual(results.count, 1000)
        XCTAssertEqual(results.map { $0.isSuccess }.count, 1000)
    }
}

struct Requestable: URLRequestConvertible {
    let number: Int
    
    func asURLRequest() throws -> URLRequest {
        let url = URL(string: "https://httpbin.org/anything/\(number)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        return request
    }
}
