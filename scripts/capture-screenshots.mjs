// ════════════════════════════════════════════════════════════════════════════
// FLK0S · captura automática de screenshots para portfolio / LinkedIn / README
// Usa Playwright Chromium. Requiere apps levantadas en localhost (dev por puerto).
//
// Uso:
//   npx playwright install chromium       # primera vez
//   node capture-screenshots.mjs          # captura todo
//   node capture-screenshots.mjs --only=hub,login   # solo subset
//
// Output: ./screenshots/*.png (1920x1200) listas para README.
// ════════════════════════════════════════════════════════════════════════════

import { chromium } from "playwright";
import path from "node:path";
import fs from "node:fs/promises";
import { fileURLToPath } from "node:url";

const __dirname  = path.dirname(fileURLToPath(import.meta.url));
const OUT_DIR    = path.resolve(__dirname, "..", "screenshots");
const VIEWPORT   = { width: 1920, height: 1200 };
const DEMO_EMAIL = process.env.FLK0S_DEMO_EMAIL    ?? "demo@flk0s.local";
const DEMO_PASS  = process.env.FLK0S_DEMO_PASSWORD ?? "FLK0S-demo-2026";

// (name, url, optional pre-login flow)
const SHOTS = [
  // — Logins
  { name: "login-cdp",              url: "http://localhost:3100/login",    auth: false },
  { name: "login-rt",               url: "http://localhost:3200/login",    auth: false },
  { name: "login-ai",               url: "http://localhost:3300/login",    auth: false },
  // — Hub
  { name: "hub-overview",           url: "http://localhost:3000/",         auth: false, waitFor: "h1, h2, [data-testid='kpi-grid']" },
  // — CDP
  { name: "cdp-dashboard",          url: "http://localhost:3100/dashboard",audience: "cdp" },
  { name: "cdp-alerts",             url: "http://localhost:3100/alerts",   audience: "cdp" },
  // — RT
  { name: "rt-dashboard",           url: "http://localhost:3200/dashboard",audience: "rt" },
  { name: "rt-campaigns",           url: "http://localhost:3200/campaigns",audience: "rt" },
  // — AI
  { name: "ai-copilot",             url: "http://localhost:3300/copilot",  audience: "airt" },
  // — Reportes
  { name: "reportes-engagements",   url: "http://localhost:3400/engagements", audience: "reporter" },
  // — Observabilidad
  { name: "grafana-overview",       url: "http://localhost:3001/",         auth: false },
];

const args   = new Set(process.argv.slice(2).flatMap(a => a.startsWith("--only=") ? a.slice(7).split(",") : []));
const filter = args.size ? (s) => [...args].some(t => s.name.includes(t)) : () => true;

async function loginViaSdk(page, audience) {
  // Ejecuta fetch en el contexto de la app — la app guarda el access en su sessionStorage.
  await page.evaluate(async ({ audience, email, password }) => {
    const r = await fetch("http://localhost:8000/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: "include",
      body: JSON.stringify({ email, password, audience }),
    });
    if (!r.ok) throw new Error(`login failed: ${r.status}`);
    const { access_token } = await r.json();
    sessionStorage.setItem("flk0s_access_token", access_token);
    // Algunas apps usan otras keys — best-effort
    sessionStorage.setItem("access_token", access_token);
    localStorage.setItem("flk0s_access_token", access_token);
  }, { audience, email: DEMO_EMAIL, password: DEMO_PASS });
}

async function capture(browser, shot) {
  const ctx  = await browser.newContext({ viewport: VIEWPORT });
  const page = await ctx.newPage();
  try {
    if (shot.audit) {
      // pre-login en el origin de la app antes de navegar a la ruta protegida
      await page.goto(shot.url.replace(/\/[^/]*$/, "/"), { waitUntil: "domcontentloaded", timeout: 30_000 });
      await loginViaSdk(page, `flk0s:${shot.audit}`);
    }
    await page.goto(shot.url, { waitUntil: "networkidle", timeout: 45_000 });
    if (shot.waitFor) {
      await page.waitForSelector(shot.waitFor, { timeout: 8_000 }).catch(() => {});
    }
    await page.waitForTimeout(800); // dejar que Framer Motion termine
    const out = path.join(OUT_DIR, `${shot.name}.png`);
    await page.screenshot({ path: out, fullPage: false });
    console.log(`  ✓ ${shot.name.padEnd(28)} → ${path.relative(process.cwd(), out)}`);
  } catch (e) {
    console.log(`  ✗ ${shot.name.padEnd(28)} → ${e.message?.slice(0, 80) ?? e}`);
  } finally {
    await ctx.close();
  }
}

(async () => {
  console.log("\nFLK0S · Screenshot capture");
  console.log("=".repeat(60));
  await fs.mkdir(OUT_DIR, { recursive: true });

  const browser = await chromium.launch({ headless: true });
  try {
    for (const shot of SHOTS.filter(filter)) {
      await capture(browser, shot);
    }
  } finally {
    await browser.close();
  }
  console.log("=".repeat(60));
  console.log(`Output: ${OUT_DIR}`);
})();
