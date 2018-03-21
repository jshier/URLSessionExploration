//
//  Request.swift
//  URLSessionExploration
//
//  Created by Jon Shier on 12/9/17.
//  Copyright © 2017 Jon Shier. All rights reserved.
//

import Foundation

typealias DataRequestCompletionHandler = (_ result: Result<Data?>) -> Void
typealias DownloadRequestCompletionHandler = (_ result: Result<URL?>) -> Void

class Request {
    enum State {
        case initialized, performing, finished
    }
    
    private var state: State = .initialized
    let queue: OperationQueue
    
    private(set) var request: URLRequest?
    var error: Error?
    
    init(underlyingQueue: DispatchQueue) {
        queue = OperationQueue(maxConcurrentOperationCount: 1, underlyingQueue: underlyingQueue, name: "com.alamofire.request", startSuspended: true)
    }
    
    func didStart(request: URLRequest) {
        self.request = request
        state = .performing
    }
    
    func didFail(with error: Error) {
        self.error = error
        finish()
    }
    
    func finish() {
        state = .finished
        queue.isSuspended = false
    }
}

class DataRequest: Request {
    private(set) var data: Data?
    
    func didComplete(with data: Data?, error: Error?) {
        self.data = data
        self.error = self.error ?? error
        
        finish()
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
        self.error = self.error ?? error
        
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
