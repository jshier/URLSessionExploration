//
//  Request.swift
//  URLSessionExploration
//
//  Created by Jon Shier on 12/9/17.
//  Copyright © 2017 Jon Shier. All rights reserved.
//

import Foundation

typealias DataRequestCompletionHandler = (_ result: Result<Data>) -> Void
typealias DownloadRequestCompletionHandler = (_ result: Result<URL?>) -> Void

protocol RequestDelegate: AnyObject {
    func cancelRequest(_ request: Request)
    func suspendRequest(_ request: Request)
    func resumeRequest(_ request: Request)
}

class Request {
    enum State {
        case initialized, performing, suspended, finished
    }
    
    private(set) var state: State = .initialized
    
    let id: UUID
    let underlyingQueue: DispatchQueue
    let queue: OperationQueue
    private weak var delegate: RequestDelegate?
    
    private(set) var request: URLRequest?
    var error: Error?
    
    init(id: UUID = UUID(), underlyingQueue: DispatchQueue, delegate: RequestDelegate) {
        self.id = id
        self.underlyingQueue = underlyingQueue
        queue = OperationQueue(maxConcurrentOperationCount: 1, underlyingQueue: underlyingQueue, name: "com.alamofire.request", startSuspended: true)
        self.delegate = delegate
    }
    
    func didStart(request: URLRequest) {
        self.request = request
        state = .performing
    }
    
    func didFail(with error: Error) {
        // TODO: Investigate whether we want a different mechanism here.
        self.error = self.error ?? error
        finish()
    }
    
    func didComplete() {
        finish()
    }
    
    func finish() {
        state = .finished
        queue.isSuspended = false
    }
    
    public func cancel() {
        delegate?.cancelRequest(self)
    }
    
    public func suspend() {
        delegate?.suspendRequest(self)
        state = .suspended
    }
    
    public func resume() {
        delegate?.resumeRequest(self)
    }
}

extension Request: Equatable {
    static func == (lhs: Request, rhs: Request) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Request: Hashable {
    var hashValue: Int {
        return id.hashValue
    }
}

class DataRequest: Request {
    private(set) var data = Data()
    
    func didRecieve(data: Data) {
        self.data.append(data)
    }
    
    @discardableResult
    func response(queue: DispatchQueue? = nil, completionHandler: @escaping DataRequestCompletionHandler) -> Self {
        self.queue.addOperation {
            (queue ?? .main).async {
                completionHandler(Result(value: self.data, error: self.error))
            }
        }
        
        return self
    }
}

class DownloadRequest: Request {
    private(set) var url: URL?
    
    func didComplete(with url: URL) {
        self.url = url
        
        finish()
    }
    
    @discardableResult
    func response(queue: DispatchQueue? = nil, completionHandler: @escaping DownloadRequestCompletionHandler) -> Self {
        self.queue.addOperation {
            (queue ?? .main).async {
                completionHandler(Result(value: self.url, error: self.error))
            }
        }
        
        return self
    }
}

extension Result {
    init(value: Value, error: Error?) {
        if let error = error {
            self = .failure(error)
        } else {
            self = .success(value)
        }
    }
}
