"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const http = require("node:http");
const path = require("node:path");
const { WebSocketServer, WebSocket } = require("ws");
const { createStore } = require("./db");
const { adminPanelHtml } = require("./admin_ui");

/** @type {Array<{ code: string, ar: string, en: string, arNorm: string, enNorm: string }>} */
let cardIndex = [];
function normalizeCardSearchText(value) {
  if (typeof value !== "string") return "";
  return value
    .replace(/[\u064B-\u065F\u0670\u0640]/g, "")
    .replace(/[أإآٱ]/g, "ا")
    .replace(/ة/g, "ه")
    .replace(/ى/g, "ي")
    .replace(/^بطاقه\s+|^بطاقة\s+|^كارت\s+/i, "")
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase();
}

try {
  const idxPath = path.join(__dirname, "card_index.json");
  if (fs.existsSync(idxPath)) {
    const raw = JSON.parse(fs.readFileSync(idxPath, "utf8"));
    if (Array.isArray(raw)) {
      cardIndex = raw.map((row) => ({
        code: String(row[0] || ""),
        ar: String(row[1] || ""),
        en: String(row[2] || ""),
        arNorm: normalizeCardSearchText(String(row[1] || "")),
        enNorm: normalizeCardSearchText(String(row[2] || ""))
      }));
    }
  }
} catch {
  cardIndex = [];
}

function resolveCardInput(rawValue) {
  const raw = typeof rawValue === "number" ? String(rawValue) : (typeof rawValue === "string" ? rawValue.trim() : "");
  if (!raw) return null;
  const asciiDigits = raw
    .replace(/[\u0660-\u0669]/g, (ch) => String(ch.charCodeAt(0) - 0x0660))
    .replace(/[\u06F0-\u06F9]/g, (ch) => String(ch.charCodeAt(0) - 0x06F0))
    .trim();
  const stripped = asciiDigits.replace(/^(CARD-|POC-|#)/i, "").trim();
  if (/^[0-9]{1,12}$/.test(stripped)) {
    const padded = stripped.length <= 8 ? stripped.padStart(8, "0") : stripped;
    const hit = cardIndex.find((c) => c.code === stripped || c.code === padded);
    return {
      cardCode: hit ? hit.code : stripped,
      cardLabel: hit ? (hit.ar || hit.en) : ""
    };
  }
  const needle = normalizeCardSearchText(raw);
  if (!needle) return null;
  let exact = cardIndex.find((c) => c.arNorm === needle || c.enNorm === needle);
  if (exact) return { cardCode: exact.code, cardLabel: exact.ar || exact.en };
  const matches = cardIndex.filter((c) => c.arNorm.includes(needle) || c.enNorm.includes(needle));
  if (matches.length > 0) {
    matches.sort((a, b) => {
      const aStarts = a.arNorm.startsWith(needle) || a.enNorm.startsWith(needle) ? 0 : 1;
      const bStarts = b.arNorm.startsWith(needle) || b.enNorm.startsWith(needle) ? 0 : 1;
      if (aStarts !== bStarts) return aStarts - bStarts;
      return (a.arNorm.length || 999) - (b.arNorm.length || 999);
    });
    return { cardCode: matches[0].code, cardLabel: matches[0].ar || matches[0].en };
  }
  if (/^[0-9A-Za-z]{1,24}$/.test(stripped)) {
    return { cardCode: stripped, cardLabel: "" };
  }
  return null;
}

function searchCards(query, limit = 12) {
  const raw = String(query || "").trim();
  if (!raw) return [];
  const asciiDigits = raw
    .replace(/[\u0660-\u0669]/g, (ch) => String(ch.charCodeAt(0) - 0x0660))
    .replace(/[\u06F0-\u06F9]/g, (ch) => String(ch.charCodeAt(0) - 0x06F0))
    .trim();
  const needle = normalizeCardSearchText(raw);
  const out = [];
  for (const c of cardIndex) {
    if (
      c.code.includes(asciiDigits) ||
      (needle && (c.arNorm.includes(needle) || c.enNorm.includes(needle)))
    ) {
      out.push({ code: c.code, ar: c.ar, en: c.en });
    }
  }
  out.sort((a, b) => {
    const aNorm = normalizeCardSearchText(a.ar);
    const bNorm = normalizeCardSearchText(b.ar);
    const aExact = a.code === asciiDigits || aNorm === needle || normalizeCardSearchText(a.en) === needle ? 0 : 1;
    const bExact = b.code === asciiDigits || bNorm === needle || normalizeCardSearchText(b.en) === needle ? 0 : 1;
    if (aExact !== bExact) return aExact - bExact;
    const aStarts = aNorm.startsWith(needle) || normalizeCardSearchText(a.en).startsWith(needle) ? 0 : 1;
    const bStarts = bNorm.startsWith(needle) || normalizeCardSearchText(b.en).startsWith(needle) ? 0 : 1;
    if (aStarts !== bStarts) return aStarts - bStarts;
    return a.ar.length - b.ar.length;
  });
  return out.slice(0, limit);
}

const PORT = Number.parseInt(process.env.PORT || "10000", 10);
const MAX_ROOMS = Number.parseInt(process.env.MAX_ROOMS || "2000", 10);
const MAX_PACKET_BYTES = 64 * 1024;
const MAX_JSON_BODY_BYTES = 128 * 1024;
const WAITING_ROOM_TTL_MS = 15 * 60 * 1000;
const HEARTBEAT_MS = 15 * 1000;
const CLEANUP_INTERVAL_MS = 60 * 1000;
const TOKEN_TTL_MS = 90 * 24 * 60 * 60 * 1000;
const ADMIN_TOKEN_TTL_MS = 12 * 60 * 60 * 1000;
const GOOGLE_STATE_TTL_MS = 10 * 60 * 1000;

let sessionSecret = (process.env.SESSION_SECRET || "").trim();
const ADMIN_PASSCODE = (
  process.env.ADMIN_PASSCODE ||
  process.env.ADMIN_PASSWORD ||
  process.env.ADMIN_CODE ||
  ""
).trim();
const GOOGLE_CLIENT_ID = (process.env.GOOGLE_CLIENT_ID || "").trim();
const GOOGLE_CLIENT_SECRET = (process.env.GOOGLE_CLIENT_SECRET || "").trim();
const PUBLIC_BASE_URL = (
  process.env.PUBLIC_BASE_URL ||
  process.env.RENDER_EXTERNAL_URL ||
  "https://poc-online-relay.onrender.com"
).trim().replace(/\/+$/, "");

/** @type {Map<string, any>} */
const rooms = new Map();
/** @type {Map<string, Set<WebSocket>>} */
const onlineSockets = new Map();
/** @type {Set<string>} */
const VALID_GAMES = new Set(["yugi", "kaiba", "joey"]);
/** @type {Record<string, Array<{ ws: WebSocket, playerId: string, displayName: string, joinedAt: number }>>} */
const matchmakingQueues = {
  "competitive:yugi": [],
  "competitive:kaiba": [],
  "competitive:joey": [],
  "sandbox:yugi": [],
  "sandbox:kaiba": [],
  "sandbox:joey": []
};
/** @type {Map<string, { status: string, createdAt: number, upgradePlayerId: string | null, token?: string, player?: any, message?: string }>} */
const googleStates = new Map();
/** @type {Map<string, number[]>} */
const authRateWindow = new Map();

let store = null;

function googleAuthEnabled() {
  return Boolean(GOOGLE_CLIENT_ID && GOOGLE_CLIENT_SECRET);
}

function sanitizeDisplayName(value) {
  if (typeof value !== "string") return "";
  return value.replace(/[\r\n\t\u0000-\u001f]+/g, " ").trim().slice(0, 24);
}

function sanitizeChatBody(value) {
  if (typeof value !== "string") return "";
  return value.replace(/[\r\n\t\u0000-\u001f]+/g, " ").trim().slice(0, 400);
}

function sanitizeUsername(value) {
  if (typeof value !== "string") return "";
  const cleaned = value.trim().toLowerCase();
  if (!/^[a-z0-9_.-]{3,24}$/.test(cleaned)) return "";
  return cleaned;
}

function normalizeCode(value) {
  if (typeof value !== "string") return "";
  const asciiDigits = value
    .replace(/[\u0660-\u0669]/g, (ch) => String(ch.charCodeAt(0) - 0x0660))
    .replace(/[\u06F0-\u06F9]/g, (ch) => String(ch.charCodeAt(0) - 0x06F0));
  return asciiDigits.replace(/[^0-9A-Za-z]/g, "").toUpperCase().slice(0, 12);
}

function safeDecodeUri(value) {
  try {
    return decodeURIComponent(value);
  } catch {
    return "";
  }
}

function normalizeGiftCode(value) {
  if (typeof value !== "string") return "";
  const asciiDigits = value
    .replace(/[\u0660-\u0669]/g, (ch) => String(ch.charCodeAt(0) - 0x0660))
    .replace(/[\u06F0-\u06F9]/g, (ch) => String(ch.charCodeAt(0) - 0x06F0));
  const cleaned = asciiDigits.trim().toUpperCase().replace(/\s+/g, "");
  if (!/^[A-Z0-9][A-Z0-9_-]{2,31}$/.test(cleaned)) return "";
  return cleaned;
}

function sanitizeCardCode(value) {
  if (typeof value !== "string" && typeof value !== "number") return "";
  const asciiDigits = String(value)
    .replace(/[\u0660-\u0669]/g, (ch) => String(ch.charCodeAt(0) - 0x0660))
    .replace(/[\u06F0-\u06F9]/g, (ch) => String(ch.charCodeAt(0) - 0x06F0))
    .trim();
  const stripped = asciiDigits.replace(/^(CARD-|POC-|#)/i, "").trim();
  if (!/^[0-9A-Za-z]{1,24}$/.test(stripped)) return "";
  return stripped;
}

function sanitizeCardLabel(value) {
  if (typeof value !== "string") return "";
  return value.replace(/[\r\n\t\u0000-\u001f]+/g, " ").trim().slice(0, 64);
}

function sanitizeCollection(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return {};
  const out = {};
  let keys = 0;
  for (const [k, v] of Object.entries(raw)) {
    if (keys >= 2000) break;
    const id = Number.parseInt(k, 10);
    const count = Number.parseInt(String(v), 10);
    if (Number.isInteger(id) && id >= 1 && id <= 9999 && Number.isInteger(count) && count >= 1 && count <= 99) {
      out[String(id)] = count;
      keys += 1;
    }
  }
  return out;
}

function sanitizeStats(raw, collection) {
  const nonNeg = (v) => {
    const n = Number.parseInt(String(v || 0), 10);
    return Number.isFinite(n) && n >= 0 && n <= 1000000 ? n : 0;
  };
  let totalCards = 0;
  const uniqueCards = Object.keys(collection).length;
  for (const c of Object.values(collection)) totalCards += c;
  const s = raw && typeof raw === "object" ? raw : {};
  const lastGame = typeof s.last_game === "string" && ["yugi", "kaiba", "joey"].includes(s.last_game) ? s.last_game : "joey";
  return {
    wins: nonNeg(s.wins),
    losses: nonNeg(s.losses),
    draws: nonNeg(s.draws),
    total_cards: totalCards,
    unique_cards: uniqueCards,
    monsters: nonNeg(s.monsters),
    spells: nonNeg(s.spells),
    traps: nonNeg(s.traps),
    last_game: lastGame
  };
}

function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString("hex");
  const derived = crypto.scryptSync(password, salt, 64).toString("hex");
  return `${salt}:${derived}`;
}

function verifyPassword(password, stored) {
  if (typeof stored !== "string" || !stored.includes(":")) return false;
  const [salt, expectedHex] = stored.split(":");
  if (!salt || !expectedHex) return false;
  try {
    const actual = crypto.scryptSync(password, salt, 64);
    const expected = Buffer.from(expectedHex, "hex");
    if (actual.length !== expected.length) return false;
    return crypto.timingSafeEqual(actual, expected);
  } catch {
    return false;
  }
}

function signToken(playerId) {
  const payload = Buffer.from(
    JSON.stringify({ sub: playerId, exp: Date.now() + TOKEN_TTL_MS }),
    "utf8"
  ).toString("base64url");
  const sig = crypto.createHmac("sha256", sessionSecret).update(payload).digest("base64url");
  return `v1.${payload}.${sig}`;
}

function verifyToken(token) {
  if (typeof token !== "string") return null;
  const parts = token.trim().split(".");
  if (parts.length !== 3 || parts[0] !== "v1") return null;
  const [, payload, sig] = parts;
  const expected = crypto.createHmac("sha256", sessionSecret).update(payload).digest("base64url");
  const a = Buffer.from(sig);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;
  try {
    const data = JSON.parse(Buffer.from(payload, "base64url").toString("utf8"));
    if (!data || typeof data.sub !== "string" || typeof data.exp !== "number" || data.exp < Date.now()) {
      return null;
    }
    return data.sub;
  } catch {
    return null;
  }
}

function signAdminToken() {
  const payload = Buffer.from(
    JSON.stringify({ role: "admin", exp: Date.now() + ADMIN_TOKEN_TTL_MS }),
    "utf8"
  ).toString("base64url");
  const sig = crypto.createHmac("sha256", sessionSecret).update("admin." + payload).digest("base64url");
  return `v1a.${payload}.${sig}`;
}

function verifyAdminToken(token) {
  if (typeof token !== "string") return false;
  const parts = token.trim().split(".");
  if (parts.length !== 3 || parts[0] !== "v1a") return false;
  const [, payload, sig] = parts;
  const expected = crypto.createHmac("sha256", sessionSecret).update("admin." + payload).digest("base64url");
  const a = Buffer.from(sig);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return false;
  try {
    const data = JSON.parse(Buffer.from(payload, "base64url").toString("utf8"));
    return Boolean(data && data.role === "admin" && typeof data.exp === "number" && data.exp >= Date.now());
  } catch {
    return false;
  }
}

function requireAdmin(req) {
  const auth = String(req.headers.authorization || "");
  if (!auth.startsWith("Bearer ")) return false;
  return verifyAdminToken(auth.slice(7));
}

async function getAdminConfigStatus() {
  if (ADMIN_PASSCODE.length > 0) {
    return { configured: true, source: "env" };
  }
  const stored = await store.getMeta("admin_passcode_hash");
  return { configured: Boolean(stored), source: stored ? "setup" : "none" };
}

async function verifyAdminPasscode(passcode) {
  if (typeof passcode !== "string") return false;
  const trimmed = passcode.trim();
  if (trimmed.length === 0) return false;
  if (ADMIN_PASSCODE.length > 0) {
    const a = crypto.createHash("sha256").update(trimmed, "utf8").digest();
    const b = crypto.createHash("sha256").update(ADMIN_PASSCODE, "utf8").digest();
    return crypto.timingSafeEqual(a, b);
  }
  const stored = await store.getMeta("admin_passcode_hash");
  if (!stored) return false;
  return verifyPassword(trimmed, stored) || verifyPassword(passcode, stored);
}

function isOnline(playerId) {
  const set = onlineSockets.get(playerId);
  return Boolean(set && set.size > 0);
}

function pushToPlayer(playerId, payload) {
  const set = onlineSockets.get(playerId);
  if (!set) return false;
  const text = JSON.stringify(payload);
  let delivered = false;
  for (const ws of set) {
    if (ws.readyState === WebSocket.OPEN) {
      try {
        ws.send(text);
        delivered = true;
      } catch {
        // Ignore send errors.
      }
    }
  }
  return delivered;
}

function broadcastPresence(payload) {
  const text = JSON.stringify(payload);
  for (const set of onlineSockets.values()) {
    for (const ws of set) {
      if (ws.readyState === WebSocket.OPEN) {
        try {
          ws.send(text);
        } catch {
          // Ignore send errors.
        }
      }
    }
  }
}

function normalizePool(raw) {
  const p = typeof raw === "string" ? raw.trim().toLowerCase() : "";
  return p === "sandbox" ? "sandbox" : "competitive";
}

function resolveEffectivePool(player, requestedPool) {
  const raw = typeof requestedPool === "string" ? requestedPool.trim().toLowerCase() : "";
  const unlocked = Boolean(player && player.allCardsUnlocked);
  if (unlocked) {
    if (raw === "competitive") {
      return { ok: false, error: "unlocked_account_sandbox_only", pool: "sandbox" };
    }
    return { ok: true, pool: "sandbox" };
  }
  return { ok: true, pool: raw === "sandbox" ? "sandbox" : "competitive" };
}

function publicPlayerSummary(player, includeCollection = false, friendStatus = "none") {
  const out = {
    playerId: player.playerId,
    displayName: player.displayName,
    username: player.username || "",
    authProvider: player.authProvider || "guest",
    avatarUrl: player.avatarUrl || "",
    online: isOnline(player.playerId),
    allCardsUnlocked: Boolean(player.allCardsUnlocked),
    stats: player.stats || {},
    lastSeenAt: player.lastSeenAt || 0,
    friendStatus
  };
  if (includeCollection) {
    out.collection = player.collection || {};
  }
  return out;
}

function checkRateLimit(req) {
  const ip = String(req.headers["x-forwarded-for"] || req.socket.remoteAddress || "unknown").split(",")[0].trim();
  const now = Date.now();
  const windowMs = 5 * 60 * 1000;
  const entries = (authRateWindow.get(ip) || []).filter((t) => now - t < windowMs);
  if (entries.length >= 40) {
    authRateWindow.set(ip, entries);
    return false;
  }
  entries.push(now);
  authRateWindow.set(ip, entries);
  return true;
}

function writeJson(res, status, payload) {
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff"
  });
  res.end(JSON.stringify(payload));
}

function readJsonBody(req) {
  return new Promise((resolve, reject) => {
    let bytes = 0;
    const chunks = [];
    req.on("data", (chunk) => {
      bytes += chunk.length;
      if (bytes > MAX_JSON_BODY_BYTES) {
        reject(new Error("BODY_TOO_LARGE"));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => {
      if (chunks.length === 0) {
        resolve({});
        return;
      }
      try {
        const parsed = JSON.parse(Buffer.concat(chunks).toString("utf8"));
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
          reject(new Error("INVALID_JSON"));
          return;
        }
        resolve(parsed);
      } catch {
        reject(new Error("INVALID_JSON"));
      }
    });
    req.on("error", reject);
  });
}

async function authenticateRequest(req) {
  const auth = String(req.headers.authorization || "");
  if (!auth.startsWith("Bearer ")) return null;
  const playerId = verifyToken(auth.slice(7));
  if (!playerId) return null;
  return store.getPlayerById(playerId);
}

async function computeFriendStatus(viewerId, targetId, friendSet, incomingSet, outgoingSet) {
  if (viewerId === targetId) return "self";
  if (friendSet.has(targetId)) return "friend";
  if (incomingSet.has(targetId)) return "incoming";
  if (outgoingSet.has(targetId)) return "outgoing";
  return "none";
}

function generateRoomCode() {
  for (let i = 0; i < 64; i += 1) {
    const code = String(crypto.randomInt(100000, 1000000));
    if (!rooms.has(code)) return code;
  }
  return null;
}

function sendWsJson(ws, payload) {
  if (!ws || ws.readyState !== WebSocket.OPEN) return;
  try {
    ws.send(JSON.stringify(payload));
  } catch {
    // Handled on close.
  }
}

function leaveRoom(ws, reason) {
  const code = ws._roomCode;
  if (!code) return;
  ws._roomCode = null;
  const role = ws._role;
  ws._role = null;

  const room = rooms.get(code);
  if (!room) return;

  const other = role === "host" ? room.guest : room.host;
  rooms.delete(code);

  if (other && other !== ws) {
    other._roomCode = null;
    other._role = null;
    if (other.readyState === WebSocket.OPEN) {
      sendWsJson(other, { type: "peer_left", reason: reason || "disconnected" });
    }
  }
}

function removeFromMatchmaking(ws) {
  for (const game of Object.keys(matchmakingQueues)) {
    const q = matchmakingQueues[game];
    const idx = q.findIndex((entry) => entry.ws === ws);
    if (idx !== -1) {
      q.splice(idx, 1);
    }
  }
  ws._matchmakingGame = null;
}

function leavePresence(ws) {
  removeFromMatchmaking(ws);
  const pid = ws._presenceId;
  if (!pid) return;
  ws._presenceId = null;
  const set = onlineSockets.get(pid);
  if (set) {
    set.delete(ws);
    if (set.size === 0) {
      onlineSockets.delete(pid);
    }
  }
}

function getBaseUrl(req) {
  if (
    (process.env.PUBLIC_BASE_URL && process.env.PUBLIC_BASE_URL.trim()) ||
    (process.env.RENDER_EXTERNAL_URL && process.env.RENDER_EXTERNAL_URL.trim())
  ) {
    return PUBLIC_BASE_URL;
  }
  const proto = String(req.headers["x-forwarded-proto"] || "http").split(",")[0].trim();
  const host = String(req.headers["x-forwarded-host"] || req.headers.host || `localhost:${PORT}`).split(",")[0].trim();
  return `${proto}://${host}`;
}

function staticAuthHtml(ok) {
  const title = ok ? "Power of Chaos Online" : "Sign-in Error";
  const heading = ok
    ? "تم تسجيل الدخول بنجاح! / Signed in successfully!"
    : "تعذر إتمام تسجيل الدخول / Sign-in could not be completed";
  const body = ok
    ? "يمكنك إغلاق هذه الصفحة والعودة مباشرة إلى اللعبة الآن.<br/>You can close this tab and return to the game now."
    : "يرجى العودة إلى اللعبة والمحاولة مرة أخرى.<br/>Please return to the game and try again.";
  const script = ok ? "<script>setTimeout(function(){try{window.close();}catch(e){}},450);</script>" : "";
  return `<!doctype html><html lang="ar"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title><style>body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:#0d0914;color:#f7e4b2;font-family:system-ui,sans-serif;text-align:center;padding:24px}.card{max-width:440px;border:2px solid #d4a63a;border-radius:14px;padding:28px;background:#161020}h1{color:#ffd257;font-size:20px;margin:0 0 12px}p{line-height:1.7;margin:0;color:#efe0bc}</style></head><body><div class="card"><h1>${heading}</h1><p>${body}</p></div>${script}</body></html>`;
}

async function handleHttp(req, res) {
  const parsedUrl = new URL(req.url || "/", `http://${req.headers.host || "localhost"}`);
  const pathname = parsedUrl.pathname;

  try {
    if (req.method === "GET" && (pathname === "/" || pathname === "/health")) {
      let duelPlayers = 0;
      for (const room of rooms.values()) duelPlayers += (room.host ? 1 : 0) + (room.guest ? 1 : 0);
      const totalAccounts = await store.countPlayers();
      const adminStatus = await getAdminConfigStatus();
      writeJson(res, 200, {
        ok: true,
        service: "poc-online-relay",
        version: "2.3.0",
        storage: store.kind,
        googleAuthEnabled: googleAuthEnabled(),
        giftCodesEnabled: true,
        adminConfigured: adminStatus.configured,
        registeredPlayers: totalAccounts,
        onlinePlayers: onlineSockets.size,
        rooms: rooms.size,
        players: duelPlayers,
        uptimeSec: Math.floor(process.uptime())
      });
      return;
    }

    if (req.method === "GET" && pathname === "/api/config") {
      writeJson(res, 200, {
        ok: true,
        googleAuthEnabled: googleAuthEnabled(),
        storage: store.kind
      });
      return;
    }

    if (req.method === "POST" && pathname === "/api/auth/guest") {
      if (!checkRateLimit(req)) {
        writeJson(res, 429, { ok: false, error: "rate_limited" });
        return;
      }
      const body = await readJsonBody(req);
      const displayName = sanitizeDisplayName(body.displayName) || `Duelist ${crypto.randomInt(100, 999)}`;
      const player = await store.createPlayer({ displayName, authProvider: "guest" });
      const token = signToken(player.playerId);
      writeJson(res, 200, { ok: true, token, player: publicPlayerSummary(player, true, "self") });
      return;
    }

    if (req.method === "POST" && pathname === "/api/auth/register") {
      if (!checkRateLimit(req)) {
        writeJson(res, 429, { ok: false, error: "rate_limited" });
        return;
      }
      const body = await readJsonBody(req);
      const username = sanitizeUsername(body.username);
      const password = typeof body.password === "string" ? body.password : "";
      const displayName = sanitizeDisplayName(body.displayName) || username;
      if (!username) {
        writeJson(res, 400, { ok: false, error: "invalid_username" });
        return;
      }
      if (password.length < 6 || password.length > 72) {
        writeJson(res, 400, { ok: false, error: "invalid_password" });
        return;
      }
      const existing = await store.getPlayerByUsername(username);
      if (existing) {
        writeJson(res, 409, { ok: false, error: "username_taken" });
        return;
      }
      const passwordHash = hashPassword(password);
      let player = null;
      const upgradeId = typeof body.upgradeGuestToken === "string" ? verifyToken(body.upgradeGuestToken) : null;
      if (upgradeId) {
        const guest = await store.getPlayerById(upgradeId);
        if (guest && guest.authProvider === "guest" && !guest.username) {
          player = await store.upgradePlayerAccount(upgradeId, { username, passwordHash, displayName });
        }
      }
      if (!player) {
        player = await store.createPlayer({ username, displayName, passwordHash, authProvider: "account" });
      }
      const token = signToken(player.playerId);
      writeJson(res, 200, { ok: true, token, player: publicPlayerSummary(player, true, "self") });
      return;
    }

    if (req.method === "POST" && pathname === "/api/auth/login") {
      if (!checkRateLimit(req)) {
        writeJson(res, 429, { ok: false, error: "rate_limited" });
        return;
      }
      const body = await readJsonBody(req);
      const username = sanitizeUsername(body.username);
      const password = typeof body.password === "string" ? body.password : "";
      if (!username || !password) {
        writeJson(res, 400, { ok: false, error: "invalid_credentials" });
        return;
      }
      const player = await store.getPlayerByUsername(username);
      if (!player || !verifyPassword(password, player.passwordHash)) {
        writeJson(res, 401, { ok: false, error: "invalid_credentials" });
        return;
      }
      await store.touchLastSeen(player.playerId);
      const token = signToken(player.playerId);
      writeJson(res, 200, { ok: true, token, player: publicPlayerSummary(player, true, "self") });
      return;
    }

    if (req.method === "POST" && pathname === "/api/auth/google/start") {
      if (!checkRateLimit(req)) {
        writeJson(res, 429, { ok: false, error: "rate_limited" });
        return;
      }
      if (!googleAuthEnabled()) {
        writeJson(res, 503, { ok: false, error: "google_not_configured" });
        return;
      }
      const body = await readJsonBody(req);
      const upgradePlayerId = typeof body.upgradeGuestToken === "string" ? verifyToken(body.upgradeGuestToken) : null;
      const state = crypto.randomBytes(24).toString("base64url");
      googleStates.set(state, { status: "pending", createdAt: Date.now(), upgradePlayerId });
      const redirectUri = `${getBaseUrl(req)}/auth/google/callback`;
      const params = new URLSearchParams({
        client_id: GOOGLE_CLIENT_ID,
        redirect_uri: redirectUri,
        response_type: "code",
        scope: "openid email profile",
        state,
        prompt: "select_account"
      });
      writeJson(res, 200, {
        ok: true,
        state,
        authUrl: `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`
      });
      return;
    }

    if (req.method === "GET" && pathname === "/auth/google/callback") {
      const state = parsedUrl.searchParams.get("state") || "";
      const code = parsedUrl.searchParams.get("code") || "";
      const entry = googleStates.get(state);
      if (!entry || entry.status !== "pending" || !code || !googleAuthEnabled()) {
        res.writeHead(400, { "Content-Type": "text/html; charset=utf-8" });
        res.end(staticAuthHtml(false));
        return;
      }
      try {
        const redirectUri = `${getBaseUrl(req)}/auth/google/callback`;
        const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({
            code,
            client_id: GOOGLE_CLIENT_ID,
            client_secret: GOOGLE_CLIENT_SECRET,
            redirect_uri: redirectUri,
            grant_type: "authorization_code"
          }).toString()
        });
        const tokenJson = await tokenRes.json();
        if (!tokenRes.ok || !tokenJson.access_token) {
          throw new Error("token_exchange_failed");
        }
        const userRes = await fetch("https://www.googleapis.com/oauth2/v3/userinfo", {
          headers: { Authorization: `Bearer ${tokenJson.access_token}` }
        });
        const info = await userRes.json();
        if (!userRes.ok || !info.sub) {
          throw new Error("userinfo_failed");
        }
        const googleSub = String(info.sub);
        const email = typeof info.email === "string" ? info.email : null;
        const avatarUrl = typeof info.picture === "string" ? info.picture : "";
        const gName = sanitizeDisplayName(info.name || info.given_name || "Duelist") || "Duelist";

        let player = await store.getPlayerByGoogleSub(googleSub);
        if (!player && entry.upgradePlayerId) {
          const guest = await store.getPlayerById(entry.upgradePlayerId);
          if (guest && guest.authProvider === "guest" && !guest.googleSub) {
            player = await store.linkPlayerGoogle(guest.playerId, { googleSub, email, avatarUrl, displayName: gName });
          }
        }
        if (!player) {
          player = await store.createPlayer({
            displayName: gName,
            googleSub,
            email,
            avatarUrl,
            authProvider: "google"
          });
        } else {
          await store.touchLastSeen(player.playerId);
        }
        entry.status = "done";
        entry.token = signToken(player.playerId);
        entry.player = publicPlayerSummary(player, true, "self");
        res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
        res.end(staticAuthHtml(true));
      } catch {
        entry.status = "error";
        entry.message = "google_auth_failed";
        res.writeHead(500, { "Content-Type": "text/html; charset=utf-8" });
        res.end(staticAuthHtml(false));
      }
      return;
    }

    if (req.method === "GET" && pathname === "/api/auth/google/poll") {
      const state = parsedUrl.searchParams.get("state") || "";
      const entry = googleStates.get(state);
      if (!entry) {
        writeJson(res, 404, { ok: false, status: "expired" });
        return;
      }
      if (entry.status === "pending") {
        writeJson(res, 200, { ok: true, status: "pending" });
        return;
      }
      if (!entry.retrievedAt) entry.retrievedAt = Date.now();
      if (entry.status === "done") {
        writeJson(res, 200, { ok: true, status: "done", token: entry.token, player: entry.player });
        return;
      }
      writeJson(res, 400, { ok: false, status: "error", error: entry.message || "google_auth_failed" });
      return;
    }

    if (req.method === "GET" && (pathname === "/admin" || pathname === "/admin/")) {
      res.writeHead(200, {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "no-store",
        "X-Content-Type-Options": "nosniff",
        "X-Frame-Options": "DENY"
      });
      res.end(adminPanelHtml());
      return;
    }

    if (req.method === "GET" && pathname === "/api/admin/status") {
      const st = await getAdminConfigStatus();
      writeJson(res, 200, { ok: true, configured: st.configured, source: st.source });
      return;
    }

    if (req.method === "POST" && pathname === "/api/admin/setup") {
      if (!checkRateLimit(req)) {
        writeJson(res, 429, { ok: false, error: "rate_limited" });
        return;
      }
      const st = await getAdminConfigStatus();
      if (st.configured) {
        writeJson(res, 409, { ok: false, error: "already_configured" });
        return;
      }
      const body = await readJsonBody(req);
      const passcode = typeof body.passcode === "string" ? body.passcode : "";
      if (passcode.length < 8 || passcode.length > 128) {
        writeJson(res, 400, { ok: false, error: "invalid_passcode" });
        return;
      }
      const saved = await store.setMetaIfUnset("admin_passcode_hash", hashPassword(passcode));
      if (!saved) {
        writeJson(res, 409, { ok: false, error: "already_configured" });
        return;
      }
      writeJson(res, 200, { ok: true, token: signAdminToken() });
      return;
    }

    if (req.method === "POST" && pathname === "/api/admin/login") {
      if (!checkRateLimit(req)) {
        writeJson(res, 429, { ok: false, error: "rate_limited" });
        return;
      }
      const st = await getAdminConfigStatus();
      if (!st.configured) {
        writeJson(res, 503, { ok: false, error: "admin_not_configured" });
        return;
      }
      const body = await readJsonBody(req);
      const passcode = typeof body.passcode === "string" ? body.passcode : "";
      const valid = await verifyAdminPasscode(passcode);
      if (!valid) {
        writeJson(res, 401, { ok: false, error: "invalid_passcode" });
        return;
      }
      writeJson(res, 200, { ok: true, token: signAdminToken() });
      return;
    }

    if (req.method === "GET" && pathname === "/api/admin/cards/search") {
      if (!requireAdmin(req)) {
        writeJson(res, 401, { ok: false, error: "unauthorized" });
        return;
      }
      const q = (parsedUrl.searchParams.get("q") || "").trim().slice(0, 64);
      writeJson(res, 200, { ok: true, cards: searchCards(q, 12) });
      return;
    }

    if (pathname === "/api/admin/gift-codes" || pathname.startsWith("/api/admin/gift-codes/")) {
      if (!requireAdmin(req)) {
        writeJson(res, 401, { ok: false, error: "unauthorized" });
        return;
      }

      if (req.method === "GET" && pathname === "/api/admin/gift-codes") {
        const giftCodes = await store.listGiftCodes();
        writeJson(res, 200, { ok: true, giftCodes });
        return;
      }

      if (req.method === "POST" && pathname === "/api/admin/gift-codes") {
        const body = await readJsonBody(req);
        const code = normalizeGiftCode(body.code);
        const maxUses = Number.parseInt(String(body.maxUses ?? 10), 10);
        const expiresAtRaw = body.expiresAt;
        let expiresAt = null;
        if (expiresAtRaw !== undefined && expiresAtRaw !== null && expiresAtRaw !== "") {
          const parsedExp = Number(expiresAtRaw);
          if (!Number.isFinite(parsedExp) || parsedExp <= Date.now()) {
            writeJson(res, 400, { ok: false, error: "invalid_expires_at" });
            return;
          }
          expiresAt = Math.floor(parsedExp);
        }
        if (!code) {
          writeJson(res, 400, { ok: false, error: "invalid_code" });
          return;
        }
        if (!Number.isInteger(maxUses) || maxUses < 1 || maxUses > 100000) {
          writeJson(res, 400, { ok: false, error: "invalid_max_uses" });
          return;
        }

        const requestedType = String(body.rewardType || "").trim().toLowerCase();
        const isUnlockAll = requestedType === "unlock_all";
        const isDeck = !isUnlockAll && (requestedType === "deck" || (Array.isArray(body.cards) && body.cards.length > 0));

        let rewardType = "card";
        let cardCode = "";
        let cardLabel = "";
        let copies = 1;
        let sanitizedCards = [];

        if (isUnlockAll) {
          rewardType = "unlock_all";
          cardCode = "ALL";
          cardLabel = sanitizeCardLabel(body.cardLabel || "فتح كل البطاقات");
          copies = 3;
          sanitizedCards = [];
        } else if (isDeck) {
          if (!Array.isArray(body.cards) || body.cards.length === 0 || body.cards.length > 120) {
            writeJson(res, 400, { ok: false, error: "invalid_deck_cards" });
            return;
          }
          const allowedZones = new Set(["main", "side", "fusion"]);
          let totalCopies = 0;
          for (const entry of body.cards) {
            const rawCard = typeof entry === "string"
              ? entry
              : (entry && typeof entry === "object" ? entry.cardCode : "");
            const resolved = resolveCardInput(rawCard);
            const cc = resolved ? sanitizeCardCode(resolved.cardCode) : "";
            if (!cc) {
              writeJson(res, 400, { ok: false, error: "invalid_card_code" });
              return;
            }
            const rawCopies = entry && typeof entry === "object" ? entry.copies : 1;
            const cp = Number.parseInt(String(rawCopies ?? 1), 10);
            if (!Number.isInteger(cp) || cp < 1 || cp > 3) {
              writeJson(res, 400, { ok: false, error: "invalid_copies" });
              return;
            }
            totalCopies += cp;
            if (totalCopies > 150) {
              writeJson(res, 400, { ok: false, error: "deck_too_large" });
              return;
            }
            const rawZone = entry && typeof entry === "object" ? String(entry.zone || "main").toLowerCase() : "main";
            const zone = allowedZones.has(rawZone) ? rawZone : "main";
            const rawLbl = entry && typeof entry === "object" && entry.cardLabel ? entry.cardLabel : (resolved ? resolved.cardLabel : "");
            sanitizedCards.push({
              cardCode: cc,
              cardLabel: sanitizeCardLabel(rawLbl),
              copies: cp,
              zone
            });
          }
          rewardType = "deck";
          cardCode = sanitizedCards[0].cardCode;
          cardLabel = sanitizeCardLabel(body.cardLabel || body.deckName || "مجموعة هدية");
          copies = 1;
        } else {
          const resolved = resolveCardInput(body.cardCode);
          cardCode = resolved ? sanitizeCardCode(resolved.cardCode) : "";
          cardLabel = sanitizeCardLabel(body.cardLabel || (resolved ? resolved.cardLabel : ""));
          copies = Number.parseInt(String(body.copies ?? 1), 10);
          if (!cardCode) {
            writeJson(res, 400, { ok: false, error: "invalid_card_code" });
            return;
          }
          if (!Number.isInteger(copies) || copies < 1 || copies > 3) {
            writeJson(res, 400, { ok: false, error: "invalid_copies" });
            return;
          }
        }

        const created = await store.createGiftCode({
          code,
          rewardType,
          cardCode,
          cardLabel,
          copies,
          cards: sanitizedCards,
          maxUses,
          active: true,
          expiresAt
        });
        if (!created) {
          writeJson(res, 409, { ok: false, error: "code_exists" });
          return;
        }
        writeJson(res, 201, { ok: true, giftCode: created });
        return;
      }

      const redemptionsMatch = pathname.match(/^\/api\/admin\/gift-codes\/([^/]+)\/redemptions$/);
      if (req.method === "GET" && redemptionsMatch) {
        const code = normalizeGiftCode(safeDecodeUri(redemptionsMatch[1]));
        if (!code) {
          writeJson(res, 400, { ok: false, error: "invalid_code" });
          return;
        }
        const redemptions = await store.listGiftCodeRedemptions(code, 100);
        writeJson(res, 200, { ok: true, redemptions });
        return;
      }

      const itemMatch = pathname.match(/^\/api\/admin\/gift-codes\/([^/]+)$/);
      if (itemMatch) {
        const code = normalizeGiftCode(safeDecodeUri(itemMatch[1]));
        if (!code) {
          writeJson(res, 400, { ok: false, error: "invalid_code" });
          return;
        }
        if (req.method === "PATCH") {
          const body = await readJsonBody(req);
          const patch = {};
          if (typeof body.active === "boolean") patch.active = body.active;
          if (body.maxUses !== undefined) {
            const mu = Number.parseInt(String(body.maxUses), 10);
            if (!Number.isInteger(mu) || mu < 1 || mu > 100000) {
              writeJson(res, 400, { ok: false, error: "invalid_max_uses" });
              return;
            }
            patch.maxUses = mu;
          }
          if (body.cardCode !== undefined) {
            const resolved = resolveCardInput(body.cardCode);
            const cc = resolved ? sanitizeCardCode(resolved.cardCode) : "";
            if (!cc) {
              writeJson(res, 400, { ok: false, error: "invalid_card_code" });
              return;
            }
            patch.cardCode = cc;
            if (body.cardLabel === undefined && resolved && resolved.cardLabel) {
              patch.cardLabel = sanitizeCardLabel(resolved.cardLabel);
            }
          }
          if (body.cardLabel !== undefined) patch.cardLabel = sanitizeCardLabel(body.cardLabel);
          if (body.copies !== undefined) {
            const cp = Number.parseInt(String(body.copies), 10);
            if (!Number.isInteger(cp) || cp < 1 || cp > 3) {
              writeJson(res, 400, { ok: false, error: "invalid_copies" });
              return;
            }
            patch.copies = cp;
          }
          if (body.expiresAt === null) {
            patch.expiresAt = null;
          } else if (body.expiresAt !== undefined) {
            const parsedExp = Number(body.expiresAt);
            if (!Number.isFinite(parsedExp) || parsedExp <= Date.now()) {
              writeJson(res, 400, { ok: false, error: "invalid_expires_at" });
              return;
            }
            patch.expiresAt = Math.floor(parsedExp);
          }
          const updated = await store.updateGiftCode(code, patch);
          if (!updated) {
            writeJson(res, 404, { ok: false, error: "code_not_found" });
            return;
          }
          writeJson(res, 200, { ok: true, giftCode: updated });
          return;
        }
        if (req.method === "DELETE") {
          const removed = await store.deleteGiftCode(code);
          if (!removed) {
            writeJson(res, 404, { ok: false, error: "code_not_found" });
            return;
          }
          writeJson(res, 200, { ok: true });
          return;
        }
      }

      writeJson(res, 404, { ok: false, error: "not_found" });
      return;
    }

    // --- Authenticated routes below ---
    const me = await authenticateRequest(req);
    if (!me) {
      writeJson(res, 401, { ok: false, error: "unauthorized" });
      return;
    }

    if (req.method === "GET" && pathname === "/api/me") {
      const reqs = await store.listFriendRequests(me.playerId);
      const friends = await store.getFriendIds(me.playerId);
      writeJson(res, 200, {
        ok: true,
        player: publicPlayerSummary(me, true, "self"),
        friendCount: friends.length,
        incomingRequestCount: reqs.incoming.length
      });
      return;
    }

    if (req.method === "PATCH" && pathname === "/api/me/profile") {
      const body = await readJsonBody(req);
      const displayName = sanitizeDisplayName(body.displayName);
      if (displayName.length < 2) {
        writeJson(res, 400, { ok: false, error: "invalid_display_name" });
        return;
      }
      const updated = await store.updateDisplayName(me.playerId, displayName);
      writeJson(res, 200, { ok: true, player: publicPlayerSummary(updated, true, "self") });
      return;
    }

    if (req.method === "POST" && pathname === "/api/me/sync") {
      const body = await readJsonBody(req);
      const collection = sanitizeCollection(body.collection);
      const stats = sanitizeStats(body.stats, collection);
      const updated = await store.syncPlayerData(me.playerId, collection, stats);
      writeJson(res, 200, { ok: true, player: publicPlayerSummary(updated, true, "self") });
      return;
    }

    if (req.method === "GET" && pathname === "/api/players") {
      const q = (parsedUrl.searchParams.get("q") || "").trim().slice(0, 40);
      const onlineOnly = parsedUrl.searchParams.get("onlineOnly") === "1";
      const [players, friendIds, reqs] = await Promise.all([
        store.listPlayers(q, 80),
        store.getFriendIds(me.playerId),
        store.listFriendRequests(me.playerId)
      ]);
      const friendSet = new Set(friendIds);
      const incomingSet = new Set(reqs.incoming);
      const outgoingSet = new Set(reqs.outgoing);
      const mapped = [];
      for (const p of players) {
        const online = isOnline(p.playerId);
        if (onlineOnly && !online) continue;
        const status = await computeFriendStatus(me.playerId, p.playerId, friendSet, incomingSet, outgoingSet);
        mapped.push(publicPlayerSummary(p, false, status));
      }
      mapped.sort((a, b) => {
        if (a.online !== b.online) return a.online ? -1 : 1;
        return (b.lastSeenAt || 0) - (a.lastSeenAt || 0);
      });
      writeJson(res, 200, { ok: true, players: mapped });
      return;
    }

    const playerMatch = pathname.match(/^\/api\/players\/([0-9A-Za-z_-]{3,20})$/);
    if (req.method === "GET" && playerMatch) {
      const targetId = playerMatch[1];
      const target = await store.getPlayerById(targetId);
      if (!target) {
        writeJson(res, 404, { ok: false, error: "player_not_found" });
        return;
      }
      const [friendIds, reqs] = await Promise.all([
        store.getFriendIds(me.playerId),
        store.listFriendRequests(me.playerId)
      ]);
      const status = await computeFriendStatus(
        me.playerId,
        target.playerId,
        new Set(friendIds),
        new Set(reqs.incoming),
        new Set(reqs.outgoing)
      );
      writeJson(res, 200, { ok: true, player: publicPlayerSummary(target, true, status) });
      return;
    }

    if (req.method === "GET" && pathname === "/api/friends") {
      const [friendIds, reqs] = await Promise.all([
        store.getFriendIds(me.playerId),
        store.listFriendRequests(me.playerId)
      ]);
      const hydrate = async (ids, status) => {
        const out = [];
        for (const id of ids) {
          const p = await store.getPlayerById(id);
          if (p) out.push(publicPlayerSummary(p, false, status));
        }
        out.sort((a, b) => (a.online === b.online ? (b.lastSeenAt || 0) - (a.lastSeenAt || 0) : a.online ? -1 : 1));
        return out;
      };
      const [friends, incoming, outgoing] = await Promise.all([
        hydrate(friendIds, "friend"),
        hydrate(reqs.incoming, "incoming"),
        hydrate(reqs.outgoing, "outgoing")
      ]);
      writeJson(res, 200, { ok: true, friends, incoming, outgoing });
      return;
    }

    if (req.method === "POST" && pathname === "/api/friends/request") {
      const body = await readJsonBody(req);
      const targetId = String(body.targetId || "").trim();
      if (!targetId || targetId === me.playerId) {
        writeJson(res, 400, { ok: false, error: "invalid_target" });
        return;
      }
      const target = await store.getPlayerById(targetId);
      if (!target) {
        writeJson(res, 404, { ok: false, error: "player_not_found" });
        return;
      }
      if (await store.areFriends(me.playerId, targetId)) {
        writeJson(res, 200, { ok: true, status: "friend" });
        return;
      }
      const reverse = await store.getPendingRequest(targetId, me.playerId);
      if (reverse) {
        await store.addFriendship(me.playerId, targetId);
        pushToPlayer(targetId, {
          type: "friend_accepted",
          playerId: me.playerId,
          displayName: me.displayName
        });
        writeJson(res, 200, { ok: true, status: "friend" });
        return;
      }
      await store.createFriendRequest(me.playerId, targetId);
      pushToPlayer(targetId, {
        type: "friend_request",
        fromId: me.playerId,
        fromName: me.displayName
      });
      writeJson(res, 200, { ok: true, status: "outgoing" });
      return;
    }

    if (req.method === "POST" && pathname === "/api/friends/respond") {
      const body = await readJsonBody(req);
      const fromId = String(body.fromId || "").trim();
      const accept = Boolean(body.accept);
      if (!fromId) {
        writeJson(res, 400, { ok: false, error: "invalid_target" });
        return;
      }
      const pending = await store.getPendingRequest(fromId, me.playerId);
      if (!pending) {
        writeJson(res, 404, { ok: false, error: "request_not_found" });
        return;
      }
      if (accept) {
        await store.addFriendship(fromId, me.playerId);
        pushToPlayer(fromId, {
          type: "friend_accepted",
          playerId: me.playerId,
          displayName: me.displayName
        });
        writeJson(res, 200, { ok: true, status: "friend" });
      } else {
        await store.deleteFriendRequest(fromId, me.playerId);
        writeJson(res, 200, { ok: true, status: "rejected" });
      }
      return;
    }

    const deleteFriendMatch = pathname.match(/^\/api\/friends\/([0-9A-Za-z_-]{3,20})$/);
    if (req.method === "DELETE" && deleteFriendMatch) {
      const targetId = deleteFriendMatch[1];
      await store.removeFriendship(me.playerId, targetId);
      await store.deleteFriendRequest(me.playerId, targetId);
      await store.deleteFriendRequest(targetId, me.playerId);
      writeJson(res, 200, { ok: true });
      return;
    }

    if (req.method === "GET" && pathname === "/api/chat/global") {
      const messages = await store.getGlobalMessages(60);
      writeJson(res, 200, { ok: true, messages });
      return;
    }

    const dmMatch = pathname.match(/^\/api\/chat\/dm\/([0-9A-Za-z_-]{3,20})$/);
    if (req.method === "GET" && dmMatch) {
      const targetId = dmMatch[1];
      if (targetId === me.playerId || !(await store.areFriends(me.playerId, targetId))) {
        writeJson(res, 403, { ok: false, error: "not_friends" });
        return;
      }
      const messages = await store.getDirectMessages(me.playerId, targetId, 60);
      writeJson(res, 200, { ok: true, messages });
      return;
    }

    if (req.method === "POST" && pathname === "/api/gift-codes/redeem") {
      if (!checkRateLimit(req)) {
        writeJson(res, 429, { ok: false, error: "rate_limited" });
        return;
      }
      const body = await readJsonBody(req);
      const code = normalizeGiftCode(body.code);
      if (!code) {
        writeJson(res, 404, { ok: false, error: "code_not_found" });
        return;
      }
      const result = await store.redeemGiftCode(code, me.playerId);
      if (!result.ok) {
        const status = result.error === "code_not_found" ? 404 : 409;
        writeJson(res, status, { ok: false, error: result.error });
        return;
      }
      const gc = result.giftCode;
      writeJson(res, 200, {
        ok: true,
        code: gc.code,
        rewardType: gc.rewardType || "card",
        cardCode: gc.cardCode,
        cardLabel: gc.cardLabel,
        copies: gc.copies,
        cards: Array.isArray(gc.cards) ? gc.cards : [],
        allCardsUnlocked: Boolean(me.allCardsUnlocked || gc.rewardType === "unlock_all"),
        usedCount: gc.usedCount,
        maxUses: gc.maxUses,
        remaining: gc.remaining
      });
      return;
    }

    writeJson(res, 404, { ok: false, error: "not_found" });
  } catch (err) {
    if (err && err.message === "BODY_TOO_LARGE") {
      writeJson(res, 413, { ok: false, error: "body_too_large" });
      return;
    }
    if (err && err.message === "INVALID_JSON") {
      writeJson(res, 400, { ok: false, error: "invalid_json" });
      return;
    }
    console.error("[poc-online-relay] HTTP error:", err);
    writeJson(res, 500, { ok: false, error: "internal_error" });
  }
}

const server = http.createServer((req, res) => {
  handleHttp(req, res);
});

const wss = new WebSocketServer({
  server,
  maxPayload: MAX_PACKET_BYTES,
  perMessageDeflate: false
});

wss.on("connection", (ws) => {
  ws._alive = true;
  ws._roomCode = null;
  ws._role = null;
  ws._presenceId = null;

  ws.on("pong", () => {
    ws._alive = true;
  });

  ws.on("message", async (data, isBinary) => {
    ws._alive = true;

    // Binary frames are raw Joey duel packets forwarded verbatim between Host and Guest.
    if (isBinary) {
      const code = ws._roomCode;
      if (!code) return;
      const room = rooms.get(code);
      if (!room || !room.host || !room.guest) return;
      const target = ws._role === "host" ? room.guest : room.host;
      if (target && target.readyState === WebSocket.OPEN) {
        try {
          target.send(data, { binary: true });
        } catch {
          // Handled on socket close.
        }
      }
      return;
    }

    let msg;
    try {
      msg = JSON.parse(data.toString("utf8"));
    } catch {
      sendWsJson(ws, { type: "error", code: "bad_request", message: "Invalid JSON" });
      return;
    }
    if (!msg || typeof msg !== "object" || typeof msg.type !== "string") {
      sendWsJson(ws, { type: "error", code: "bad_request", message: "Missing message type" });
      return;
    }

    if (msg.type === "ping") {
      sendWsJson(ws, { type: "pong" });
      return;
    }

    // --- Online Presence, Matchmaking, Chat & Live Duel Invites ---
    if (msg.type === "presence") {
      const playerId = verifyToken(String(msg.token || ""));
      if (!playerId) {
        sendWsJson(ws, { type: "error", code: "unauthorized", message: "Invalid session token" });
        return;
      }
      const player = await store.getPlayerById(playerId);
      if (!player) {
        sendWsJson(ws, { type: "error", code: "unauthorized", message: "Unknown player" });
        return;
      }
      leavePresence(ws);
      ws._presenceId = playerId;
      ws._chatTimestamps = [];
      let set = onlineSockets.get(playerId);
      if (!set) {
        set = new Set();
        onlineSockets.set(playerId, set);
      }
      set.add(ws);
      await store.touchLastSeen(playerId);
      sendWsJson(ws, {
        type: "presence_ok",
        playerId,
        onlineCount: onlineSockets.size,
        allCardsUnlocked: Boolean(player.allCardsUnlocked)
      });
      return;
    }

    if (msg.type === "matchmaking_join") {
      if (!ws._presenceId) {
        sendWsJson(ws, { type: "matchmaking_error", code: "unauthorized" });
        return;
      }
      const game = sanitizeDisplayName(msg.game || "joey").toLowerCase();
      if (!VALID_GAMES.has(game)) {
        sendWsJson(ws, { type: "matchmaking_error", code: "invalid_game" });
        return;
      }
      const me = await store.getPlayerById(ws._presenceId);
      if (!me) {
        sendWsJson(ws, { type: "matchmaking_error", code: "unauthorized" });
        return;
      }
      const poolCheck = resolveEffectivePool(me, msg.pool);
      if (!poolCheck.ok) {
        sendWsJson(ws, { type: "matchmaking_error", code: poolCheck.error, expectedPool: "sandbox" });
        return;
      }
      const pool = poolCheck.pool;
      const queueKey = `${pool}:${game}`;
      removeFromMatchmaking(ws);
      const queue = matchmakingQueues[queueKey];
      // Clean dead sockets or duplicate entries for this player.
      for (let i = queue.length - 1; i >= 0; i -= 1) {
        const item = queue[i];
        if (!item.ws || item.ws.readyState !== WebSocket.OPEN || item.playerId === me.playerId) {
          if (item.ws) item.ws._matchmakingGame = null;
          queue.splice(i, 1);
        }
      }
      if (queue.length > 0 && rooms.size < MAX_ROOMS) {
        const pickIndex = crypto.randomInt(0, queue.length);
        const rival = queue.splice(pickIndex, 1)[0];
        if (rival && rival.ws) rival.ws._matchmakingGame = null;
        const code = generateRoomCode();
        if (!code) {
          queue.push(rival);
          if (rival && rival.ws) rival.ws._matchmakingGame = queueKey;
          sendWsJson(ws, { type: "matchmaking_error", code: "server_full" });
          return;
        }
        rooms.set(code, {
          code,
          game,
          pool,
          reserved: true,
          host: null,
          hostName: "",
          guest: null,
          guestName: "",
          createdAt: Date.now(),
          pairedAt: 0
        });
        const firstIsHost = crypto.randomInt(0, 2) === 0;
        sendWsJson(rival.ws, {
          type: "match_found",
          game,
          pool,
          roomCode: code,
          isHost: firstIsHost,
          opponentId: me.playerId,
          opponentName: me.displayName
        });
        sendWsJson(ws, {
          type: "match_found",
          game,
          pool,
          roomCode: code,
          isHost: !firstIsHost,
          opponentId: rival.playerId,
          opponentName: rival.displayName
        });
        return;
      }
      queue.push({ ws, playerId: me.playerId, displayName: me.displayName, joinedAt: Date.now() });
      ws._matchmakingGame = queueKey;
      sendWsJson(ws, { type: "matchmaking_queued", game, pool, queueSize: queue.length });
      return;
    }

    if (msg.type === "matchmaking_leave") {
      removeFromMatchmaking(ws);
      sendWsJson(ws, { type: "matchmaking_left" });
      return;
    }

    if (msg.type === "chat_global_send") {
      if (!ws._presenceId) {
        sendWsJson(ws, { type: "chat_error", code: "unauthorized" });
        return;
      }
      const text = sanitizeChatBody(msg.text || "");
      if (!text) return;
      const now = Date.now();
      const stamps = (ws._chatTimestamps || []).filter((t) => now - t < 10000);
      if (stamps.length >= 10) {
        ws._chatTimestamps = stamps;
        sendWsJson(ws, { type: "chat_error", code: "rate_limited" });
        return;
      }
      stamps.push(now);
      ws._chatTimestamps = stamps;
      const sender = await store.getPlayerById(ws._presenceId);
      if (!sender) return;
      const saved = await store.addGlobalMessage({
        senderId: sender.playerId,
        senderName: sender.displayName,
        body: text
      });
      broadcastPresence({ type: "chat_global", message: saved });
      return;
    }

    if (msg.type === "chat_dm_send") {
      if (!ws._presenceId) {
        sendWsJson(ws, { type: "chat_error", code: "unauthorized" });
        return;
      }
      const toId = String(msg.toId || "").trim();
      const text = sanitizeChatBody(msg.text || "");
      if (!toId || !text || toId === ws._presenceId) return;
      if (!(await store.areFriends(ws._presenceId, toId))) {
        sendWsJson(ws, { type: "chat_error", code: "not_friends" });
        return;
      }
      const now = Date.now();
      const stamps = (ws._chatTimestamps || []).filter((t) => now - t < 10000);
      if (stamps.length >= 12) {
        ws._chatTimestamps = stamps;
        sendWsJson(ws, { type: "chat_error", code: "rate_limited" });
        return;
      }
      stamps.push(now);
      ws._chatTimestamps = stamps;
      const sender = await store.getPlayerById(ws._presenceId);
      if (!sender) return;
      const saved = await store.addDirectMessage({
        fromId: sender.playerId,
        toId,
        senderName: sender.displayName,
        body: text
      });
      pushToPlayer(sender.playerId, { type: "chat_dm", message: saved });
      pushToPlayer(toId, { type: "chat_dm", message: saved });
      return;
    }

    if (msg.type === "invite_duel") {
      if (!ws._presenceId) {
        sendWsJson(ws, { type: "error", code: "unauthorized", message: "Sign in required" });
        return;
      }
      const targetId = String(msg.targetId || "").trim();
      const roomCode = normalizeCode(msg.roomCode);
      const game = sanitizeDisplayName(msg.game || "joey").toLowerCase() || "joey";
      if (!targetId || !roomCode || targetId === ws._presenceId) {
        sendWsJson(ws, { type: "invite_error", code: "bad_request" });
        return;
      }
      const sender = await store.getPlayerById(ws._presenceId);
      if (!sender) return;
      const existingRoom = rooms.get(roomCode);
      const desiredPool = existingRoom ? existingRoom.pool : msg.pool;
      const poolCheck = resolveEffectivePool(sender, desiredPool);
      if (!poolCheck.ok) {
        sendWsJson(ws, { type: "invite_error", code: poolCheck.error, targetId });
        return;
      }
      const pool = poolCheck.pool;
      const target = await store.getPlayerById(targetId);
      if (target && target.allCardsUnlocked && pool === "competitive") {
        sendWsJson(ws, { type: "invite_error", code: "target_sandbox_only", targetId });
        return;
      }
      const fromName = sanitizeDisplayName(msg.fromName) || sender.displayName || sender.username || "Duelist";
      const delivered = pushToPlayer(targetId, {
        type: "duel_invite",
        fromId: sender.playerId,
        fromName,
        roomCode,
        game,
        pool
      });
      sendWsJson(ws, { type: "invite_status", targetId, roomCode, pool, delivered });
      return;
    }

    if (msg.type === "invite_decline") {
      if (!ws._presenceId) return;
      const fromId = String(msg.fromId || "").trim();
      const roomCode = normalizeCode(msg.roomCode);
      const decliner = await store.getPlayerById(ws._presenceId);
      if (fromId && decliner) {
        pushToPlayer(fromId, {
          type: "invite_declined",
          byId: decliner.playerId,
          byName: decliner.displayName,
          roomCode
        });
      }
      return;
    }

    // --- Duel Relay Room Hosting / Joining ---
    if (msg.type === "host") {
      if (ws._roomCode) leaveRoom(ws, "rehost");
      const game = sanitizeDisplayName(msg.game || "joey").toLowerCase() || "joey";
      const name = sanitizeDisplayName(msg.name || "Player") || "Player";
      const claimCode = normalizeCode(msg.claimCode || "");
      const hostPlayerId = ws._presenceId || verifyToken(String(msg.token || ""));
      const hostPlayer = hostPlayerId ? await store.getPlayerById(hostPlayerId) : null;
      if (claimCode) {
        const reservedRoom = rooms.get(claimCode);
        if (!reservedRoom || !reservedRoom.reserved) {
          sendWsJson(ws, { type: "error", code: "not_found", message: "Room not found" });
          return;
        }
        if (reservedRoom.game !== game) {
          sendWsJson(ws, { type: "error", code: "game_mismatch", expectedGame: reservedRoom.game, message: "Game version mismatch" });
          return;
        }
        const reservedPool = reservedRoom.pool === "sandbox" ? "sandbox" : "competitive";
        if (reservedPool === "competitive" && hostPlayer && hostPlayer.allCardsUnlocked) {
          sendWsJson(ws, { type: "error", code: "unlocked_account_sandbox_only", expectedPool: "sandbox", message: "Unlocked accounts must play in Deck Testing server" });
          return;
        }
        if (reservedRoom.host && reservedRoom.host.readyState === WebSocket.OPEN) {
          sendWsJson(ws, { type: "error", code: "room_full", message: "Room already claimed" });
          return;
        }
        reservedRoom.host = ws;
        reservedRoom.hostName = name;
        ws._roomCode = claimCode;
        ws._role = "host";
        sendWsJson(ws, { type: "hosted", code: claimCode, game, pool: reservedPool });
        if (reservedRoom.guest && reservedRoom.guest.readyState === WebSocket.OPEN) {
          reservedRoom.pairedAt = Date.now();
          sendWsJson(reservedRoom.host, { type: "ready", code: claimCode, role: "host", pool: reservedPool, opponent: reservedRoom.guestName });
          sendWsJson(reservedRoom.guest, { type: "ready", code: claimCode, role: "guest", pool: reservedPool, opponent: reservedRoom.hostName });
        }
        return;
      }
      const poolCheck = resolveEffectivePool(hostPlayer, msg.pool);
      if (!poolCheck.ok) {
        sendWsJson(ws, { type: "error", code: poolCheck.error, expectedPool: "sandbox", message: "Unlocked accounts must play in Deck Testing server" });
        return;
      }
      const pool = poolCheck.pool;
      if (rooms.size >= MAX_ROOMS) {
        sendWsJson(ws, { type: "error", code: "server_full", message: "Server is busy, try again" });
        return;
      }
      const code = generateRoomCode();
      if (!code) {
        sendWsJson(ws, { type: "error", code: "server_full", message: "Could not allocate room code" });
        return;
      }
      rooms.set(code, {
        code,
        game,
        pool,
        reserved: false,
        host: ws,
        hostName: name,
        guest: null,
        guestName: "",
        createdAt: Date.now(),
        pairedAt: 0
      });
      ws._roomCode = code;
      ws._role = "host";
      sendWsJson(ws, { type: "hosted", code, game, pool });
      return;
    }

    if (msg.type === "join") {
      if (ws._roomCode) leaveRoom(ws, "rejoin");
      const code = normalizeCode(msg.code);
      const game = sanitizeDisplayName(msg.game || "joey").toLowerCase() || "joey";
      const name = sanitizeDisplayName(msg.name || "Player") || "Player";
      if (!code) {
        sendWsJson(ws, { type: "error", code: "bad_request", message: "Room code required" });
        return;
      }
      const room = rooms.get(code);
      const hostReady = Boolean(room && room.host && room.host.readyState === WebSocket.OPEN);
      if (!room || (!room.reserved && !hostReady)) {
        if (room) rooms.delete(code);
        sendWsJson(ws, { type: "error", code: "not_found", message: "Room not found" });
        return;
      }
      if (room.guest) {
        sendWsJson(ws, { type: "error", code: "room_full", message: "Room is full" });
        return;
      }
      if (room.game !== game) {
        sendWsJson(ws, { type: "error", code: "game_mismatch", expectedGame: room.game, message: "Game version mismatch" });
        return;
      }
      const roomPool = room.pool === "sandbox" ? "sandbox" : "competitive";
      const guestPlayerId = ws._presenceId || verifyToken(String(msg.token || ""));
      const guestPlayer = guestPlayerId ? await store.getPlayerById(guestPlayerId) : null;
      if (roomPool === "competitive" && guestPlayer && guestPlayer.allCardsUnlocked) {
        sendWsJson(ws, { type: "error", code: "unlocked_account_sandbox_only", expectedPool: "sandbox", message: "Unlocked accounts must play in Deck Testing server" });
        return;
      }
      const requestedJoinPool = typeof msg.pool === "string" && msg.pool.trim() ? normalizePool(msg.pool) : "";
      if (requestedJoinPool && requestedJoinPool !== roomPool) {
        sendWsJson(ws, { type: "error", code: "pool_mismatch", expectedPool: roomPool, message: "Server mode mismatch" });
        return;
      }
      room.guest = ws;
      room.guestName = name;
      ws._roomCode = code;
      ws._role = "guest";

      if (room.host && room.host.readyState === WebSocket.OPEN) {
        room.pairedAt = Date.now();
        sendWsJson(room.host, { type: "ready", code, role: "host", pool: roomPool, opponent: room.guestName });
        sendWsJson(room.guest, { type: "ready", code, role: "guest", pool: roomPool, opponent: room.hostName });
      }
      return;
    }

    sendWsJson(ws, { type: "error", code: "bad_request", message: "Unknown message type" });
  });

  ws.on("close", () => {
    leaveRoom(ws, "disconnected");
    leavePresence(ws);
  });

  ws.on("error", () => {
    leaveRoom(ws, "error");
    leavePresence(ws);
  });
});

const heartbeatTimer = setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws._alive) {
      leaveRoom(ws, "timeout");
      leavePresence(ws);
      ws.terminate();
      continue;
    }
    ws._alive = false;
    try {
      ws.ping();
    } catch {
      ws.terminate();
    }
  }
}, HEARTBEAT_MS);

const cleanupTimer = setInterval(() => {
  const now = Date.now();
  for (const [code, room] of rooms.entries()) {
    if ((!room.guest || !room.host) && now - room.createdAt > WAITING_ROOM_TTL_MS) {
      rooms.delete(code);
      for (const peer of [room.host, room.guest]) {
        if (!peer) continue;
        sendWsJson(peer, { type: "error", code: "expired", message: "Room expired" });
        peer._roomCode = null;
        peer._role = null;
        try {
          peer.close(1000, "expired");
        } catch {
          // Ignore close errors.
        }
      }
    }
  }
  for (const [state, entry] of googleStates.entries()) {
    if (now - entry.createdAt > GOOGLE_STATE_TTL_MS || (entry.retrievedAt && now - entry.retrievedAt > 60 * 1000)) {
      googleStates.delete(state);
    }
  }
}, CLEANUP_INTERVAL_MS);

async function shutdown() {
  clearInterval(heartbeatTimer);
  clearInterval(cleanupTimer);
  for (const ws of wss.clients) {
    try {
      ws.close(1001, "server_shutdown");
    } catch {
      // Ignore close errors.
    }
  }
  server.close(async () => {
    if (store) await store.close();
    process.exit(0);
  });
}

process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);

(async () => {
  store = await createStore();
  if (!sessionSecret) {
    sessionSecret = await store.getOrCreateMeta("session_secret", () => crypto.randomBytes(32).toString("hex"));
  }
  server.listen(PORT, "0.0.0.0", () => {
    console.log(`[poc-online-relay] listening on 0.0.0.0:${PORT} (storage=${store.kind}, google=${googleAuthEnabled()})`);
  });
})().catch((err) => {
  console.error("[poc-online-relay] failed to start:", err);
  process.exit(1);
});
