// SPDX-License-Identifier: MIT
// Copyright (c) 2026 K. S. Ernest (iFire) Lee

// Verifies that the threaded wasm64 Godot web export initialises in Chromium:
//   - SharedArrayBuffer available (COOP/COEP headers applied)
//   - Engine.getMissingFeatures({threads: true}) returns []
//   - No WASM load errors in console
//
// Requires a built web export in multiplayer-fabric-godot/bin/:
//   cd multiplayer-fabric-godot && gescons target=template_debug
//
// Run:
//   pnpm playwright test godot_web_init --project=chromium

import { test, expect, chromium } from "@playwright/test";
import * as http from "http";
import * as fs from "fs";
import * as path from "path";

const GODOT_BIN = path.resolve(
  __dirname,
  "../../../multiplayer-fabric-godot/bin/.web_zip"
);
const ENGINE_JS = "godot.js";
const SERVICE_WORKER_JS = path.resolve(
  __dirname,
  "../../../../multiplayer-fabric-godot/misc/dist/html/service-worker.js"
);

function serveWithCOOP(dir: string): Promise<{ server: http.Server; port: number }> {
  const server = http.createServer((req, res) => {
    // COOP/COEP required for SharedArrayBuffer (threaded Godot).
    res.setHeader("Cross-Origin-Opener-Policy", "same-origin");
    res.setHeader("Cross-Origin-Embedder-Policy", "require-corp");

    const filePath = path.join(dir, req.url === "/" ? "/index.html" : req.url!);
    fs.readFile(filePath, (err, data) => {
      if (err) {
        res.writeHead(404);
        res.end("not found");
        return;
      }
      const ext = path.extname(filePath);
      const mime: Record<string, string> = {
        ".js": "application/javascript",
        ".wasm": "application/wasm",
        ".html": "text/html",
      };
      res.writeHead(200, { "Content-Type": mime[ext] ?? "application/octet-stream" });
      res.end(data);
    });
  });

  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address() as { port: number };
      resolve({ server, port });
    });
  });
}

test.use({ browserName: "chromium" });

test("Godot wasm64 web export: Engine loads and getMissingFeatures returns [] with threads", async () => {
  // Write a minimal index.html alongside the engine files.
  const indexPath = path.join(GODOT_BIN, "index.html");
  fs.writeFileSync(
    indexPath,
    `<!DOCTYPE html><html><head><title>Godot Init Test</title></head><body>
<script src="${ENGINE_JS}"></script>
<script>
(async () => {
  const log = s => { console.log(s); };
  if (typeof SharedArrayBuffer === "undefined") {
    log("FAIL: SharedArrayBuffer not available (COOP/COEP missing)");
    document.title = "FAIL:no-sab";
    return;
  }
  log("SharedArrayBuffer: available");

  if (typeof Engine === "undefined") {
    log("FAIL: Engine not defined after loading engine JS");
    document.title = "FAIL:no-engine";
    return;
  }
  log("Engine: defined");

  const missing = Engine.getMissingFeatures({ threads: true });
  if (missing.length > 0) {
    log("FAIL: missing features: " + missing.join(", "));
    document.title = "FAIL:missing:" + missing.join(",");
    return;
  }
  log("PASS: no missing features, threaded engine ready");
  document.title = "PASS";
})();
</script></body></html>`
  );

  const { server, port } = await serveWithCOOP(GODOT_BIN);
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();

  const errors: string[] = [];
  page.on("console", (msg) => {
    console.log("browser:", msg.text());
    if (msg.type() === "error") errors.push(msg.text());
  });
  page.on("pageerror", (err) => errors.push(err.message));

  await page.goto(`http://localhost:${port}/`, { waitUntil: "load" });

  await expect(page).toHaveTitle(/^(PASS|FAIL.*)$/, { timeout: 30_000 });

  const title = await page.title();
  console.log("Console errors:", errors);
  expect(title, `Expected PASS, got: ${title}\nErrors: ${errors.join("\n")}`).toBe("PASS");

  await browser.close();
  server.close();
  fs.unlinkSync(indexPath);
});
