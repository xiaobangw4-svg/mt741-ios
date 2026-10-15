import Foundation

enum H5Fire {
    static let javaScript = #"""
    (function () {
      if (window.__mt741fireReady) return;
      window.__mt741fireReady = true;
      function onceDeviceHeader() {
        var proto = XMLHttpRequest.prototype;
        if (proto.__mt741didOnce) return;
        proto.__mt741didOnce = true;
        var orig = proto.setRequestHeader;
        proto.setRequestHeader = function (k, v) {
          var lk = String(k || '').toLowerCase();
          if (lk === 'mt-device-id') {
            if (this.__mt741didSet) return;
            this.__mt741didSet = true;
          }
          return orig.apply(this, arguments);
        };
      }
      onceDeviceHeader();
      function expireTails() {
        return [
          '; path=/',
          '; path=/; domain=h5.moutai519.com.cn',
          '; path=/; domain=.moutai519.com.cn'
        ];
      }
      function expireCookie(name) {
        var tails = expireTails();
        for (var i = 0; i < tails.length; i++) {
          try { document.cookie = name + '=' + tails[i] + '; expires=Thu, 01 Jan 1970 00:00:00 GMT'; } catch (e) {}
        }
      }
      function pinCookie(name, value) {
        if (!name || value === undefined || value === null) return;
        expireCookie(name);
        try {
          document.cookie = name + '=' + String(value) + '; path=/; domain=h5.moutai519.com.cn';
        } catch (e) {}
      }
      function pinRushCookies(bsDeviceId) {
        expireCookie('gdxidpyhxdE');
        expireCookie('__snaker__id');
        pinCookie('YX_SUPPORT_WEBP', '1');
        var bs = String(bsDeviceId || '');
        if (!bs) {
          try {
            var m = String(document.cookie || '').match(/(?:^|; )_bs_device_id=([^;]*)/);
            if (m && m[1]) bs = decodeURIComponent(m[1]);
          } catch (e) {}
        }
        if (/^bid-[0-9]+-[0-9a-f]{4}-[0-9a-f]{4}$/i.test(bs)) {
          pinCookie('_bs_device_id', bs.toLowerCase());
        }
      }
      function pinIdentity(deviceId, token, userId, bsDeviceId) {
        pinRushCookies(bsDeviceId);
        if (deviceId) {
          try { document.cookie = 'MT-Device-ID-Wap=' + String(deviceId) + '; path=/'; } catch (e) {}
        }
        if (token) {
          try { document.cookie = 'MT-Token-Wap=' + String(token) + '; path=/'; } catch (e) {}
        }
        if (userId) {
          try { localStorage.setItem('_u_id_', String(userId)); } catch (e) {}
        }
      }
      window.__mt741pinIdentity = pinIdentity;
      function lockDevice(xhr, deviceId) {
        if (!deviceId) return;
        if (xhr.__mt741didSet) return;
        try { xhr.setRequestHeader('MT-Device-ID', String(deviceId)); } catch (e) {}
      }
      window.__mt741h5Did = function () {
        function pick(v) {
          v = String(v || '').replace(/^["']|["']$/g, '').trim();
          if (/^h[0-9a-f]{31,32}$/i.test(v)) return v.toLowerCase();
          var m = String(v).match(/h[0-9a-f]{31,32}/i);
          return m ? m[0].toLowerCase() : '';
        }
        try {
          if (window.__FORCE_DID__) {
            var forced = pick(window.__FORCE_DID__);
            if (forced) return forced;
          }
        } catch (e0) {}
        try {
          var ud = localStorage.getItem('__ud') || sessionStorage.getItem('__ud') || '';
          var fromStore = pick(ud);
          if (fromStore) return fromStore;
        } catch (e1) {}
        try {
          for (var i = 0; i < localStorage.length; i++) {
            var k = localStorage.key(i);
            var fromAll = pick(k + ' ' + localStorage.getItem(k));
            if (fromAll) return fromAll;
          }
        } catch (e1b) {}
        try {
          var el = document.getElementById('__ud__');
          if (el) {
            var fromEl = pick(el.getAttribute('d') || el.getAttribute('data-did') || '');
            if (fromEl) return fromEl;
          }
        } catch (e2) {}
        try {
          var m = String(document.cookie || '').match(/(?:^|; )__ud=([^;]+)/);
          if (m) {
            var fromCk = pick(decodeURIComponent(m[1]));
            if (fromCk) return fromCk;
          }
        } catch (e3) {}
        return '';
      };
      window.__mt741signReady = function () {
        try {
          if (window.__SIGN_WASM_OK__ || window.__wasm_sign_ok__ || window.__SIGN_WASM_VERSION__) return true;
        } catch (e) {}
        try {
          if (document.querySelector('script[src*="bs_h5"]')) return true;
        } catch (e2) {}
        return false;
      };
      function applyHeaders(xhr, extraHeaders, kv, deviceId) {
        if (extraHeaders) {
          for (var k in extraHeaders) {
            if (!Object.prototype.hasOwnProperty.call(extraHeaders, k)) continue;
            var val = extraHeaders[k];
            if (val === undefined || val === null) continue;
            var lk = String(k).toLowerCase();
            if (val === '' && lk !== 'x-csrf-token') continue;
            if (lk === 'content-web-bb' || lk === 'content-hh-bb' || lk === 'cookie' || lk === 'sdk-ver-bb' || lk === 'mt-device-id') continue;
            try { xhr.setRequestHeader(k, String(val)); } catch (e) {}
          }
        }
        if (kv) {
          if (kv.k) { try { xhr.setRequestHeader('MT-K', String(kv.k)); } catch (e) {} }
          if (kv.v) { try { xhr.setRequestHeader('MT-V', String(kv.v)); } catch (e) {} }
        }
      }
      function xhrOnce(method, url, body, timeoutMs, extraHeaders, kv, deviceId, token, userId, bsDeviceId) {
        return new Promise(function (resolve) {
          var t0 = Date.now();
          try {
            pinIdentity(deviceId, token, userId, bsDeviceId);
            var xhr = new XMLHttpRequest();
            xhr.open(method, url, true);
            xhr.withCredentials = true;
            xhr.timeout = timeoutMs || 8000;
            lockDevice(xhr, deviceId);
            xhr.setRequestHeader('Accept', 'application/json, text/javascript, */*; q=0.01');
            xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
            if (method !== 'GET') {
              xhr.setRequestHeader('Content-Type', 'application/json');
            }
            applyHeaders(xhr, extraHeaders, kv, deviceId);
            xhr.onload = function () {
              resolve({
                ok: xhr.status >= 200 && xhr.status < 300,
                status: xhr.status,
                ms: Date.now() - t0,
                body: String(xhr.responseText || '').slice(0, 1200),
                error: ''
              });
            };
            xhr.onerror = function () {
              resolve({ ok: false, status: 0, ms: Date.now() - t0, body: '', error: 'network' });
            };
            xhr.ontimeout = function () {
              resolve({ ok: false, status: 0, ms: Date.now() - t0, body: '', error: 'timeout' });
            };
            xhr.send(body || null);
          } catch (e) {
            resolve({ ok: false, status: 0, ms: Date.now() - t0, body: '', error: String(e) });
          }
        });
      }
      window.__mt741request = function (payload) {
        payload = payload || {};
        var headers = payload.headers || {};
        var deviceId = payload.deviceId || headers['MT-Device-ID'] || headers['mt-device-id'] || '';
        var token = payload.wapToken || '';
        var userId = payload.userId || '';
        var bsDeviceId = payload.bsDeviceId || '';
        return xhrOnce(payload.method || 'GET', payload.url, payload.body || null, payload.timeoutMs || 12000, headers, payload.kv, deviceId, token, userId, bsDeviceId);
      };
      window.__mt741fire = function (payload) {
        payload = payload || {};
        var n = Math.max(1, Math.min(64, payload.n || 1));
        var c = Math.max(1, Math.min(16, payload.concurrency || n));
        var interval = Math.max(0, payload.intervalMs || 0);
        var url = payload.url;
        var body = payload.body;
        var headers = payload.headers || {};
        var kvList = payload.kv || [];
        var deviceId = payload.deviceId || headers['MT-Device-ID'] || headers['mt-device-id'] || '';
        var token = payload.wapToken || '';
        var userId = payload.userId || '';
        var bsDeviceId = payload.bsDeviceId || '';
        pinIdentity(deviceId, token, userId, bsDeviceId);
        var shots = new Array(n);
        return new Promise(function (resolve) {
          var started = 0;
          var inflight = 0;
          var finished = 0;
          function pump() {
            while (inflight < c && started < n) {
              (function (i) {
                started += 1;
                inflight += 1;
                setTimeout(function () {
                  xhrOnce('POST', url, body, 8000, headers, kvList[i] || {}, deviceId, token, userId, bsDeviceId).then(function (one) {
                    shots[i] = {
                      idx: i,
                      ok: one.ok,
                      status: one.status,
                      ms: one.ms,
                      body: one.body,
                      error: one.error
                    };
                    inflight -= 1;
                    finished += 1;
                    if (finished >= n) resolve({ n: n, shots: shots });
                    else pump();
                  });
                }, i * interval);
              })(started);
            }
          }
          pump();
        });
      };
    })();
    """#

    static func pageHeaders(deviceId: String, product: Product = .sku741) -> [String: String] {
        _ = deviceId
        return [
            "MT-APP-Version": AuthDigest.appVersion,
            "Sdk-Ver-Bb": HeaderBuilder.sdkVer,
            "MT-Info": HeaderBuilder.mtInfo,
            "Accept-Language": "zh-CN,zh-Hans;q=0.9",
            "Referer": product.h5URL.absoluteString,
            "x-csrf-token": "",
        ]
    }

    static func kvPairs(count: Int, deviceId: String) -> [[String: String]] {
        let n = BurstClient.clampN(count)
        let base = Int64(Date().timeIntervalSince1970 * 1000)
        return (0..<n).map { i in
            let mtK = String(base + Int64(i))
            let mtV = AuthDigest.mtV(
                timestamp: mtK,
                deviceId: deviceId,
                version: AuthDigest.appVersion,
                suffix: AuthDigest.randomSuffix()
            )
            return ["k": mtK, "v": mtV]
        }
    }

    static func parseShots(_ result: Any?) -> [BurstShot] {
        let root: [String: Any]
        if let dict = result as? [String: Any] {
            root = dict
        } else if let s = result as? String, let data = s.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = dict
        } else {
            return []
        }
        let rows = JSONText.array(root["shots"])
        return rows.enumerated().map { idx, row in
            BurstShot(
                idx: JSONText.int(row["idx"]) ?? idx,
                ok: (row["ok"] as? Bool) ?? ((row["ok"] as? NSNumber)?.boolValue ?? false),
                status: JSONText.int(row["status"]) ?? 0,
                ms: (row["ms"] as? Double) ?? Double(JSONText.int(row["ms"]) ?? 0),
                body: JSONText.string(row["body"]),
                error: JSONText.string(row["error"])
            )
        }
    }

    static func stats(from result: Any?, request: BurstRequest, elapsedMs: Double) -> BurstStats {
        let shots = parseShots(result)
        var status: [String: Int] = [:]
        var ok = 0
        for shot in shots {
            if shot.ok { ok += 1 }
            let key = String(shot.status)
            status[key, default: 0] += 1
        }
        let fail = shots.count - ok
        let summary = shots.prefix(8).map { shot in
            "[\(shot.idx)] \(shot.status) \(String(shot.body.prefix(80)))"
        }.joined(separator: " | ")
        return BurstStats(
            url: request.target.urlString,
            n: max(shots.count, BurstClient.clampN(request.n)),
            concurrency: BurstClient.clampC(request.concurrency),
            intervalMs: BurstClient.clampInterval(request.intervalMs),
            sku: request.product.sku,
            elapsedMs: elapsedMs,
            ok: ok,
            fail: fail,
            status: status,
            summary: summary,
            shots: shots
        )
    }
}
