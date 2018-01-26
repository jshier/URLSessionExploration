//
//  SessionDelegate.swift
//  URLSessionExploration
//
//  Created by Jon Shier on 1/20/18.
//  Copyright © 2018 Jon Shier. All rights reserved.
//

import Foundation

class SessionDelegate: NSObject {
    private var requests: [URLSessionTask : Request] = [:]
    private var responseDatas: [URLSessionTask : Data] = [:]
    private weak var manager: SessionManager?
    
    func didCreate(sessionManager: SessionManager) {
        manager = sessionManager
    }
    
    func didCreate(urlRequest: URLRequest, for request: Request, and task: URLSessionTask) {
        requests[task] = request
        responseDatas[task] = Data()
        task.resume()
        request.didStart(request: urlRequest)
    }
    
    func complete(task: URLSessionTask, withData data: Data?, error: Error?) {
        requests[task]?.didComplete(with: responseDatas[task], error: error)
        requests.removeValue(forKey: task)
        responseDatas.removeValue(forKey: task)
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
            requests[task]?.didFail(with: AFError.certificatePinningFailed(reason: .evaluationFailed))
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
    
    // Progress of sending the body data.
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        NSLog("URLSession: \(session), task: \(task), didSendBodyData: \(bytesSent), totalBytesSent: \(totalBytesSent), totalBytesExpectedToSent: \(totalBytesExpectedToSend)")
    }
    
    // This delegate method is called under two circumstances:
    // To provide the initial request body stream if the task was created with uploadTaskWithStreamedRequest:
    //To provide a replacement request body stream if the task needs to resend a request that has a body stream because of an authentication challenge or other recoverable server error.
    // You do not need to implement this if your code provides the request body using a file URL or an NSData object.
    // Don't enable if streamed bodies aren't supported.
    //    func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
    //
    //    }
    
    // This method is called only for tasks in default and ephemeral sessions. Tasks in background sessions automatically follow redirects.
    // Only code should be customization closure?
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        NSLog("URLSession: \(session), task: \(task), willPerformHTTPRedirection: \(response), newRequest: \(request)")
        completionHandler(request)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        NSLog("URLSession: \(session), task: \(task), didFinishCollecting: \(metrics)")
    }
    
    // Task finished transferring data or had a client error.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        NSLog("URLSession: \(session), task: \(task), didCompleteWithError: \(error?.localizedDescription ?? "None")")
        complete(task: task, withData: responseDatas[task], error: error)
    }
    
    // Only used when background sessions are resuming a delayed task.
    //    func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest request: URLRequest, completionHandler: @escaping (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
    //
    //    }
    @available(macOS 10.13, iOS 11.0, *)
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        NSLog("URLSession: \(session), taskIsWaitingForConnectivity: \(task)")
    }
}

extension SessionDelegate: URLSessionDataDelegate {
    // This method is optional unless you need to support the (relatively obscure) multipart/x-mixed-replace content type.
    // With that content type, the server sends a series of parts, each of which is intended to replace the previous part.
    // The session calls this method at the beginning of each part, and you should then display, discard, or otherwise process the previous part, as appropriate.
    // Don't support?
    //    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    //
    //    }
    
    // Only called if didReceiveResponse is called.
    //    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
    //
    //    }
    
    // Only called if didReceiveResponse is called.
    //    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
    //
    //    }
    
    // Called, possibly more than once, to accumulate the data for a response.
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        NSLog("URLSession: \(session), dataTask: \(dataTask), didReceiveDataOfLength: \(data.count)")
        responseDatas[dataTask]?.append(data)
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
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        NSLog("URLSession: \(session), downloadTask: \(downloadTask), didFinishDownloadingTo: \(location)")
    }
}
