//
//  ResponseSerialization.swift
//  URLSessionExploration
//
//  Created by Jon Shier on 4/17/18.
//  Copyright © 2018 Jon Shier. All rights reserved.
//

import Foundation

// MARK: Protocols

/// The type to which all data response serializers must conform in order to serialize a response.
public protocol DataResponseSerializerProtocol {
    /// The type of serialized object to be created by this serializer.
    associatedtype SerializedObject
    
    /// The function used to serialize the response data in response handlers.
    func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> SerializedObject
}

/// The type to which all download response serializers must conform in order to serialize a response.
public protocol DownloadResponseSerializerProtocol {
    /// The type of serialized object to be created by this `DownloadResponseSerializerType`.
    associatedtype SerializedObject
    
    /// The function used to serialize the downloaded data in response handlers.
    func serializeDownload(request: URLRequest?, response: HTTPURLResponse?, fileURL: URL?, error: Error?) throws -> SerializedObject
}

/// A serializer that can handle both data and download responses.
public typealias ResponseSerializer = DataResponseSerializerProtocol & DownloadResponseSerializerProtocol

/// By default, any serializer declared to conform to both types will get file serialization for free, as it just feeds
/// the data read from disk into the data response serializer.
public extension DownloadResponseSerializerProtocol where Self: DataResponseSerializerProtocol {
    public func serializeDownload(request: URLRequest?, response: HTTPURLResponse?, fileURL: URL?, error: Error?) throws -> Self.SerializedObject {
        guard error == nil else { throw error! }
        
        guard let fileURL = fileURL else {
            throw AFError.responseSerializationFailed(reason: .inputFileNil)
        }
        
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw AFError.responseSerializationFailed(reason: .inputFileReadFailed(at: fileURL))
        }
        
        do {
            return try serialize(request: request, response: response, data: data, error: error)
        } catch {
            throw error
        }
    }
}

// MARK: - AnyResponseSerializer

/// A generic `ResponseSerializer` conforming type.
public final class AnyResponseSerializer<Value>: ResponseSerializer {
    /// A closure which can be used to serialize data responses.
    public typealias DataSerializer = (_ request: URLRequest?, _ response: HTTPURLResponse?, _ data: Data?, _ error: Error?) throws -> Value
    /// A closure which can be used to serialize download reponses.
    public typealias DownloadSerializer = (_ request: URLRequest?, _ response: HTTPURLResponse?, _ fileURL: URL?, _ error: Error?) throws -> Value
    
    let dataSerializer: DataSerializer
    let downloadSerializer: DownloadSerializer?
    
    /// Initialze the instance with both a `DataSerializer` closure and a `DownloadSerializer` closure.
    ///
    /// - Parameters:
    ///   - dataSerializer:     A `DataSerializer` closure.
    ///   - downloadSerializer: A `DownloadSerializer` closure.
    public init(dataSerializer: @escaping DataSerializer, downloadSerializer: @escaping DownloadSerializer) {
        self.dataSerializer = dataSerializer
        self.downloadSerializer = downloadSerializer
    }
    
    /// Initialze the instance with a `DataSerializer` closure. Download serialization will fallback to a default
    /// implementation.
    ///
    /// - Parameters:
    ///   - dataSerializer:     A `DataSerializer` closure.
    public init(dataSerializer: @escaping DataSerializer) {
        self.dataSerializer = dataSerializer
        self.downloadSerializer = nil
    }
    
    public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> Value {
        return try dataSerializer(request, response, data, error)
    }
    
    public func serializeDownload(request: URLRequest?, response: HTTPURLResponse?, fileURL: URL?, error: Error?) throws -> Value {
        return try downloadSerializer?(request, response, fileURL, error) ?? { (request, response, fileURL, error) in
            guard error == nil else { throw error! }
            
            guard let fileURL = fileURL else {
                throw AFError.responseSerializationFailed(reason: .inputFileNil)
            }
            
            let data: Data
            do {
                data = try Data(contentsOf: fileURL)
            } catch {
                throw AFError.responseSerializationFailed(reason: .inputFileReadFailed(at: fileURL))
            }
            
            do {
                return try serialize(request: request, response: response, data: data, error: error)
            } catch {
                throw error
            }
            }(request, response, fileURL, error)
    }
}

// MARK: - Default

extension DataRequest {
    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:              The queue on which the completion handler is dispatched. Defaults to `nil`, which means
    ///                         the handler is called on `.main`.
    ///   - responseSerializer: The response serializer responsible for serializing the request, response, and data.
    ///   - completionHandler:  The code to be executed once the request has finished.
    /// - Returns:              The request.
    @discardableResult
    public func response<Serializer: DataResponseSerializerProtocol>(
        queue: DispatchQueue? = nil,
        responseSerializer: Serializer,
        completionHandler: @escaping (DataResponse<Serializer.SerializedObject>) -> Void)
        -> Self
    {
        internalQueue.addOperation {
            // TODO: Explore use of serialization queue.
//            self.serializationQueue.async {
                let result = Result { try responseSerializer.serialize(request: self.finalRequest,
                                                                       response: self.response,
                                                                       data: self.data,
                                                                       error: self.error)}
                let response = DataResponse<Serializer.SerializedObject>(request: self.finalRequest,
                                                                         response: self.response,
                                                                         data: self.data,
                                                                         result: result)
                (queue ?? .main).async { completionHandler(response) }
//            }
        }
        
        
        return self
    }
    
    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:             The queue on which the completion handler is dispatched. Defaults to `nil`, which means
    ///                        the handler is called on `.main`.
    ///   - options:           The JSON serialization reading options. Defaults to `.allowFragments`.
    ///   - completionHandler: A closure to be executed once the request has finished.
    /// - Returns:             The request.
    @discardableResult
    public func responseJSON(
        queue: DispatchQueue? = nil,
        options: JSONSerialization.ReadingOptions = .allowFragments,
        completionHandler: @escaping (DataResponse<Any>) -> Void)
        -> Self
    {
        return response(
            queue: queue,
            responseSerializer: JSONResponseSerializer(options: options),
            completionHandler: completionHandler
        )
    }
}

/// A `ResponseSerializer` that decodes the response data using `JSONSerialization`. By default, a request returning
/// `nil` or no data is considered an error. However, if the response is has a status code valid for empty responses
/// (`204`, `205`), then an `NSNull`  value is returned.
public final class JSONResponseSerializer: ResponseSerializer {
    let options: JSONSerialization.ReadingOptions
    
    /// Creates an instance with the given `JSONSerilization.ReadingOptions`.
    ///
    /// - Parameter options: The options to use. Defaults to `.allowFragments`.
    public init(options: JSONSerialization.ReadingOptions = .allowFragments) {
        self.options = options
    }
    
    public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> Any {
        guard error == nil else { throw error! }
        
        guard let validData = data, validData.count > 0 else {
            if let response = response, emptyDataStatusCodes.contains(response.statusCode) {
                return NSNull()
            }
            
            throw AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)
        }
        
        do {
            return try JSONSerialization.jsonObject(with: validData, options: options)
        } catch {
            throw AFError.responseSerializationFailed(reason: .jsonSerializationFailed(error: error))
        }
    }
}

/// A set of HTTP response status code that do not contain response data.
private let emptyDataStatusCodes: Set<Int> = [204, 205]
