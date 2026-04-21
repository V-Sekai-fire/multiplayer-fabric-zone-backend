// SPDX-License-Identifier: MIT
// Copyright (c) 2026 K. S. Ernest (iFire) Lee
import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  timeout: 30_000,
  use: {
    baseURL: process.env.API_ORIGIN ?? "https://hub-700a.chibifire.com",
    extraHTTPHeaders: {
      Accept: "application/json",
    },
  },
});
