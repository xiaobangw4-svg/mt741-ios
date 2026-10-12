import Foundation

enum CWBHook {
    static let handlerName = "cwb"

    static let javaScript = #"""
    (function () {
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
      function hookXHR() {
        var proto = XMLHttpRequest.prototype;
        if (proto.__mt741set) return;
        proto.__mt741set = true;
        var open = proto.open;
        proto.open = function (m, u) {
          this.__mt741url = u;
          if (!this.__mt741cap) {
            this.__mt741cap = true;
            this.addEventListener('load', function () {
              try {
                var u2 = String(this.__mt741url || '');
                if (u2.indexOf('purchaseInfoV2') >= 0) {
                  window.__mt741purchaseInfo = String(this.responseText || '');
                }
              } catch (e) {}
            });
          }
          return open.apply(this, arguments);
        };
        var setH = proto.setRequestHeader;
        proto.setRequestHeader = function (k, v) {
          var lk = String(k || '').toLowerCase();
          if (lk === 'content-web-bb' && v) this.__mt741cwb = v;
          if (lk === 'content-hh-bb' && v) this.__mt741hh = v;
          if (this.__mt741cwb) report(this.__mt741cwb, this.__mt741hh, this.__mt741url);
          return setH.apply(this, arguments);
        };
        var send = proto.send;
        proto.send = function () {
          if (this.__mt741cwb) report(this.__mt741cwb, this.__mt741hh, this.__mt741url);
          return send.apply(this, arguments);
        };
      }
      function hookFetch() {
        if (window.__mt741fetch) return;
        window.__mt741fetch = true;
        var origFetch = window.fetch;
        window.fetch = function (input, init) {
          var url = (typeof input === 'string') ? input : ((input && input.url) || '');
          var h = (init && init.headers) || (input && input.headers);
          var p = fromHeaders(h);
          if (p.cwb) report(p.cwb, p.hh, url);
          return origFetch.apply(this, arguments).then(function (res) {
            try {
              var u2 = String((res && res.url) || url || '');
              if (u2.indexOf('purchaseInfoV2') >= 0 && res && res.clone) {
                res.clone().text().then(function (t) { window.__mt741purchaseInfo = String(t || ''); }).catch(function () {});
              }
              if (res && !res.ok && /wasm/i.test(u2)) {
                window.__mt741wasmErr = String(res.status) + ' ' + u2;
              }
            } catch (e) {}
            return res;
          }, function (err) {
            if (/wasm/i.test(url)) { window.__mt741wasmErr = String(err) + ' ' + url; }
            throw err;
          });
        };
      }
      function hookHeaders() {
        try {
          var Hs = window.Headers;
          if (!Hs || !Hs.prototype || Hs.prototype.__mt741) return;
          Hs.prototype.__mt741 = true;
          var hset = Hs.prototype.set;
          Hs.prototype.set = function (k, v) {
            var lk = String(k || '').toLowerCase();
            if (lk === 'content-web-bb' && v) report(v, '', '');
            if (lk === 'content-hh-bb' && v) report('', v, '');
            return hset.apply(this, arguments);
          };
          var happ = Hs.prototype.append;
          Hs.prototype.append = function (k, v) {
            var lk = String(k || '').toLowerCase();
            if (lk === 'content-web-bb' && v) report(v, '', '');
            return happ.apply(this, arguments);
          };
        } catch (e) {}
      }
      hookXHR();
      hookFetch();
      hookHeaders();
      window.__mt741cwb = true;
      window.__mt741hookCWB = function () { hookXHR(); hookFetch(); hookHeaders(); return true; };
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
