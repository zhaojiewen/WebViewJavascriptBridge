//
//  AppDelegate.swift
//  WebViewJavascriptBridge-Example-macOS
//
//  Created by 宜信 on 2018/6/12.
//  Copyright © 2018年 宜信. All rights reserved.
//

import Cocoa
import WebKit

@available(OSX 10.10, *)
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate,WebPolicyDelegate,WKNavigationDelegate {

    @IBOutlet weak var window: NSWindow!
    var webView : WebView?
    var wk_webView : WKWebView?
    var bridge : WebViewJavascriptBridge?
    var wk_bridge : WKWebViewJavascriptBridge?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        createView()
        configWebView()
        configWKWebView()
    }
    
    func configWebView() {
        bridge = WebViewJavascriptBridge.bridge(forWebView: webView!)
        WebViewJavascriptBridge.enableLogging()
        bridge?.registerHandler(handlerName: "testObjcCallback", handler: { (data, responseCallBack) in
            print("testObjcCallback called: \(String(describing: data))")
            responseCallBack("Response from testObjcCallback")
        })
        bridge?.callHandler(handlerName: "testJavascriptHandler", data: ["foo":"before ready"])
        
        let callBackButton = NSButton(frame: NSRect(x: 5, y: 0, width: 120, height: 40))
        callBackButton.title = "Call handler"
        callBackButton.bezelStyle = .rounded
        callBackButton.target = self
        callBackButton.action =  #selector(callHandler)
        webView?.addSubview(callBackButton)
        
        let webViewToggleButton = NSButton(frame: NSRect(x: 120, y: 0, width: 180, height: 40))
        webViewToggleButton.title = "Switch to WKWebView"
        webViewToggleButton.bezelStyle = .rounded
        webViewToggleButton.target = self
        webViewToggleButton.action = #selector(toggleExample)
        webView?.addSubview(webViewToggleButton)
        
        let htmlPath = Bundle.main.path(forResource: "ExampleApp", ofType: "html")
        do {
            let htmlString = try String(contentsOfFile: htmlPath!, encoding: .utf8)
            let baseURL = URL(fileURLWithPath: htmlPath!)
            webView?.mainFrame.loadHTMLString(htmlString, baseURL: baseURL)
        }
        catch let error{
            print(error)
        }
        
    }
    
    func webView(_ webView: WebView!, decidePolicyForNavigationAction actionInformation: [AnyHashable : Any]!, request: URLRequest!, frame: WebFrame!, decisionListener listener: WebPolicyDecisionListener!) {
        
        listener.use()
    }
    
    
    
    func configWKWebView() {
        wk_bridge = WKWebViewJavascriptBridge.bridge(forWebView: wk_webView!)
        wk_bridge?.webViewDelegate = self
        wk_bridge?.registerHandler(handlerName: "testObjcCallback", handler: { (data, responseCallBack) in
            print("testObjcCallback called: \(String(describing: data))")
            responseCallBack("Response from testObjcCallback")
        })
        
        wk_bridge?.callHandler(handlerName: "testJavascriptHandler", data: ["foo":"before ready"])
        
        let callBackButton = NSButton(frame: NSRect(x: 5, y: 0, width: 120, height: 40))
        callBackButton.title = "Call handler"
        callBackButton.bezelStyle = .roundRect
        callBackButton.target = self
        callBackButton.action =  #selector(wk_callHandler)
        wk_webView?.addSubview(callBackButton)
        
        let webViewToggleButton = NSButton(frame: NSRect(x: 120, y: 0, width: 180, height: 40))
        webViewToggleButton.title = "Switch to WebView"
        webViewToggleButton.bezelStyle = .rounded
        webViewToggleButton.target = self
        webViewToggleButton.action = #selector(toggleExample)
        wk_webView?.addSubview(webViewToggleButton)
        
        let htmlPath = Bundle.main.path(forResource: "ExampleApp", ofType: "html")
        do {
            let htmlString = try String(contentsOfFile: htmlPath!, encoding: .utf8)
            let baseURL = URL(fileURLWithPath: htmlPath!)
            wk_webView?.loadHTMLString(htmlString, baseURL: baseURL)
        }
        catch let error{
            print(error)
        }
    }
    
    
    @objc func toggleExample() {
        wk_webView?.isHidden = !(wk_webView?.isHidden)!
        webView?.isHidden = !(webView?.isHidden)!
    }
    
    @objc func callHandler() {
        let data = ["greetingFromObjC": "Hi there, JS!"]
        bridge?.callHandler(handlerName: "testJavascriptHandler", data: data) { (data) in
            print("testJavascriptHandler responded: \(String(describing: data))")
        }
    }
    
    @objc func wk_callHandler() {
        let data = ["greetingFromObjC": "Hi there, JS!"]
        wk_bridge?.callHandler(handlerName: "testJavascriptHandler", data: data) { (data) in
            print("testJavascriptHandler responded: \(String(describing: data))")
        }
    }
    
    func createView() {
        webView = WebView(frame: (window.contentView?.frame)!)
        webView?.isHidden = true
        webView?.autoresizingMask = [.height,.width]
        if #available(OSX 10.10, *) {
            wk_webView = WKWebView(frame: (window.contentView?.frame)!)
            wk_webView?.autoresizingMask = [.height,.width]
            window.contentView?.addSubview(wk_webView!)
            window.contentView?.addSubview(webView!)
        }
        
    }
    
    @available(OSX 10.10, *)
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

