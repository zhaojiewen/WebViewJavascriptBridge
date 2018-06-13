# XHQWebViewJavascriptBridge
[![Version](https://img.shields.io/cocoapods/v/XHQWebViewJavascriptBridge.svg?style=flat)](https://cocoapods.org/pods/XHQWebViewJavascriptBridge)
[![License](https://img.shields.io/cocoapods/l/XHQWebViewJavascriptBridge.svg?style=flat)](https://cocoapods.org/pods/XHQWebViewJavascriptBridge)
[![Platform](https://img.shields.io/cocoapods/p/XHQWebViewJavascriptBridge.svg?style=flat)](https://cocoapods.org/pods/XHQWebViewJavascriptBridge)

An iOS/macOS bridge for sending messages between Swift and JavaScript in UIWebViews, WebViews, WKWebViews. According to [Obj-C and JavaScript](https://github.com/marcuswestin/WebViewJavascriptBridge), and fixxing some bugs.


Installation (iOS & macOS)
------------------------

### Installation with CocoaPods
Add this to your [podfile](https://guides.cocoapods.org/using/getting-started.html) and run `pod install` to install:

```ruby
pod 'XHQWebViewJavascriptBridge'
```
### Manual installation

Drag the `WebViewJavascriptBridge` folder into your project.

In the dialog that appears, uncheck "Copy items into destination group's folder" and select "Create groups for any folders".

Examples
--------

See the `Example/` folder. Open either the iOS or macOS project and hit run to see it in action.

To use a WebViewJavascriptBridge in your own project:

Usage
-----

1) Instantiate WebViewJavascriptBridge with a UIWebView (iOS) or WebView (OSX)  ,or WKWebViewJavascriptBridge with      a WKWebView:

```Swift
bridge = WebViewJavascriptBridge.bridge(forWebView: webView!) 
or
bridge = WKWebViewJavascriptBridge.bridge(forWebView: webView!) 

```

2) Register a handler in Swift, and call a JS handler:

```Swift
bridge?.registerHandler(handlerName: "Swift Echo", handler: { (data, responseCallback) in
print("Swift Echo called with: \(String(describing: data))")
responseCallback(data)
})

bridge?.callHandler(handlerName: "JS Echo", data: nil, responseCallback: { (data) in
print("Swift received response\(String(describing: data))")
})
```

4) Copy and paste `setupWebViewJavascriptBridge` into your JS:

```javascript
function setupWebViewJavascriptBridge(callback) {
if (window.WebViewJavascriptBridge) { return callback(WebViewJavascriptBridge); }
if (window.WVJBCallbacks) { return window.WVJBCallbacks.push(callback); }
window.WVJBCallbacks = [callback];
var WVJBIframe = document.createElement('iframe');
WVJBIframe.style.display = 'none';
WVJBIframe.src = 'https://__bridge_loaded__';
document.documentElement.appendChild(WVJBIframe);
setTimeout(function() { document.documentElement.removeChild(WVJBIframe) }, 0)
}
```

5) Finally, call `setupWebViewJavascriptBridge` and then use the bridge to register handlers and call Swift handlers:

```javascript
setupWebViewJavascriptBridge(function(bridge) {

/* Initialize your app here */

bridge.registerHandler('JS Echo', function(data, responseCallback) {
console.log("JS Echo called with:", data)
responseCallback(data)
})
bridge.callHandler('Swift Echo', {'key':'value'}, function responseCallback(responseData) {
console.log("JS received response:", responseData)
})
})
```

API Reference
-------------

### Swift API

##### `WebViewJavascriptBridge.bridge(forWebView: webView:UIWebView/WebView) or   WKWebViewJavascriptBridge.bridge(forWebView: webView:WKWebView) `

Create a javascript bridge for the given web view.

Example:

```swift   
WebViewJavascriptBridge.bridge(forWebView: webView!) 
WKWebViewJavascriptBridge.bridge(forWebView: webView!) 
```

##### `bridge.registerHandler(handlerName:String,handler:@escaping WVJBHandler)`

Register a handler called `handlerName`. The javascript can then call this handler with `WebViewJavascriptBridge.callHandler("handlerName")`.

Example:

```Swift
bridge?.registerHandler(handlerName: "getScreenHeight", handler: { (data, responseCallback) in
            print("ObjC Echo called with: \(String(describing: data))")
            
            responseCallback(UIScreen.main.bounds.size.height)
})
 
bridge?.registerHandler(handlerName: "log", handler: { (data, responseCallback) in
            print("Log \(String(describing: data))")
})

```

##### `bridge.callHandler(handlerName:String?)`
##### `bridge.callHandler(handlerName:String?, data:Any?)`
##### `bridge.callHandler(handlerName:String?, data:Any?,responseCallback:WVJBResponseCallback?)`


Call the javascript handler called `handlerName`. If a `responseCallback` closure is given the javascript handler can respond.

Example:

```Swift
bridge?.callHandler(handlerName: "testJavascriptHandler", data: ["foo":"before ready"])

```

#### `bridge.webViewDelegate`

Optionally, set a `WKNavigationDelegate/UIWebViewDelegate` if you need to respond to the [web view's lifecycle events](https://developer.apple.com/reference/uikit/uiwebviewdelegate).

##### `bridge.disableJavscriptAlertBoxSafetyTimeout()`

UNSAFE. Speed up bridge message passing by disabling the setTimeout safety check. It is only safe to disable this safety check if you do not call any of the javascript popup box functions (alert, confirm, and prompt). If you call any of these functions from the bridged javascript code, the app will hang.

Example:

bridge.disableJavscriptAlertBoxSafetyTimeout();



### Javascript API

##### `bridge.registerHandler("handlerName", function(responseData) { ... })`

Register a handler called `handlerName`. The Swift can then call this handler with `[bridge callHandler:"handlerName" data:@"Foo"]` and `[bridge callHandler:"handlerName" data:@"Foo" responseCallback:^(id responseData) { ... }]`

Example:

```javascript
bridge.registerHandler("showAlert", function(data) { alert(data) })
bridge.registerHandler("getCurrentPageUrl", function(data, responseCallback) {
responseCallback(document.location.toString())
})
```


##### `bridge.callHandler("handlerName", data)`
##### `bridge.callHandler("handlerName", data, function responseCallback(responseData) { ... })`

Call an Swift handler called `handlerName`. If a `responseCallback` function is given the Swift handler can respond.

Example:

```javascript
bridge.callHandler("Log", "Foo")
bridge.callHandler("getScreenHeight", null, function(response) {
alert('Screen height:' + response)
})
```


##### `bridge.disableJavscriptAlertBoxSafetyTimeout()`

Calling `bridge.disableJavscriptAlertBoxSafetyTimeout()` has the same effect as calling `bridge.disableJavscriptAlertBoxSafetyTimeout()` in Swift.

Example:

```javascript
bridge.disableJavscriptAlertBoxSafetyTimeout()
```

## Author

xuhaiqing, xuhaiqing007@gmail.com

## License

XHQWebViewJavascriptBridge is available under the MIT license. See the LICENSE file for more info.
