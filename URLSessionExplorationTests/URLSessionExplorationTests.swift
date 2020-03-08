//
//  URLSessionExplorationTests.swift
//  URLSessionExplorationTests
//
//  Created by Jon Shier on 12/9/17.
//  Copyright © 2017 Jon Shier. All rights reserved.
//

import XCTest
@testable import URLSessionExploration

final class URLSessionExplorationTests: XCTestCase {
    func testRequest() {
        // Given
        let request = URLRequest.makeHTTPBinRequest()
        let delegate = SessionDelegate()
        let queue = DispatchQueue(label: "aQueue")
        let opQueue = OperationQueue()
        opQueue.maxConcurrentOperationCount = 1
        opQueue.underlyingQueue = queue
        let didGather = expectation(description: "metrics gathered")
        let didComplete = expectation(description: "didComplete")
        delegate.didGatherMetrics = { didGather.fulfill() }
        delegate.didComplete = { didComplete.fulfill() }
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["Header": "Header"]
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: opQueue)
        
        // When
        let task = session.dataTask(with: request)
        task.resume()
        task.cancel()
        
        wait(for: [didGather, didComplete], timeout: 1, enforceOrder: true)
        
        // Then
        XCTAssertTrue(session.configuration.allowsCellularAccess)
    }
    
    func testRequestAsyncCancel() {
        // Given
        let request = URLRequest.makeHTTPBinRequest()
        let delegate = SessionDelegate()
        let queue = DispatchQueue(label: "aQueue")
        let opQueue = OperationQueue()
        opQueue.maxConcurrentOperationCount = 1
        opQueue.underlyingQueue = queue
        let didGather = expectation(description: "metrics gathered")
        let didComplete = expectation(description: "didComplete")
        delegate.didGatherMetrics = { didGather.fulfill() }
        delegate.didComplete = { didComplete.fulfill() }
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["Header": "Header"]
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: opQueue)
        
        // When
        let task = session.dataTask(with: request)
        task.resume()
        DispatchQueue.main.async { task.cancel() }
        
        wait(for: [didGather, didComplete], timeout: 1, enforceOrder: true)
        
        // Then
        XCTAssertTrue(session.configuration.allowsCellularAccess)
    }
    
    func testDownloadNotWorking() {
        // Given
        let request = URLRequest.makeHTTPBinRequest()
        let delegate = SessionDelegate()
        let queue = DispatchQueue(label: "aQueue")
        let opQueue = OperationQueue()
        opQueue.maxConcurrentOperationCount = 1
        opQueue.underlyingQueue = queue
        let didGather = expectation(description: "metrics gathered")
        let didComplete = expectation(description: "didComplete")
        delegate.didGatherMetrics = { didGather.fulfill() }
        delegate.didComplete = { didComplete.fulfill() }
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["Header": "Header"]
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: opQueue)
        
        // When
        let task = session.downloadTask(with: request)
        task.resume()
        DispatchQueue.main.async { task.cancel() }
        
        wait(for: [didComplete, didGather], timeout: 1)
        
        // Then
        XCTAssertTrue(session.configuration.allowsCellularAccess)
    }
    
    func testDownload() {
        // Given
        let request = URLRequest.makeHTTPBinRequest()
        let delegate = SessionDelegate()
        let queue = DispatchQueue(label: "aQueue")
        let opQueue = OperationQueue()
        opQueue.maxConcurrentOperationCount = 1
        opQueue.underlyingQueue = queue
        let didGather = expectation(description: "metrics gathered")
        let didComplete = expectation(description: "didComplete")
        delegate.didGatherMetrics = { didGather.fulfill() }
        delegate.didComplete = { didComplete.fulfill() }
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["Header": "Header"]
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: opQueue)
        
        // When
        let task = session.downloadTask(with: request)
        task.resume()
        DispatchQueue.main.async { task.cancel(byProducingResumeData: { _ in }) }
        
        wait(for: [didComplete, didGather], timeout: 5)
        
        // Then
        XCTAssertTrue(session.configuration.allowsCellularAccess)
    }
    
//    func testMany() {
//        for _ in 0..<100 {
//            testRequestAsyncCancel()
//        }
//    }
}

extension String {
    static let httpBinURLString = "https://httpbin.org"
}

extension URL {
    static func makeHTTPBinURL(path: String = "get") -> URL {
        let url = URL(string: .httpBinURLString)!
        return url.appendingPathComponent(path)
    }
}

extension URLRequest {
    static func makeHTTPBinRequest(path: String = "get",
                                   method: String = "GET",
                                   headers: [String: String] = .init(),
                                   timeout: TimeInterval = 60,
                                   cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy) -> URLRequest {
        var request = URLRequest(url: .makeHTTPBinURL(path: path))
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        request.timeoutInterval = timeout
        request.cachePolicy = cachePolicy
        
        return request
    }
}
