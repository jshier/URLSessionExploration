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
        case initialized, performing, suspended, validating, finished
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
    fileprivate(set) var error: Error?
    private(set) var credential: URLCredential?
    fileprivate(set) var validators: [() -> Void] = []
    
    init(id: UUID = UUID(), underlyingQueue: DispatchQueue, serializationQueue: DispatchQueue? = nil, delegate: RequestDelegate) {
        self.id = id
        self.underlyingQueue = underlyingQueue
        self.serializationQueue = serializationQueue ?? underlyingQueue
        internalQueue = OperationQueue(maxConcurrentOperationCount: 1, underlyingQueue: underlyingQueue, name: "org.alamofire.request", startSuspended: true)
        self.delegate = delegate
        
        internalQueue.addOperation {
            self.validators.forEach { $0() }
            self.state = .finished
        }
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
        state = .validating
        
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
    
    /// A closure used to validate a request that takes a URL request, a URL response and data, and returns whether the
    /// request was valid.
    public typealias Validation = (URLRequest?, HTTPURLResponse, Data?) -> ValidationResult
    
    /// Validates the request, using the specified closure.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - parameter validation: A closure to validate the request.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate(_ validation: @escaping Validation) -> Self {
        underlyingQueue.async {
            let validationExecution: () -> Void = { [unowned self] in
                if
                    let response = self.response,
                    self.error == nil,
                    case let .failure(error) = validation(self.finalRequest, response, self.data)
                {
                    self.error = error
                }
            }
            
            self.validators.append(validationExecution)
        }
        
        return self
    }
}

class DownloadRequest: Request {
    private(set) var temporaryURL: URL?
    
    func didComplete(task: URLSessionTask, with url: URL) {
        temporaryURL = url
        
        didComplete(task: task)
    }
    
    @discardableResult
    func response(queue: DispatchQueue? = nil, completionHandler: @escaping DownloadRequestCompletionHandler) -> Self {
        self.internalQueue.addOperation {
            (queue ?? .main).async {
                completionHandler(Result(value: self.temporaryURL, error: self.error))
            }
        }
        
        return self
    }
    
    /// A closure used to validate a request that takes a URL request, a URL response, a temporary URL and a
    /// destination URL, and returns whether the request was valid.
    public typealias Validation = (
        _ request: URLRequest?,
        _ response: HTTPURLResponse,
        _ temporaryURL: URL?,
        _ destinationURL: URL?)
        -> ValidationResult
    
    /// Validates the request, using the specified closure.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - parameter validation: A closure to validate the request.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate(_ validation: @escaping Validation) -> Self {
        underlyingQueue.async {
            let validationExecution: () -> Void = { [unowned self] in
                let request = self.finalRequest
                let temporaryURL = self.temporaryURL
                let destinationURL = self.temporaryURL
                
                if
                    let response = self.response,
                    self.error == nil,
                    case let .failure(error) = validation(request, response, temporaryURL, destinationURL)
                {
                    self.error = error
                }
            }
            
            self.validators.append(validationExecution)
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
