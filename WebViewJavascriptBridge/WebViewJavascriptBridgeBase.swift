//
//  WebViewJavascriptBridgeBase.swift
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

public struct WebViewBaseURI {
    static public let scheme = "https"
    static public let queueHasMessage = "__wvjb_queue_message__"
    static public let bridgeLoaded = "__bridge_loaded__"
}

public typealias WVJBResponseCallback = (Any?) -> Swift.Void
public typealias WVJBHandler = (Any?,@escaping WVJBResponseCallback) -> Swift.Void
public typealias WVJBMessage = Dictionary<String, Any>

public protocol WebViewJavascriptBridgeAPIProtocol : NSObjectProtocol {
    associatedtype Bridge:NSObject,WebViewJavascriptBridgeAPIProtocol
    associatedtype B_WebView
    
    static func bridge(forWebView webView:Self.B_WebView) -> Bridge
    static func enableLogging() -> Void
    static func setLogMax(length:Int)
    
    func setupInstance(_ webView:Any)
    func callHandler(handlerName:String?)
    func callHandler(handlerName:String?, data:Any?)
    func callHandler(handlerName:String?, data:Any?,responseCallback:WVJBResponseCallback?)
    func registerHandler(handlerName:String,handler:@escaping WVJBHandler)
    func removeHandler(handlerName:String)
    func disableJavascriptAlertBoxSafetyTimeout()
    
    var webViewDelegate:AnyObject? {get set}

}

extension WebViewJavascriptBridgeAPIProtocol {
    public static func bridge(forWebView webView:Self.B_WebView) -> Bridge{
        let bridge = Self.Bridge()
        bridge.setupInstance(webView)
        return bridge
    }
}


public protocol WebViewJavascriptBridgeBaseProtocol:NSObjectProtocol {
    @discardableResult func _evaluateJavascript(_ javascriptCommand:String) -> String
}

public class WebViewJavascriptBridgeBase: NSObject {
    public weak var delegate : WebViewJavascriptBridgeBaseProtocol?
    public var startupMessageQueue : Array<WVJBMessage>?
    public var responseCallbacks : Dictionary<String, WVJBResponseCallback>?
    public var messageHandlers : Dictionary<String, WVJBHandler>?
    public var messageHandler : WVJBMessage?
    
    private var _uniqueId:Int
    private weak var _webViewDelegate:AnyObject?
    
    private static var logging = false
    private static var logMaxLength = 500
    
    override init() {
        _uniqueId = 0
        messageHandlers = Dictionary<String , WVJBHandler>()
        startupMessageQueue = []
        responseCallbacks = Dictionary<String , WVJBResponseCallback>()
    }
    deinit {
        messageHandlers = nil
        startupMessageQueue = nil
        responseCallbacks = nil
    }
    
    public static func enableLogging() {
        logging = true
    }
    
    public static func setLogMax(length:Int) {
        logMaxLength = length
    }
    
    public func reset() {
        startupMessageQueue = Array<WVJBMessage>()
        responseCallbacks = Dictionary<String, WVJBResponseCallback>()
    }
    
    public func send(data:Any?,responseCallback:WVJBResponseCallback?,handlerName:String?){
        var message = [String:Any]()
        if data != nil {
            message["data"] = data
        }
        if responseCallback != nil {
            _uniqueId += 1
            let callbackId = "swift_cb_\(_uniqueId)"
            
            responseCallbacks?[callbackId] = responseCallback
            message["callbackId"] = callbackId
        }
        
        if handlerName != nil {
            message["handlerName"] = handlerName
        }
        _queue(message:message)
    }
    
    public func flush(messageQueue:String?) {
        guard let messageQueueString:String = messageQueue, messageQueueString.count > 0 else {
            print("WebViewJavascriptBridge: WARNING: Swift got nil while fetching the message queue JSON from webview. This can happen if the WebViewJavascriptBridge JS is not currently present in the webview, e.g if the webview just loaded a new page.")
            return
        }
        
        let messages = _deserialize(messageJSON: messageQueueString) ?? []
        
        for message in messages {
            guard message is WVJBMessage else {
                print("WebViewJavascriptBridge: WARNING: Invalid \(type(of: messages))  received: \(messages)")
                continue
            }
            _log(action: "REVD", json: message)
            
            let jb_message = message as! WVJBMessage
            if let responseId = jb_message["responseId"] as? String {
                if let responseCallback = self.responseCallbacks?[responseId] {
                    responseCallback(jb_message["responseData"])
                    self.responseCallbacks?.removeValue(forKey: responseId)
                }
            }else {
                var responseCallback:WVJBResponseCallback = { responseData in
                    // do nothing
                }
                if let callbackId = jb_message["callbackId"] {
                    responseCallback = {responseData in
                        let msg : WVJBMessage = ["responseId":callbackId,"responseData":responseData ?? ""]
                        self._queue(message: msg)
                    }
                }
                if let handler = self.messageHandlers![jb_message["handlerName"] as! String] {
                    handler(jb_message["data"],responseCallback)
                }else {
                    print("WVJBNoHandlerException, No handler for message from JS: \(jb_message)")
                    continue
                }
                
            }
        }
        
    }
    
    public func injectJavascriptFile() {
        _evaluateJavascript(javascriptCommand: WebViewJavascriptBridge_js)
        if self.startupMessageQueue != nil {
            let queue = self.startupMessageQueue!
            self.startupMessageQueue = nil
            for queuedMessage in queue {
                _dispatch(message: queuedMessage)
            }
        }
    }
    
    public func isWebViewJavascriptBridgeURL(_ url:URL) -> Bool {
        if  !isSchemeMatch(url) {
            return false
        }
        return isQueueMessageURL(url) || isBridgeLoadedURL(url)
    }
    
    public func isSchemeMatch(_ url:URL) -> Bool {
        return url.scheme?.lowercased() == WebViewBaseURI.scheme
    }
    
    public func isQueueMessageURL(_ url:URL) -> Bool {
        return isSchemeMatch(url) && url.host?.lowercased() == WebViewBaseURI.queueHasMessage
    }
    
    public func isBridgeLoadedURL(_ url:URL) -> Bool {
        return isSchemeMatch(url) && url.host?.lowercased() == WebViewBaseURI.bridgeLoaded
    }
    
    public func logUnknownMessage(_ url:URL) {
        print("WebViewJavascriptBridge: WARNING: Received unknown WebViewJavascriptBridge command \(url.absoluteString)")
    }
    
    public func webViewJavascriptCheckCommand() -> String {
        return "typeof WebViewJavascriptBridge == \'object\';"
    }
    
    public func webViewJavascriptFetchQueueCommand() -> String{
        return "WebViewJavascriptBridge._fetchQueue();"
    }
    
    public func disableJavscriptAlertBoxSafetyTimeout() {
        send(data: nil, responseCallback: nil, handlerName: "_disableJavascriptAlertBoxSafetyTimeout")
    }
    
    //Private
    //\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    private func _evaluateJavascript(javascriptCommand:String) {
        delegate?._evaluateJavascript(javascriptCommand)
    }
    
    private func _queue(message:WVJBMessage) {
        if startupMessageQueue != nil {
            startupMessageQueue!.append(message)
        }else {
            _dispatch(message:message)
        }
    }
    
    private func _dispatch(message:WVJBMessage) {
        _log(action: "SEND", json: message)
        let messageJSON = _serialize(message: message, pretty: false, base64: true) ?? ""
        
        let javascriptCommand = "WebViewJavascriptBridge._handleMessageFromSwift('\(messageJSON)');"
        DispatchQueue.main.async{
            self._evaluateJavascript(javascriptCommand: javascriptCommand)
        }
    }
    
    private func _serialize(message:Any, pretty:Bool, base64:Bool = false) ->String? {
        
        do {
            let messageData = try JSONSerialization.data(withJSONObject: message, options: pretty ? JSONSerialization.WritingOptions.prettyPrinted : [])
            
            var utf8Message = String(data:messageData , encoding: String.Encoding.utf8)
            
            if base64 {
                //solve messy code by Non-ASCII Characters
                utf8Message = utf8Message?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                return utf8Message?.data(using: .utf8)?.base64EncodedString(options: [])
            }else {
                return utf8Message
            }
        }
        catch let error {
            print(error)
            return nil
        }
    }
    
    private func _deserialize(messageJSON:String) -> Array<Any>? {
        
        let base64DecodedData =  Data(base64Encoded: messageJSON, options:.ignoreUnknownCharacters)
        let urlEncodedString = String(data: base64DecodedData!, encoding: .utf8)
        let urlDecodedString = urlEncodedString?.removingPercentEncoding
        
        if let messagaData = urlDecodedString?.data(using:.utf8) {
            do {
                return try JSONSerialization.jsonObject(with:messagaData , options: .allowFragments) as? Array<Any>
            }
            catch let error {
                print(error)
            }
        }
        return nil
    }
    
    private func _log(action:String,json:Any) {
        if (!WebViewJavascriptBridgeBase.logging) {
            return
        }
        var jsonObj = json
        if !(jsonObj is String) {
            jsonObj = _serialize(message: json, pretty: true) ?? ""
        }
        let jsonString = jsonObj as! String
        
        if jsonString.count > WebViewJavascriptBridgeBase.logMaxLength {
            print("WVJB \(action): \(jsonString.prefix(WebViewJavascriptBridgeBase.logMaxLength))[...]")
        }else {
            print("WVJB \(action): \(jsonString)")
        }
    }
    
}
