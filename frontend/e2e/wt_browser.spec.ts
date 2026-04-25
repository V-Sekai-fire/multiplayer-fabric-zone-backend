// SPDX-License-Identifier: MIT
// Copyright (c) 2026 K. S. Ernest (iFire) Lee

// Single-client WebTransport browser smoke test.
//
// Requires wt_server_demo.gd running locally:
//   cd multiplayer-fabric-godot
//   godot.macos.editor.dev.arm64 --headless \
//     --script modules/http3/demo/wt_server_demo.gd > /tmp/wt_server.log 2>&1 &
//
// Run:
//   pnpm playwright test wt_browser --project=chromium

import { test, expect, chromium } from "@playwright/test";
import { execSync } from "child_process";
import * as http from "http";

const WT_PORT = parseInt(process.env.WT_PORT ?? "54370", 10);

function readCertHash(): string {
  try {
    const log = execSync("grep cert_hash /tmp/wt_server.log").toString();
    return JSON.parse(log.trim()).cert_hash as string;
  } catch {
    throw new Error(
      "wt_server_demo not running — start it first:\n" +
      "  godot --headless --script modules/http3/demo/wt_server_demo.gd > /tmp/wt_server.log 2>&1 &"
    );
  }
}

function makeTestPage(certHash: string, port: number): string {
  return `<!DOCTYPE html>
<html><head><title>WT Datagram Test</title></head><body>
<pre id="log"></pre>
<script>
const PORT = ${port}, HASH = "${certHash}", MSG = "Hello Godot WebTransport";
const log = s => { document.getElementById("log").textContent += s + "\\n"; console.log(s); };
(async () => {
  if (typeof WebTransport === "undefined") {
    log("SKIP: WebTransport not available");
    document.title = "SKIP";
    return;
  }
  const hashBytes = Uint8Array.from(atob(HASH), c => c.charCodeAt(0));
  let wt;
  try {
    wt = new WebTransport("https://127.0.0.1:" + PORT + "/wt", {
      serverCertificateHashes: [{ algorithm: "sha-256", value: hashBytes }]
    });
    await wt.ready;
    log("session ready");
  } catch(e) { log("FAIL connect: " + e); document.title = "FAIL"; return; }

  const writer = wt.datagrams.writable.getWriter();
  const reader = wt.datagrams.readable.getReader();
  await writer.write(new TextEncoder().encode(MSG));
  log("sent datagram: " + MSG);

  const { value } = await reader.read();
  const echo = new TextDecoder().decode(value);
  if (echo === MSG) {
    log("PASS: echo matched");
    document.title = "PASS";
  } else {
    log("FAIL: got " + JSON.stringify(echo));
    document.title = "FAIL";
  }
})();
</script></body></html>`;
}

test.use({ browserName: "chromium" });

test("WebTransport datagram echo: browser sends datagram, Godot echoes it back", async () => {
  const certHash = readCertHash();

  // Serve the test page from http://localhost so Chrome treats it as a secure context.
  const html = makeTestPage(certHash, WT_PORT);
  const server = http.createServer((_req, res) => {
    res.writeHead(200, { "Content-Type": "text/html" });
    res.end(html);
  });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const { port: httpPort } = server.address() as { port: number };

  const browser = await chromium.launch({
    headless: false,
    args: ["--ignore-certificate-errors", "--allow-insecure-localhost"],
  });

  const page = await browser.newPage();
  page.on("console", (msg) => console.log("browser:", msg.text()));

  await page.goto(`http://localhost:${httpPort}/`, { waitUntil: "load" });

  try {
    await expect(page).toHaveTitle(/^(PASS|FAIL|SKIP)$/, { timeout: 15_000 });
  } finally {
    const pageLog = await page.locator("#log").textContent().catch(() => "(no #log)");
    console.log("Page log:\n" + pageLog);
    await page.screenshot({ path: "/tmp/wt_browser_test.png" });
  }

  const title = await page.title();
  expect(title, `Expected PASS, got ${title}`).toBe("PASS");

  await browser.close();
  server.close();
});
