// SPDX-License-Identifier: MIT
// Copyright (c) 2026 K. S. Ernest (iFire) Lee

// Phase 1 GO — Godot headless observer smoke test.
//
// Spawns godot --headless with headless_log_observer.gd against the local
// zone server (127.0.0.1:7443 by default) and asserts that at least one
// entity is received and written to the JSON dump.
//
// Prerequisites:
//   - Zone server running: docker compose up -d zone-server (UDP 7443)
//   - Godot binary on PATH or GODOT_BIN env var
//
// Run:
//   pnpm playwright test headless_go --project=chromium
//
// Override server:
//   ZONE_HOST=zone-700a.chibifire.com ZONE_PORT=443 pnpm playwright test headless_go

import { test, expect } from "@playwright/test";
import { execFile } from "child_process";
import { readFileSync, existsSync } from "fs";
import { tmpdir } from "os";
import * as path from "path";

const ABYSSAL_VR = path.resolve(
  __dirname,
  "../../../multiplayer-fabric-godot/modules/multiplayer_fabric/demo/abyssal_vr"
);
const DUMP_PATH = path.join(tmpdir(), "go_test_entities.json");
const GODOT_BIN = process.env.GODOT_BIN ?? "godot";
const ZONE_HOST = process.env.ZONE_HOST ?? "127.0.0.1";
const ZONE_PORT = process.env.ZONE_PORT ?? "7443";
const FRAMES    = process.env.GO_FRAMES  ?? "600";

function runObserver(): Promise<{ code: number; stdout: string; stderr: string }> {
  return new Promise((resolve) => {
    execFile(
      GODOT_BIN,
      [
        "--headless",
        "--path", ABYSSAL_VR,
        "--script", "scripts/headless_log_observer.gd",
        "--",
        `--host=${ZONE_HOST}`,
        `--port=${ZONE_PORT}`,
        `--dump-json=${DUMP_PATH}`,
        `--frames=${FRAMES}`,
      ],
      { timeout: 120_000 },
      (err, stdout, stderr) => {
        resolve({ code: (err as NodeJS.ErrnoException)?.code as unknown as number ?? 0, stdout, stderr });
      }
    );
  });
}

const godotAvailable = (() => {
  try {
    require("child_process").execFileSync(GODOT_BIN, ["--version"], { timeout: 5000 });
    return true;
  } catch {
    return false;
  }
})();

test.describe("Phase 1 GO — Godot headless observer", () => {
  test.skip(!godotAvailable, `Godot binary not found: ${GODOT_BIN} — set GODOT_BIN env var`);

  test("entities > 0 received from zone server at " + ZONE_HOST + ":" + ZONE_PORT, async () => {
    test.setTimeout(130_000);

    const { code, stdout, stderr } = await runObserver();
    if (stdout) console.log("[GO stdout]", stdout.trim());
    if (stderr) console.log("[GO stderr]", stderr.trim());

    expect(
      code,
      `observer exited ${code} — zone server not reachable at ${ZONE_HOST}:${ZONE_PORT}?`
    ).toBe(0);

    expect(existsSync(DUMP_PATH), `dump file not written: ${DUMP_PATH}`).toBe(true);

    const entities = JSON.parse(readFileSync(DUMP_PATH, "utf-8")) as unknown[];
    expect(entities.length, "no entities in dump — zone server running but no entities?").toBeGreaterThan(0);

    console.log(`GO PASS: ${entities.length} entities received`);
  });
});
