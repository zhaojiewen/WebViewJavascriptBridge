//
//  WebViewJavascriptBridge.swift
//
//
//  Created by xuhaiqing on 2018/6/7.
//  Copyright © 2018年 xuhaiqing. All rights reserved.
//
//import WebKit

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


class WebViewJavascriptBridge: NSObject,WebViewJavascriptBridgeAPIProtocol,WebViewJavascriptBridgeBaseProtocol,WVJB_WEBVIEW_DELEGATE_INTERFACE {
    private weak var _webView :WVJB_WEBVIEW_TYPE?
    private var _uniqueId : Int = 0
    private var _base : WebViewJavascriptBridgeBase?
    
    weak var webViewDelegate : AnyObject?

    func _evaluateJavascript(_ javascriptCommand: String) -> String {
        return _webView?.stringByEvaluatingJavaScript(from: javascriptCommand) ?? ""
    }
    
    static func enableLogging() -> Void {
        WebViewJavascriptBridgeBase.enableLogging()
    }
    
    static func setLogMax(length:Int) {
        WebViewJavascriptBridgeBase.setLogMax(length: length)
    }
    
    static private func bridge(_ webView:Any) -> WebViewJavascriptBridge? {
        if let wv_webView = webView as? WVJB_WEBVIEW_TYPE {
            let bridge = WebViewJavascriptBridge()
            bridge._platformSpecificSetup(wv_webView)
            return bridge
        }
        fatalError("BadWebViewType:Unknown web view type.")
    }
    
    static func bridge(forWebView webView:Any) -> WebViewJavascriptBridge? {
        return bridge(webView)
    }
    
    private func send(_ data:Any?) {
        send(data, responseCallback: nil)
    }
    
    private func send(_ data:Any?,responseCallback:WVJBResponseCallback?) {
        _base?.send(data: data, responseCallback: responseCallback, handlerName: nil)
    }
    
    func callHandler(handlerName:String?) {
        callHandler(handlerName: handlerName, data: nil)
    }
    
    func callHandler(handlerName:String?, data:Any?){
        callHandler(handlerName: handlerName, data: data, responseCallback: nil)
    }
    
    func callHandler(handlerName:String?, data:Any?,responseCallback:WVJBResponseCallback?){
        _base?.send(data: data, responseCallback: responseCallback, handlerName: handlerName)
    }
    
    func registerHandler(handlerName:String,handler:@escaping WVJBHandler){
        _base?.messageHandlers?[handlerName] = handler
    }
    
    func removeHandler(handlerName:String){
        _base?.messageHandlers?.removeValue(forKey: handlerName)
    }
    
    func disableJavascriptAlertBoxSafetyTimeout(){
        _base?.disableJavscriptAlertBoxSafetyTimeout()
    }
    
    deinit {
        _platformSpecificDealloc()
        _base = nil
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
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        if webView != _webView {
            return
        }
        webViewDelegate?.webViewDidFinishLoad?(webView)
    }
    
    func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        if webView != _webView {
            return
        }
        webViewDelegate?.webView?(webView, didFailLoadWithError: error)
    }
    
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
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
        }else if webViewDelegate != nil && webViewDelegate!.responds(to: #selector(webView(_:shouldStartLoadWith:navigationType:))){
            return webViewDelegate!.webView!(webView, shouldStartLoadWith: request, navigationType: navigationType)
        }else {
            return true
        }
    }
    
    func webViewDidStartLoad(_ webView: UIWebView) {
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
    
    func webView(_ webView: WebView!, decidePolicyForNavigationAction actionInformation: [AnyHashable : Any]!, request: URLRequest!, frame: WebFrame!, decisionListener listener: WebPolicyDecisionListener!) {
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





