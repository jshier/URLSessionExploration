//
//  RequestTaskMap.swift
//  URLSessionExploration
//
//  Created by Jon Shier on 4/7/18.
//  Copyright © 2018 Jon Shier. All rights reserved.
//

import Foundation

/// A type that maintains a two way, one to on map of `URLSessionTask`s to `Request`s.
struct RequestTaskMap {
    private var requests: [URLSessionTask: Request]
    private var tasks: [Request: URLSessionTask]
    
    init(requests: [URLSessionTask: Request] = [:], tasks: [Request: URLSessionTask] = [:]) {
        self.requests = requests
        self.tasks = tasks
    }

    // TODO: Investigate whether we could make stronger guarantees. Would likely need to abandon subscripts.
    subscript(_ request: Request) -> URLSessionTask? {
        get { return tasks[request] }
        set {
            guard let newValue = newValue else {
                guard let task = tasks[request] else {
                    fatalError("RequestTaskMap consistency error: no task corresponding to request found.")
                }
                
                tasks.removeValue(forKey: request)
                requests.removeValue(forKey: task)
                
                return
            }
            
            tasks[request] = newValue
            requests[newValue] = request
        }
    }
    
    subscript(_ task: URLSessionTask) -> Request? {
        get { return requests[task] }
        set {
            guard let newValue = newValue else {
                guard let request = requests[task] else {
                    fatalError("RequestTaskMap consistency error: no request corresponding to task found.")
                }
                
                requests.removeValue(forKey: task)
                tasks.removeValue(forKey: request)
                
                return
            }
            
            requests[task] = newValue
            tasks[newValue] = task
        }
    }
    
    var count: Int {
        precondition(requests.count == tasks.count,
                     "RequestTaskMap.count invalid, requests.count: \(requests.count) != tasks.count: \(tasks.count)")
        
        return requests.count
    }
    
    var isEmpty: Bool {
        precondition(requests.isEmpty == tasks.isEmpty,
                     "RequestTaskMap.isEmpty invalid, requests.isEmpty: \(requests.isEmpty) != tasks.isEmpty: \(tasks.isEmpty)")
        
        return requests.isEmpty
    }
}
