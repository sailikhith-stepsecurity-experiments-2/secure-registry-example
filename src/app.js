import express from "express";

export function createApp() {
  const app = express();

  app.get("/health", (req, res) => {
    res.json({ status: "ok" });
  });

  app.get("/greet", (req, res) => {
    const name = typeof req.query.name === "string" && req.query.name ? req.query.name : "world";
    res.json({ message: `Hello, ${name}!` });
  });

  return app;
}
