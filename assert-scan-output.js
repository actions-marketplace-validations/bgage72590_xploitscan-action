#!/usr/bin/env node
/**
 * Fail closed when the scan that feeds the Action gate did not produce a
 * usable result.
 *
 * CLI exit codes (packages/cli/src/commands/scan.ts):
 *   0 — scan finished. Critical/high security findings were not found
 *       (quality findings do not set this unless --fail-on-quality).
 *   1 — findings over the CLI's own threshold (critical or high security,
 *       or quality when that flag is on), or a handled failure that still
 *       uses exit 1 (quota, unreadable directory) and then writes no JSON.
 *   anything else — crash, signal, or a missing binary (127).
 *
 * Exit 0 and 1 are normal. This script does not apply fail-on. The
 * check-failure-threshold.sh step does that from the graded counts. This
 * script only rejects a crash, a missing or empty file, JSON that does not
 * parse, or JSON that is not a scan result.
 *
 * Usage: node assert-scan-output.js <exit-code> <json-path>
 * Exit: 0 usable, 1 fail closed (::error:: on stdout).
 */

const fs = require("node:fs");

function fail(message) {
  process.stdout.write(`::error::XploitScan: ${message}\n`);
  process.exit(1);
}

function isNormalExit(raw) {
  return raw === "0" || raw === "1";
}

function assertShape(value) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    fail(
      "scan JSON is not a scan result (expected an object with a findings array and a numeric filesScanned). Refusing to treat it as a pass.",
    );
  }
  if (!Array.isArray(value.findings)) {
    fail(
      "scan JSON is not a scan result (expected an object with a findings array and a numeric filesScanned). Refusing to treat it as a pass.",
    );
  }
  if (typeof value.filesScanned !== "number" || !Number.isFinite(value.filesScanned)) {
    fail(
      "scan JSON is not a scan result (filesScanned must be a number). Refusing to treat it as a pass.",
    );
  }
  for (const item of value.findings) {
    if (item === null || typeof item !== "object" || Array.isArray(item)) {
      fail(
        "scan JSON findings must be objects. Refusing to treat it as a pass.",
      );
    }
  }
  if (value.quality !== undefined) {
    if (!Array.isArray(value.quality)) {
      fail(
        "scan JSON quality must be an array when present. Refusing to treat it as a pass.",
      );
    }
    for (const item of value.quality) {
      if (item === null || typeof item !== "object" || Array.isArray(item)) {
        fail(
          "scan JSON quality entries must be objects. Refusing to treat it as a pass.",
        );
      }
    }
  }
}

function main() {
  const code = process.argv[2];
  const file = process.argv[3];
  if (code === undefined || file === undefined) {
    fail(
      "assert-scan-output.js needs an exit code and a JSON path. Refusing to pass.",
    );
  }

  if (!isNormalExit(code)) {
    fail(
      `CLI exited ${code}. Exit 0 is a clean scan and exit 1 means findings over the CLI's critical/high threshold; any other exit is a crash, so this job is failing closed.`,
    );
  }

  let raw;
  try {
    raw = fs.readFileSync(file, "utf8");
  } catch (error) {
    const detail = error && error.code === "ENOENT" ? "missing" : "unreadable";
    fail(
      `scan JSON is ${detail} (${file}). The CLI exited ${code}. Refusing to treat a missing report as a pass.`,
    );
  }

  if (raw.trim() === "") {
    fail(
      `scan JSON is empty (${file}). The CLI exited ${code}, which is also the findings code, but it did not write a scan result. Refusing to pass.`,
    );
  }

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (error) {
    const detail = error && error.message ? error.message : "parse error";
    fail(
      `scan JSON did not parse (${detail}). Refusing to treat an unreadable report as a pass.`,
    );
  }

  assertShape(parsed);
}

main();
