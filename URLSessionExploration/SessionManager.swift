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
    
    let configuration: URLSessionConfiguration
    let delegate: SessionDelegate
    let rootQueue: DispatchQueue
    let requestQueue: DispatchQueue
    let adapter: RequestAdapter?
    let retrier: RequestRetrier?
    let trustManager: ServerTrustManager?
    
    let session: URLSession
    
    init(configuration: URLSessionConfiguration = .default,
         delegate: SessionDelegate = SessionDelegate(),
         rootQueue: DispatchQueue = DispatchQueue(label: "org.alamofire.sessionManager"),
         requestAdapter: RequestAdapter? = nil,
         trustManager: ServerTrustManager? = nil,
         requestRetrier: RequestRetrier? = nil) {
        self.configuration = configuration
        self.delegate = delegate
        self.rootQueue = rootQueue
        adapter = requestAdapter
        retrier = requestRetrier
        self.trustManager = trustManager
        requestQueue = DispatchQueue(label: "\(rootQueue.label).requestQueue", target: rootQueue)
        let delegateQueue = OperationQueue(maxConcurrentOperationCount: 1, underlyingQueue: rootQueue, name: "org.alamofire.sessionManager.sessionDelegateQueue")
        session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
        delegate.didCreate(sessionManager: self)
    }
    
    func request<Convertible: URLRequestConvertible>(_ convertible: Convertible) -> DataRequest {
        let request = DataRequest(underlyingQueue: rootQueue, delegate: delegate)
        
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
    
    func download<Convertible: URLRequestConvertible>(_ convertible: Convertible) -> DownloadRequest {
        let request = DownloadRequest(underlyingQueue: rootQueue, delegate: delegate)
        
        requestQueue.async {
            do {
                let initialRequest = try convertible.asURLRequest()
                let adaptedRequest = try self.adapter?.adapt(initialRequest)
                let urlRequest = adaptedRequest ?? initialRequest
                let task = self.session.downloadTask(with: urlRequest)
                self.delegate.didCreate(urlRequest: urlRequest, for: request, and: task)
            } catch {
                request.didFail(with: error)
            }
        }
        
        return request
    }
    
    func upload<Convertible: URLRequestConvertible>(data: Data, with convertible: Convertible) -> DataRequest {
        let request = DataRequest(underlyingQueue: rootQueue, delegate: delegate)
        
        requestQueue.async {
            do {
                let initialRequest = try convertible.asURLRequest()
                let adaptedRequest = try self.adapter?.adapt(initialRequest)
                let urlRequest = adaptedRequest ?? initialRequest
                let task = self.session.uploadTask(with: urlRequest, from: data)
                self.delegate.didCreate(urlRequest: urlRequest, for: request, and: task)
            } catch {
                request.didFail(with: error)
            }
        }
        
        return request
    }
    
    func upload<Convertible: URLRequestConvertible>(file fileURL: URL, with convertible: Convertible) -> DataRequest {
        let request = DataRequest(underlyingQueue: rootQueue, delegate: delegate)
        
        requestQueue.async {
            do {
                let initialRequest = try convertible.asURLRequest()
                let adaptedRequest = try self.adapter?.adapt(initialRequest)
                let urlRequest = adaptedRequest ?? initialRequest
                let task = self.session.uploadTask(with: urlRequest, fromFile: fileURL)
                self.delegate.didCreate(urlRequest: urlRequest, for: request, and: task)
            } catch {
                request.didFail(with: error)
            }
        }
        
        return request
    }
}

extension OperationQueue {
    convenience init(qualityOfService: QualityOfService = .default,
                     maxConcurrentOperationCount: Int = OperationQueue.defaultMaxConcurrentOperationCount,
                     underlyingQueue: DispatchQueue? = nil,
                     name: String? = nil,
                     startSuspended: Bool = false) {
        self.init()
        self.qualityOfService = qualityOfService
        self.maxConcurrentOperationCount = maxConcurrentOperationCount
        self.underlyingQueue = underlyingQueue
        self.name = name
        self.isSuspended = startSuspended
    }
}
