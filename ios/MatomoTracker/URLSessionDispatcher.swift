import Foundation

import WebKit

final class URLSessionDispatcher: Dispatcher {
    
    let serializer = EventSerializer()
    let timeout: TimeInterval
    let session: URLSession
    let baseURL: URL

    private(set) var userAgent: String?
    
    /// Generate a URLSessionDispatcher instance
    ///
    /// - Parameters:
    ///   - baseURL: The url of the Matomo server. This url has to end in `piwik.php`.
    ///   - userAgent: An optional parameter for custom user agent.
    init(baseURL: URL, userAgent: String? = nil) {
        self.baseURL = baseURL
        self.timeout = 5
        self.session = URLSession.shared
        self.userAgent = userAgent
        if self.userAgent == nil {
            self.setDefaultUserAgent()
        }
    }
    
    private func setDefaultUserAgent() {
        DispatchQueue.main.async {
            let webView = WKWebView(frame: .zero)
            UIApplication.shared.keyWindow?.rootViewController?.view?.addSubview(webView)
            webView.evaluateJavaScript("navigator.userAgent") { (result, error) in
                if let ua = result as? String {
                    if let regex = try? NSRegularExpression(pattern: "\\((iPad|iPhone);", options: .caseInsensitive) {
                        let deviceModel = Device.makeCurrentDevice().platform
                        self.userAgent = regex.stringByReplacingMatches(
                            in: ua,
                            options: .withTransparentBounds,
                            range: NSRange(location: 0, length: ua.count),
                            withTemplate: "(\(deviceModel);"
                        ).appending(" MatomoTracker SDK URLSessionDispatcher")
                    }
                }
                webView.removeFromSuperview()
            }
        }
    }
    
    func send(events: [Event], success: @escaping ()->(), failure: @escaping (_ error: Error)->()) {
        let jsonBody: Data
        do {
            jsonBody = try serializer.jsonData(for: events)
        } catch  {
            failure(error)
            return
        }
        let request = buildRequest(baseURL: baseURL, method: "POST", contentType: "application/json; charset=utf-8", body: jsonBody)
        send(request: request, success: success, failure: failure)
    }
    
    private func buildRequest(baseURL: URL, method: String, contentType: String? = nil, body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: baseURL, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: timeout)
        request.httpMethod = method
        body.map { request.httpBody = $0 }
        contentType.map { request.setValue($0, forHTTPHeaderField: "Content-Type") }
        userAgent.map { request.setValue($0, forHTTPHeaderField: "User-Agent") }
        return request
    }
    
    private func send(request: URLRequest, success: @escaping ()->(), failure: @escaping (_ error: Error)->()) {
        let task = session.dataTask(with: request) { data, response, error in
            // should we check the response?
            // let dataString = String(data: data!, encoding: String.Encoding.utf8)
            if let error = error {
                failure(error)
            } else {
                success()
            }
        }
        task.resume()
    }
    
}

