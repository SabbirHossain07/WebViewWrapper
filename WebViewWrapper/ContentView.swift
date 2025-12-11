//
//  ContentView.swift
//  WebViewWrapper
//
//  Created by Sopnil Sohan on 11/12/25.
//

import SwiftUI

struct ContentView: View {
    @State private var showWebView = false
    @State private var urlString = "https://www.apple.com"
    @State private var urlValidationError: String? = nil
    @FocusState private var isURLFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.blue)
                
                Text("Enhanced WebView Wrapper")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter URL:")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.gray)
                        
                        TextField("https://example.com", text: $urlString)
                            .textFieldStyle(PlainTextFieldStyle())
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($isURLFieldFocused)
                            .onSubmit {
                                validateAndOpenURL()
                            }
                        
                        if !urlString.isEmpty {
                            Button(action: {
                                urlString = ""
                                urlValidationError = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    if let error = urlValidationError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal)
                
                Button(action: validateAndOpenURL) {
                    HStack {
                        Image(systemName: "safari")
                        Text("Open WebView")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Divider()
                    .padding(.vertical)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Links:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(quickLinks, id: \.url) { link in
                                Button(action: {
                                    urlString = link.url
                                    validateAndOpenURL()
                                }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: link.icon)
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                        Text(link.name)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 80, height: 80)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            isURLFieldFocused = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .fullScreenCover(isPresented: $showWebView) {
                if let url = URL(string: urlString) {
                    NavigationStack {
                        WebViewWrapper(url: url)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button(action: {
                                        showWebView = false
                                    }) {
                                        HStack {
                                            Image(systemName: "chevron.left")
                                            Text("Back")
                                        }
                                    }
                                }
                            }
                    }
                }
            }
        }
    }
    
    private func validateAndOpenURL() {
        isURLFieldFocused = false
        
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if empty
        guard !trimmedURL.isEmpty else {
            urlValidationError = "Please enter a URL"
            return
        }
        
        // Add https:// prefix if missing
        var finalURLString = trimmedURL
        if !finalURLString.lowercased().hasPrefix("http://") &&
           !finalURLString.lowercased().hasPrefix("https://") {
            finalURLString = "https://" + finalURLString
        }
        
        // Validate URL format
        guard let url = URL(string: finalURLString),
              url.scheme?.lowercased() == "http" || url.scheme?.lowercased() == "https" else {
            urlValidationError = "Please enter a valid URL (starting with http:// or https://)"
            return
        }
        
        // Update URL string with proper format
        urlString = finalURLString
        urlValidationError = nil
        showWebView = true
    }
    
    private let quickLinks = [
        (name: "Apple", url: "https://www.apple.com", icon: "applelogo"),
        (name: "Google", url: "https://www.google.com", icon: "magnifyingglass"),
        (name: "GitHub", url: "https://github.com", icon: "chevron.left.forwardslash.chevron.right"),
        (name: "SwiftUI", url: "https://developer.apple.com/xcode/swiftui", icon: "swift")
    ]
}
