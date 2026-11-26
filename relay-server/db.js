"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const { Pool } = require("pg");

const DATA_DIR = process.env.STORE_DATA_DIR
  ? path.resolve(process.env.STORE_DATA_DIR)
  : path.resolve(__dirname, "data");
const STORE_PATH = path.join(DATA_DIR, "store.json");

function defaultStats() {
  return {
    wins: 0,
    losses: 0,
    draws: 0,
    total_cards: 0,
    unique_cards: 0,
    monsters: 0,
    spells: 0,
    traps: 0,
    last_game: "joey"
  };
}

function normalizePair(a, b) {
  return a < b ? [a, b] : [b, a];
}

function generateNumericId() {
  return String(crypto.randomInt(100000, 1000000));
}

class JsonStore {
  constructor() {
    this.kind = "json";
    this.state = {
      players: {},
      friendships: [],
      friendRequests: [],
      globalMessages: [],
      directMessages: [],
      giftCodes: {},
      giftRedemptions: [],
      meta: {}
    };
  }

  async init() {
    fs.mkdirSync(DATA_DIR, { recursive: true });
    if (fs.existsSync(STORE_PATH)) {
      try {
        const parsed = JSON.parse(fs.readFileSync(STORE_PATH, "utf8"));
        if (parsed && typeof parsed === "object") {
          this.state.players = parsed.players && typeof parsed.players === "object" ? parsed.players : {};
          this.state.friendships = Array.isArray(parsed.friendships) ? parsed.friendships : [];
          this.state.friendRequests = Array.isArray(parsed.friendRequests) ? parsed.friendRequests : [];
          this.state.globalMessages = Array.isArray(parsed.globalMessages) ? parsed.globalMessages : [];
          this.state.directMessages = Array.isArray(parsed.directMessages) ? parsed.directMessages : [];
          this.state.giftCodes = parsed.giftCodes && typeof parsed.giftCodes === "object" ? parsed.giftCodes : {};
          this.state.giftRedemptions = Array.isArray(parsed.giftRedemptions) ? parsed.giftRedemptions : [];
          this.state.meta = parsed.meta && typeof parsed.meta === "object" ? parsed.meta : {};
        }
      } catch {
        // Start clean if local file was corrupt.
      }
    }
  }

  async getMeta(key) {
    return typeof this.state.meta[key] === "string" && this.state.meta[key].length > 0
      ? this.state.meta[key]
      : null;
  }

  async setMetaIfUnset(key, value) {
    if (typeof this.state.meta[key] === "string" && this.state.meta[key].length > 0) {
      return false;
    }
    this.state.meta[key] = String(value);
    this._persist();
    return true;
  }

  async getOrCreateMeta(key, generator) {
    if (typeof this.state.meta[key] === "string" && this.state.meta[key].length > 0) {
      return this.state.meta[key];
    }
    const value = String(generator());
    this.state.meta[key] = value;
    this._persist();
    return value;
  }

  _persist() {
    fs.mkdirSync(DATA_DIR, { recursive: true });
    const tmp = STORE_PATH + ".tmp";
    fs.writeFileSync(tmp, JSON.stringify(this.state, null, 2), "utf8");
    fs.renameSync(tmp, STORE_PATH);
  }

  _allocatePlayerId() {
    for (let i = 0; i < 200; i += 1) {
      const id = generateNumericId();
      if (!this.state.players[id]) return id;
    }
    return String(Date.now()).slice(-8);
  }

  async createPlayer({ username = null, displayName, passwordHash = null, googleSub = null, email = null, avatarUrl = "", authProvider = "guest" }) {
    const now = Date.now();
    const playerId = this._allocatePlayerId();
    const player = {
      playerId,
      username: username ? username.toLowerCase() : null,
      displayName,
      passwordHash,
      googleSub,
      email,
      avatarUrl,
      authProvider,
      collection: {},
      stats: defaultStats(),
      allCardsUnlocked: false,
      createdAt: now,
      lastSeenAt: now
    };
    this.state.players[playerId] = player;
    this._persist();
    return { ...player };
  }

  async getPlayerById(playerId) {
    const p = this.state.players[playerId];
    return p ? { ...p } : null;
  }

  async getPlayerByUsername(username) {
    const lower = username.toLowerCase();
    for (const p of Object.values(this.state.players)) {
      if (p.username === lower) return { ...p };
    }
    return null;
  }

  async getPlayerByGoogleSub(googleSub) {
    for (const p of Object.values(this.state.players)) {
      if (p.googleSub === googleSub) return { ...p };
    }
    return null;
  }

  async upgradePlayerAccount(playerId, { username, passwordHash, displayName }) {
    const p = this.state.players[playerId];
    if (!p) return null;
    p.username = username.toLowerCase();
    p.passwordHash = passwordHash;
    if (displayName) p.displayName = displayName;
    p.authProvider = "account";
    p.lastSeenAt = Date.now();
    this._persist();
    return { ...p };
  }

  async linkPlayerGoogle(playerId, { googleSub, email, avatarUrl, displayName }) {
    const p = this.state.players[playerId];
    if (!p) return null;
    p.googleSub = googleSub;
    if (email) p.email = email;
    if (avatarUrl) p.avatarUrl = avatarUrl;
    if (displayName && p.authProvider === "guest") p.displayName = displayName;
    p.authProvider = "google";
    p.lastSeenAt = Date.now();
    this._persist();
    return { ...p };
  }

  async updateDisplayName(playerId, displayName) {
    const p = this.state.players[playerId];
    if (!p) return null;
    p.displayName = displayName;
    p.lastSeenAt = Date.now();
    this._persist();
    return { ...p };
  }

  async touchLastSeen(playerId) {
    const p = this.state.players[playerId];
    if (!p) return;
    p.lastSeenAt = Date.now();
    this._persist();
  }

  async syncPlayerData(playerId, collection, stats) {
    const p = this.state.players[playerId];
    if (!p) return null;
    p.collection = collection;
    p.stats = { ...defaultStats(), ...stats };
    p.lastSeenAt = Date.now();
    this._persist();
    return { ...p };
  }

  async listPlayers(query = "", limit = 60) {
    const q = query.trim().toLowerCase();
    const list = Object.values(this.state.players).filter((p) => {
      if (!q) return true;
      return (
        p.playerId.toLowerCase().includes(q) ||
        p.displayName.toLowerCase().includes(q) ||
        (p.username && p.username.includes(q))
      );
    });
    list.sort((a, b) => (b.lastSeenAt || 0) - (a.lastSeenAt || 0));
    return list.slice(0, limit).map((p) => ({ ...p }));
  }

  async areFriends(a, b) {
    const [p1, p2] = normalizePair(a, b);
    return this.state.friendships.some((f) => f.playerA === p1 && f.playerB === p2);
  }

  async addFriendship(a, b) {
    const [p1, p2] = normalizePair(a, b);
    if (!this.state.friendships.some((f) => f.playerA === p1 && f.playerB === p2)) {
      this.state.friendships.push({ playerA: p1, playerB: p2, createdAt: Date.now() });
    }
    this.state.friendRequests = this.state.friendRequests.filter(
      (r) => !((r.fromId === a && r.toId === b) || (r.fromId === b && r.toId === a))
    );
    this._persist();
  }

  async removeFriendship(a, b) {
    const [p1, p2] = normalizePair(a, b);
    this.state.friendships = this.state.friendships.filter((f) => !(f.playerA === p1 && f.playerB === p2));
    this._persist();
  }

  async getFriendIds(playerId) {
    const ids = [];
    for (const f of this.state.friendships) {
      if (f.playerA === playerId) ids.push(f.playerB);
      else if (f.playerB === playerId) ids.push(f.playerA);
    }
    return ids;
  }

  async getPendingRequest(fromId, toId) {
    return this.state.friendRequests.find((r) => r.fromId === fromId && r.toId === toId) || null;
  }

  async createFriendRequest(fromId, toId) {
    if (!this.state.friendRequests.some((r) => r.fromId === fromId && r.toId === toId)) {
      this.state.friendRequests.push({ fromId, toId, createdAt: Date.now() });
      this._persist();
    }
  }

  async deleteFriendRequest(fromId, toId) {
    this.state.friendRequests = this.state.friendRequests.filter(
      (r) => !(r.fromId === fromId && r.toId === toId)
    );
    this._persist();
  }

  async listFriendRequests(playerId) {
    const incoming = this.state.friendRequests.filter((r) => r.toId === playerId).map((r) => r.fromId);
    const outgoing = this.state.friendRequests.filter((r) => r.fromId === playerId).map((r) => r.toId);
    return { incoming, outgoing };
  }

  async countPlayers() {
    return Object.keys(this.state.players).length;
  }

  async addGlobalMessage({ senderId, senderName, body }) {
    const entry = {
      id: Date.now() * 1000 + crypto.randomInt(0, 1000),
      senderId,
      senderName,
      body,
      createdAt: Date.now()
    };
    this.state.globalMessages.push(entry);
    if (this.state.globalMessages.length > 300) {
      this.state.globalMessages = this.state.globalMessages.slice(-300);
    }
    this._persist();
    return { ...entry };
  }

  async getGlobalMessages(limit = 60) {
    const n = Math.max(1, Math.min(100, Number(limit) || 60));
    return this.state.globalMessages.slice(-n).map((m) => ({ ...m }));
  }

  async addDirectMessage({ fromId, toId, senderName, body }) {
    const entry = {
      id: Date.now() * 1000 + crypto.randomInt(0, 1000),
      fromId,
      toId,
      senderName,
      body,
      createdAt: Date.now()
    };
    this.state.directMessages.push(entry);
    if (this.state.directMessages.length > 4000) {
      this.state.directMessages = this.state.directMessages.slice(-4000);
    }
    this._persist();
    return { ...entry };
  }

  async getDirectMessages(userA, userB, limit = 60) {
    const n = Math.max(1, Math.min(100, Number(limit) || 60));
    const list = this.state.directMessages.filter(
      (m) => (m.fromId === userA && m.toId === userB) || (m.fromId === userB && m.toId === userA)
    );
    return list.slice(-n).map((m) => ({ ...m }));
  }

  _formatGiftCode(gc) {
    if (!gc) return null;
    const maxUses = Math.max(1, Number(gc.maxUses || 1));
    const usedCount = Math.max(0, Number(gc.usedCount || 0));
    const expiresAt = gc.expiresAt ? Number(gc.expiresAt) : null;
    const cards = Array.isArray(gc.cards) ? gc.cards : [];
    const rewardType = gc.rewardType === "unlock_all"
      ? "unlock_all"
      : (gc.rewardType === "deck" && cards.length > 0 ? "deck" : "card");
    return {
      code: gc.code,
      rewardType,
      cardCode: gc.cardCode,
      cardLabel: gc.cardLabel || "",
      copies: Math.max(1, Math.min(3, Number(gc.copies || 1))),
      cards,
      maxUses,
      usedCount,
      remaining: Math.max(0, maxUses - usedCount),
      active: Boolean(gc.active),
      exhausted: usedCount >= maxUses,
      expired: Boolean(expiresAt && Date.now() > expiresAt),
      expiresAt,
      createdAt: Number(gc.createdAt || 0)
    };
  }

  async createGiftCode({ code, rewardType = "card", cardCode, cardLabel = "", copies = 1, cards = [], maxUses = 10, active = true, expiresAt = null }) {
    if (this.state.giftCodes[code]) return null;
    const normCards = Array.isArray(cards) ? cards : [];
    const normType = rewardType === "unlock_all"
      ? "unlock_all"
      : (rewardType === "deck" && normCards.length > 0 ? "deck" : "card");
    const entry = {
      code,
      rewardType: normType,
      cardCode,
      cardLabel,
      copies,
      cards: normCards,
      maxUses,
      usedCount: 0,
      active: Boolean(active),
      expiresAt: expiresAt ? Number(expiresAt) : null,
      createdAt: Date.now()
    };
    this.state.giftCodes[code] = entry;
    this._persist();
    return this._formatGiftCode(entry);
  }

  async getGiftCode(code) {
    return this._formatGiftCode(this.state.giftCodes[code]);
  }

  async listGiftCodes() {
    const list = Object.values(this.state.giftCodes).map((g) => this._formatGiftCode(g));
    list.sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0));
    return list;
  }

  async updateGiftCode(code, patch) {
    const gc = this.state.giftCodes[code];
    if (!gc) return null;
    if (typeof patch.active === "boolean") gc.active = patch.active;
    if (typeof patch.maxUses === "number" && Number.isInteger(patch.maxUses) && patch.maxUses >= 1) {
      gc.maxUses = patch.maxUses;
    }
    if (patch.rewardType === "card" || patch.rewardType === "deck" || patch.rewardType === "unlock_all") {
      gc.rewardType = patch.rewardType;
    }
    if (Array.isArray(patch.cards)) {
      gc.cards = patch.cards;
    }
    if (typeof patch.cardCode === "string" && patch.cardCode.length > 0) gc.cardCode = patch.cardCode;
    if (typeof patch.cardLabel === "string") gc.cardLabel = patch.cardLabel;
    if (typeof patch.copies === "number" && Number.isInteger(patch.copies) && patch.copies >= 1 && patch.copies <= 3) {
      gc.copies = patch.copies;
    }
    if (patch.expiresAt === null || typeof patch.expiresAt === "number") {
      gc.expiresAt = patch.expiresAt;
    }
    this._persist();
    return this._formatGiftCode(gc);
  }

  async deleteGiftCode(code) {
    if (!this.state.giftCodes[code]) return false;
    delete this.state.giftCodes[code];
    this.state.giftRedemptions = this.state.giftRedemptions.filter((r) => r.code !== code);
    this._persist();
    return true;
  }

  async listGiftCodeRedemptions(code, limit = 50) {
    const n = Math.max(1, Math.min(200, Number(limit) || 50));
    const list = this.state.giftRedemptions
      .filter((r) => r.code === code)
      .sort((a, b) => (b.redeemedAt || 0) - (a.redeemedAt || 0))
      .slice(0, n)
      .map((r) => {
        const p = this.state.players[r.playerId];
        return {
          playerId: r.playerId,
          displayName: p ? p.displayName : r.playerId,
          redeemedAt: Number(r.redeemedAt || 0)
        };
      });
    return list;
  }

  async redeemGiftCode(code, playerId) {
    const gc = this.state.giftCodes[code];
    if (!gc) return { ok: false, error: "code_not_found" };
    if (!gc.active) return { ok: false, error: "code_inactive" };
    if (gc.expiresAt && Date.now() > Number(gc.expiresAt)) {
      return { ok: false, error: "code_expired" };
    }
    const already = this.state.giftRedemptions.some((r) => r.code === code && r.playerId === playerId);
    if (already) return { ok: false, error: "already_redeemed" };
    if (Number(gc.usedCount || 0) >= Number(gc.maxUses || 1)) {
      return { ok: false, error: "code_exhausted" };
    }
    gc.usedCount = Number(gc.usedCount || 0) + 1;
    this.state.giftRedemptions.push({ code, playerId, redeemedAt: Date.now() });
    if (gc.rewardType === "unlock_all" && this.state.players[playerId]) {
      this.state.players[playerId].allCardsUnlocked = true;
    }
    this._persist();
    return { ok: true, giftCode: this._formatGiftCode(gc) };
  }

  async close() {}
}

function resolveInitialSsl(connectionString) {
  try {
    const parsed = new URL(connectionString);
    const sslMode = (parsed.searchParams.get("sslmode") || "").toLowerCase();
    if (sslMode === "disable") return false;
    if (sslMode === "require" || sslMode === "verify-ca" || sslMode === "verify-full") {
      return { rejectUnauthorized: false };
    }
    const host = (parsed.hostname || "").toLowerCase();
    // Localhost or Render Internal Postgres hostnames (e.g. dpg-xxxx-a, no dot) default to no SSL.
    if (!host || host === "localhost" || host === "127.0.0.1" || !host.includes(".")) {
      return false;
    }
    return { rejectUnauthorized: false };
  } catch {
    return connectionString.includes("localhost") || connectionString.includes("127.0.0.1")
      ? false
      : { rejectUnauthorized: false };
  }
}

class PostgresStore {
  constructor(connectionString) {
    this.kind = "postgres";
    this.connectionString = connectionString;
    this._ssl = resolveInitialSsl(connectionString);
    this.pool = new Pool({ connectionString, ssl: this._ssl, max: 10 });
  }

  async _ensureSchema() {
    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS server_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS players (
        player_id TEXT PRIMARY KEY,
        username TEXT UNIQUE,
        display_name TEXT NOT NULL,
        password_hash TEXT,
        google_sub TEXT UNIQUE,
        email TEXT,
        avatar_url TEXT NOT NULL DEFAULT '',
        auth_provider TEXT NOT NULL DEFAULT 'guest',
        collection JSONB NOT NULL DEFAULT '{}'::jsonb,
        stats JSONB NOT NULL DEFAULT '{}'::jsonb,
        all_cards_unlocked BOOLEAN NOT NULL DEFAULT FALSE,
        created_at BIGINT NOT NULL,
        last_seen_at BIGINT NOT NULL
      );
      ALTER TABLE players ADD COLUMN IF NOT EXISTS all_cards_unlocked BOOLEAN NOT NULL DEFAULT FALSE;
      CREATE TABLE IF NOT EXISTS friendships (
        player_a TEXT NOT NULL REFERENCES players(player_id) ON DELETE CASCADE,
        player_b TEXT NOT NULL REFERENCES players(player_id) ON DELETE CASCADE,
        created_at BIGINT NOT NULL,
        PRIMARY KEY (player_a, player_b)
      );
      CREATE TABLE IF NOT EXISTS friend_requests (
        from_id TEXT NOT NULL REFERENCES players(player_id) ON DELETE CASCADE,
        to_id TEXT NOT NULL REFERENCES players(player_id) ON DELETE CASCADE,
        created_at BIGINT NOT NULL,
        PRIMARY KEY (from_id, to_id)
      );
      CREATE TABLE IF NOT EXISTS global_messages (
        id BIGSERIAL PRIMARY KEY,
        sender_id TEXT NOT NULL REFERENCES players(player_id) ON DELETE CASCADE,
        sender_name TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at BIGINT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS direct_messages (
        id BIGSERIAL PRIMARY KEY,
        from_id TEXT NOT NULL REFERENCES players(player_id) ON DELETE CASCADE,
        to_id TEXT NOT NULL REFERENCES players(player_id) ON DELETE CASCADE,
        sender_name TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at BIGINT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS gift_codes (
        code TEXT PRIMARY KEY,
        reward_type TEXT NOT NULL DEFAULT 'card',
        card_code TEXT NOT NULL,
        card_label TEXT NOT NULL DEFAULT '',
        copies INTEGER NOT NULL DEFAULT 1,
        cards_json JSONB NOT NULL DEFAULT '[]'::jsonb,
        max_uses INTEGER NOT NULL,
        used_count INTEGER NOT NULL DEFAULT 0,
        active BOOLEAN NOT NULL DEFAULT TRUE,
        expires_at BIGINT,
        created_at BIGINT NOT NULL
      );
      ALTER TABLE gift_codes ADD COLUMN IF NOT EXISTS reward_type TEXT NOT NULL DEFAULT 'card';
      ALTER TABLE gift_codes ADD COLUMN IF NOT EXISTS cards_json JSONB NOT NULL DEFAULT '[]'::jsonb;
      CREATE TABLE IF NOT EXISTS gift_code_redemptions (
        code TEXT NOT NULL REFERENCES gift_codes(code) ON DELETE CASCADE,
        player_id TEXT NOT NULL REFERENCES players(player_id) ON DELETE CASCADE,
        redeemed_at BIGINT NOT NULL,
        PRIMARY KEY (code, player_id)
      );
      CREATE INDEX IF NOT EXISTS idx_players_last_seen ON players (last_seen_at DESC);
      CREATE INDEX IF NOT EXISTS idx_friend_requests_to ON friend_requests (to_id);
      CREATE INDEX IF NOT EXISTS idx_global_messages_created ON global_messages (created_at DESC, id DESC);
      CREATE INDEX IF NOT EXISTS idx_dm_pair ON direct_messages (LEAST(from_id, to_id), GREATEST(from_id, to_id), created_at DESC, id DESC);
      CREATE INDEX IF NOT EXISTS idx_gift_codes_created ON gift_codes (created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_gift_redemptions_code ON gift_code_redemptions (code, redeemed_at DESC);
    `);
  }

  async init() {
    try {
      await this._ensureSchema();
    } catch (err) {
      const msg = String(err && err.message ? err.message : "").toLowerCase();
      const sslMismatch =
        msg.includes("does not support ssl") ||
        msg.includes("ssl") ||
        msg.includes("no pg_hba.conf entry");
      if (!sslMismatch) throw err;
      await this.pool.end().catch(() => {});
      this._ssl = this._ssl ? false : { rejectUnauthorized: false };
      this.pool = new Pool({ connectionString: this.connectionString, ssl: this._ssl, max: 10 });
      await this._ensureSchema();
    }
  }

  async getMeta(key) {
    const res = await this.pool.query("SELECT value FROM server_meta WHERE key = $1", [key]);
    if (res.rowCount > 0 && res.rows[0].value) {
      return String(res.rows[0].value);
    }
    return null;
  }

  async setMetaIfUnset(key, value) {
    const res = await this.pool.query(
      "INSERT INTO server_meta (key, value) VALUES ($1, $2) ON CONFLICT (key) DO NOTHING RETURNING key",
      [key, String(value)]
    );
    return res.rowCount > 0;
  }

  async getOrCreateMeta(key, generator) {
    const existing = await this.pool.query("SELECT value FROM server_meta WHERE key = $1", [key]);
    if (existing.rowCount > 0 && existing.rows[0].value) {
      return String(existing.rows[0].value);
    }
    const generated = String(generator());
    await this.pool.query(
      "INSERT INTO server_meta (key, value) VALUES ($1, $2) ON CONFLICT (key) DO NOTHING",
      [key, generated]
    );
    const after = await this.pool.query("SELECT value FROM server_meta WHERE key = $1", [key]);
    return after.rowCount > 0 ? String(after.rows[0].value) : generated;
  }

  _rowToPlayer(row) {
    if (!row) return null;
    return {
      playerId: row.player_id,
      username: row.username,
      displayName: row.display_name,
      passwordHash: row.password_hash,
      googleSub: row.google_sub,
      email: row.email,
      avatarUrl: row.avatar_url || "",
      authProvider: row.auth_provider || "guest",
      collection: row.collection && typeof row.collection === "object" ? row.collection : {},
      stats: { ...defaultStats(), ...(row.stats && typeof row.stats === "object" ? row.stats : {}) },
      allCardsUnlocked: Boolean(row.all_cards_unlocked),
      createdAt: Number(row.created_at || 0),
      lastSeenAt: Number(row.last_seen_at || 0)
    };
  }

  async _allocatePlayerId() {
    for (let i = 0; i < 64; i += 1) {
      const id = generateNumericId();
      const res = await this.pool.query("SELECT 1 FROM players WHERE player_id = $1", [id]);
      if (res.rowCount === 0) return id;
    }
    return String(Date.now()).slice(-8);
  }

  async createPlayer({ username = null, displayName, passwordHash = null, googleSub = null, email = null, avatarUrl = "", authProvider = "guest" }) {
    const now = Date.now();
    const playerId = await this._allocatePlayerId();
    const res = await this.pool.query(
      `INSERT INTO players (
         player_id, username, display_name, password_hash, google_sub, email,
         avatar_url, auth_provider, collection, stats, created_at, last_seen_at
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9::jsonb,$10::jsonb,$11,$12)
       RETURNING *`,
      [
        playerId,
        username ? username.toLowerCase() : null,
        displayName,
        passwordHash,
        googleSub,
        email,
        avatarUrl || "",
        authProvider,
        JSON.stringify({}),
        JSON.stringify(defaultStats()),
        now,
        now
      ]
    );
    return this._rowToPlayer(res.rows[0]);
  }

  async getPlayerById(playerId) {
    const res = await this.pool.query("SELECT * FROM players WHERE player_id = $1", [playerId]);
    return this._rowToPlayer(res.rows[0]);
  }

  async getPlayerByUsername(username) {
    const res = await this.pool.query("SELECT * FROM players WHERE username = $1", [username.toLowerCase()]);
    return this._rowToPlayer(res.rows[0]);
  }

  async getPlayerByGoogleSub(googleSub) {
    const res = await this.pool.query("SELECT * FROM players WHERE google_sub = $1", [googleSub]);
    return this._rowToPlayer(res.rows[0]);
  }

  async upgradePlayerAccount(playerId, { username, passwordHash, displayName }) {
    const res = await this.pool.query(
      `UPDATE players
       SET username = $2, password_hash = $3, display_name = COALESCE($4, display_name),
           auth_provider = 'account', last_seen_at = $5
       WHERE player_id = $1 RETURNING *`,
      [playerId, username.toLowerCase(), passwordHash, displayName || null, Date.now()]
    );
    return this._rowToPlayer(res.rows[0]);
  }

  async linkPlayerGoogle(playerId, { googleSub, email, avatarUrl, displayName }) {
    const res = await this.pool.query(
      `UPDATE players
       SET google_sub = $2,
           email = COALESCE($3, email),
           avatar_url = COALESCE($4, avatar_url),
           display_name = CASE WHEN auth_provider = 'guest' AND $5 IS NOT NULL THEN $5 ELSE display_name END,
           auth_provider = 'google',
           last_seen_at = $6
       WHERE player_id = $1 RETURNING *`,
      [playerId, googleSub, email || null, avatarUrl || null, displayName || null, Date.now()]
    );
    return this._rowToPlayer(res.rows[0]);
  }

  async updateDisplayName(playerId, displayName) {
    const res = await this.pool.query(
      "UPDATE players SET display_name = $2, last_seen_at = $3 WHERE player_id = $1 RETURNING *",
      [playerId, displayName, Date.now()]
    );
    return this._rowToPlayer(res.rows[0]);
  }

  async touchLastSeen(playerId) {
    await this.pool.query("UPDATE players SET last_seen_at = $2 WHERE player_id = $1", [playerId, Date.now()]);
  }

  async syncPlayerData(playerId, collection, stats) {
    const mergedStats = { ...defaultStats(), ...stats };
    const res = await this.pool.query(
      "UPDATE players SET collection = $2::jsonb, stats = $3::jsonb, last_seen_at = $4 WHERE player_id = $1 RETURNING *",
      [playerId, JSON.stringify(collection), JSON.stringify(mergedStats), Date.now()]
    );
    return this._rowToPlayer(res.rows[0]);
  }

  async listPlayers(query = "", limit = 60) {
    const q = query.trim();
    if (!q) {
      const res = await this.pool.query("SELECT * FROM players ORDER BY last_seen_at DESC LIMIT $1", [limit]);
      return res.rows.map((r) => this._rowToPlayer(r));
    }
    const pattern = `%${q}%`;
    const res = await this.pool.query(
      `SELECT * FROM players
       WHERE player_id ILIKE $1 OR display_name ILIKE $1 OR COALESCE(username, '') ILIKE $1
       ORDER BY last_seen_at DESC LIMIT $2`,
      [pattern, limit]
    );
    return res.rows.map((r) => this._rowToPlayer(r));
  }

  async areFriends(a, b) {
    const [p1, p2] = normalizePair(a, b);
    const res = await this.pool.query(
      "SELECT 1 FROM friendships WHERE player_a = $1 AND player_b = $2",
      [p1, p2]
    );
    return res.rowCount > 0;
  }

  async addFriendship(a, b) {
    const [p1, p2] = normalizePair(a, b);
    await this.pool.query(
      "INSERT INTO friendships (player_a, player_b, created_at) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING",
      [p1, p2, Date.now()]
    );
    await this.pool.query(
      "DELETE FROM friend_requests WHERE (from_id = $1 AND to_id = $2) OR (from_id = $2 AND to_id = $1)",
      [a, b]
    );
  }

  async removeFriendship(a, b) {
    const [p1, p2] = normalizePair(a, b);
    await this.pool.query("DELETE FROM friendships WHERE player_a = $1 AND player_b = $2", [p1, p2]);
  }

  async getFriendIds(playerId) {
    const res = await this.pool.query(
      `SELECT CASE WHEN player_a = $1 THEN player_b ELSE player_a END AS fid
       FROM friendships WHERE player_a = $1 OR player_b = $1`,
      [playerId]
    );
    return res.rows.map((r) => r.fid);
  }

  async getPendingRequest(fromId, toId) {
    const res = await this.pool.query(
      "SELECT from_id, to_id, created_at FROM friend_requests WHERE from_id = $1 AND to_id = $2",
      [fromId, toId]
    );
    if (res.rowCount === 0) return null;
    return { fromId: res.rows[0].from_id, toId: res.rows[0].to_id, createdAt: Number(res.rows[0].created_at) };
  }

  async createFriendRequest(fromId, toId) {
    await this.pool.query(
      "INSERT INTO friend_requests (from_id, to_id, created_at) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING",
      [fromId, toId, Date.now()]
    );
  }

  async deleteFriendRequest(fromId, toId) {
    await this.pool.query("DELETE FROM friend_requests WHERE from_id = $1 AND to_id = $2", [fromId, toId]);
  }

  async listFriendRequests(playerId) {
    const inc = await this.pool.query("SELECT from_id FROM friend_requests WHERE to_id = $1 ORDER BY created_at DESC", [playerId]);
    const out = await this.pool.query("SELECT to_id FROM friend_requests WHERE from_id = $1 ORDER BY created_at DESC", [playerId]);
    return {
      incoming: inc.rows.map((r) => r.from_id),
      outgoing: out.rows.map((r) => r.to_id)
    };
  }

  async countPlayers() {
    const res = await this.pool.query("SELECT COUNT(*)::int AS c FROM players");
    return Number(res.rows[0].c || 0);
  }

  async addGlobalMessage({ senderId, senderName, body }) {
    const now = Date.now();
    const res = await this.pool.query(
      `INSERT INTO global_messages (sender_id, sender_name, body, created_at)
       VALUES ($1, $2, $3, $4)
       RETURNING id, sender_id, sender_name, body, created_at`,
      [senderId, senderName, body, now]
    );
    const r = res.rows[0];
    return {
      id: Number(r.id),
      senderId: r.sender_id,
      senderName: r.sender_name,
      body: r.body,
      createdAt: Number(r.created_at)
    };
  }

  async getGlobalMessages(limit = 60) {
    const n = Math.max(1, Math.min(100, Number(limit) || 60));
    const res = await this.pool.query(
      `SELECT id, sender_id, sender_name, body, created_at
       FROM global_messages
       ORDER BY created_at DESC, id DESC
       LIMIT $1`,
      [n]
    );
    return res.rows.reverse().map((r) => ({
      id: Number(r.id),
      senderId: r.sender_id,
      senderName: r.sender_name,
      body: r.body,
      createdAt: Number(r.created_at)
    }));
  }

  async addDirectMessage({ fromId, toId, senderName, body }) {
    const now = Date.now();
    const res = await this.pool.query(
      `INSERT INTO direct_messages (from_id, to_id, sender_name, body, created_at)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, from_id, to_id, sender_name, body, created_at`,
      [fromId, toId, senderName, body, now]
    );
    const r = res.rows[0];
    return {
      id: Number(r.id),
      fromId: r.from_id,
      toId: r.to_id,
      senderName: r.sender_name,
      body: r.body,
      createdAt: Number(r.created_at)
    };
  }

  async getDirectMessages(userA, userB, limit = 60) {
    const n = Math.max(1, Math.min(100, Number(limit) || 60));
    const res = await this.pool.query(
      `SELECT id, from_id, to_id, sender_name, body, created_at
       FROM direct_messages
       WHERE (from_id = $1 AND to_id = $2) OR (from_id = $2 AND to_id = $1)
       ORDER BY created_at DESC, id DESC
       LIMIT $3`,
      [userA, userB, n]
    );
    return res.rows.reverse().map((r) => ({
      id: Number(r.id),
      fromId: r.from_id,
      toId: r.to_id,
      senderName: r.sender_name,
      body: r.body,
      createdAt: Number(r.created_at)
    }));
  }

  _rowToGiftCode(row) {
    if (!row) return null;
    const maxUses = Math.max(1, Number(row.max_uses || 1));
    const usedCount = Math.max(0, Number(row.used_count || 0));
    const expiresAt = row.expires_at != null ? Number(row.expires_at) : null;
    const cards = Array.isArray(row.cards_json) ? row.cards_json : [];
    const rewardType = row.reward_type === "unlock_all"
      ? "unlock_all"
      : (row.reward_type === "deck" && cards.length > 0 ? "deck" : "card");
    return {
      code: row.code,
      rewardType,
      cardCode: row.card_code,
      cardLabel: row.card_label || "",
      copies: Math.max(1, Math.min(3, Number(row.copies || 1))),
      cards,
      maxUses,
      usedCount,
      remaining: Math.max(0, maxUses - usedCount),
      active: Boolean(row.active),
      exhausted: usedCount >= maxUses,
      expired: Boolean(expiresAt && Date.now() > expiresAt),
      expiresAt,
      createdAt: Number(row.created_at || 0)
    };
  }

  async createGiftCode({ code, rewardType = "card", cardCode, cardLabel = "", copies = 1, cards = [], maxUses = 10, active = true, expiresAt = null }) {
    const normCards = Array.isArray(cards) ? cards : [];
    const normType = rewardType === "unlock_all"
      ? "unlock_all"
      : (rewardType === "deck" && normCards.length > 0 ? "deck" : "card");
    const res = await this.pool.query(
      `INSERT INTO gift_codes (code, reward_type, card_code, card_label, copies, cards_json, max_uses, used_count, active, expires_at, created_at)
       VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7, 0, $8, $9, $10)
       ON CONFLICT (code) DO NOTHING
       RETURNING *`,
      [code, normType, cardCode, cardLabel, copies, JSON.stringify(normCards), maxUses, Boolean(active), expiresAt ? Number(expiresAt) : null, Date.now()]
    );
    return res.rowCount > 0 ? this._rowToGiftCode(res.rows[0]) : null;
  }

  async getGiftCode(code) {
    const res = await this.pool.query("SELECT * FROM gift_codes WHERE code = $1", [code]);
    return res.rowCount > 0 ? this._rowToGiftCode(res.rows[0]) : null;
  }

  async listGiftCodes() {
    const res = await this.pool.query("SELECT * FROM gift_codes ORDER BY created_at DESC");
    return res.rows.map((r) => this._rowToGiftCode(r));
  }

  async updateGiftCode(code, patch) {
    const sets = [];
    const values = [code];
    let idx = 2;
    if (typeof patch.active === "boolean") {
      sets.push(`active = $${idx++}`);
      values.push(patch.active);
    }
    if (typeof patch.maxUses === "number" && Number.isInteger(patch.maxUses) && patch.maxUses >= 1) {
      sets.push(`max_uses = $${idx++}`);
      values.push(patch.maxUses);
    }
    if (patch.rewardType === "card" || patch.rewardType === "deck" || patch.rewardType === "unlock_all") {
      sets.push(`reward_type = $${idx++}`);
      values.push(patch.rewardType);
    }
    if (Array.isArray(patch.cards)) {
      sets.push(`cards_json = $${idx++}::jsonb`);
      values.push(JSON.stringify(patch.cards));
    }
    if (typeof patch.cardCode === "string" && patch.cardCode.length > 0) {
      sets.push(`card_code = $${idx++}`);
      values.push(patch.cardCode);
    }
    if (typeof patch.cardLabel === "string") {
      sets.push(`card_label = $${idx++}`);
      values.push(patch.cardLabel);
    }
    if (typeof patch.copies === "number" && Number.isInteger(patch.copies) && patch.copies >= 1 && patch.copies <= 3) {
      sets.push(`copies = $${idx++}`);
      values.push(patch.copies);
    }
    if (patch.expiresAt === null || typeof patch.expiresAt === "number") {
      sets.push(`expires_at = $${idx++}`);
      values.push(patch.expiresAt);
    }
    if (sets.length === 0) {
      return this.getGiftCode(code);
    }
    const res = await this.pool.query(
      `UPDATE gift_codes SET ${sets.join(", ")} WHERE code = $1 RETURNING *`,
      values
    );
    return res.rowCount > 0 ? this._rowToGiftCode(res.rows[0]) : null;
  }

  async deleteGiftCode(code) {
    const res = await this.pool.query("DELETE FROM gift_codes WHERE code = $1", [code]);
    return res.rowCount > 0;
  }

  async listGiftCodeRedemptions(code, limit = 50) {
    const n = Math.max(1, Math.min(200, Number(limit) || 50));
    const res = await this.pool.query(
      `SELECT r.player_id, COALESCE(p.display_name, r.player_id) AS display_name, r.redeemed_at
       FROM gift_code_redemptions r
       LEFT JOIN players p ON p.player_id = r.player_id
       WHERE r.code = $1
       ORDER BY r.redeemed_at DESC
       LIMIT $2`,
      [code, n]
    );
    return res.rows.map((r) => ({
      playerId: r.player_id,
      displayName: r.display_name,
      redeemedAt: Number(r.redeemed_at || 0)
    }));
  }

  async redeemGiftCode(code, playerId) {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const gcRes = await client.query("SELECT * FROM gift_codes WHERE code = $1 FOR UPDATE", [code]);
      if (gcRes.rowCount === 0) {
        await client.query("ROLLBACK");
        return { ok: false, error: "code_not_found" };
      }
      const row = gcRes.rows[0];
      if (!row.active) {
        await client.query("ROLLBACK");
        return { ok: false, error: "code_inactive" };
      }
      if (row.expires_at != null && Date.now() > Number(row.expires_at)) {
        await client.query("ROLLBACK");
        return { ok: false, error: "code_expired" };
      }
      const dupRes = await client.query(
        "SELECT 1 FROM gift_code_redemptions WHERE code = $1 AND player_id = $2",
        [code, playerId]
      );
      if (dupRes.rowCount > 0) {
        await client.query("ROLLBACK");
        return { ok: false, error: "already_redeemed" };
      }
      if (Number(row.used_count || 0) >= Number(row.max_uses || 1)) {
        await client.query("ROLLBACK");
        return { ok: false, error: "code_exhausted" };
      }
      await client.query(
        "INSERT INTO gift_code_redemptions (code, player_id, redeemed_at) VALUES ($1, $2, $3)",
        [code, playerId, Date.now()]
      );
      const updRes = await client.query(
        "UPDATE gift_codes SET used_count = used_count + 1 WHERE code = $1 RETURNING *",
        [code]
      );
      if (row.reward_type === "unlock_all") {
        await client.query(
          "UPDATE players SET all_cards_unlocked = TRUE WHERE player_id = $1",
          [playerId]
        );
      }
      await client.query("COMMIT");
      return { ok: true, giftCode: this._rowToGiftCode(updRes.rows[0]) };
    } catch (err) {
      await client.query("ROLLBACK").catch(() => {});
      throw err;
    } finally {
      client.release();
    }
  }

  async close() {
    await this.pool.end();
  }
}

async function createStore() {
  const dbUrl = (
    process.env.DATABASE_URL ||
    process.env.POSTGRES_URL ||
    process.env.POSTGRESQL_URL ||
    ""
  ).trim();
  const store = dbUrl ? new PostgresStore(dbUrl) : new JsonStore();
  await store.init();
  return store;
}

module.exports = { createStore, defaultStats };
