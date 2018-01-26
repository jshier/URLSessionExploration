//
//  URLSessionExplorationTests.swift
//  URLSessionExplorationTests
//
//  Created by Jon Shier on 12/9/17.
//  Copyright © 2017 Jon Shier. All rights reserved.
//

import XCTest
@testable import URLSessionExploration

extension String: URLRequestConvertible {
    public func asURLRequest() throws -> URLRequest {
        let url = URL(string: self)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        return request
    }
}

class URLSessionExplorationTests: XCTestCase {
    
    func testRequest() {
        // Given
        let manager = SessionManager()
        let urlString = "https://httpbin.org/get"
        let expect = expectation(description: "request should finish")
        var requestResult: Result<Data?>?
        
        // When
        manager.request(urlString).response { result in
            requestResult = result
            expect.fulfill()
        }
        waitForExpectations(timeout: 30, handler: nil)
        
        // Then
        XCTAssertTrue(requestResult?.isSuccess == true)
    }
    
    func testFailedConvertible() {
        // Given
        struct ConvertibleFailure: URLRequestConvertible, Error {
            func asURLRequest() throws -> URLRequest {
                throw self
            }
        }
        let manager = SessionManager()
        let expect = expectation(description: "request should fail")
        var requestResult: Result<Data?>?
        
        // When
        manager.request(ConvertibleFailure()).response { result in
            requestResult = result
            expect.fulfill()
        }
        waitForExpectations(timeout: 30, handler: nil)
        
        // Then
        XCTAssertTrue(requestResult?.isSuccess == false)
        XCTAssertNotNil(requestResult?.error)
    }
    
    func testFailedAdapter() {
        // Given
        struct FailingAdapter: RequestAdapter, Error {
            func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
                throw self
            }
        }
        let manager = SessionManager(requestAdapter: FailingAdapter())
        let expect = expectation(description: "request should fail")
        var requestResult: Result<Data?>?
        
        // When
        manager.request("https://httpbin.org/get").response { result in
            requestResult = result
            expect.fulfill()
        }
        waitForExpectations(timeout: 30, handler: nil)
        
        // Then
        XCTAssertTrue(requestResult?.isSuccess == false)
        XCTAssertNotNil(requestResult?.error)
    }
    
    func testFailedEvaluator() {
        // Given
        struct FailedEvaluator: ServerTrustEvaluating {
            func evaluate(_ trust: SecTrust, forHost host: String) -> Bool {
                return false
            }
        }
        let trustManager = ServerTrustManager(evaluators: ["httpbin.org": FailedEvaluator()])
        let manager = SessionManager(trustManager: trustManager)
        let expect = expectation(description: "request should fail")
        var requestResult: Result<Data?>?
        
        // When
        manager.request("https://httpbin.org/get").response { result in
            requestResult = result
            expect.fulfill()
        }
        waitForExpectations(timeout: 30, handler: nil)
        
        // Then
        guard let error = requestResult?.error as? AFError, case .certificatePinningFailed = error else {
            XCTFail()
            return
        }
        
        XCTAssertTrue(requestResult?.isSuccess == false)
        XCTAssertNotNil(requestResult?.error)
    }
    
    func testEvaluatorsWork() {
        // Given
        let trustManager = ServerTrustManager(evaluators: ["httpbin.org": DefaultTrustEvaluator()])
        let manager = SessionManager(trustManager: trustManager)
        let expect = expectation(description: "request should fail")
        var requestResult: Result<Data?>?
        
        // When
        manager.request("https://httpbin.org/get").response { result in
            requestResult = result
            expect.fulfill()
        }
        waitForExpectations(timeout: 30, handler: nil)
        
        // Then
        XCTAssertTrue(requestResult?.isSuccess == true)
    }
    
}
