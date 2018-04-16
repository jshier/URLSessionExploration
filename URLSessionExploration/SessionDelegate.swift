//
//  SessionDelegate.swift
//  URLSessionExploration
//
//  Created by Jon Shier on 1/20/18.
//  Copyright © 2018 Jon Shier. All rights reserved.
//

import Foundation

class SessionDelegate: NSObject {
    // TODO: Investigate queueing active tasks?
    private(set) var requestTaskMap = RequestTaskMap()

    // TODO: Better way to connect delegate to manager, including queue.
    private weak var manager: SessionManager?
    
    func didCreate(sessionManager: SessionManager) {
        manager = sessionManager
    }
    
    // TODO: Separate task and request creation.
    func didCreate(urlRequest: URLRequest, for request: Request, and task: URLSessionTask) {
        requestTaskMap[request] = task
        
        request.didCreate(request: urlRequest)

        task.resume()
        
        request.didResume()
    }
}

// All delegate methods come from a random queue and need to be enqueued onto the internal queue.
extension SessionDelegate: RequestDelegate {
    func cancelRequest(_ request: Request) {
        manager?.rootQueue.async {
            self.requestTaskMap[request]?.cancel()
            request.didCancel()
        }
    }
    
    func suspendRequest(_ request: Request) {
        manager?.rootQueue.async {
            self.requestTaskMap[request]?.suspend()
            request.didSuspend()
        }
    }
    
    func resumeRequest(_ request: Request) {
        manager?.rootQueue.async {
            // TODO: If queue, move manually resumed requests to the top.
            self.requestTaskMap[request]?.resume()
            request.didResume()
        }
    }
}

extension SessionDelegate: URLSessionDelegate {
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        NSLog("URLSession: \(session), didBecomeInvalidWithError: \(error?.localizedDescription ?? "None")")
    }
    
    // Choose not to implement so the task delegate always receives challenges?
//    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
//
//        completionHandler(.rejectProtectionSpace, nil)
//    }
    
    // iOS: Background Events Method
    // No background specific functionality?
    //    @available(iOS 8.0, *)
    //    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    //
    //    }
    
}

extension SessionDelegate: URLSessionTaskDelegate {
    // Auth challenge, will be received always since the URLSessionDelegate method isn't implemented.
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        NSLog("URLSession: \(session), task: \(task), didReceiveChallenge: \(challenge)")
        let host = challenge.protectionSpace.host
        
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let evaluator = manager?.trustManager?.serverTrustEvaluators(forHost: host),
            let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        guard evaluator.evaluate(serverTrust, forHost: host) else {
            requestTaskMap[task]?.didFail(with: task,
                                          error: AFError.certificatePinningFailed(reason: .evaluationFailed))
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
    
    // Progress of sending the body data.
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        NSLog("URLSession: \(session), task: \(task), didSendBodyData: \(bytesSent), totalBytesSent: \(totalBytesSent), totalBytesExpectedToSent: \(totalBytesExpectedToSend)")
        if #available(iOS 11.0, *) {
            NSLog("URLSession: \(session), task: \(task), progress: \(task.progress)")
        }
    }
    
    // This delegate method is called under two circumstances:
    // To provide the initial request body stream if the task was created with uploadTaskWithStreamedRequest:
    //To provide a replacement request body stream if the task needs to resend a request that has a body stream because of an authentication challenge or other recoverable server error.
    // You do not need to implement this if your code provides the request body using a file URL or an NSData object.
    // Don't enable if streamed bodies aren't supported.
    func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        NSLog("URLSession: \(session), task: \(task), needNewBodyStream")
        
        guard let request = requestTaskMap[task] as? UploadRequest else {
            fatalError("needNewBodyStream for request that isn't UploadRequest.")
        }
        
        completionHandler(request.inputStream())
    }
    
    // This method is called only for tasks in default and ephemeral sessions. Tasks in background sessions automatically follow redirects.
    // Only code should be customization closure?
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        NSLog("URLSession: \(session), task: \(task), willPerformHTTPRedirection: \(response), newRequest: \(request)")
        completionHandler(request)
    }
    
    @available(macOS 10.12, iOS 10.0, *)
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        NSLog("URLSession: \(session), task: \(task), didFinishCollecting: \(metrics)")
    }
    
    // Task finished transferring data or had a client error.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        NSLog("URLSession: \(session), task: \(task), didCompleteWithError: \(error?.localizedDescription ?? "None")")
        
        // TODO: Need to differentiate between Request types?
        if let error = error {
            requestTaskMap[task]?.didFail(with: task, error: error)
        } else {
            requestTaskMap[task]?.didComplete(task: task)
        }
        
        requestTaskMap[task] = nil
        
//        guard let retrier = manager?.retrier, let taskError = error, let manager = manager, let request = requests[task] else {
//            complete(task: task, withData: responseDatas[task], error: error)
//            return
//        }
//
//        retrier.should(manager, retry: request, with: taskError) { (shouldRetry, interval) in
//
//        }
    }
    
    // Only used when background sessions are resuming a delayed task.
    //    func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest request: URLRequest, completionHandler: @escaping (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
    //
    //    }
    
    // This method is called if the waitsForConnectivity property of URLSessionConfiguration is true, and sufficient
    // connectivity is unavailable. The delegate can use this opportunity to update the user interface; for example, by
    // presenting an offline mode or a cellular-only mode.
    //
    // This method is called, at most, once per task, and only if connectivity is initially unavailable. It is never
    // called for background sessions because waitsForConnectivity is ignored for those sessions.
    @available(macOS 10.13, iOS 11.0, *)
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        NSLog("URLSession: \(session), taskIsWaitingForConnectivity: \(task)")
        // Post Notification?
        // Update Request state?
        // Only once? How to know when it's done waiting and resumes the task?
    }
}

extension SessionDelegate: URLSessionDataDelegate {
    // This method is optional unless you need to support the (relatively obscure) multipart/x-mixed-replace content type.
    // With that content type, the server sends a series of parts, each of which is intended to replace the previous part.
    // The session calls this method at the beginning of each part, and you should then display, discard, or otherwise process the previous part, as appropriate.
    // Don't support?
//    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
//        NSLog("URLSession: \(session), dataTask: \(dataTask), didReceive: \(response)")
//
//        completionHandler(.allow)
//    }
    
    // Only called if didReceiveResponse is called.
//    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
//        NSLog("URLSession: \(session), dataTask: \(dataTask), didBecomeDownloadTask")
//    }
    
    // Only called if didReceiveResponse is called.
//    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
//        NSLog("URLSession: \(session), dataTask: \(dataTask), didBecomeStreamTask: \(streamTask)")
//    }
    
    // Called, possibly more than once, to accumulate the data for a response.
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        NSLog("URLSession: \(session), dataTask: \(dataTask), didReceiveDataOfLength: \(data.count)")
        guard let request = requestTaskMap[dataTask] as? DataRequest else {
            fatalError("dataTask received data for incorrect Request subclass: \(String(describing: requestTaskMap[dataTask]))")
        }
        
        request.didRecieve(data: data)
        // Update Request progress?
    }
    
    //    The session calls this delegate method after the task finishes receiving all of the expected data. If you do not implement this method, the default behavior is to use the caching policy specified in the session’s configuration object. The primary purpose of this method is to prevent caching of specific URLs or to modify the userInfo dictionary associated with the URL response.
    //
    //    This method is called only if the NSURLProtocol handling the request decides to cache the response. As a rule, responses are cached only when all of the following are true:
    //
    //    The request is for an HTTP or HTTPS URL (or your own custom networking protocol that supports caching).
    //
    //    The request was successful (with a status code in the 200–299 range).
    //
    //    The provided response came from the server, rather than out of the cache.
    //
    //    The session configuration’s cache policy allows caching.
    //
    //    The provided NSURLRequest object's cache policy (if applicable) allows caching.
    //
    //    The cache-related headers in the server’s response (if present) allow caching.
    //
    //    The response size is small enough to reasonably fit within the cache. (For example, if you provide a disk cache, the response must be no larger than about 5% of the disk cache size.)
    // Only for customization of caching?
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        NSLog("URLSession: \(session), dataTask: \(dataTask), willCacheResponse: \(proposedResponse)")
        
        completionHandler(proposedResponse)
    }
}

extension SessionDelegate: URLSessionDownloadDelegate {
    // Indicates resume data was used to start a download task. Use for ?
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        NSLog("URLSession: \(session), downloadTask: \(downloadTask), didResumeAtOffset: \(fileOffset), expectedTotalBytes: \(expectedTotalBytes)")
    }
    
    // Download progress, as provided by the `Content-Length` header. `totalBytesExpectedToWrite` will be `NSURLSessionTransferSizeUnknown` when there's no header.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        NSLog("URLSession: \(session), downloadTask: \(downloadTask), didWriteData bytesWritten: \(bytesWritten), totalBytesWritten: \(totalBytesWritten), totalBytesExpectedToWrite: \(totalBytesExpectedToWrite)")
    }
    
    // When finished, open for reading or move the file.
    // A file URL for the temporary file. Because the file is temporary, you must either open the file for reading or
    // move it to a permanent location in your app’s sandbox container directory before returning from this delegate
    // method.
    //
    // If you choose to open the file for reading, you should do the actual reading in another thread to avoid blocking
    // the delegate queue.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        NSLog("URLSession: \(session), downloadTask: \(downloadTask), didFinishDownloadingTo: \(location)")
        
        guard let request = requestTaskMap[downloadTask] as? DownloadRequest else {
            fatalError("download finished but either no request found or request wasn't DownloadRequest")
        }
        
        request.didComplete(task: downloadTask, with: location)
    }
}
