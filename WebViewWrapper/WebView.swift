//
//  WebView.swift
//  WebViewWrapper
//
//  Created by Sopnil Sohan on 11/12/25.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL?
    @Binding var isLoading: Bool
    @Binding var estimatedProgress: Double
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var pageTitle: String?
    @Binding var errorMessage: String?
    @Binding var showError: Bool
    
    // Configuration
    var enableJavaScript: Bool = true
    var allowsBackForwardNavigationGestures: Bool = true
    var openExternalLinksInSafari: Bool = false
    var customUserAgent: String? = nil
    
    // Callbacks
    var onNavigationFailed: ((Error) -> Void)? = nil
    var onNavigationFinished: (() -> Void)? = nil
    var onContentSizeChange: ((CGSize) -> Void)? = nil
    var onWebViewCreated: ((WKWebView) -> Void)? = nil
    
    // Coordinator
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = enableJavaScript
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = allowsBackForwardNavigationGestures
        webView.scrollView.bounces = true
        webView.scrollView.showsHorizontalScrollIndicator = true
        webView.scrollView.showsVerticalScrollIndicator = true
        
        if let userAgent = customUserAgent {
            webView.customUserAgent = userAgent
        }
        
        // Add observers
        addObservers(to: webView, coordinator: context.coordinator)
        
        // Store webView reference in coordinator
        context.coordinator.webView = webView
        
        // Notify wrapper that webView is created
        DispatchQueue.main.async {
            self.onWebViewCreated?(webView)
        }
        
        // Load initial URL (gate by lastRequestedURL)
        if let url = url {
            context.coordinator.lastRequestedURL = url
            loadURL(url, in: webView)
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Update URL only when the bound URL actually changes
        if let url = url,
           context.coordinator.lastRequestedURL != url {
            context.coordinator.lastRequestedURL = url
            loadURL(url, in: webView)
        }
    }
    
    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        // Remove observers
        removeObservers(from: uiView, coordinator: coordinator)
        coordinator.webView = nil
    }
    
    // MARK: - Private Methods
    private func addObservers(to webView: WKWebView, coordinator: Coordinator) {
        webView.addObserver(coordinator,
                          forKeyPath: #keyPath(WKWebView.isLoading),
                          options: [.new],
                          context: nil)
        
        webView.addObserver(coordinator,
                          forKeyPath: #keyPath(WKWebView.estimatedProgress),
                          options: [.new],
                          context: nil)
        
        webView.addObserver(coordinator,
                          forKeyPath: #keyPath(WKWebView.canGoBack),
                          options: [.new],
                          context: nil)
        webView.addObserver(coordinator,
                          forKeyPath: #keyPath(WKWebView.canGoForward),
                          options: [.new],
                          context: nil)
        
        webView.addObserver(coordinator,
                          forKeyPath: #keyPath(WKWebView.title),
                          options: [.new],
                          context: nil)
    }
    
    private static func removeObservers(from webView: WKWebView, coordinator: Coordinator) {
        let keyPaths = [
            #keyPath(WKWebView.isLoading),
            #keyPath(WKWebView.estimatedProgress),
            #keyPath(WKWebView.canGoBack),
            #keyPath(WKWebView.canGoForward),
            #keyPath(WKWebView.title)
        ]
        
        for keyPath in keyPaths {
            webView.removeObserver(coordinator, forKeyPath: keyPath)
        }
    }
    
    private func loadURL(_ url: URL, in webView: WKWebView) {
        let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
        webView.load(request)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebView
        weak var webView: WKWebView?
        var lastLoadedURL: URL?
        var lastRequestedURL: URL?
        private var isCancelledError = false
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        deinit {
            // Clean up observers if not already removed
            if let webView = webView {
                WebView.removeObservers(from: webView, coordinator: self)
            }
        }
        
        // MARK: - WKNavigationDelegate
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.errorMessage = nil
                self.parent.showError = false
                self.isCancelledError = false
                // Avoid aggressively resetting progress here to prevent flicker on sub-navigations
            }
        }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.errorMessage = nil
                self.parent.showError = false
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.errorMessage = nil
                self.parent.showError = false
                self.parent.onNavigationFinished?()
                
                // Update last loaded URL
                self.lastLoadedURL = webView.url
                
                // Update content size
                webView.evaluateJavaScript("document.body.scrollWidth") { (width, error) in
                    webView.evaluateJavaScript("document.body.scrollHeight") { (height, error) in
                        if let width = width as? CGFloat, let height = height as? CGFloat {
                            DispatchQueue.main.async {
                                self.parent.onContentSizeChange?(CGSize(width: width, height: height))
                            }
                        }
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleError(error)
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handleError(error)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Check if this is a cancelled navigation
            if let _ = navigationAction.request.url,
               navigationAction.navigationType == .linkActivated {
                isCancelledError = false
            }
            
            // Handle external links more conservatively: open Safari only for truly external hosts
            if parent.openExternalLinksInSafari,
               let url = navigationAction.request.url,
               navigationAction.navigationType == .linkActivated,
               !url.isFileURL {
                let currentHost = webView.url?.host
                if url.host != currentHost {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                        decisionHandler(.cancel)
                        return
                    }
                }
            }
            
            decisionHandler(.allow)
        }
        
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            // Handle WebContent process termination
            DispatchQueue.main.async {
                self.parent.errorMessage = "Web content process terminated. Please reload."
                self.parent.showError = true
                self.parent.isLoading = false
            }
        }
        
        // MARK: - WKUIDelegate
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Handle new window/target="_blank"
            if navigationAction.targetFrame == nil {
                if let url = navigationAction.request.url {
                    let currentHost = webView.url?.host
                    if parent.openExternalLinksInSafari,
                       url.host != currentHost,
                       UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        webView.load(navigationAction.request)
                    }
                }
            }
            return nil
        }
        
        // MARK: - Error Handling
        
        private func handleError(_ error: Error) {
            let nsError = error as NSError
            
            // Filter out cancelled errors (-999)
            if nsError.domain == NSURLErrorDomain && nsError.code == -999 {
                isCancelledError = true
                DispatchQueue.main.async {
                    self.parent.isLoading = false
                    self.parent.estimatedProgress = 0
                }
                return
            }
            
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.estimatedProgress = 0
                
                if !self.isCancelledError {
                    // Generate user-friendly error message
                    let errorMessage = self.userFriendlyErrorMessage(for: error)
                    self.parent.errorMessage = errorMessage
                    self.parent.showError = true
                    self.parent.onNavigationFailed?(error)
                    
                    // Log error for debugging
                    print("WebView Error: \(error.localizedDescription)")
                    print("Error Code: \(nsError.code)")
                    print("Error Domain: \(nsError.domain)")
                }
            }
        }
        
        private func userFriendlyErrorMessage(for error: Error) -> String {
            let nsError = error as NSError
            
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return "No internet connection. Please check your network settings."
            case NSURLErrorTimedOut:
                return "The request timed out. Please try again."
            case NSURLErrorCannotFindHost:
                return "Cannot find the server. Please check the URL."
            case NSURLErrorCannotConnectToHost:
                return "Cannot connect to the server. The server may be down."
            case NSURLErrorNetworkConnectionLost:
                return "Network connection was lost. Please try again."
            case NSURLErrorSecureConnectionFailed:
                return "Secure connection failed. This may be due to an expired or invalid SSL certificate."
            case NSURLErrorServerCertificateHasBadDate,
                 NSURLErrorServerCertificateUntrusted,
                 NSURLErrorServerCertificateHasUnknownRoot,
                 NSURLErrorServerCertificateNotYetValid:
                return "There's a problem with the website's security certificate."
            case NSURLErrorCancelled:
                return "Navigation was cancelled."
            default:
                if let urlError = error as? URLError {
                    return urlError.localizedDescription
                } else {
                    return "Failed to load page. Please check your internet connection and try again."
                }
            }
        }
        
        // MARK: - KVO Observer
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            guard let webView = object as? WKWebView else { return }
            
            DispatchQueue.main.async {
                switch keyPath {
                case #keyPath(WKWebView.estimatedProgress):
                    self.parent.estimatedProgress = webView.estimatedProgress
                case #keyPath(WKWebView.canGoBack):
                    self.parent.canGoBack = webView.canGoBack
                case #keyPath(WKWebView.canGoForward):
                    self.parent.canGoForward = webView.canGoForward
                case #keyPath(WKWebView.title):
                    self.parent.pageTitle = webView.title
                default:
                    break
                }
            }
        }
    }
}
