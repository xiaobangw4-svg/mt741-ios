import Foundation

/// Hidden WKWebView runs the official unpatched `StyleTotal`.
/// A 4-digit ext_142 makes today's CWB 768 (plaintext 367); 5 digits make 800 (368).
/// Chrome sign pool rewrites the loop in `bs_h5.min.js`. Here wrap the export at
/// document-start: keep natural 5-digit hashes, lift the rest with `10000+(e<<8|n)`.
enum StyleTotalPatch {
    static let minFiveDigit: UInt32 = 10_000
    static let loopFrom = #"for(var c=0,f=0;f<10;f++){u.style.width=(e+f*s)%256+"px";var l=getComputedStyle(u);c=c+7*parseInt(l.width)+parseInt(l.height)^parseInt(l.paddingTop)}return document.body.removeChild(u),c>>>0"#
    static let loopTo = #"for(var c=0,f=0;f<10;f++){var _spec=(e+f*s)%256;u.style.width=_spec+"px";void u.offsetWidth;var l=getComputedStyle(u);var _fb=_spec;if(a>_fb)_fb=a;if(!(a>o)&&o<_fb)_fb=o;var _n=function(v,fb){var x=parseInt(v,10);return x===x&&!(x===0&&fb)?x:fb};c=c+7*_n(l.width,_fb)+_n(l.height,n)^_n(l.paddingTop,r)}var _h=c>>>0;return document.body.removeChild(u),_h<10000?_h+10000+(e<<8|n):_h"#

    static func hexPair(_ token: String, offset: Int) -> UInt32 {
        if offset >= token.count { return 0 }
        let start = token.index(token.startIndex, offsetBy: offset)
        let pair = String(token[start...].prefix(2))
        if pair.isEmpty { return 0 }
        return UInt32(pair, radix: 16) ?? 0
    }

    static func lift(_ hash: UInt32, token: String) -> UInt32 {
        if hash >= minFiveDigit { return hash }
        let e = hexPair(token, offset: 0)
        let n = hexPair(token, offset: 2)
        return hash &+ minFiveDigit &+ ((e &<< 8) | n)
    }

    static func cwbClass(_ hash: UInt32) -> Int {
        String(hash).count >= 5 ? 800 : 768
    }

    static func statusLabel(wrapped: Int, from: Int, patched: Bool) -> String {
        if wrapped > 0 || from > 0 { return "Style抬位" }
        if patched { return "Style脚本在" }
        return "Style未挂"
    }

    static func statusLabel(fromJSON json: String) -> String {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return "Style未挂" }
        let patched: Bool
        if let b = obj["patched"] as? Bool {
            patched = b
        } else {
            patched = JSONText.int(obj["patched"]) == 1
        }
        return statusLabel(
            wrapped: JSONText.int(obj["wrapped"]) ?? 0,
            from: JSONText.int(obj["from"]) ?? 0,
            patched: patched
        )
    }

    static let javaScript = #"""
    (function () {
      var FROM = "for(var c=0,f=0;f<10;f++){u.style.width=(e+f*s)%256+\"px\";var l=getComputedStyle(u);c=c+7*parseInt(l.width)+parseInt(l.height)^parseInt(l.paddingTop)}return document.body.removeChild(u),c>>>0";
      var TO = "for(var c=0,f=0;f<10;f++){var _spec=(e+f*s)%256;u.style.width=_spec+\"px\";void u.offsetWidth;var l=getComputedStyle(u);var _fb=_spec;if(a>_fb)_fb=a;if(!(a>o)&&o<_fb)_fb=o;var _n=function(v,fb){var x=parseInt(v,10);return x===x&&!(x===0&&fb)?x:fb};c=c+7*_n(l.width,_fb)+_n(l.height,n)^_n(l.paddingTop,r)}var _h=c>>>0;return document.body.removeChild(u),_h<10000?_h+10000+(e<<8|n):_h";
      window.__mt741styleHit = window.__mt741styleHit || 0;
      window.__mt741styleWrapped = window.__mt741styleWrapped || 0;
      window.__mt741styleFrom = window.__mt741styleFrom || 0;
      function lift(h, token) {
        h = h >>> 0;
        if (h >= 10000) return h;
        var s = String(token || '');
        var e = parseInt(s.substr(0, 2), 16);
        var n = parseInt(s.substr(2, 2), 16);
        if (!(e === e)) e = 0;
        if (!(n === n)) n = 0;
        return (h + 10000 + ((e << 8) | n)) >>> 0;
      }
      function disguise(fn, orig) {
        try {
          fn.toString = function () { return Function.prototype.toString.call(orig); };
        } catch (e) {}
        return fn;
      }
      function wrapFn(fn) {
        if (typeof fn !== 'function') return fn;
        if (fn.__mt741st) return fn;
        var wrapped = function (t) {
          return lift(fn.apply(this, arguments), t);
        };
        wrapped.__mt741st = true;
        window.__mt741styleWrapped = (window.__mt741styleWrapped || 0) + 1;
        return disguise(wrapped, fn);
      }
      function patchSrc(src) {
        if (typeof src !== 'string' || !src) return src;
        var n = src.split(FROM).length - 1;
        if (n) {
          window.__mt741styleFrom = (window.__mt741styleFrom || 0) + n;
          return src.split(FROM).join(TO);
        }
        return src;
      }
      function copyDesc(desc) {
        var copy = {};
        if ('value' in desc) copy.value = desc.value;
        if ('writable' in desc) copy.writable = desc.writable;
        if ('get' in desc) copy.get = desc.get;
        if ('set' in desc) copy.set = desc.set;
        if ('enumerable' in desc) copy.enumerable = desc.enumerable;
        if ('configurable' in desc) copy.configurable = desc.configurable;
        return copy;
      }
      function wrapDesc(desc) {
        if (!desc) return desc;
        var copy = copyDesc(desc);
        if (typeof copy.value === 'function') copy.value = wrapFn(copy.value);
        if (typeof copy.get === 'function') {
          var g = copy.get;
          copy.get = function () { return wrapFn(g.call(this)); };
        }
        if (typeof copy.set === 'function') {
          var s = copy.set;
          copy.set = function (fn) { return s.call(this, wrapFn(fn)); };
        }
        return copy;
      }
      function hookStyleTotalAssign() {
        try {
          var desc = Object.getOwnPropertyDescriptor(Object.prototype, 'StyleTotal');
          if (desc && desc.set) return;
          Object.defineProperty(Object.prototype, 'StyleTotal', {
            configurable: true,
            enumerable: false,
            set: function (fn) {
              Object.defineProperty(this, 'StyleTotal', {
                configurable: true,
                enumerable: true,
                writable: true,
                value: wrapFn(fn)
              });
            },
            get: function () {
              return Object.prototype.hasOwnProperty.call(this, 'StyleTotal')
                ? undefined
                : undefined;
            }
          });
        } catch (e) {}
      }
      function hookDefineProperty() {
        if (window.__mt741defStyle) return;
        window.__mt741defStyle = true;
        try {
          var def = Object.defineProperty;
          var wrapped = function (obj, prop, desc) {
            try {
              if (String(prop) === 'StyleTotal' && desc) desc = wrapDesc(desc);
            } catch (e) {}
            return def.call(this, obj, prop, desc);
          };
          disguise(wrapped, def);
          Object.defineProperty = wrapped;
        } catch (e) {}
      }
      function hookGCS() {
        if (window.__mt741gcs) return;
        try {
          var gcs = window.getComputedStyle;
          if (typeof gcs !== 'function') return;
          var wrapped = function (el, pseudo) {
            try { if (el) void el.offsetWidth; } catch (e) {}
            return gcs.call(window, el, pseudo);
          };
          disguise(wrapped, gcs);
          try {
            window.getComputedStyle = wrapped;
            window.__mt741gcs = true;
          } catch (e) {
            try {
              Object.defineProperty(window, 'getComputedStyle', {
                configurable: true,
                writable: true,
                value: wrapped
              });
              window.__mt741gcs = true;
            } catch (e2) {}
          }
        } catch (e) {}
      }
      function hookFetch() {
        if (window.__mt741styleFetch) return;
        if (typeof window.fetch !== 'function') return;
        window.__mt741styleFetch = true;
        var orig = window.fetch;
        window.fetch = disguise(function (input, init) {
          var url = (typeof input === 'string') ? input : ((input && input.url) || '');
          var p = orig.apply(this, arguments);
          if (!/bs_h5(\.min)?\.js/i.test(String(url))) return p;
          return p.then(function (res) {
            return res.text().then(function (text) {
              var patched = patchSrc(text);
              window.__mt741styleHit = (window.__mt741styleHit || 0) + 1;
              return new Response(patched, { status: res.status, statusText: res.statusText, headers: res.headers });
            });
          });
        }, orig);
      }
      function hook() {
        hookStyleTotalAssign();
        hookDefineProperty();
        hookFetch();
        hookGCS();
        try {
          if (typeof window.StyleTotal === 'function') {
            window.StyleTotal = wrapFn(window.StyleTotal);
          }
        } catch (e) {}
        window.__mt741stylePatched = true;
        return {
          patched: true,
          wrapped: window.__mt741styleWrapped || 0,
          from: window.__mt741styleFrom || 0,
          hit: window.__mt741styleHit || 0
        };
      }
      window.__mt741liftStyle = lift;
      window.__mt741hookStyle = hook;
      hook();
    })();
    """#
}
