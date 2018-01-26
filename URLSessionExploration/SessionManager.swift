//
//  SessionManager.swift
//  URLSessionExploration
//
//  Created by Jon Shier on 12/9/17.
//  Copyright © 2017 Jon Shier. All rights reserved.
//

import Foundation

class SessionManager {
    static let `default` = SessionManager()
    
    private let configuration: URLSessionConfiguration
    private let delegate: SessionDelegate
    private let rootQueue: DispatchQueue
    private let requestQueue: DispatchQueue
    private let adapter: RequestAdapter?
    let retrier: RequestRetrier?
    let trustManager: ServerTrustManager?
    
    private let session: URLSession
    
    init(configuration: URLSessionConfiguration = .default, delegate: SessionDelegate = SessionDelegate(), rootQueue: DispatchQueue = DispatchQueue(label: "com.alamofire.sessionManager"), requestAdapter: RequestAdapter? = nil, trustManager: ServerTrustManager? = nil, requestRetrier: RequestRetrier? = nil) {
        self.configuration = configuration
        self.delegate = delegate
        self.rootQueue = rootQueue
        adapter = requestAdapter
        retrier = requestRetrier
        self.trustManager = trustManager
        requestQueue = DispatchQueue(label: "\(rootQueue.label).requestQueue", target: rootQueue)
        let delegateQueue = OperationQueue(maxConcurrentOperationCount: 1, underlyingQueue: rootQueue, name: "com.alamofire.sessionManager.sessionDelegateQueue")
        session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
        delegate.didCreate(sessionManager: self)
    }
    
    func request<Convertible: URLRequestConvertible>(_ convertible: Convertible) -> Request {
        let request = Request(underlyingQueue: rootQueue)
        
        requestQueue.async {
            do {
                let initialRequest = try convertible.asURLRequest()
                let adaptedRequest = try self.adapter?.adapt(initialRequest)
                let urlRequest = adaptedRequest ?? initialRequest
                let task = self.session.dataTask(with: urlRequest)
                self.delegate.didCreate(urlRequest: urlRequest, for: request, and: task)
            } catch {
                request.didFail(with: error)
            }
        }
        
        return request
    }
}

extension OperationQueue {
    convenience init(qualityOfService: QualityOfService = .default, maxConcurrentOperationCount: Int = OperationQueue.defaultMaxConcurrentOperationCount, underlyingQueue: DispatchQueue? = nil, name: String? = nil, startSuspended: Bool = false) {
        self.init()
        self.qualityOfService = qualityOfService
        self.maxConcurrentOperationCount = maxConcurrentOperationCount
        self.underlyingQueue = underlyingQueue
        self.name = name
        self.isSuspended = startSuspended
    }
}
