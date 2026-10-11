import Foundation

enum H5Fire {
    static let javaScript = #"""
    (function () {
      if (window.__mt741fireReady) return;
      window.__mt741fireReady = true;
      function applyHeaders(xhr, extraHeaders, kv) {
        if (extraHeaders) {
          for (var k in extraHeaders) {
            if (!Object.prototype.hasOwnProperty.call(extraHeaders, k)) continue;
            var val = extraHeaders[k];
            if (val === undefined || val === null || val === '') continue;
            var lk = String(k).toLowerCase();
            if (lk === 'content-web-bb' || lk === 'content-hh-bb' || lk === 'cookie' || lk === 'sdk-ver-bb') continue;
            try { xhr.setRequestHeader(k, String(val)); } catch (e) {}
          }
        }
        if (kv) {
          if (kv.k) { try { xhr.setRequestHeader('MT-K', String(kv.k)); } catch (e) {} }
          if (kv.v) { try { xhr.setRequestHeader('MT-V', String(kv.v)); } catch (e) {} }
        }
      }
      function xhrOnce(method, url, body, timeoutMs, extraHeaders, kv) {
        return new Promise(function (resolve) {
          var t0 = Date.now();
          try {
            var xhr = new XMLHttpRequest();
            xhr.open(method, url, true);
            xhr.withCredentials = true;
            xhr.timeout = timeoutMs || 8000;
            xhr.setRequestHeader('Accept', 'application/json, text/javascript, */*; q=0.01');
            xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
            if (method !== 'GET') {
              xhr.setRequestHeader('Content-Type', 'application/json');
            }
            applyHeaders(xhr, extraHeaders, kv);
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
        return xhrOnce(payload.method || 'GET', payload.url, payload.body || null, payload.timeoutMs || 12000, payload.headers, payload.kv);
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
                  xhrOnce('POST', url, body, 8000, headers, kvList[i] || {}).then(function (one) {
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
        [
            "MT-Device-ID": deviceId,
            "MT-APP-Version": AuthDigest.appVersion,
            "Sdk-Ver-Bb": HeaderBuilder.sdkVer,
            "MT-Info": HeaderBuilder.mtInfo,
            "Accept-Language": "zh-CN,zh-Hans;q=0.9",
            "Referer": product.h5URL.absoluteString,
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
