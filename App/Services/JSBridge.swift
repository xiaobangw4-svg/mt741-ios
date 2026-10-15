import Foundation

/// Official 1.9.14 YXWebViewKit: H5 calls `WebViewJavascriptBridge.callHandler('getUserInfo')`
/// → native `getUserInfo:nativeBidgeResponseCallback:` → H5 writes `localStorage._u_id_`.
/// Bangcle reads field 130 from `_u_id_`. Empty user_id shortens CWB into the 768 bucket.
enum JSBridge {
    static let wvjbHandlerName = "kYXScriptHandlerName"
    static let jxbHandlerName = "WKNativeMethodMessage"

    static let handlerNames = [wvjbHandlerName, jxbHandlerName]

    /// Official 1.9.14 rush_capture 2026-10-12 iPhone 13 actParam / getLocation.
    static let bijieLatitude = 27.414705
    static let bijieLongitude = 105.380223
    static let bijieLatText = "27.414705"
    static let bijieLngText = "105.380223"

    struct Decision {
        var handler: String
        var callbackId: String
        var jxbIdentifier: String
        var isJXB: Bool
        var payload: Any
        var pinUserId: String
        /// JXB `window.Callback` status. `fail` lets H5 fall back to its own fk1 XHR.
        var jxbStatus: String = "success"
    }

    static func isHandler(_ name: String) -> Bool {
        name == wvjbHandlerName || name == jxbHandlerName
    }

    static func decide(name: String, body: Any, session: Session?) -> Decision? {
        guard isHandler(name) else { return nil }
        let dict = dictionary(from: body)
        let isJXB = name == jxbHandlerName
        let handler: String
        if isJXB {
            handler = normalize(
                JSONText.string(dict["actionName"]).isEmpty
                    ? JSONText.string(dict["action"])
                    : JSONText.string(dict["actionName"])
            )
        } else {
            let raw = JSONText.string(dict["handlerName"])
            handler = normalize(raw.isEmpty ? JSONText.string(dict["handler"]) : raw)
        }
        let callbackId = JSONText.string(dict["callbackId"])
        let identifier = JSONText.string(dict["identifier"])
        let key = handler.lowercased()
        let payload = payload(for: key, session: session)
        var pin = ""
        if key == "getuserinfo" || key == "getuserloginstatus" || key == "getuserid" {
            pin = session?.userId ?? ""
        }
        return Decision(
            handler: handler,
            callbackId: callbackId,
            jxbIdentifier: identifier,
            isJXB: isJXB,
            payload: payload,
            pinUserId: pin,
            jxbStatus: key == "bangclereport" ? "fail" : "success"
        )
    }

    static func payload(for handler: String, session: Session?) -> Any {
        switch handler {
        case "checkrequestheader":
            return NSNull()
        case "getuserinfo", "getuserid":
            return userInfo(session)
        case "getuserloginstatus":
            var info = userInfo(session)
            info["isLogin"] = session?.isLoggedIn == true
            return info
        case "getuserbasecontext":
            let deviceId = session?.authDeviceId ?? ""
            return [
                "mt_code": 200,
                "deviceId": deviceId,
                "appUserAgent": CookieBridge.userAgent(
                    deviceId: deviceId.isEmpty ? "MT741" : deviceId,
                    bsDvid: session?.bsDvid ?? "",
                    h5Did: session?.h5Did ?? ""
                ),
            ] as [String: Any]
        case "detectappenv":
            return [
                "mt_code": 200,
                "isApp": true,
                "appName": AuthDigest.bundleId,
                "appVersion": AuthDigest.appVersion,
                "platform": "ios",
                "osVersion": "18.7",
            ] as [String: Any]
        case "getlocation", "openlocation":
            return [
                "mt_code": 200,
                "latitude": bijieLatitude,
                "longitude": bijieLongitude,
                "accuracy": 100,
                "city": "毕节市",
                "province": "贵州省",
            ] as [String: Any]
        case "getverifystatus":
            return [
                "mt_code": 200,
                "userVerifyStatus": session?.isLoggedIn == true ? 1 : 0,
            ] as [String: Any]
        case "getbaseinfo", "getappinfo", "appinfo":
            return [
                "mt_code": 200,
                "platform": "iOS",
                "appVersion": AuthDigest.appVersion,
                "os": "iOS",
                "osVersion": "18.7",
                "model": "iPhone 13",
            ] as [String: Any]
        case "getdeviceinfo":
            return [
                "mt_code": 200,
                "deviceId": session?.authDeviceId ?? "",
                "osVersion": "18.7",
            ] as [String: Any]
        case "getnetworkstatus":
            return [
                "mt_code": 200,
                "type": "CELLULAR",
                "network": "4G",
            ] as [String: Any]
        case "bangclereport":
            // No native Bangcle SDK. Fake success stops official H5 from POSTing fk1 itself.
            return ["success": false, "mt_code": 404] as [String: Any]
        case "hideloadingtoast", "showloadingtoast", "showtoast",
             "successcallback", "closewebview", "xsw":
            return ["mt_code": 200] as [String: Any]
        default:
            return ["mt_code": 200] as [String: Any]
        }
    }

    static func userInfo(_ session: Session?) -> [String: Any] {
        let userId = session?.userId ?? ""
        let token = session?.wapToken ?? ""
        return [
            "mt_code": 200,
            "userId": userId,
            "userid": userId,
            "token": token,
            "deviceId": session?.authDeviceId ?? "",
            "mobile": session?.mobile ?? "",
        ]
    }

    static func callbackJavaScript(_ decision: Decision) -> String {
        if decision.isJXB, !decision.jxbIdentifier.isEmpty {
            let id = jsonAtom(decision.jxbIdentifier)
            let data = jsonAtom(decision.payload)
            return """
            (function(){
              try { window.Callback(\(id), '\(decision.jxbStatus)', \(data)); } catch (e) {}
            })();
            """
        }
        if !decision.callbackId.isEmpty {
            let msg: [String: Any] = [
                "responseId": decision.callbackId,
                "responseData": decision.payload,
            ]
            let raw = jsonAtom(encodeJSON(msg))
            return """
            (function(){
              try {
                var s = \(raw);
                if (window.WebViewJavascriptBridge && window.WebViewJavascriptBridge._handleMessageFromObjC) {
                  window.WebViewJavascriptBridge._handleMessageFromObjC(s);
                }
              } catch (e) {}
            })();
            """
        }
        return ""
    }

    static func identityJavaScript(session: Session) -> String {
        pinJavaScript(
            userId: session.userId,
            deviceId: session.authDeviceId,
            token: session.wapToken
        )
    }

    static func pinJavaScript(userId: String, deviceId: String = "", token: String = "") -> String {
        let uid = jsonAtom(userId)
        let did = jsonAtom(deviceId)
        let tok = jsonAtom(token)
        return """
        (function(){
          var uid = \(uid);
          var did = \(did);
          var tok = \(tok);
          try { if (uid) localStorage.setItem('_u_id_', String(uid)); } catch (e) {}
          try { if (uid) localStorage.setItem('mt-game-user-id', String(uid)); } catch (e) {}
          try { if (did) document.cookie = 'MT-Device-ID-Wap=' + String(did) + '; path=/'; } catch (e) {}
          try { if (tok) document.cookie = 'MT-Token-Wap=' + String(tok) + '; path=/'; } catch (e) {}
        })();
        """
    }

    static func pushUserIdJavaScript(userId: String) -> String {
        let uid = jsonAtom(userId)
        let pin = pinJavaScript(userId: userId)
        return """
        \(pin)
        (function(){
          var uid = \(uid);
          if (!uid) return;
          try {
            if (window.WebViewJavascriptBridge && window.WebViewJavascriptBridge._handleMessageFromObjC) {
              window.WebViewJavascriptBridge._handleMessageFromObjC(JSON.stringify({
                handlerName: 'getUserId_callback',
                data: uid
              }));
            }
          } catch (e) {}
        })();
        """
    }

    static func encodeJSON(_ value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value),
              let text = String(data: data, encoding: .utf8)
        else { return "null" }
        return text
    }

    static func jsonAtom(_ value: Any) -> String {
        if value is NSNull { return "null" }
        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let data = try? JSONSerialization.data(withJSONObject: [value]),
           let text = String(data: data, encoding: .utf8), text.count >= 2 {
            return String(text.dropFirst().dropLast())
        }
        return "null"
    }

    static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let idx = trimmed.firstIndex(of: ":") {
            return String(trimmed[..<idx])
        }
        return trimmed
    }

    private static func dictionary(from body: Any) -> [String: Any] {
        if let dict = body as? [String: Any] { return dict }
        if let s = body as? String, let data = s.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) {
            return JSONText.object(obj)
        }
        return [:]
    }

    /// Official WebViewJavascriptBridge.js + NEJsbridge.js + JXBJSBridge.js, posting to native.
    static let javaScript = #"""
    (function () {
      if (window.__mt741bridge) return;
      window.__mt741bridge = true;
      function postWVJB(message) {
        try {
          var h = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.kYXScriptHandlerName;
          if (h && typeof h.postMessage === 'function') h.postMessage(message);
        } catch (e) {}
      }
      if (!window.WebViewJavascriptBridge) {
        var responseCallbacks = {};
        var messageHandlers = {};
        var uniqueId = 1;
        var receiveMessageQueue = [];
        function init(messageHandler) {
          if (WebViewJavascriptBridge._messageHandler) return;
          WebViewJavascriptBridge._messageHandler = messageHandler;
          var queued = receiveMessageQueue;
          receiveMessageQueue = null;
          for (var i = 0; i < queued.length; i++) _dispatchMessageFromObjC(queued[i]);
        }
        function registerHandler(handlerName, handler) {
          messageHandlers[handlerName] = handler;
        }
        function callHandler(handlerName, data, responseCallback) {
          if (arguments.length === 2 && typeof data === 'function') {
            responseCallback = data;
            data = null;
          }
          var message = { handlerName: String(handlerName || ''), data: data == null ? null : data };
          if (responseCallback) {
            var callbackId = 'cb_' + (uniqueId++) + '_' + Date.now();
            responseCallbacks[callbackId] = responseCallback;
            message.callbackId = callbackId;
          }
          postWVJB(message);
        }
        function _dispatchMessageFromObjC(messageJSON) {
          var message = typeof messageJSON === 'string' ? JSON.parse(messageJSON) : messageJSON;
          if (!message) return;
          if (message.responseId) {
            var cb = responseCallbacks[message.responseId];
            if (!cb) return;
            cb(message.responseData);
            return;
          }
          var handler = WebViewJavascriptBridge._messageHandler;
          if (message.handlerName) handler = messageHandlers[message.handlerName];
          var responseCallback;
          if (message.callbackId) {
            var callbackResponseId = message.callbackId;
            responseCallback = function (responseData) {
              postWVJB({ responseId: callbackResponseId, responseData: responseData });
            };
          }
          try { if (typeof handler === 'function') handler(message.data, responseCallback); } catch (e) {}
        }
        function _handleMessageFromObjC(messageJSON) {
          if (receiveMessageQueue) receiveMessageQueue.push(messageJSON);
          else _dispatchMessageFromObjC(messageJSON);
        }
        window.WebViewJavascriptBridge = {
          init: init,
          send: function (data, responseCallback) { callHandler('_default', data, responseCallback); },
          registerHandler: registerHandler,
          callHandler: callHandler,
          _fetchQueue: function () { return '[]'; },
          _handleMessageFromObjC: _handleMessageFromObjC
        };
      }
      window.NEJsbridge = window.WebViewJavascriptBridge;
      window.NEJsbridge.call = window.WebViewJavascriptBridge.callHandler;
      window.NEJsbridge.invoke = window.WebViewJavascriptBridge.callHandler;
      try {
        var callbacks = window.WVJBCallbacks;
        window.WVJBCallbacks = undefined;
        if (callbacks && callbacks.length) {
          for (var i = 0; i < callbacks.length; i++) {
            try { callbacks[i](window.WebViewJavascriptBridge); } catch (e2) {}
          }
        }
      } catch (e3) {}
      try {
        if (!window.JXBCallBackList || typeof window.JXBCallBackList !== 'object') window.JXBCallBackList = {};
        if (typeof String.prototype.hashCode !== 'function') {
          String.prototype.hashCode = function () {
            var hash = 0;
            if (this.length === 0) return hash;
            for (var index = 0; index < this.length; index++) {
              var charactor = this.charCodeAt(index);
              hash = ((hash << 5) - hash) + charactor;
              hash = hash & hash;
            }
            return hash;
          };
        }
        if (typeof window.Callback !== 'function') {
          window.Callback = function (identifier, resultStatus, resultData) {
            var callBackDict = window.JXBCallBackList[identifier];
            if (!callBackDict) return;
            var isFinished = true;
            if (resultStatus == 'success' || resultStatus == '200') {
              if (typeof callBackDict.success === 'function') callBackDict.success(resultData);
              else if (typeof callBackDict === 'function') callBackDict(resultStatus, resultData);
            }
            if (resultStatus == 'fail') {
              if (typeof callBackDict.fail === 'function') callBackDict.fail(resultData);
            }
            if (resultStatus == 'progress') {
              isFinished = false;
              if (typeof callBackDict.progress === 'function') callBackDict.progress(resultData);
            }
            if (isFinished) {
              window.JXBCallBackList[identifier] = null;
              delete window.JXBCallBackList[identifier];
            }
          };
        }
        if (!window.JXBJSBridge || typeof window.JXBJSBridge !== 'object') window.JXBJSBridge = {};
        if (typeof window.JXBJSBridge.call !== 'function') {
          window.JXBJSBridge.call = function (bridgeObjc) {
            bridgeObjc = bridgeObjc || {};
            var data = bridgeObjc.data == null ? {} : bridgeObjc.data;
            var dataString = encodeURIComponent(JSON.stringify(data));
            var timestamp = Date.parse(new Date());
            var target = String(bridgeObjc.target || bridgeObjc.targetName || '');
            var action = String(bridgeObjc.action || bridgeObjc.actionName || '');
            var identifier = String(bridgeObjc.identifier || (target + action + dataString + timestamp).hashCode());
            window.JXBCallBackList[identifier] = bridgeObjc.callback || bridgeObjc.callBack || {};
            try {
              var h = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.WKNativeMethodMessage;
              if (h && typeof h.postMessage === 'function') {
                h.postMessage({
                  targetName: target,
                  actionName: action,
                  data: data,
                  identifier: identifier
                });
              }
            } catch (e4) {}
            return identifier;
          };
        }
      } catch (e5) {}
      function fireReady(name) {
        try {
          var ev = document.createEvent('Events');
          ev.initEvent(name);
          ev.bridge = window.WebViewJavascriptBridge;
          document.dispatchEvent(ev);
        } catch (e6) {}
      }
      fireReady('WebViewJavascriptBridgeReady');
      fireReady('NEJsbridgeReady');
      try {
        if (window.WebViewJavascriptBridge && !window.WebViewJavascriptBridge._messageHandler) {
          window.WebViewJavascriptBridge.init(function () {});
        }
      } catch (e7) {}
    })();
    """#
}
