//
//  WKWebViewController.swift
//  WebViewJavascriptBridge-Example-iOS
//
//  Created by 宜信 on 2018/6/11.
//  Copyright © 2018年 宜信. All rights reserved.
//

import UIKit
import WebKit

class WKWebViewController: UINavigationController,WKNavigationDelegate {

    var bridge:WKWebViewJavascriptBridge?
    var webView:WKWebView?
    override func viewDidLoad() {
        super.viewDidLoad()
        configUI()
    }
    
    func configUI()  {
        webView = WKWebView(frame: self.view.bounds)
        self.view.addSubview(webView!)
        WebViewJavascriptBridge.enableLogging()
        bridge = WKWebViewJavascriptBridge.bridge(forWebView: webView!)
        bridge?.webViewDelegate = self
        renderButton(webView!)
        loadExampleApp(webView!)
        configBridge()
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
    }
    
    func renderButton(_ webView:WKWebView) {
        
        let font = UIFont(name: "HelveticaNeue", size: 11)
        let c_button = UIButton(type:.roundedRect)
        self.view.insertSubview(c_button, aboveSubview: webView)
        c_button.setTitle("Call handler", for: .normal)
        c_button.titleLabel?.font = font
        c_button.frame = CGRect(x: 0, y: 400, width: 100, height: 35)
        c_button.addTarget(self, action: #selector(callHandler(sender:)), for: .touchUpInside)
        
        let reload_button = UIButton(type:.roundedRect)
        self.view.insertSubview(reload_button, aboveSubview: webView)
        reload_button.setTitle("Reload WebView", for: .normal)
        reload_button.titleLabel?.font = font
        reload_button.frame = CGRect(x: 90, y: 400, width: 100, height: 35)
        reload_button.addTarget(self, action: #selector(reload), for: .touchUpInside)
        
        let safetyTimeOutButton = UIButton(type: .roundedRect)
        safetyTimeOutButton.setTitle("Disable safety timeout", for: .normal)
        safetyTimeOutButton.frame = CGRect(x: 190, y: 400, width: 120, height: 35)
        safetyTimeOutButton.titleLabel?.font = font
        self.view.insertSubview(safetyTimeOutButton, aboveSubview: webView)
        safetyTimeOutButton.addTarget(self, action: #selector(disableSafetyTimeout), for: .touchUpInside)
    }
    
    
    func loadExampleApp(_ webView:WKWebView) {
        let path = Bundle.main.path(forResource: "ExampleApp", ofType: "html")
        let url = URL(fileURLWithPath: path!)
        do {
            let htmlString = try String(contentsOfFile: path!, encoding: .utf8)
            webView.loadHTMLString(htmlString, baseURL: url)
        }
        catch let error {
            print(error)
        }
    }
    
    @objc
    func callHandler(sender:Any)  {
        let data = ["greetingFromObjC": "Hi there, JS!"]
        bridge?.callHandler(handlerName: "testJavascriptHandler", data: data, responseCallback: { (data) in
            print("testJavascriptHandler responded: \(data)")
        })
    }
    
    @objc
    func reload()  {
        webView?.reload()
    }
    
    @objc
    func disableSafetyTimeout() {
        bridge?.disableJavascriptAlertBoxSafetyTimeout()
    }
    
    func configBridge(){
        bridge?.registerHandler(handlerName: "testObjcCallback", handler: { (data, responseBack) in
            print("testObjcCallback called: \(String(describing: data))")
            responseBack("Response from testObjcCallback")
        })
        bridge?.callHandler(handlerName: "testJavascriptHandler", data: ["foo":"before ready"])
    }

}
