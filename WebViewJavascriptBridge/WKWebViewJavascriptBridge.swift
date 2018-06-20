//
//  WKWebViewJavascriptBridge.swift
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

import Foundation
import WebKit

@available(iOS 7.1,OSX 10.10, *)
public class WKWebViewJavascriptBridge: NSObject,WebViewJavascriptBridgeAPIProtocol,WKNavigationDelegate,WebViewJavascriptBridgeBaseProtocol {
    public typealias B_WebView = WKWebView
    public typealias Bridge = WKWebViewJavascriptBridge
    
    private weak var _webView : B_WebView?
    public weak var webViewDelegate : AnyObject?
    var _uniqueId : Int = 0
    var _base : WebViewJavascriptBridgeBase?
    
    public static func enableLogging(){
        WebViewJavascriptBridgeBase.enableLogging()
    }
    
    public static func setLogMax(length:Int) {
        WebViewJavascriptBridgeBase.setLogMax(length: length)
    }
    
    func reset() {
        _base!.reset()
    }
    
    public func setupInstance(_ webView:Any) {
        _webView = (webView as! WKWebViewJavascriptBridge.B_WebView)
        _webView!.navigationDelegate = self
        _base = WebViewJavascriptBridgeBase()
        _base!.delegate = self
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
    
    public func _evaluateJavascript(_ javascriptCommand: String) -> String {
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
    
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView != _webView {
            return
        }
        webViewDelegate?.webView?(webView, didFinish: navigation)
    }
    
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if webView != _webView {
            decisionHandler(.allow)
            return
        }
        guard webViewDelegate?.webView?(webView, decidePolicyFor: navigationResponse, decisionHandler: decisionHandler) != nil else {
            decisionHandler(.allow)
            return
        }
        
    }
    
    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if webView != _webView {
            completionHandler(.performDefaultHandling,nil)
            return
        }
        guard webViewDelegate?.webView?(webView, didReceive: challenge, completionHandler: completionHandler) != nil else {
            completionHandler(.performDefaultHandling,nil)
            return
        }
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
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
            return
        }
        
        guard webViewDelegate?.webView?(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler) != nil else {
            decisionHandler(.allow)
            return
        }
    }
    
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if webView != _webView {
            return
        }
        
        webViewDelegate?.webView?(webView, didCommit: navigation)
    }
    
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if webView != _webView {
            return
        }
        webViewDelegate?.webView?(webView, didStartProvisionalNavigation: navigation)
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if webView != _webView {
            return
        }
        webViewDelegate?.webView?(webView, didFail: navigation, withError: error)
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if webView != _webView {
            return
        }
        webViewDelegate?.webView?(webView, didFailProvisionalNavigation: navigation, withError: error)
    }
    
    public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        if webView != _webView {
            return
        }
        webViewDelegate?.webView?(webView, didReceiveServerRedirectForProvisionalNavigation: navigation)
    }
    
    @available(iOS 9.0,OSX 10.11,*)
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if webView != _webView {
            return
        }
        webViewDelegate?.webViewWebContentProcessDidTerminate?(webView)
    }
}
