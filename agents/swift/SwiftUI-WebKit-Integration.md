# SwiftUI WebKit Integration

## Overview

SwiftUI provides native integration with WebKit through the `WebView` struct, allowing developers to embed web content directly within SwiftUI applications. This integration enables displaying HTML, CSS, and JavaScript content alongside native views, with support for full browsing experiences including navigation, JavaScript execution, and customization options.

Key components:
- `WebView`: A SwiftUI view that displays web content
- `WebPage`: An observable class that controls and manages web content behavior
- JavaScript interaction capabilities
- Navigation management
- Customization options

## WebView Basics

### Creating a Basic WebView

```swift
import SwiftUI
import WebKit

struct ContentView: View {
    var body: some View {
        WebView(url: URL(string: "https://www.apple.com"))
            .frame(height: 400)
    }
}
```

### Toggling Between Different URLs

```swift
struct ContentView: View {
    @State private var toggle = false

    private var url: URL? {
        toggle ? URL(string: "https://www.webkit.org") : URL(string: "https://www.swift.org")
    }

    var body: some View {
        WebView(url: url)
            .toolbar {
                Button(toggle ? "Show Swift" : "Show WebKit", 
                       systemImage: toggle ? "swift" : "network") {
                    toggle.toggle()
                }
            }
    }
}
```

### Using WebView with WebPage

```swift
struct ContentView: View {
    @State private var page = WebPage()

    var body: some View {
        NavigationStack {
            WebView(page)
                .navigationTitle(page.title)
        }
        .onAppear {
            if let url = URL(string: "https://www.apple.com") {
                let _ = page.load(URLRequest(url: url))
            }
        }
    }
}
```

### Enabling Text Search in a WebView

Use the `findNavigator(isPresented:)` modifier to enable text search within the WebView content.

```swift
import SwiftUI
import WebKit

struct ContentView: View {
    @State private var searchVisible = true

    var body: some View {
        WebView(url: URL(string: "https://www.apple.com"))
            .frame(height: 400)
            .findNavigator(isPresented: $searchVisible)
    }
}
```

## WebPage Configuration

### Creating a WebPage with Configuration

```swift
var configuration = WebPage.Configuration()
configuration.loadsSubresources = true
configuration.defaultNavigationPreferences.allowsContentJavaScript = true
configuration.websiteDataStore = .default()

let page = WebPage(configuration: configuration)
```

### Using Non-Persistent Data Store

```swift
var configuration = WebPage.Configuration()
configuration.websiteDataStore = .nonPersistent()
let page = WebPage(configuration: configuration)
```

### Setting Custom User Agent

```swift
let page = WebPage()
page.customUserAgent = "MyApp/1.0 CustomUserAgent"
```

### Configuring JavaScript Permissions

```swift
var configuration = WebPage.Configuration()
configuration.defaultNavigationPreferences.allowsContentJavaScript = true
let page = WebPage(configuration: configuration)
```

## Navigation Management

### Loading Content

```swift
// Load from URL
let url = URL(string: "https://www.example.com")!
let navigationID = page.load(URLRequest(url: url))

// Load HTML string
let html = "<html><body><h1>Hello World</h1></body></html>"
let navigationID = page.load(html: html, baseURL: URL(string: "https://www.example.com")!)

// Load from Data
let data = Data() // Your data
let navigationID = page.load(data, mimeType: "text/html", characterEncoding: .utf8, baseURL: URL(string: "https://www.example.com")!)
```

### Navigation Controls

```swift
// Reload page
let navigationID = page.reload(fromOrigin: false)

// Stop loading
page.stopLoading()

// Access back-forward list
let canGoBack = !page.backForwardList.backList.isEmpty
let canGoForward = !page.backForwardList.forwardList.isEmpty

// Navigate back or forward
if let backItem = page.backForwardList.backItem {
    let navigationID = page.load(backItem)
}
```

### Observing Navigation Events

```swift
struct ContentView: View {
    @State private var page = WebPage()
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            WebView(page)
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .onChange(of: page.currentNavigationEvent) { _, newEvent in
            if let event = newEvent {
                switch event.state {
                case .started:
                    isLoading = true
                case .finished, .failed:
                    isLoading = false
                default:
                    break
                }
            }
        }
    }
}
```

### Customizing Navigation Behavior

```swift
struct MyNavigationDecider: WebPage.NavigationDeciding {
    func decidePolicyFor(navigationAction: WebPage.NavigationAction) async -> WebPage.NavigationPreferences? {
        // Block navigation to specific domains
        if let url = navigationAction.request.url, url.host == "blocked-site.com" {
            return nil // Return nil to cancel navigation
        }
        
        // Allow navigation with custom preferences
        var preferences = WebPage.NavigationPreferences()
        preferences.allowsContentJavaScript = true
        return preferences
    }
    
    func decidePolicyFor(navigationResponse: WebPage.NavigationResponse) async -> Bool {
        // Check response status code
        if let httpResponse = navigationResponse.response as? HTTPURLResponse {
            return httpResponse.statusCode == 200
        }
        return true
    }
}

// Use the custom navigation decider
let page = WebPage(configuration: WebPage.Configuration(), 
                  navigationDecider: MyNavigationDecider())
```

## JavaScript Interaction

### Executing JavaScript

```swift
// Basic JavaScript execution
let script = "document.title"
do {
    let title = try await page.callJavaScript(script)
    print("Page title: \(title)")
} catch {
    print("Error executing JavaScript: \(error)")
}
```

### Passing Arguments to JavaScript

```swift
let script = """
function findElement(selector) {
    return document.querySelector(selector)?.textContent;
}
return findElement(selector);
"""

let arguments = ["selector": ".main-content h1"]

do {
    let result = try await page.callJavaScript(script, arguments: arguments)
    if let headingText = result as? String {
        print("Heading text: \(headingText)")
    }
} catch {
    print("Error executing JavaScript: \(error)")
}
```

### Executing JavaScript in Specific Frame

```swift
// Get main frame info
if let mainFrame = page.currentNavigationEvent?.frameInfo {
    let script = "document.body.innerHTML"
    do {
        let html = try await page.callJavaScript(script, in: mainFrame)
        print("HTML content: \(html)")
    } catch {
        print("Error executing JavaScript: \(error)")
    }
}
```

### Using Content Worlds for Isolated JavaScript Execution

```swift
import WebKit

let script = "document.title"
let contentWorld = WKContentWorld.page // or .defaultClient or a custom world

do {
    let title = try await page.callJavaScript(script, contentWorld: contentWorld)
    print("Page title: \(title)")
} catch {
    print("Error executing JavaScript: \(error)")
}
```

### Extracting Metadata Example

```swift
func fetchMetadata(for url: URL) async throws -> (title: String, description: String) {
    let page = WebPage()
    
    let request = URLRequest(url: url)
    let navigationID = page.load(request)
    
    // Wait for the page to load by tracking navigation events
    while page.isLoading {
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }
    
    // Extract title
    guard let title = page.title else {
        throw URLError(.cannotParseResponse)
    }
    
    // Extract description using JavaScript
    let fetchDescription = """
    const metaDescription = document.querySelector('meta[name="description"]');
    return metaDescription ? metaDescription.getAttribute('content') : '';
    """
    
    guard let description = try await page.callJavaScript(fetchDescription) as? String else {
        throw URLError(.cannotParseResponse)
    }
    
    return (title, description)
}
```

## Customization Options

### Disabling Navigation Gestures

```swift
WebView(url: url)
    .webViewBackForwardNavigationGestures(.disabled)
```

### Configuring Magnification Gestures

```swift
WebView(url: url)
    .webViewMagnificationGestures(.enabled)
```

### Customizing Link Previews

```swift
WebView(url: url)
    .webViewLinkPreviews(.disabled)
```

### Configuring Text Selection

```swift
WebView(url: url)
    .webViewTextSelection(.enabled)
```

### Setting Content Background

```swift
WebView(url: url)
    .webViewContentBackground(.color(.systemBackground))
```

### Customizing Context Menu

```swift
WebView(url: url)
    .webViewContextMenu { defaultActions in
        // Filter or modify default actions
        let filteredActions = defaultActions.filter { action in
            // Only allow copy and share actions
            return action.identifier == .copy || action.identifier == .share
        }
        
        // Add custom actions
        let customAction = UIAction(title: "Custom Action") { _ in
            print("Custom action triggered")
        }
        
        return filteredActions + [customAction]
    }
```

### Handling Fullscreen Content

```swift
WebView(url: url)
    .webViewElementFullscreenBehavior(.enabled)
```

## Advanced Features

### Capturing Web Content as Image

```swift
func captureWebViewSnapshot(from page: WebPage) async -> Image? {
    do {
        let config = WKSnapshotConfiguration()
        config.rect = CGRect(x: 0, y: 0, width: 1024, height: 768)
        
        return try await page.snapshot(config)
    } catch {
        print("Error capturing snapshot: \(error)")
        return nil
    }
}
```

### Generating PDF from Web Content

```swift
func generatePDF(from page: WebPage) async -> Data? {
    do {
        let config = WKPDFConfiguration()
        return try await page.pdf(configuration: config)
    } catch {
        print("Error generating PDF: \(error)")
        return nil
    }
}
```

### Creating Web Archive

```swift
func createWebArchive(from page: WebPage) async -> Data? {
    do {
        return try await page.webArchiveData()
    } catch {
        print("Error creating web archive: \(error)")
        return nil
    }
}
```

### Custom URL Scheme Handling

```swift
struct MyURLSchemeHandler: URLSchemeHandler {
    func start(task: URLSchemeTask) {
        guard let url = task.request.url, url.scheme == "myapp" else {
            task.didFailWithError(URLError(.badURL))
            return
        }
        
        // Handle custom URL scheme
        let response = URLResponse(url: url, 
                                  mimeType: "text/html", 
                                  expectedContentLength: -1, 
                                  textEncodingName: "utf-8")
        
        let html = "<html><body><h1>Custom Scheme Content</h1></body></html>"
        let data = Data(html.utf8)
        
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }
    
    func stop(task: URLSchemeTask) {
        // Handle task cancellation
    }
}

// Register the custom URL scheme handler
var configuration = WebPage.Configuration()
configuration.setURLSchemeHandler(MyURLSchemeHandler(), forURLScheme: "myapp")
let page = WebPage(configuration: configuration)

// Load content with custom scheme
let customURL = URL(string: "myapp://content")!
let _ = page.load(URLRequest(url: customURL))
```

## References

- [WebKit for SwiftUI Documentation](https://developer.apple.com/documentation/WebKit/webkit-for-swiftui)
- [WebView Documentation](https://developer.apple.com/documentation/WebKit/WebView-swift.struct)
- [WebPage Documentation](https://developer.apple.com/documentation/WebKit/WebPage)
- [JavaScript Execution in WebKit](https://developer.apple.com/documentation/WebKit/WebPage#Executing-JavaScript)
- [WebKit Navigation Management](https://developer.apple.com/documentation/WebKit/webkit-for-swiftui#Managing-navigation-between-webpages)