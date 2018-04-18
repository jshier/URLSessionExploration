//
//  Response.swift
//  URLSessionExploration
//
//  Created by Jon Shier on 4/17/18.
//  Copyright © 2018 Jon Shier. All rights reserved.
//

import Foundation

/// Used to store all data associated with a serialized response of a data or upload request.
public struct DataResponse<Value> {
    /// The URL request sent to the server.
    public let request: URLRequest?
    
    /// The server's response to the URL request.
    public let response: HTTPURLResponse?
    
    /// The data returned by the server.
    public let data: Data?
    
    /// The result of response serialization.
    public let result: Result<Value>
    
    /// The timeline of the complete lifecycle of the request.
//    public let timeline: Timeline
    
    /// Returns the associated value of the result if it is a success, `nil` otherwise.
    public var value: Value? { return result.value }
    
    /// Returns the associated error value if the result if it is a failure, `nil` otherwise.
    public var error: Error? { return result.error }
    
//    var _metrics: AnyObject?
    
    /// Creates a `DataResponse` instance with the specified parameters derived from response serialization.
    ///
    /// - parameter request:  The URL request sent to the server.
    /// - parameter response: The server's response to the URL request.
    /// - parameter data:     The data returned by the server.
    /// - parameter result:   The result of response serialization.
    /// - parameter timeline: The timeline of the complete lifecycle of the `Request`. Defaults to `Timeline()`.
    ///
    /// - returns: The new `DataResponse` instance.
    public init(
        request: URLRequest?,
        response: HTTPURLResponse?,
        data: Data?,
        result: Result<Value>)
    {
        self.request = request
        self.response = response
        self.data = data
        self.result = result
    }
}
