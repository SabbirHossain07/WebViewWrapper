//
//  WebViewWrapper.swift
//  WebViewWrapper
//
//  Created by Sopnil Sohan on 11/12/25.
//

import SwiftUI
import WebKit

struct WebViewWrapper: View {
    let url: URL
    @State private var isLoading = false
    @State private var estimatedProgress: Double = 0
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var pageTitle: String? = nil
    @State private var webView: WKWebView?
    @State private var errorMessage: String? = nil
    @State private var showErrorOverlay = false
    @State private var contentSize: CGSize = .zero
    @State private var navigationError: Error? = nil
    
    // Configuration
    var showProgressBar: Bool = true
    var showNavigationControls: Bool = true
    var showPageTitle: Bool = true
    var openExternalLinksInSafari: Bool = true
    
    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Progress Bar
                if showProgressBar && isLoading {
                    WebViewProgressBar(progress: estimatedProgress)
                        .zIndex(1)
                }
                
                // WebView
                WebView(
                    url: url,
                    isLoading: $isLoading,
                    estimatedProgress: $estimatedProgress,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    pageTitle: $pageTitle,
                    errorMessage: $errorMessage,
                    showError: $showErrorOverlay,
                    openExternalLinksInSafari: openExternalLinksInSafari,
                    onNavigationFailed: { error in
                        navigationError = error
                        logErrorDetails(error)
                    },
                    onNavigationFinished: {
                        // Reset error state on successful navigation
                        withAnimation {
                            showErrorOverlay = false
                        }
                    },
                    onContentSizeChange: { size in
                        contentSize = size
                    },
                    onWebViewCreated: { webView in
                        self.webView = webView
                    }
                )
                .edgesIgnoringSafeArea(.bottom)
            }
            
            // Error Overlay (centered, not covering controls)
            if showErrorOverlay, let errorMessage = errorMessage {
                Color.black.opacity(0.1)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        clearError()
                    }
                
                VStack {
                    Spacer()
                    
                    WebViewErrorView(
                        errorMessage: errorMessage,
                        onRetry: reload,
                        onDismiss: clearError
                    )
                    .padding(.horizontal)
                    .padding(.bottom, showNavigationControls ? 80 : 20)
                    
                    Spacer()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showErrorOverlay)
        .onChange(of: errorMessage) { oldValue, newValue in
            withAnimation {
                showErrorOverlay = newValue != nil
            }
        }
        .onChange(of: isLoading) { oldValue, newValue in
            // Reset progress when loading starts
            if newValue {
                estimatedProgress = 0
            }
        }
    }
    
    // MARK: - Actions
    
    private func goBack() {
        webView?.goBack()
        clearError()
    }
    
    private func goForward() {
        webView?.goForward()
        clearError()
    }
    
    private func reload() {
        clearError()
        if isLoading {
            webView?.stopLoading()
        } else {
            webView?.reload()
        }
    }
    
    private func openInSafari() {
        if let currentURL = webView?.url {
            UIApplication.shared.open(currentURL)
        } else {
            UIApplication.shared.open(url)
        }
    }
    
    private func clearError() {
        withAnimation {
            errorMessage = nil
            showErrorOverlay = false
            navigationError = nil
        }
    }
    
    private func logErrorDetails(_ error: Error) {
        let nsError = error as NSError
    }
}
