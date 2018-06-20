//
//  WebViewJavascriptBridge.swift
//
//  Copyright © 2018年 xuhaiqing(xuhaiqing007@gmail.com). All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
//

import WebKit

#if os(iOS)

import UIKit
public typealias WVJB_WEBVIEW_TYPE = UIWebView
public typealias WVJB_WEBVIEW_DELEGATE_TYPE = UIWebViewDelegate
public typealias WVJB_WEBVIEW_DELEGATE_INTERFACE = WVJB_WEBVIEW_DELEGATE_TYPE

#else

import AppKit

public typealias WVJB_WEBVIEW_TYPE = WebView
public typealias WVJB_WEBVIEW_DELEGATE_TYPE = WebPolicyDelegate
public typealias WVJB_WEBVIEW_DELEGATE_INTERFACE = WVJB_WEBVIEW_DELEGATE_TYPE

#endif


public class WebViewJavascriptBridge: NSObject,WebViewJavascriptBridgeAPIProtocol,WebViewJavascriptBridgeBaseProtocol,WVJB_WEBVIEW_DELEGATE_INTERFACE {
    public typealias B_WebView = WVJB_WEBVIEW_TYPE
    public typealias Bridge = WebViewJavascriptBridge
    
    private weak var _webView :WVJB_WEBVIEW_TYPE?
    private var _uniqueId : Int = 0
    private var _base : WebViewJavascriptBridgeBase?
    
    weak public var webViewDelegate : AnyObject?

    public func _evaluateJavascript(_ javascriptCommand: String) -> String {
        return _webView?.stringByEvaluatingJavaScript(from: javascriptCommand) ?? ""
    }
    
    public static func enableLogging() -> Void {
        WebViewJavascriptBridgeBase.enableLogging()
    }
    
    public static func setLogMax(length:Int) {
        WebViewJavascriptBridgeBase.setLogMax(length: length)
    }
        
    private func send(_ data:Any?) {
        send(data, responseCallback: nil)
    }
    
    private func send(_ data:Any?,responseCallback:WVJBResponseCallback?) {
        _base?.send(data: data, responseCallback: responseCallback, handlerName: nil)
    }
    
    public func callHandler(handlerName:String?) {
        callHandler(handlerName: handlerName, data: nil)
    }
    
    public func callHandler(handlerName:String?, data:Any?){
        callHandler(handlerName: handlerName, data: data, responseCallback: nil)
    }
    
    public func callHandler(handlerName:String?, data:Any?,responseCallback:WVJBResponseCallback?){
        _base?.send(data: data, responseCallback: responseCallback, handlerName: handlerName)
    }
    
    public func registerHandler(handlerName:String,handler:@escaping WVJBHandler){
        _base?.messageHandlers?[handlerName] = handler
    }
    
    public func removeHandler(handlerName:String){
        _base?.messageHandlers?.removeValue(forKey: handlerName)
    }
    
    public func disableJavascriptAlertBoxSafetyTimeout(){
        _base?.disableJavscriptAlertBoxSafetyTimeout()
    }
    
    deinit {
        _platformSpecificDealloc()
        _base = nil
    }
    
    public func setupInstance(_ webView: Any) {
        _platformSpecificSetup(webView as! WVJB_WEBVIEW_TYPE)
    }
    
    
    #if os(iOS)
    /* Platform specific internals: iOS
     **********************************/
    private func _platformSpecificSetup(_ webView:WVJB_WEBVIEW_TYPE) {
        _webView = webView
        webView.delegate = self
        _base = WebViewJavascriptBridgeBase()
        _base?.delegate = self
    }
    
    private func _platformSpecificDealloc() {
        _webView?.delegate = nil
    }
    
    public func webViewDidFinishLoad(_ webView: UIWebView) {
        if webView != _webView {
            return
        }
        webViewDelegate?.webViewDidFinishLoad?(webView)
    }
    
    public func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        if webView != _webView {
            return
        }
        webViewDelegate?.webView?(webView, didFailLoadWithError: error)
    }
    
    public func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        guard webView == _webView else {
            return true
        }
        guard let url = request.url else {
            return false
        }
        if _base!.isWebViewJavascriptBridgeURL(url) {
            if _base!.isBridgeLoadedURL(url) {
                _base!.injectJavascriptFile()
            }else if _base!.isQueueMessageURL(url) {
                let messageQueueString = _evaluateJavascript(_base!.webViewJavascriptFetchQueueCommand())
                _base!.flush(messageQueue: messageQueueString)
            }else {
                _base!.logUnknownMessage(url)
            }
            return false
        }
        guard let shouldStart = webViewDelegate?.webView?(webView, shouldStartLoadWith: request, navigationType: navigationType)  else {
            return true
        }
        return shouldStart
    }
    
    public func webViewDidStartLoad(_ webView: UIWebView) {
        if webView != _webView {
            return
        }
        webViewDelegate?.webViewDidStartLoad?(webView)
    }
    
    #else
    /* Platform specific internals: macOS
     **********************************/
    private func _platformSpecificSetup(_ webView:WVJB_WEBVIEW_TYPE) {
        _webView = webView
        webView.policyDelegate = self
        _base = WebViewJavascriptBridgeBase()
        _base?.delegate = self
    }
    
    private func _platformSpecificDealloc() {
        _webView?.policyDelegate = nil
    }
    
    public func webView(_ webView: WebView!, decidePolicyForNavigationAction actionInformation: [AnyHashable : Any]!, request: URLRequest!, frame: WebFrame!, decisionListener listener: WebPolicyDecisionListener!) {
        if  webView != _webView {
            listener.use()
            return
        }
        guard let url = request.url else {
            listener.ignore()
            return
        }
        
        if _base!.isWebViewJavascriptBridgeURL(url) {
            if _base!.isBridgeLoadedURL(url) {
                _base!.injectJavascriptFile()
            }else if _base!.isQueueMessageURL(url) {
                let messageQueueString = _evaluateJavascript(_base!.webViewJavascriptFetchQueueCommand())
                _base!.flush(messageQueue: messageQueueString)
            }else {
                _base!.logUnknownMessage(url)
            }
            listener.ignore()
            return
        }
        
        guard webViewDelegate?.webView?(webView, decidePolicyForNavigationAction: actionInformation,request: request, frame: frame, decisionListener: listener) != nil else {
            listener.use()
            return
        }
    }
    #endif
}





