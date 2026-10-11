import Foundation

enum CWBHook {
    static let handlerName = "cwb"

    static let javaScript = #"""
    (function () {
      if (window.__mt741cwb) return;
      window.__mt741cwb = true;
      function report(cwb, hh, url) {
        try {
          if (!cwb) return;
          var bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.cwb;
          if (!bridge) return;
          bridge.postMessage({ cwb: String(cwb), hh: String(hh || ''), url: String(url || '') });
        } catch (e) {}
      }
      function fromHeaders(h) {
        var cwb = '', hh = '';
        if (!h) return { cwb: cwb, hh: hh };
        if (typeof h.get === 'function') {
          cwb = h.get('Content-Web-Bb') || h.get('content-web-bb') || '';
          hh = h.get('Content-Hh-Bb') || h.get('content-hh-bb') || '';
        } else if (typeof h === 'object') {
          for (var k in h) {
            if (!Object.prototype.hasOwnProperty.call(h, k)) continue;
            var lk = String(k).toLowerCase();
            if (lk === 'content-web-bb') cwb = h[k];
            if (lk === 'content-hh-bb') hh = h[k];
          }
        }
        return { cwb: cwb, hh: hh };
      }
      var open = XMLHttpRequest.prototype.open;
      XMLHttpRequest.prototype.open = function (m, u) {
        this.__mt741url = u;
        return open.apply(this, arguments);
      };
      var setH = XMLHttpRequest.prototype.setRequestHeader;
      XMLHttpRequest.prototype.setRequestHeader = function (k, v) {
        var lk = String(k || '').toLowerCase();
        if (lk === 'content-web-bb' && v) this.__mt741cwb = v;
        if (lk === 'content-hh-bb' && v) this.__mt741hh = v;
        if (this.__mt741cwb) report(this.__mt741cwb, this.__mt741hh, this.__mt741url);
        return setH.apply(this, arguments);
      };
      var send = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.send = function () {
        if (this.__mt741cwb) report(this.__mt741cwb, this.__mt741hh, this.__mt741url);
        return send.apply(this, arguments);
      };
      var origFetch = window.fetch;
      window.fetch = function (input, init) {
        var url = (typeof input === 'string') ? input : ((input && input.url) || '');
        var h = (init && init.headers) || (input && input.headers);
        var p = fromHeaders(h);
        if (p.cwb) report(p.cwb, p.hh, url);
        return origFetch.apply(this, arguments);
      };
    })();
    """#

    static func parse(_ body: Any) -> (cwb: String, hh: String, url: String) {
        if let s = body as? String {
            return (s, "", "")
        }
        if let dict = body as? [String: Any] {
            return (
                JSONText.string(dict["cwb"]),
                JSONText.string(dict["hh"]),
                JSONText.string(dict["url"])
            )
        }
        return ("", "", "")
    }
}
