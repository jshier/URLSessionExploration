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
        case initialized, performing, validating, suspended, finished
    }
    
    private(set) var state: State = .initialized
    
    let id: UUID
    let underlyingQueue: DispatchQueue
    let serializationQueue: DispatchQueue
    let internalQueue: OperationQueue
    private weak var delegate: RequestDelegate?
    
    private(set) var initialRequest: URLRequest?
    var finalRequest: URLRequest? {
        return lastTask?.currentRequest
    }
    var response: HTTPURLResponse? {
        return lastTask?.response as? HTTPURLResponse
    }
    // TODO: Preseve all tasks?
    // TODO: How to expose task progress on iOS 11?
    private(set) var lastTask: URLSessionTask?
    private(set) var error: Error?
    private(set) var credential: URLCredential?
    
    init(id: UUID = UUID(), underlyingQueue: DispatchQueue, serializationQueue: DispatchQueue? = nil, delegate: RequestDelegate) {
        self.id = id
        self.underlyingQueue = underlyingQueue
        self.serializationQueue = serializationQueue ?? underlyingQueue
        internalQueue = OperationQueue(maxConcurrentOperationCount: 1, underlyingQueue: underlyingQueue, name: "org.alamofire.request", startSuspended: true)
        self.delegate = delegate
    }
    
    // MARK: - Internal API
    // Called from internal queue.
    
    func didCreate(request: URLRequest) {
        self.initialRequest = request
    }
    
    func didResume() {
        state = .performing
    }
    
    func didSuspend() {
        state = .suspended
    }
    
    func didCancel() {
        error = AFError.explicitlyCancelled
    }
    
    func didFail(with task: URLSessionTask?, error: Error) {
        // TODO: Investigate whether we want a different mechanism here.
        self.error = self.error ?? error
        didComplete(task: task)
    }
    
    func didComplete(task: URLSessionTask?) {
        lastTask = task
        state = .finished
        
        internalQueue.isSuspended = false
    }
    
    // MARK: - Public API
    
    // Callable from any queue.
    
    public func cancel() {
        delegate?.cancelRequest(self)
    }
    
    public func suspend() {
        delegate?.suspendRequest(self)
    }
    
    public func resume() {
        delegate?.resumeRequest(self)
    }
    
    // MARK: - Closure API
    
    // Callable from any queue
    // TODO: Handle race from internal queue?
    @discardableResult
    func authenticate(withUsername username: String, password: String, persistence: URLCredential.Persistence = .forSession) -> Self {
        let credential = URLCredential(user: username, password: password, persistence: persistence)
        return authenticate(with: credential)
    }
    
    @discardableResult
    func authenticate(with credential: URLCredential) -> Self {
        self.credential = credential
        
        return self
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
    private(set) var data: Data?
    
    func didRecieve(data: Data) {
        if self.data == nil {
            self.data = data
        } else {
            self.data?.append(data)
        }
    }
    
    @discardableResult
    func response(queue: DispatchQueue? = nil, completionHandler: @escaping DataRequestCompletionHandler) -> Self {
        internalQueue.addOperation {
            (queue ?? .main).async {
                completionHandler(Result(value: self.data ?? Data(), error: self.error))
            }
        }
        
        return self
    }
}

class DownloadRequest: Request {
    private(set) var url: URL?
    
    func didComplete(task: URLSessionTask, with url: URL) {
        self.url = url
        
        didComplete(task: task)
    }
    
    @discardableResult
    func response(queue: DispatchQueue? = nil, completionHandler: @escaping DownloadRequestCompletionHandler) -> Self {
        self.internalQueue.addOperation {
            (queue ?? .main).async {
                completionHandler(Result(value: self.url, error: self.error))
            }
        }
        
        return self
    }
}

class UploadRequest: DataRequest {
    enum Uploadable {
        case data(Data)
        case file(URL)
        case stream(InputStream)
    }
    
    let uploadable: Uploadable
    
    init(id: UUID = UUID(), underlyingQueue: DispatchQueue, delegate: RequestDelegate, uploadable: Uploadable) {
        self.uploadable = uploadable
        
        super.init(id: id, underlyingQueue: underlyingQueue, delegate: delegate)
    }
    
    func inputStream() -> InputStream {
        switch uploadable {
        case .stream(let stream): return stream
        default: fatalError("Attempted to access the stream of an UploadRequest that wasn't created with one.")
        }
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
