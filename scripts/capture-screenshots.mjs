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

import { chromium, request as pwRequest } from "playwright";
import path from "node:path";
import fs from "node:fs/promises";
import { fileURLToPath } from "node:url";

const __dirname  = path.dirname(fileURLToPath(import.meta.url));
const OUT_DIR    = path.resolve(__dirname, "..", "screenshots");
const VIEWPORT   = { width: 1920, height: 1200 };
const DEMO_EMAIL = process.env.FLK0S_DEMO_EMAIL    ?? "demo@flk0s.local";
const DEMO_PASS  = process.env.FLK0S_DEMO_PASSWORD ?? "FLK0S-demo-2026";

// (name, url, optional pre-login flow)
// fullPage:true → captura la página completa con scroll (sirve para mostrar
//   el EcosystemSwitcher que en logins queda debajo del fold).
const SHOTS = [
  // — Logins (fullPage para incluir EcosystemSwitcher)
  { name: "login-cdp",              url: "http://localhost:3100/login",    auth: false, fullPage: true },
  { name: "login-rt",               url: "http://localhost:3200/login",    auth: false, fullPage: true },
  { name: "login-ai",               url: "http://localhost:3300/login",    auth: false, fullPage: true },
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

async function fetchGatewayToken(audience) {
  // Login fuera del page context (sin CORS) — Playwright APIRequest.
  const ctx = await pwRequest.newContext();
  try {
    const r = await ctx.post("http://localhost:8000/auth/login", {
      data: { email: DEMO_EMAIL, password: DEMO_PASS, audience },
    });
    if (!r.ok()) throw new Error(`login failed: ${r.status()}`);
    const { access_token } = await r.json();
    return access_token;
  } finally {
    await ctx.dispose();
  }
}

async function injectToken(page, accessToken, email) {
  // Siembra el token en TODAS las storages que las apps consultan, y marca
  // los onboarding tours como ya vistos para que no tapen los screenshots.
  await page.evaluate(({ accessToken, email }) => {
    sessionStorage.setItem("flk0s_access_token", accessToken);
    sessionStorage.setItem("access_token", accessToken);
    localStorage.setItem("flk0s_access_token", accessToken);

    // CDP — zustand persist "cyberia-auth"
    localStorage.setItem("cyberia-auth", JSON.stringify({
      state: { accessToken, refreshToken: null, email },
      version: 0,
    }));

    // RT — cookie + localStorage
    document.cookie = `flk0s_rt_token=${accessToken}; path=/; max-age=${60 * 60 * 4}`;
    localStorage.setItem("flk0s_rt_token", accessToken);

    // Onboarding tours seen — patrones comunes (intercom-style, driver.js,
    // react-joyride, custom). Best-effort: si la app no usa esa key, ignora.
    const tourKeys = [
      "flk0s-onboarding-seen", "onboarding-seen", "onboarding-done",
      "tour-seen", "tour-done", "tour-completed",
      "flk0s-cdp-onboarding", "flk0s-rt-onboarding",
      "flk0s-reporter-onboarding", "flk0s-ai-onboarding",
      "intro-seen", "first-visit", "welcome-tour-done",
    ];
    for (const k of tourKeys) {
      localStorage.setItem(k, "true");
    }
  }, { accessToken, email });
}

async function dismissModals(page) {
  // Estrategia conservadora — sólo botones que SEAN onboarding inequívoco
  // (texto "Saltar tour" o data-testid específico). Evitamos selectores
  // genéricos como "Saltar"/"Skip" porque pueden matchear otros elementos.
  await page.keyboard.press("Escape").catch(() => {});
  await page.waitForTimeout(150);
  const skipSelectors = [
    "button:has-text('Saltar tour')",
    "button:has-text('Skip tour')",
    "[data-testid='skip-tour']",
    "[data-testid='close-onboarding']",
  ];
  for (const sel of skipSelectors) {
    const btn = page.locator(sel).first();
    if (await btn.count().catch(() => 0)) {
      await btn.click({ timeout: 800 }).catch(() => {});
      await page.waitForTimeout(200);
    }
  }
}

async function capture(browser, shot) {
  const ctx  = await browser.newContext({ viewport: VIEWPORT });
  const page = await ctx.newPage();
  try {
    if (shot.audience) {
      // 1) login fuera del page (sin CORS) y 2) navega al origin para inyectar
      const token = await fetchGatewayToken(`flk0s:${shot.audience}`);
      await page.goto(shot.url.replace(/\/[^/]*$/, "/"), { waitUntil: "domcontentloaded", timeout: 30_000 });
      await injectToken(page, token, DEMO_EMAIL);
    }
    await page.goto(shot.url, { waitUntil: "networkidle", timeout: 45_000 });
    if (shot.waitFor) {
      await page.waitForSelector(shot.waitFor, { timeout: 8_000 }).catch(() => {});
    }
    await page.waitForTimeout(800); // dejar que Framer Motion termine
    await dismissModals(page);
    await page.waitForTimeout(400);
    const out = path.join(OUT_DIR, `${shot.name}.png`);
    await page.screenshot({ path: out, fullPage: shot.fullPage === true });
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
