//
//  RequestTaskMapTests.swift
//  URLSessionExplorationTests
//
//  Created by Jon Shier on 4/7/18.
//  Copyright © 2018 Jon Shier. All rights reserved.
//

import XCTest
@testable import URLSessionExploration

class RequestTaskMapTests: XCTestCase {
    func testRequestTaskMap() {
        // Given
        var map = RequestTaskMap()
        let request = Request(underlyingQueue: .main, delegate: TestRequestDelegate())
        let task = URLSessionTask()
        
        // When
        map[request] = task
        let retrievedTask = map[request]
        let retrievedRequest = map[task]
        
        // Then
        XCTAssertTrue(retrievedTask === task)
        XCTAssertEqual(retrievedRequest, request)
    }
}

final class TestRequestDelegate: RequestDelegate {
    func suspendRequest(_ request: Request) {
        
    }
    
    func resumeRequest(_ request: Request) {
        
    }
    
    func cancelRequest(_ request: Request) {
        
    }
}
