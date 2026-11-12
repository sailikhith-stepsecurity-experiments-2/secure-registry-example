import { test } from "node:test";
import assert from "node:assert/strict";
import semver from "semver";

test("semver compares versions", () => {
  assert.ok(semver.gt("1.2.3", "1.2.0"));
  assert.equal(semver.maxSatisfying(["1.0.0", "1.4.0", "2.0.0"], "^1.0.0"), "1.4.0");
});
