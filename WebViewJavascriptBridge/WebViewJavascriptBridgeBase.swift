//
//  WebViewJavascriptBridgeBase.swift
//  CEWebJavaScriptBridge__Frame
//
//  Created by xuhaiqing on 2018/6/6.
//  Copyright © 2018年 xuhaiqing. All rights reserved.
//

import Foundation

struct WebViewBaseURI {
    static public let scheme = "https"
    static public let queueHasMessage = "__wvjb_queue_message__"
    static public let bridgeLoaded = "__bridge_loaded__"
}

typealias WVJBResponseCallback = (Any?) -> Swift.Void
typealias WVJBHandler = (Any?,@escaping WVJBResponseCallback) -> Swift.Void
typealias WVJBMessage = Dictionary<String, Any>

protocol WebViewJavascriptBridgeAPIProtocol : NSObjectProtocol {
    associatedtype Bridge
    
    static func bridge(forWebView webView:Any) -> Bridge
    
    static func enableLogging() -> Void
    static func setLogMax(length:Int)
    
    func callHandler(handlerName:String?)
    func callHandler(handlerName:String?, data:Any?)
    func callHandler(handlerName:String?, data:Any?,responseCallback:WVJBResponseCallback?)
    func registerHandler(handlerName:String,handler:@escaping WVJBHandler)
    func removeHandler(handlerName:String)
    func disableJavascriptAlertBoxSafetyTimeout()

    var webViewDelegate:AnyObject? {get set}
}

protocol WebViewJavascriptBridgeBaseProtocol:NSObjectProtocol {
    @discardableResult func _evaluateJavascript(_ javascriptCommand:String) -> String
}

class WebViewJavascriptBridgeBase: NSObject {
    open weak var delegate : WebViewJavascriptBridgeBaseProtocol?
    open var startupMessageQueue : Array<WVJBMessage>?
    open var responseCallbacks : Dictionary<String, WVJBResponseCallback>?
    open var messageHandlers : Dictionary<String, WVJBHandler>?
    open var messageHandler : WVJBMessage?
    
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
    
    open static func enableLogging() {
        logging = true
    }
    
    open static func setLogMax(length:Int) {
        logMaxLength = length
    }
    
    open func reset() {
        startupMessageQueue = Array<WVJBMessage>()
        responseCallbacks = Dictionary<String, WVJBResponseCallback>()
    }
    
    open func send(data:Any?,responseCallback:WVJBResponseCallback?,handlerName:String?){
        var message = [String:Any]()
        if data != nil {
            message["data"] = data
        }
        if responseCallback != nil {
            _uniqueId += 1
            let callbackId = "objc_cb_\(_uniqueId)"
            
            responseCallbacks?[callbackId] = responseCallback
            message["callbackId"] = callbackId
        }
        
        if handlerName != nil {
            message["handlerName"] = handlerName
        }
        _queue(message:message)
    }
    
    open func flush(messageQueue:String?) {
        guard let messageQueueString:String = messageQueue, messageQueueString.count > 0 else {
            print("WebViewJavascriptBridge: WARNING: ObjC got nil while fetching the message queue JSON from webview. This can happen if the WebViewJavascriptBridge JS is not currently present in the webview, e.g if the webview just loaded a new page.")
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
                        var msg_responseData = responseData
                        if msg_responseData == nil {
                            msg_responseData = "null"
                        }
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
    
    open func injectJavascriptFile() {
        _evaluateJavascript(javascriptCommand: WebViewJavascriptBridge_js)
        if self.startupMessageQueue != nil {
            let queue = self.startupMessageQueue!
            self.startupMessageQueue = nil
            for queuedMessage in queue {
                _dispatch(message: queuedMessage)
            }
        }
    }
    
    open func isWebViewJavascriptBridgeURL(_ url:URL) -> Bool {
        if  !isSchemeMatch(url) {
            return false
        }
        return isQueueMessageURL(url) || isBridgeLoadedURL(url)
    }
    
    open func isSchemeMatch(_ url:URL) -> Bool {
        return url.scheme?.lowercased() == WebViewBaseURI.scheme
    }
    
    open func isQueueMessageURL(_ url:URL) -> Bool {
        return isSchemeMatch(url) && url.host?.lowercased() == WebViewBaseURI.queueHasMessage
    }
    
    open func isBridgeLoadedURL(_ url:URL) -> Bool {
        return isSchemeMatch(url) && url.host?.lowercased() == WebViewBaseURI.bridgeLoaded
    }
    
    open func logUnknownMessage(_ url:URL) {
        print("WebViewJavascriptBridge: WARNING: Received unknown WebViewJavascriptBridge command \(url.absoluteString)")
    }
    
    open func webViewJavascriptCheckCommand() -> String {
        return "typeof WebViewJavascriptBridge == \'object\';"
    }
    
    open func webViewJavascriptFetchQueueCommand() -> String{
        return "WebViewJavascriptBridge._fetchQueue();"
    }
    
    open func disableJavscriptAlertBoxSafetyTimeout() {
        send(data: nil, responseCallback: nil, handlerName: "_disableJavascriptAlertBoxSafetyTimeout")
    }
    
    //Private
    //\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    private func _evaluateJavascript(javascriptCommand:String) {
        if delegate != nil {
            delegate?._evaluateJavascript(javascriptCommand)
        }
    }
    
    private func _queue(message:WVJBMessage) {
        if startupMessageQueue != nil {
            startupMessageQueue?.append(message)
        }else {
            _dispatch(message:message)
        }
    }
    
    private func _dispatch(message:WVJBMessage) {
        var messageJSON = _serialize(message: message, pretty: false) ?? ""
        _log(action: "SEND", json: messageJSON)
        messageJSON = messageJSON.replacingOccurrences(of: "\\", with: "\\\\")
        messageJSON = messageJSON.replacingOccurrences(of: "\"", with: "\\\"")
        messageJSON = messageJSON.replacingOccurrences(of: "\'", with: "\\\'")
        messageJSON = messageJSON.replacingOccurrences(of: "\n", with: "\\n")
        messageJSON = messageJSON.replacingOccurrences(of: "\r", with: "\\r")
        messageJSON = messageJSON.replacingOccurrences(of: "\u{2028}", with: "\\u{2028}")
        messageJSON = messageJSON.replacingOccurrences(of: "\u{2029}", with: "\\u{2029}")
        
        let javascriptCommand = "WebViewJavascriptBridge._handleMessageFromObjC('\(messageJSON)');"
        DispatchQueue.main.async{
            self._evaluateJavascript(javascriptCommand: javascriptCommand)
        }
    }
    
    private func _serialize(message:Any, pretty:Bool) ->String? {
        
        do {
            let messageData = try JSONSerialization.data(withJSONObject: message, options: pretty ? JSONSerialization.WritingOptions.prettyPrinted : [])
            return String(data:messageData , encoding: String.Encoding.utf8)

        }
        catch let error {
            print(error)
        }
        return nil
    }
    
    private func _deserialize(messageJSON:String) -> Array<Any>? {
        if let messagaData = messageJSON.data(using:.utf8) {
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
