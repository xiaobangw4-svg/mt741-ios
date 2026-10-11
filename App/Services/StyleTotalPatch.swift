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

    static func statusLabel(wrapped: Int, from: Int, patched: Bool, bump: Int = 0, gcs: Bool = false, rewritten: Bool = false) -> String {
        if rewritten || wrapped > 0 || from > 0 || bump > 0 || gcs { return "Style抬位" }
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
        let gcs: Bool
        if let b = obj["gcs"] as? Bool {
            gcs = b
        } else {
            gcs = JSONText.int(obj["gcs"]) == 1
        }
        let rewritten: Bool
        if let b = obj["rewritten"] as? Bool {
            rewritten = b
        } else {
            rewritten = JSONText.int(obj["rewritten"]) == 1
        }
        return statusLabel(
            wrapped: JSONText.int(obj["wrapped"]) ?? 0,
            from: JSONText.int(obj["from"]) ?? 0,
            patched: patched,
            bump: JSONText.int(obj["bump"]) ?? 0,
            gcs: gcs,
            rewritten: rewritten
        )
    }

    static let javaScript = #"""
    (function () {
      var FROM = "for(var c=0,f=0;f<10;f++){u.style.width=(e+f*s)%256+\"px\";var l=getComputedStyle(u);c=c+7*parseInt(l.width)+parseInt(l.height)^parseInt(l.paddingTop)}return document.body.removeChild(u),c>>>0";
      var TO = "for(var c=0,f=0;f<10;f++){var _spec=(e+f*s)%256;u.style.width=_spec+\"px\";void u.offsetWidth;var l=getComputedStyle(u);var _fb=_spec;if(a>_fb)_fb=a;if(!(a>o)&&o<_fb)_fb=o;var _n=function(v,fb){var x=parseInt(v,10);return x===x&&!(x===0&&fb)?x:fb};c=c+7*_n(l.width,_fb)+_n(l.height,n)^_n(l.paddingTop,r)}var _h=c>>>0;return document.body.removeChild(u),_h<10000?_h+10000+(e<<8|n):_h";
      window.__mt741styleHit = window.__mt741styleHit || 0;
      window.__mt741styleWrapped = window.__mt741styleWrapped || 0;
      window.__mt741styleFrom = window.__mt741styleFrom || 0;
      window.__mt741styleBump = window.__mt741styleBump || 0;
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
      function isProbe(el) {
        try {
          if (!el || el.nodeName !== 'DIV') return false;
          if (el.id) return false;
          var cn = el.className;
          if (cn && String(cn).length) return false;
          var w = el.style && el.style.width;
          if (!w) return false;
          var n = parseInt(w, 10);
          return n === n && n >= 0 && n <= 255;
        } catch (e) { return false; }
      }
      function bumpPx(v) {
        var n = parseInt(v, 10);
        if (n !== n) return v;
        return (n + 200) + 'px';
      }
      function bumpStyle(st, el) {
        if (!st || !isProbe(el)) return st;
        try {
          window.__mt741styleBump = (window.__mt741styleBump || 0) + 1;
          return {
            width: bumpPx(st.width),
            height: bumpPx(st.height),
            paddingTop: st.paddingTop,
            getPropertyValue: function (name) {
              if (name === 'width') return this.width;
              if (name === 'height') return this.height;
              if (name === 'padding-top' || name === 'paddingTop') return this.paddingTop;
              try { return st.getPropertyValue(name); } catch (e) { return ''; }
            }
          };
        } catch (e) { return st; }
      }
      function hookGCS() {
        if (window.__mt741gcs) return;
        var gcs = window.getComputedStyle;
        if (typeof gcs !== 'function') return;
        var wrapped = function (el, pseudo) {
          try { if (el) void el.offsetWidth; } catch (e) {}
          var st = gcs.call(window, el, pseudo);
          return bumpStyle(st, el);
        };
        disguise(wrapped, gcs);
        try {
          window.getComputedStyle = wrapped;
          window.__mt741gcs = true;
          return;
        } catch (e) {}
        try {
          Object.defineProperty(window, 'getComputedStyle', {
            configurable: true,
            writable: true,
            value: wrapped
          });
          window.__mt741gcs = true;
        } catch (e2) {}
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
      function hookScriptSrc() {
        if (window.__mt741scriptSrc) return;
        window.__mt741scriptSrc = true;
        function isSdk(url) {
          return /bs_h5(\.min)?\.js/i.test(String(url || ''));
        }
        var srcDesc = Object.getOwnPropertyDescriptor(HTMLScriptElement.prototype, 'src')
          || Object.getOwnPropertyDescriptor(HTMLElement.prototype, 'src');
        var setAttr = Element.prototype.setAttribute;
        function fetchPatched(url) {
          var xhr = new XMLHttpRequest();
          xhr.open('GET', url, false);
          xhr.send(null);
          return patchSrc(xhr.responseText || '');
        }
        function hijack(el, url) {
          if (!el || el.__mt741sdk) return;
          el.__mt741sdk = true;
          try { el.removeAttribute('integrity'); } catch (e) {}
          try { el.type = 'text/plain'; } catch (e) {}
          var patched = '';
          try { patched = fetchPatched(url); } catch (e) { patched = ''; }
          try {
            if (srcDesc && srcDesc.set) srcDesc.set.call(el, url);
            else setAttr.call(el, 'src', url);
          } catch (e) {}
          if (!patched || patched.indexOf('_h<10000') === -1) {
            try { el.type = 'text/javascript'; } catch (e) {}
            try {
              if (srcDesc && srcDesc.set) srcDesc.set.call(el, url);
            } catch (e) {}
            return;
          }
          var s = document.createElement('script');
          s.text = patched + '\n//# sourceURL=' + url;
          var parent = el.parentNode || document.head || document.documentElement;
          if (el.nextSibling) parent.insertBefore(s, el.nextSibling);
          else parent.appendChild(s);
          window.__mt741styleHit = (window.__mt741styleHit || 0) + 1;
        }
        if (srcDesc && srcDesc.set) {
          Object.defineProperty(HTMLScriptElement.prototype, 'src', {
            configurable: true,
            enumerable: true,
            get: function () { return srcDesc.get ? srcDesc.get.call(this) : ''; },
            set: function (url) {
              if (isSdk(url) && !this.__mt741sdk) { hijack(this, url); return; }
              srcDesc.set.call(this, url);
            }
          });
        }
        Element.prototype.setAttribute = function (name, value) {
          if (this.tagName === 'SCRIPT' && String(name).toLowerCase() === 'src' && isSdk(value) && !this.__mt741sdk) {
            hijack(this, value);
            return;
          }
          return setAttr.apply(this, arguments);
        };
      }
      function hookBeforeLoad() {
        if (window.__mt741beforeLoad) return;
        window.__mt741beforeLoad = true;
        function isSdk(url) {
          return /bs_h5(\.min)?\.js/i.test(String(url || ''));
        }
        function intercept(el) {
          if (!el || el.__mt741sdk) return;
          var url = '';
          try { url = el.getAttribute('src') || el.src || ''; } catch (e) {}
          if (!isSdk(url)) return;
          try { el.type = 'text/plain'; } catch (e) {}
          el.__mt741sdk = true;
          try {
            var xhr = new XMLHttpRequest();
            xhr.open('GET', url, false);
            xhr.send(null);
            var patched = patchSrc(xhr.responseText || '');
            if (patched && patched.indexOf('_h<10000') !== -1) {
              var s = document.createElement('script');
              s.text = patched + '\n//# sourceURL=' + url;
              var parent = el.parentNode || document.head || document.documentElement;
              parent.appendChild(s);
              window.__mt741styleHit = (window.__mt741styleHit || 0) + 1;
              return;
            }
          } catch (e) {}
          try { el.type = 'text/javascript'; } catch (e) {}
        }
        document.addEventListener('beforeload', function (e) {
          try {
            var el = e.target;
            if (el && el.tagName === 'SCRIPT' && isSdk(el.src || '')) {
              try { e.preventDefault(); } catch (err) {}
              intercept(el);
            }
          } catch (err) {}
        }, true);
        document.addEventListener('DOMNodeInserted', function (e) {
          try {
            var el = e.target;
            if (el && el.tagName === 'SCRIPT') intercept(el);
          } catch (err) {}
        }, true);
      }
      function hook() {
        try { hookGCS(); } catch (e) {}
        try { hookStyleTotalAssign(); } catch (e) {}
        try { hookDefineProperty(); } catch (e) {}
        try { hookBeforeLoad(); } catch (e) {}
        try { hookScriptSrc(); } catch (e) {}
        try { hookFetch(); } catch (e) {}
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
          hit: window.__mt741styleHit || 0,
          bump: window.__mt741styleBump || 0,
          gcs: !!window.__mt741gcs
        };
      }
      window.__mt741liftStyle = lift;
      window.__mt741hookStyle = hook;
      hook();
    })();
    """#
}
