//
//  WKWebViewJavascriptBridge.swift
//  CEWebJavaScriptBridge__Frame
//
//  Created by xuhaiqing on 2018/6/11.
//  Copyright © 2018年 xuhaiqing. All rights reserved.
//

import Foundation
import WebKit

class WKWebViewJavascriptBridge: NSObject,WKNavigationDelegate,WebViewJavascriptBridgeBaseProtocol {
    
    private weak var _webView : WKWebView?
    weak var webViewDelegate : WKNavigationDelegate?
    var _uniqueId : Int = 0
    var _base : WebViewJavascriptBridgeBase?
    
    static func enableLogging(){
        WebViewJavascriptBridgeBase.enableLogging()
    }
    
    static func bridge(forWebView webView:WKWebView) -> WKWebViewJavascriptBridge{
        let bridge = WKWebViewJavascriptBridge()
        bridge._setupInstance(webView)
        bridge.reset()
        return bridge
    }
    
    func reset() {
        _base!.reset()
    }
    
    private func _setupInstance(_ webView:WKWebView) {
        _webView = webView
        _webView!.navigationDelegate = self
        _base = WebViewJavascriptBridgeBase()
        _base!.delegate = self
    }
    
    open func send(_ data:Any?) {
        send(data, responseCallback: nil)
    }
    
    open func send(_ data:Any?,responseCallback:WVJBResponseCallback?) {
        _base?.send(data: data, responseCallback: responseCallback, handlerName: nil)
    }
    
    open func callHandler(handlerName:String?) {
        callHandler(handlerName: handlerName, data: nil)
    }
    
    open func callHandler(handlerName:String?, data:Any?){
        callHandler(handlerName: handlerName, data: data, responseCallback: nil)
    }
    
    open func callHandler(handlerName:String?, data:Any?,responseCallback:WVJBResponseCallback?){
        _base?.send(data: data, responseCallback: responseCallback, handlerName: handlerName)
    }
    
    open func registerHandler(handlerName:String,handler:@escaping WVJBHandler){
        _base?.messageHandlers?[handlerName] = handler
    }
    
    open func removeHandler(handlerName:String){
        _base?.messageHandlers?.removeValue(forKey: handlerName)
    }
    
    open func disableJavascriptAlertBoxSafetyTimeout(){
        _base?.disableJavscriptAlertBoxSafetyTimeout()
    }
    
    internal func _evaluateJavascript(_ javascriptCommand: String) -> String {
        _webView!.evaluateJavaScript(javascriptCommand)
        return ""
    }
    
    deinit {
        _base = nil
        _webView?.navigationDelegate = nil
        _webView = nil
        webViewDelegate = nil
    }
    
    func wk_flushMessageQueue() {
        _webView?.evaluateJavaScript(_base!.webViewJavascriptFetchQueueCommand(), completionHandler: { (result, error) in
            if error != nil {
                print("WebViewJavascriptBridge: WARNING: Error when trying to fetch data from WKWebView: \(String(describing: error))")
            }
            self._base?.flush(messageQueue: result as? String)
        })
    }
    
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView != _webView {
            return
        }
        webViewDelegate?.webView?(webView, didFinish: navigation)
    }
    
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if webView != _webView {
            decisionHandler(.allow)
            return
        }
        guard webViewDelegate?.webView?(webView, decidePolicyFor: navigationResponse, decisionHandler: decisionHandler) != nil else {
            decisionHandler(.allow)
            return
        }
        
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if webView != _webView {
            completionHandler(.performDefaultHandling,nil)
            return
        }
        guard webViewDelegate?.webView?(webView, didReceive: challenge, completionHandler: completionHandler) != nil else {
            completionHandler(.performDefaultHandling,nil)
            return
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if webView != _webView {
            decisionHandler(.allow)
            return
        }
        guard let url = navigationAction.request.url else{
            decisionHandler(.cancel)
            return
        }
        
        if _base!.isWebViewJavascriptBridgeURL(url) {
            if _base!.isBridgeLoadedURL(url) {
                _base!.injectJavascriptFile()
            }else if _base!.isQueueMessageURL(url) {
                wk_flushMessageQueue()
            }else {
                _base?.logUnknownMessage(url)
            }
            decisionHandler(.cancel)
        }
        
        guard webViewDelegate?.webView?(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler) != nil else {
            decisionHandler(.allow)
            return
        }
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if webView != _webView {
            return
        }
        
        webViewDelegate?.webView?(webView, didCommit: navigation)
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if webView != _webView {
            return
        }
        webViewDelegate?.webView?(webView, didStartProvisionalNavigation: navigation)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if webView != _webView {
            return
        }
        webViewDelegate?.webView?(webView, didFail: navigation, withError: error)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if webView != _webView {
            return
        }
        webViewDelegate?.webView?(webView, didFailProvisionalNavigation: navigation, withError: error)
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        if webView != _webView {
            return
        }
        webViewDelegate?.webView?(webView, didReceiveServerRedirectForProvisionalNavigation: navigation)
    }
    
}
