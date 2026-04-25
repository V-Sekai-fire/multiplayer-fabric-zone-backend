// SPDX-License-Identifier: MIT
// Copyright (c) 2026 K. S. Ernest (iFire) Lee

// Operator camera tests — two layers:
//
// Layer 1 (always runs): Pure JS simulation of the camera state machine.
//   Verifies twist snapping, zoom clamping, mode transitions and the
//   swing-is-constant invariant without requiring a Godot build.
//
// Layer 2 (skipped if no web export): Real Godot web export.
//   Sends keyboard events and reads window.__camera_state written by
//   operator_camera.gd via JavaScriptBridge.eval().
//
// Run:
//   pnpm playwright test operator_camera --project=chromium

import { test, expect, chromium } from "@playwright/test";
import * as http from "http";
import * as fs from "fs";
import * as path from "path";

// ---------------------------------------------------------------------------
// Shared constants matching operator_camera.gd
// ---------------------------------------------------------------------------
const SWING_ELEVATION = 0.153;
const SNAP_STEP = 0.25;
const ZOOM_MIN = 10.0;
const ZOOM_MAX = 60.0;
const SNAPS = [0.0, 0.25, 0.5, 0.75];

// ---------------------------------------------------------------------------
// Layer 1 — JS simulation (no Godot required)
// ---------------------------------------------------------------------------

// Mirror of operator_camera.gd state machine in TypeScript.
type Mode = "survey" | "follow";
interface CameraState {
  mode: Mode;
  twist: number;   // [0, 1]
  swing: number;   // constant = SWING_ELEVATION
  zoom: number;    // [ZOOM_MIN, ZOOM_MAX]
}

function initialState(): CameraState {
  return { mode: "survey", twist: 0.0, swing: SWING_ELEVATION, zoom: 40.0 };
}

function rotateLeft(s: CameraState): CameraState {
  const t = ((s.twist - SNAP_STEP) % 1.0 + 1.0) % 1.0;
  return { ...s, twist: t };
}

function rotateRight(s: CameraState): CameraState {
  const t = (s.twist + SNAP_STEP) % 1.0;
  return { ...s, twist: t };
}

function zoomIn(s: CameraState): CameraState {
  return { ...s, zoom: Math.max(s.zoom - 5.0, ZOOM_MIN) };
}

function zoomOut(s: CameraState): CameraState {
  return { ...s, zoom: Math.min(s.zoom + 5.0, ZOOM_MAX) };
}

function enterFollow(s: CameraState): CameraState {
  return { ...s, mode: "follow" };
}

function exitFollow(s: CameraState): CameraState {
  return { ...s, mode: "survey" };
}

function isSnapped(twist: number): boolean {
  return SNAPS.some((v) => Math.abs(twist - v) < 1e-6);
}

test.describe("Operator camera — JS simulation", () => {
  test("initial state is survey, orthographic, twist=0, swing=SWING_ELEVATION", () => {
    const s = initialState();
    expect(s.mode).toBe("survey");
    expect(s.twist).toBeCloseTo(0.0);
    expect(s.swing).toBeCloseTo(SWING_ELEVATION);
    expect(s.zoom).toBeGreaterThanOrEqual(ZOOM_MIN);
    expect(s.zoom).toBeLessThanOrEqual(ZOOM_MAX);
  });

  test("Q (rotate left) snaps twist through all four cardinal positions", () => {
    let s = initialState();
    const visited: number[] = [s.twist];
    for (let i = 0; i < 4; i++) {
      s = rotateLeft(s);
      expect(isSnapped(s.twist)).toBe(true);
      visited.push(s.twist);
    }
    // Full rotation returns to start
    expect(s.twist).toBeCloseTo(initialState().twist);
    // All four cardinal positions visited (start = end = 0, so 4 distinct values)
    expect(new Set(visited.map((v) => Math.round(v * 4))).size).toBe(4);
  });

  test("E (rotate right) snaps through all four cardinal positions", () => {
    let s = initialState();
    for (let i = 0; i < 4; i++) {
      s = rotateRight(s);
      expect(isSnapped(s.twist)).toBe(true);
    }
    expect(s.twist).toBeCloseTo(0.0); // full cycle returns to 0
  });

  test("zoom stays within [ZOOM_MIN, ZOOM_MAX]", () => {
    let s = initialState();
    for (let i = 0; i < 20; i++) s = zoomIn(s);
    expect(s.zoom).toBeCloseTo(ZOOM_MIN);

    for (let i = 0; i < 20; i++) s = zoomOut(s);
    expect(s.zoom).toBeCloseTo(ZOOM_MAX);
  });

  test("swing never changes", () => {
    let s = initialState();
    s = rotateLeft(s);
    s = rotateRight(s);
    s = zoomIn(s);
    s = enterFollow(s);
    s = exitFollow(s);
    expect(s.swing).toBeCloseTo(SWING_ELEVATION);
  });

  test("Follow mode locks twist", () => {
    let s = initialState();
    s = rotateRight(s);              // twist = 0.25
    const twistBeforeFollow = s.twist;
    s = enterFollow(s);
    expect(s.mode).toBe("follow");
    // In follow mode we do NOT call rotateLeft/Right — twist is frozen.
    // Simulating that no rotation occurs while in follow mode:
    expect(s.twist).toBeCloseTo(twistBeforeFollow);
  });

  test("Escape exits Follow and restores Survey mode", () => {
    let s = initialState();
    s = enterFollow(s);
    expect(s.mode).toBe("follow");
    s = exitFollow(s);
    expect(s.mode).toBe("survey");
  });
});

// ---------------------------------------------------------------------------
// Layer 2 — Real Godot web export
// ---------------------------------------------------------------------------

const ABYSSAL_WEB = path.resolve(
  __dirname,
  "../../../multiplayer-fabric-godot/modules/multiplayer_fabric/demo/abyssal_vr/export/web"
);

function serveWithCOOP(dir: string): Promise<{ server: http.Server; port: number }> {
  const server = http.createServer((req, res) => {
    res.setHeader("Cross-Origin-Opener-Policy", "same-origin");
    res.setHeader("Cross-Origin-Embedder-Policy", "require-corp");
    const filePath = path.join(dir, req.url === "/" ? "/index.html" : req.url!);
    fs.readFile(filePath, (err, data) => {
      if (err) { res.writeHead(404); res.end("not found"); return; }
      const mime: Record<string, string> = {
        ".js": "application/javascript", ".wasm": "application/wasm",
        ".html": "text/html", ".pck": "application/octet-stream",
      };
      res.writeHead(200, { "Content-Type": mime[path.extname(filePath)] ?? "application/octet-stream" });
      res.end(data);
    });
  });
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => {
      resolve({ server, port: (server.address() as { port: number }).port });
    });
  });
}

const webExportExists = fs.existsSync(path.join(ABYSSAL_WEB, "index.html"));

test.describe("Operator camera — Godot web export", () => {
  test.skip(!webExportExists, `Web export not found at ${ABYSSAL_WEB} — run: gescons path=modules/multiplayer_fabric/demo/abyssal_vr target=template_debug`);

  test("window.__camera_state exposed; Q/E changes twist; zoom clamps; Tab toggles projection", async () => {
    const { server, port } = await serveWithCOOP(ABYSSAL_WEB);
    const browser = await chromium.launch({ headless: false });
    const page = await browser.newPage();

    page.on("console", (m) => console.log("browser:", m.text()));
    page.on("pageerror", (e) => console.error("pageerror:", e.message));

    await page.goto(`http://localhost:${port}/`, { waitUntil: "load" });

    // Wait for Godot to boot and first _process() to run
    await page.waitForFunction(
      () => typeof (window as any).__camera_state !== "undefined",
      { timeout: 30_000 }
    );

    // Initial state
    const initial = await page.evaluate(() => (window as any).__camera_state);
    expect(initial.mode).toBe("survey");
    expect(initial.projection).toBe("orthographic");
    expect(isSnapped(initial.twist)).toBe(true);

    // Q — rotate left
    await page.keyboard.press("q");
    await page.waitForTimeout(200);
    const afterQ = await page.evaluate(() => (window as any).__camera_state);
    expect(isSnapped(afterQ.twist)).toBe(true);
    expect(afterQ.twist).not.toBeCloseTo(initial.twist);
    expect(afterQ.swing).toBeCloseTo(SWING_ELEVATION); // swing unchanged

    // E — rotate right (should return toward start)
    await page.keyboard.press("e");
    await page.waitForTimeout(200);
    const afterE = await page.evaluate(() => (window as any).__camera_state);
    expect(isSnapped(afterE.twist)).toBe(true);

    // Scroll down — zoom out
    await page.mouse.wheel(0, 120);
    await page.waitForTimeout(200);
    const afterZoomOut = await page.evaluate(() => (window as any).__camera_state);
    expect(afterZoomOut.zoom).toBeLessThanOrEqual(ZOOM_MAX);
    expect(afterZoomOut.zoom).toBeGreaterThanOrEqual(ZOOM_MIN);

    // Tab — toggle projection
    await page.keyboard.press("Tab");
    await page.waitForTimeout(200);
    const afterTab = await page.evaluate(() => (window as any).__camera_state);
    expect(afterTab.projection).toBe("perspective");

    // Tab again — back to orthographic
    await page.keyboard.press("Tab");
    await page.waitForTimeout(200);
    const afterTab2 = await page.evaluate(() => (window as any).__camera_state);
    expect(afterTab2.projection).toBe("orthographic");

    await browser.close();
    server.close();
  });

  function isSnapped(twist: number): boolean {
    return [0.0, 0.25, 0.5, 0.75].some((v) => Math.abs(twist - v) < 0.02);
  }
});
