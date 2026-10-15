import Foundation

enum CWBHook {
    static let handlerName = "cwb"
    static let fk1HandlerName = "fk1"
    static let netHandlerName = "net"

    static let javaScript = #"""
    (function () {
      try {
        window._bb_h = window._bb_h || 'fk1.moutai519.com.cn/bangcle';
        window._bb_w = window._bb_w || 'fk1.moutai519.com.cn/bangcle';
        window._bb_a = window._bb_a || '10001';
      } catch (e0) {}
      function report(cwb, hh, url) {
        try {
          if (!cwb) return;
          var bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.cwb;
          if (!bridge) return;
          bridge.postMessage({ cwb: String(cwb), hh: String(hh || ''), url: String(url || '') });
        } catch (e) {}
      }
      function reportFk1(url, status) {
        try {
          window.__mt741fk1 = (window.__mt741fk1 || 0) + 1;
          var bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.fk1;
          if (!bridge) return;
          bridge.postMessage({ url: String(url || ''), status: status || 0 });
        } catch (e) {}
        reportNet('fk1', url, status, '');
      }
      function reportNet(kind, url, status, body) {
        try {
          var bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.net;
          if (!bridge) return;
          bridge.postMessage({
            kind: String(kind || ''),
            url: String(url || ''),
            status: status || 0,
            body: String(body || '').slice(0, 240)
          });
        } catch (e1) {}
      }
      function isFk1(u) {
        var s = String(u || '');
        return /bbprbdata/i.test(s) || /fk1\.moutai519\.com\.cn/i.test(s) || /\/bangcle\//i.test(s);
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
      function disguise(fn, orig) {
        try { fn.toString = function () { return Function.prototype.toString.call(orig); }; } catch (e) {}
        return fn;
      }
      function hookXHR() {
        var proto = XMLHttpRequest.prototype;
        if (proto.__mt741set) return;
        proto.__mt741set = true;
        var open = proto.open;
        proto.open = disguise(function (m, u) {
          this.__mt741url = u;
          if (!this.__mt741cap) {
            this.__mt741cap = true;
            this.addEventListener('load', function () {
              try {
                var u2 = String(this.__mt741url || '');
                if (u2.indexOf('purchaseInfoV2') >= 0) {
                  window.__mt741purchaseInfo = String(this.responseText || '');
                }
                if (u2.indexOf('rushPurchase') >= 0) {
                  reportNet('rush', u2, this.status, this.responseText);
                }
                if (isFk1(u2)) {
                  reportFk1(u2, this.status);
                }
              } catch (e) {}
            });
          }
          return open.apply(this, arguments);
        }, open);
        var setH = proto.setRequestHeader;
        proto.setRequestHeader = disguise(function (k, v) {
          var lk = String(k || '').toLowerCase();
          if (lk === 'content-web-bb' && v) this.__mt741cwb = v;
          if (lk === 'content-hh-bb' && v) this.__mt741hh = v;
          if (this.__mt741cwb) report(this.__mt741cwb, this.__mt741hh, this.__mt741url);
          return setH.apply(this, arguments);
        }, setH);
      }
      function hookFetch() {
        if (window.__mt741fetch) return;
        window.__mt741fetch = true;
        var origFetch = window.fetch;
        window.fetch = disguise(function (input, init) {
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
              if (u2.indexOf('rushPurchase') >= 0) {
                res.clone().text().then(function (t) { reportNet('rush', u2, res.status, t); }).catch(function () {
                  reportNet('rush', u2, res.status, '');
                });
              }
              if (isFk1(u2)) {
                reportFk1(u2, res.status);
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
        }, origFetch);
      }
      function hookHeaders() {
        try {
          var Hs = window.Headers;
          if (!Hs || !Hs.prototype || Hs.prototype.__mt741) return;
          Hs.prototype.__mt741 = true;
          var hset = Hs.prototype.set;
          Hs.prototype.set = disguise(function (k, v) {
            var lk = String(k || '').toLowerCase();
            if (lk === 'content-web-bb' && v) report(v, '', '');
            if (lk === 'content-hh-bb' && v) report('', v, '');
            return hset.apply(this, arguments);
          }, hset);
          var happ = Hs.prototype.append;
          Hs.prototype.append = disguise(function (k, v) {
            var lk = String(k || '').toLowerCase();
            if (lk === 'content-web-bb' && v) report(v, '', '');
            return happ.apply(this, arguments);
          }, happ);
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
