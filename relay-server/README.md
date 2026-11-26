# Power of Chaos — Online Platform & Relay Server (Render)

Full online backend for **Yu-Gi-Oh! Power of Chaos Remake**:
- Player accounts (Guest with permanent 6-digit Player ID, Username + Password, and Google Sign-In)
- Persistent player profiles & card collection showcase (all owned cards + counts + stats)
- Player directory, search by Player ID, friend requests, friends list, and live online status
- Direct duel invitations + 6-digit room-code WebSocket duel relay

## Render Configuration
- **Root Directory**: `relay-server`
- **Build Command**: `npm install`
- **Start Command**: `npm start`
- **Health Check Path**: `/health`

### Optional Environment Variables (in Render Dashboard → Environment)
1. **Permanent Database (Recommended)**: Add `DATABASE_URL` from a free PostgreSQL database (Render Postgres, Neon, or Supabase) so player accounts, IDs, cards, and friends never reset when Render redeploys. *(Without `DATABASE_URL`, it automatically uses local JSON storage.)*
2. **Google Sign-In**: Add `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` (Web OAuth Client with redirect URI `https://poc-online-relay.onrender.com/auth/google/callback`) and `PUBLIC_BASE_URL=https://poc-online-relay.onrender.com`.
3. **Stable Login Sessions**: Add `SESSION_SECRET` (any long random string) so player tokens remain valid across server restarts.
