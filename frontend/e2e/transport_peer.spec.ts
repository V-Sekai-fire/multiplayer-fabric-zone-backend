// SPDX-License-Identifier: MIT
// Copyright (c) 2026 K. S. Ernest (iFire) Lee

// External smoke tests for FabricMMOGTransportPeer data path.
//
// These tests verify that zone-backend returns the fields that
// FabricMMOGTransportPeer::create_client() needs to dial a zone server
// and that the OpenAPI spec documents the WebTransport extension.
//
// Run against the live stack (default: https://hub-700a.chibifire.com):
//   cd frontend && pnpm playwright test
//
// Run against a local stack:
//   API_ORIGIN=http://localhost pnpm playwright test

import { test, expect, APIRequestContext } from "@playwright/test";

// ── helpers ──────────────────────────────────────────────────────────────────

async function registerZone(request: APIRequestContext) {
  return request.post("/api/v1/shards", {
    data: {
      zone: {
        address: "127.0.0.1",
        port: 7443,
        map: "test_map",
        name: "playwright-test-zone",
        cert_hash: "dGVzdA==", // base64("test")
      },
    },
  });
}

// ── shards listing ───────────────────────────────────────────────────────────

test("GET /api/v1/shards returns 200 with a data.zones array", async ({
  request,
}) => {
  const res = await request.get("/api/v1/shards");
  expect(res.status()).toBe(200);

  const body = await res.json();
  expect(body).toHaveProperty("data.zones");
  expect(Array.isArray(body.data.zones)).toBe(true);
});

test("each zone record has the fields required by FabricMMOGTransportPeer", async ({
  request,
}) => {
  // Register a zone so there is at least one entry.
  const createRes = await registerZone(request);
  // Accept any 2xx (auth-gated deployments may return 201; open ones 200).
  expect(createRes.ok()).toBe(true);

  const listRes = await request.get("/api/v1/shards");
  expect(listRes.status()).toBe(200);

  const { data } = await listRes.json();
  const zone = (data.zones as Record<string, unknown>[]).find(
    (z) => z.name === "playwright-test-zone"
  );
  expect(zone).toBeDefined();

  // Fields consumed by FabricMMOGTransportPeer::create_client(address, port).
  expect(typeof zone!.address).toBe("string");
  expect(zone!.address).not.toBe("");
  expect(typeof zone!.port).toBe("number");
  expect(zone!.port).toBeGreaterThan(0);

  // cert_hash is required for WebTransport TLS cert pinning.
  expect(typeof zone!.cert_hash).toBe("string");
});

// ── WebSocket fallback route ──────────────────────────────────────────────────

test("zone-backend /ws route exists (not 404)", async ({ request }) => {
  // The WebSocketMultiplayerPeer fallback connects to ws://host:port/ws.
  // A plain HTTP GET with Upgrade headers should get 101, 400, or 426 —
  // anything but 404 proves the route is configured.
  const res = await request.get("/ws", {
    headers: {
      Connection: "Upgrade",
      Upgrade: "websocket",
      "Sec-WebSocket-Key": "dGhlIHNhbXBsZSBub25jZQ==",
      "Sec-WebSocket-Version": "13",
    },
    maxRedirects: 0,
    failOnStatusCode: false,
  });
  expect(res.status()).not.toBe(404);
});

// ── OpenAPI spec ──────────────────────────────────────────────────────────────

test("OpenAPI spec includes x-webtransport extension on GET /shards", async ({
  request,
}) => {
  const res = await request.get("/api/v1/openapi");
  expect(res.status()).toBe(200);

  const spec = await res.json();
  const shardsGet = spec?.paths?.["/shards"]?.get;
  expect(shardsGet).toBeDefined();
  expect(shardsGet["x-webtransport"]).toBeDefined();
});
