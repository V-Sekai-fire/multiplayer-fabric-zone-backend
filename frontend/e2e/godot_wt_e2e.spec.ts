// SPDX-License-Identifier: MIT
// Copyright (c) 2026 K. S. Ernest (iFire) Lee

// End-to-end: Godot web export loads, GDScript creates WebTransportPeer,
// connects to the local echo server, sends a datagram, receives echo.
//
// Requires:
//   1. wt_server_demo.gd running (started by qa.sh)
//      cert_hash in /tmp/wt_server.log
//   2. Web export files in multiplayer-fabric-godot/bin/.web_zip/
//      and game.pck in modules/http3/demo/export/web/game.pck
//
// The GDScript (wt_client_web.gd) writes JSON beacons to window.__wt_beacons
// so Playwright can poll them via page.evaluate().
//
// Run:
//   pnpm playwright test godot_wt_e2e --project=chromium

import { test, expect, chromium } from "@playwright/test";
import * as http from "http";
import * as fs from "fs";
import * as path from "path";
import { execSync } from "child_process";

const GODOT_ZIP = path.resolve(
  __dirname,
  "../../../multiplayer-fabric-godot/bin/.web_zip"
);
const GAME_PCK = path.resolve(
  __dirname,
  "../../../multiplayer-fabric-godot/modules/http3/demo/export/web/game.pck"
);

function readCertHash(): string {
  try {
    const log = execSync("grep cert_hash /tmp/wt_server.log").toString();
    return JSON.parse(log.trim()).cert_hash as string;
  } catch {
    throw new Error("wt_server_demo not running — start it first (see qa.sh)");
  }
}

function readWtPort(): number {
  try {
    const log = execSync("grep cert_hash /tmp/wt_server.log").toString();
    return JSON.parse(log.trim()).port as number ?? 54370;
  } catch {
    return 54370;
  }
}

function serveWithCOOP(
  engineDir: string,
  pckPath: string,
  certHash: string,
  wtPort: number
): Promise<{ server: http.Server; port: number }> {
  const server = http.createServer((req, res) => {
    res.setHeader("Cross-Origin-Opener-Policy", "same-origin");
    res.setHeader("Cross-Origin-Embedder-Policy", "require-corp");

    const url = req.url === "/" ? "/index.html" : req.url!;

    // Serve game.pck from the export directory.
    if (url === "/game.pck") {
      const data = fs.readFileSync(pckPath);
      res.writeHead(200, { "Content-Type": "application/octet-stream" });
      res.end(data);
      return;
    }

    // Serve engine files from .web_zip.
    if (url === "/index.html") {
      res.writeHead(200, { "Content-Type": "text/html" });
      res.end(makeIndexHtml(certHash, wtPort));
      return;
    }

    const filePath = path.join(engineDir, url);
    fs.readFile(filePath, (err, data) => {
      if (err) { res.writeHead(404); res.end("not found"); return; }
      const mime: Record<string, string> = {
        ".js": "application/javascript",
        ".wasm": "application/wasm",
      };
      res.writeHead(200, {
        "Content-Type": mime[path.extname(filePath)] ?? "application/octet-stream",
      });
      res.end(data);
    });
  });

  return new Promise((resolve) =>
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address() as { port: number };
      resolve({ server, port });
    })
  );
}

function makeIndexHtml(certHash: string, wtPort: number): string {
  return `<!DOCTYPE html>
<html><head><title>Godot WT E2E</title>
<style>body{background:#000;margin:0} #canvas{display:block;width:100vw;height:100vh}</style>
</head><body>
<canvas id="canvas"></canvas>
<script src="godot.js"></script>
<script>
// Passed to quic_web_glue.js godot_wt_connect() for self-signed cert pinning.
window.WT_HOST = "127.0.0.1";
window.WT_PORT = ${wtPort};
window.WT_CERT_HASH = "${certHash}";

window.__wt_call_log = [];
// Monkey-patch WebTransport to inject serverCertificateHashes when
// window.WT_CERT_HASH is set and to log all connection attempts.
(function() {
  const _OrigWT = window.WebTransport;
  window.WebTransport = function(url, opts) {
    window.__wt_call_log.push({url: url, opts: JSON.stringify(opts)});
    console.log("[WT patch] connecting to: " + url);
    if (window.WT_CERT_HASH && !(opts && opts.serverCertificateHashes)) {
      const hashBytes = Uint8Array.from(atob(window.WT_CERT_HASH), function(c) { return c.charCodeAt(0); });
      opts = Object.assign({}, opts, {
        serverCertificateHashes: [{ algorithm: 'sha-256', value: hashBytes }]
      });
    }
    const wt = new _OrigWT(url, opts);
    wt.ready.then(() => console.log("[WT patch] ready: " + url))
             .catch((e) => console.log("[WT patch] failed: " + url + " " + e));
    return wt;
  };
})();
window.__wt_beacons = [];

const engine = new Engine({
  executable: "godot",
  mainPack: "game.pck",
  canvasResizePolicy: 0,
  args: [],
});
engine.startGame({}).catch(function(e) {
  window.__wt_beacons.push({event: "engine_error", reason: String(e)});
});
</script></body></html>`;
}

test.use({ browserName: "chromium" });

test("Godot web export: GDScript WebTransportPeer connects and echoes datagram", async () => {
  if (!fs.existsSync(GAME_PCK)) {
    test.skip(true, `game.pck not found at ${GAME_PCK} — run: cd modules/http3/demo && godot --headless --export-pack "Web" export/web/game.pck`);
    return;
  }

  const certHash = readCertHash();
  const wtPort = readWtPort();

  const { server, port } = await serveWithCOOP(GODOT_ZIP, GAME_PCK, certHash, wtPort);

  const browser = await chromium.launch({
    headless: false,
    args: ["--ignore-certificate-errors", "--allow-insecure-localhost"],
  });
  const page = await browser.newPage();
  page.on("console", (msg) => console.log("browser:", msg.text()));

  await page.goto(`http://localhost:${port}/`, { waitUntil: "load" });

  // Poll window.__wt_beacons until we see "pass" or "fail" or timeout (30s).
  const result = await page.evaluate(() => {
    return new Promise<{ event: string; echo?: string; reason?: string; debug?: any }>(
      (resolve) => {
        const check = () => {
          const beacons: Array<{ event: string }> = (window as any).__wt_beacons || [];
          const terminal = beacons.find(
            (b) => b.event === "pass" || b.event === "fail" || b.event === "engine_error"
          );
          if (terminal) {
            // Attach debug info
            const wtSessions = (window as any).GodotWebTransport?._sessions ?? "unavailable";
            const wtCalls = (window as any).__wt_call_log ?? [];
            resolve(Object.assign({}, terminal as any, { debug: { sessions: wtSessions, calls: wtCalls, beacons } }));
          } else {
            setTimeout(check, 200);
          }
        };
        check();
      }
    );
  });

  console.log("Result:", result);
  await page.screenshot({ path: "/tmp/godot_wt_e2e.png" });

  await browser.close();
  server.close();

  expect(
    result.event,
    `Expected pass, got ${result.event}: ${result.reason ?? result.echo}`
  ).toBe("pass");
});
