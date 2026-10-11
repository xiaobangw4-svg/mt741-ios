import Foundation

/// Hidden WKWebView runs the official unpatched `StyleTotal`.
/// A 4-digit ext_142 makes today's CWB 768 (plaintext 367); 5 digits make 800 (368).
/// Chrome sign pool rewrites the loop in `bs_h5.min.js`. Here the SDK is already
/// compiled, so wrap the function at document-start: force a layout read, then
/// lift hashes below 10000 with `10000 + (e<<8|n)` from the token. Natural 5-digit
/// hashes stay as the SDK computed them.
enum StyleTotalPatch {
    static let minFiveDigit: UInt32 = 10_000

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

    static let javaScript = #"""
    (function () {
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
        if (typeof fn !== 'function' || fn.__mt741st) return fn;
        var wrapped = function (t) {
          return lift(fn.apply(this, arguments), t);
        };
        wrapped.__mt741st = true;
        return disguise(wrapped, fn);
      }
      function hookGCS() {
        if (window.__mt741gcs) return;
        var gcs = window.getComputedStyle;
        if (typeof gcs !== 'function') return;
        window.__mt741gcs = true;
        window.getComputedStyle = disguise(function (el, pseudo) {
          try { if (el) void el.offsetWidth; } catch (e) {}
          return gcs.call(window, el, pseudo);
        }, gcs);
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
              try { delete Object.prototype.StyleTotal; } catch (e) {}
            },
            get: function () { return undefined; }
          });
        } catch (e) {}
      }
      function hook() {
        hookGCS();
        hookStyleTotalAssign();
        try {
          if (typeof window.StyleTotal === 'function') {
            window.StyleTotal = wrapFn(window.StyleTotal);
          }
        } catch (e) {}
        window.__mt741stylePatched = true;
        return true;
      }
      window.__mt741liftStyle = lift;
      window.__mt741hookStyle = hook;
      hook();
    })();
    """#
}
