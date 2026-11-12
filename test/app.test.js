import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { createApp } from "../src/app.js";

let server;
let baseUrl;

before(async () => {
  server = createApp().listen(0);
  await new Promise((resolve) => server.once("listening", resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(() => {
  server.close();
});

test("GET /health returns ok", async () => {
  const res = await fetch(`${baseUrl}/health`);
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { status: "ok" });
});

test("GET /greet greets by name", async () => {
  const res = await fetch(`${baseUrl}/greet?name=Ada`);
  assert.deepEqual(await res.json(), { message: "Hello, Ada!" });
});

test("GET /greet defaults to world", async () => {
  const res = await fetch(`${baseUrl}/greet`);
  assert.deepEqual(await res.json(), { message: "Hello, world!" });
});
