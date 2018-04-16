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
        var requestResult: Result<Data>?
        
        // When
        manager.request(urlString).response { result in
            requestResult = result
            expect.fulfill()
        }
        waitForExpectations(timeout: 30, handler: nil)
        
        // Then
        XCTAssertTrue(requestResult?.isSuccess == true)
    }
    
    func testDelegateIsEmptyAfterRequestFinishes() {
        // Given
        let delegate = SessionDelegate()
        let manager = SessionManager(delegate: delegate)
        let urlString = "https://httpbin.org/get"
        let expect = expectation(description: "request should finish")
        var requestResult: Result<Data>?
        
        // When
        manager.request(urlString).response { result in
            requestResult = result
            expect.fulfill()
        }
        waitForExpectations(timeout: 30, handler: nil)
        
        // Then
        XCTAssertTrue(requestResult?.isSuccess == true)
        XCTAssertTrue(delegate.requestTaskMap.isEmpty)
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
        var requestResult: Result<Data>?
        
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
        var requestResult: Result<Data>?
        
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
        var requestResult: Result<Data>?
        
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
        var requestResult: Result<Data>?
        
        // When
        manager.request("https://httpbin.org/get").response { result in
            requestResult = result
            expect.fulfill()
        }
        waitForExpectations(timeout: 30, handler: nil)
        
        // Then
        XCTAssertTrue(requestResult?.isSuccess == true)
    }
    
    func testDownload() {
        // Given
        let manager = SessionManager()
        let urlString = "https://httpbin.org/bytes/\(1024 * 1024)"
        let expect = expectation(description: "download should finish")
        var requestResult: Result<URL?>?
        
        // When
        manager.download(urlString).response { result in
            requestResult = result
            expect.fulfill()
        }
        waitForExpectations(timeout: 30, handler: nil)
        
        // Then
        XCTAssertTrue(requestResult?.isSuccess == true)
    }
    
    func testDataRequestCanBeCancelled() {
        // Given
        let delegate = SessionDelegate()
        let manager = SessionManager(delegate: delegate)
        let urlString = "https://httpbin.org/delay/1"
        let expect = expectation(description: "request should finish")
        var requestResult: Result<Data>?
        
        // When
        let request = manager.request(urlString).response { result in
            requestResult = result
            expect.fulfill()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            request.cancel()
        }
        
        waitForExpectations(timeout: 30, handler: nil)
        
        // Then
        XCTAssertTrue(requestResult?.isSuccess == false)
        XCTAssertTrue(delegate.requestTaskMap.isEmpty)
        guard let error = request.error as? AFError, error.isExplictlyCancelledError else {
            XCTFail()
            return
        }
    }
    
    func testDataRequestCanBeSuspendedAndResumed() {
        // Given
        let delegate = SessionDelegate()
        let manager = SessionManager(delegate: delegate)
        let urlString = "https://httpbin.org/delay/1"
        let expect = expectation(description: "request should finish")
        var requestResult: Result<Data>?
        var capturedState: Request.State?
        
        // When
        let request = manager.request(urlString).response { result in
            requestResult = result
            expect.fulfill()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            request.suspend()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            capturedState = request.state
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            request.resume()
        }
        
        waitForExpectations(timeout: 30, handler: nil)
        
        // Then
        XCTAssertTrue(requestResult?.isSuccess == true)
        XCTAssertTrue(delegate.requestTaskMap.isEmpty)
        XCTAssertTrue(capturedState == .suspended)
    }
    
    func testUploadRequest() {
        // Given
        let url = Bundle(for: URLSessionExplorationTests.self).url(forResource: "imac", withExtension: "jpg")!
        let imageData = try! Data(contentsOf: url)
        let manager = SessionManager()
        let uploadable = Uploadable()
        let expect = expectation(description: "upload should finish")
        var requestResult: Result<Data>?
        
        // When
        manager.upload(data: imageData, with: uploadable).response { (result) in
            requestResult = result
            expect.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
        
        // Then
        XCTAssertTrue(requestResult?.isSuccess == true)
    }
    
    func testUploadFromFileRequest() {
        // Given
        let url = Bundle(for: URLSessionExplorationTests.self).url(forResource: "imac", withExtension: "jpg")!
        let manager = SessionManager()
        let uploadable = Uploadable()
        let expect = expectation(description: "upload should finish")
        var requestResult: Result<Data>?
        
        // When
        manager.upload(file: url, with: uploadable).response { (result) in
            requestResult = result
            expect.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
        
        // Then
        XCTAssertTrue(requestResult?.isSuccess == true)
    }
    
    func testNonUploadUploadRequest() {
        // Given
        let url = Bundle(for: URLSessionExplorationTests.self).url(forResource: "imac", withExtension: "jpg")!
        let imageData = try! Data(contentsOf: url)
        let manager = SessionManager()
        let uploadable = Uploadable(imageData)
        let expect = expectation(description: "upload should finish")
        var requestResult: Result<Data>?
        
        // When
        manager.request(uploadable).response { (result) in
            requestResult = result
            expect.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
        
        // Then
        XCTAssertTrue(requestResult?.isSuccess == true)
    }
    
    func testUploadFromStreamRequest() {
        // Given
        let url = Bundle(for: URLSessionExplorationTests.self).url(forResource: "imac", withExtension: "jpg")!
        let imageData = try! Data(contentsOf: url)
        let manager = SessionManager()
        let uploadable = Uploadable(imageData)
        let expect = expectation(description: "upload should finish")
        var requestResult: Result<Data>?
        
        // When
        manager.upload(stream: uploadable.stream, with: uploadable).response { (result) in
            requestResult = result
            expect.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
        
        // Then
        XCTAssertTrue(requestResult?.isSuccess == true)
    }
    
    func testUploadFromManualStreamRequest() {
        // Given
        let url = Bundle(for: URLSessionExplorationTests.self).url(forResource: "imac", withExtension: "jpg")!
        let manager = SessionManager()
        let uploadable = Uploadable()
        let stream = InputStream(url: url)!
        let expect = expectation(description: "upload should finish")
        var requestResult: Result<Data>?
        
        // When
        manager.upload(stream: stream, with: uploadable).response { (result) in
            requestResult = result
            expect.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
        
        // Then
        XCTAssertTrue(requestResult?.isSuccess == true)
    }
}

struct Uploadable: URLRequestConvertible {
    let url = URL(string: "https://httpbin.org/anything")!
    let data: Data?
    
    var stream: InputStream {
        return InputStream(data: data!)
    }
    
    init(_ data: Data? = nil) {
        self.data = data
    }
    
    func asURLRequest() throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        
        return request
    }
}
