<!-- markdownlint-disable -->

Love the idea—“phone-call style” messaging with zero server storage. Below is a concrete, privacy-first design you can ship.

# 1) Core principles

- **No content on servers**: server only does *discovery + signaling*; never sees message payloads.
- **Ephemeral sessions**: chats exist only while both peers are online; session keys die when either leaves.
- **Identity = keys, not PII**: usernames are public aliases; trust is anchored in device/account keys.
- **Metadata minimization**: store only what’s essential for reachability; aggressively rotate/expire the rest.

# 2) System components

- **Directory/Signaling server** (stateless-ish):
  - Maps `username → currently online deviceIDs` (volatile in-memory store).
  - Handles friend requests, session offers (SDP/ICE), push wakeups.
  - Keeps *no message content, no chat history*.
- **TURN/STUN**:
  - NAT traversal for P2P; fallback to **TURN relay** (still E2E-encrypted).
- **Clients (devices)**:
  - Hold keys, contact list, and minimal logs **locally**.
  - Establish **WebRTC/WebTransport/QUIC** data channels for live encrypted messages.

# 3) Keys & identity

- **Account keypair (AK)** (long-term, per user): Ed25519 (identity). Stored on each device after trusted enrollment.
- **Device keypair (DK)** (long-term, per device): Ed25519 (device auth) + Curve25519 (X25519) for ECDH.
- **Pre-keys** (ephemeral, per device): short-lived X25519 bundle advertised *only while online* to enable fast AKE (Authenticated Key Exchange).
- **Session keys**: derived via **X3DH → Double Ratchet** (Signal-style) *or* Noise IK/XX + Double Ratchet for continuous PFS.

> Server only ever sees *public* AK/DK and transient pre-keys during online presence.

# 4) User & device lifecycle

**Register new account (on first device)**

1. Client generates `AK`, `DK`, and an initial pre-key bundle.
2. Pick a `username` (check availability).
3. Server records: `username`, `AK_pub`, `deviceID`, `DK_pub`. (No private keys. No PII.)
4. Device stores its `AK_priv`, `DK_priv` locally (Secure Enclave/KeyStore).

**Add another device to same account**

- Use **QR handoff** (online, both devices present):
  1. Old device displays a short-lived *enrollment token* (signed with `AK_priv`) as a QR.
  2. New device scans, proves possession by completing a mutual challenge signed by its `DK_priv`.
  3. Server verifies `AK_pub` signature and links the new `deviceID` to the account.
- Or **OTP handoff** (if remote), still signed by `AK_priv`.

# 5) Contacting someone

**Add contact**

1. Enter `usernameB`.
2. Server returns “online?” + **safety number** (a hash of both AK_pubs) so clients can verify out-of-band if they wish.

**First connect (not yet friends)**

1. A → Server: “request session with usernameB”.
2. If B has any online devices, server forwards a **connection request** (no content).
3. B accepts → both sides fetch each other’s **pre-keys** (from server’s volatile store).
4. Run **X3DH/Noise** to derive session key, then switch to **Double Ratchet** on the P2P channel.

**Friends (subsequent connects)**

- If B is offline:
  - Server triggers **push wakeup** using a stored, *rotating, blinded push token* (no username in payload).
  - If B comes online within a window, signaling proceeds; else A sees “user offline”.

# 6) Messaging channel

- **Transport**: WebRTC DataChannel (desktop/mobile/web) or QUIC (native).
- **Encryption**: Double Ratchet (PFS + post-compromise security). Message headers contain only a counter and ratchet data—no metadata like names.
- **No storage policy**:
  - Clients keep messages only in memory (ring buffer). On app close/OS kill/lock → buffer cleared.
  - Optional “blur mode”: render from RAM; screenshots/notifications redact content.

# 7) What the server stores (and how long)

- Persistent (minimal):
  - `username`, `AK_pub`
  - Per device: `deviceID`, `DK_pub`, **public** capabilities (supported transports), and **rotating** push token envelope (opaque).
- Ephemeral (memory; TTL seconds–minutes):
  - Online presence: `username → [deviceIDs]`
  - Pre-key bundles (public) for online devices
  - Outstanding session offers (SDP/ICE), expiring quickly
- **Never**: messages, contact lists, safety numbers, IP logs (beyond short rolling window for abuse control).

# 8) Privacy, threat model & mitigations

- **Server compromise**: only public keys and minimal routing info leak—no content, no history.
- **MITM on first contact**: prevent via **authenticated AKE** (X3DH ties to AK) + show **safety number**; allow optional QR key verify when meeting IRL.
- **Metadata leakage (IP)**: prefer **TURN-only** mode to hide peer IPs from each other; or multi-hop relays. Allow user toggle.
- **Spam/abuse**: require “know the exact username” + rate-limits + PoW/puzzles for first contact; auto-blocklist locally.
- **Device loss**: revoke a device by signing a **revocation** with `AK_priv` from another device; server stops advertising that `deviceID`.
- **Push privacy**: store tokens encrypted with a server key; rotate frequently; payloads carry only a wake hint.

# 9) Notifications without storing chats

- Store only a **friendship flag** on both accounts (signed by both AKs at the moment of friending). This lets server send “wake” pings to offline friends—still no content or history.
- Friendship removal = both sides publish a signed “unfriend” to the server.

# 10) Data model (lean)

```txt
User {
  username: string (unique),
  ak_pub: bytes
}

Device {
  deviceId: string,
  username: string (FK),
  dk_pub_sign: bytes,
  dk_pub_eph: bytes,
  transportCaps: bitmask,
  pushTokenEnvelope: bytes (opaque, rotated)
}

Presence (RAM, TTL) {
  username -> [deviceId...]
  deviceId -> {preKeyBundle[], iceCandidates, sdpOffer/Answer}
}

Friendship {
  userA, userB, signedByA, signedByB, createdAt, revokedAt?
}
```

# 11) Protocol sketch (first secure session)

1. **Discover**: A asks server for B’s online devices.
2. **Offer**: A → server → B: SDP offer + A’s pre-key ref.
3. **Accept**: B responds with SDP answer + pre-key ref.
4. **X3DH**: Both pull each other’s pre-keys (public), compute shared secret bound to `AK_pub`.
5. **Double Ratchet**: Start ratchet; verify **safety number** (optional).
6. **Chat**: E2E over DataChannel; no persistence.

# 12) Tech stack options

- **Mobile**: Kotlin/Jetpack + iOS Swift; **React Native** if cross-platform.
- **Transport**: WebRTC (Pion/aiortc/libwebrtc) or QUIC (Quiche/msquic).
- **Crypto**: libsodium / Noise Protocol Framework / libsignal.
- **Server**: Go/Rust/Node—small service with TLS, Redis (in-memory) for presence; Postgres for persistent minimal rows.
- **Push**: APNs / FCM using opaque tokens.

# 13) “No storage” UX details

- Show a prominent “This chat is ephemeral” banner.
- Disable screenshots by default (best-effort on Android; can’t fully prevent on iOS/web).
- When either side disconnects: **both** tear down ratchet state and wipe RAM buffers.
- Provide a “panic close” (instant memory wipe) and an inactivity timeout.

# 14) Compliance & ops

- Publish a short **Data Retention Policy** (presence ≤ N minutes; logs ≤ 24–72h for DoS debugging; configurable to 0 in strict mode).
- Open-source client crypto; third-party audits for the protocol.
- Enable **transparency reports** (counts only, no content).

# 15) MVP cut-list (2–3 sprints)

- ✅ Account creation, username claim, AK/DK gen & local secure storage  
- ✅ Add device via QR handoff  
- ✅ Friend request + accept (with safety number)  
- ✅ Online-only chat using WebRTC + Double Ratchet (in-memory buffers)  
- ✅ TURN fallback; basic push wake (friends only)  
- ✅ Device revoke; panic close; ephemeral presence

# 16) Edge cases to decide now

- **Multi-device fan-out**: when B has 3 devices online, pick one (last active) or ring all?
- **Offline invites**: do you allow A to create a *pending* friend request that wakes B? (It leaks “A knows B’s username”; still no content.)
- **Strict mode**: TURN-only relaying, zero server logs, no push (fully pull-based). Heavier battery, best privacy.

---

If you want, I can sketch a minimal Go/Node signaling server (REST + WebSocket), the X3DH/Noise handshake message formats, and a React Native client scaffold with WebRTC + libsodium—just say the word and I’ll drop the starter code.

---

Got it—let’s bake those 3 discovery modes cleanly into the protocol, server logic, and UX without breaking the “no storage of content” promise.

# Discovery modes (account-level, overridable per-contact)

1) **Public**  
   - Directory shows: `username`, **online/offline**.  
   - Anyone can initiate a request when you’re online.  
   - Offline lookups return “offline” (prevents guesswork about existence).

2) **Default (privacy-preserving)**  
   - Server only responds to exact username with:  
     - **Online** → can send request  
     - **Not found** → indistinguishable between “offline” and “no such user”  
   - No public directory listing.

3) **Strict (username + Friend Verification Code)**  
   - First contact requires: `username` **and** **FVC** (short code).  
   - If either is wrong (or user is offline), server returns **Not found**.  
   - Prevents **user enumeration** and spray-requests.

> Users can optionally whitelist specific friends to bypass strict for subsequent reconnects.

---

# How the Friend Verification Code (FVC) works (privacy-first)

- **Goal**: server can verify a short code for a username without storing secrets per user.  
- **Design**:
  - Let `seed = HMAC(server_secret, ak_pub || fvc_salt)` (no PII, deterministic; `fvc_salt` is a random per-user 16B value stored with the profile).
  - Use **TOTP** (time-based one-time password) over `seed` with a **60–120s** step to generate a 6–8 digit/char code.  
  - Code format: digits or Crockford base32 (better for voice).  
  - Users can switch to **Static FVC** (printed once) if they dislike time codes—store **only a salted hash** of the static string.
- **Sharing UX**: show a QR/deep link that bundles `username + current FVC`, or display the code as text. Never shown in notifications.

---

# Server behavior by mode (high-level)

**/discover (POST)**  
Input: `{ username, fvc? }`  
Output (all modes): `{ result: "ok" | "not_found", online?: boolean }`

- **Public**:  
  - If `username` exists: return `{ ok, online }`.  
- **Default**:  
  - If `username` **online**: `{ ok, online: true }`; otherwise `{ not_found }`.  
- **Strict**:  
  - Validate `fvc`: if correct **and** user online → `{ ok, online: true }`; else `{ not_found }`.

**/requestSession (POST)**  
Input: `{ fromDeviceId, toUsername, fvc? }`  

- Gate exactly as `/discover`. If gate passes, forward request to target’s online devices (or ring policy).

**/mode (PUT, auth required)**  
Input: `{ mode: "PUBLIC" | "DEFAULT" | "STRICT", strictOptions? }`  

- `strictOptions`: `{ scheme: "TOTP" | "STATIC", codeLength?: 6|7|8 }`  
- Rotate `fvc_salt` on switch to STRICT (TOTP), or update hashed code if STATIC.

---

# Data model additions (minimal + privacy conscious)

```
User {
  username: string,           // unique
  ak_pub: bytes,
  privacy_mode: enum,         // PUBLIC | DEFAULT | STRICT
  fvc_mode: enum,             // TOTP | STATIC (only if STRICT)
  fvc_salt: bytes?,           // random 16B for TOTP seed derivation (no secret per se)
  fvc_static_hash: bytes?     // if STATIC; e.g., scrypt(hash)
  friendship: [usernames]?     // OPTIONAL: signed friendship edges (for wake & bypass)
}

Presence (RAM, TTL)
  username -> [deviceIDs] // online devices
```

> No message content. Presence and offers remain ephemeral (memory/short TTL).

---

# UX rules & copy (crisp)

- **Mode picker** during onboarding + settings, clearly explained:
  - *Public:* easy to reach, shows online/offline.
  - *Default:* can only be reached if you’re online and they know your username.
  - *Strict:* requires your username **and** your code; best for journalists/targets.
- **Share contact**:
  - Public/Default: share username (QR/text).  
  - Strict: share *“username + short code”* (as QR that auto-fills both).
- **Errors (user-visible)**: always say “User not found or offline.” (never reveal which).  
- **Friends**: after mutual accept, subsequent wake/requests don’t require FVC (unless user keeps “Always FVC” toggle on).

---

# Signaling & notifications with modes

- **Public**: offline lookups may return `online:false`; you can optionally allow “offline invite” (sends privacy-minimal wake).  
- **Default & Strict**:
  - **No offline invites** before friendship.  
  - After friendship, server can send a **wake ping** (opaque token only).

---

# Anti-abuse safeguards

- **Rate limits** on `/discover` and `/requestSession` per IP/device/account.  
- **Proof-of-Work** or CAPTCHA on repeated failures in STRICT.  
- **Backoff** on any `not_found` to make enumeration expensive.  
- **Local autoblock** for N failed requests from same origin.

---

# Multi-device & “ring” policy

- Public: can ring **all online devices** (throttled) or last-active first.  
- Default/Strict: same, but only after gating passes.  
- For **Strict**, the FVC is checked **once per request**, not per device.

---

# Migration & compatibility

- Default is **DEFAULT** mode for all new users.  
- Older clients (pre-modes) behave as **DEFAULT**.  
- If a user flips to **STRICT**, server immediately enforces FVC on first-contact requests; existing friends unaffected unless “Always FVC” is on.  
- Rotating `fvc_salt` invalidates old QR links—warn the user before rotate.

---

# API sketches (concise)

```http
POST /discover
{ "username":"alice", "fvc":"123456" }  -> { "result":"ok", "online":true }
                                      or { "result":"not_found" }

POST /requestSession
{ "toUsername":"alice", "fvc":"123456", "offer":{...} } -> { "result":"delivered" | "not_found" }

PUT /mode
{ "mode":"STRICT", "strictOptions":{"scheme":"TOTP","codeLength":6} } -> { "result":"ok" }

GET /myMode  -> { "mode":"STRICT", "strictOptions":{"scheme":"TOTP","codeLength":6} }
```

---

# Cryptography fit

- Modes do **not** change E2E: keep **X3DH/Noise + Double Ratchet** for sessions.  
- FVC sits **before** key exchange as an *access gate*; never used as crypto material.  
- TOTP window: 60–120s; skew tolerance ±1 step.  
- If you want zero per-user secrets on server: the HMAC-seed approach above + stored `fvc_salt` is enough.

---

# Tests you should run

- **Enumeration**: brute force usernames under all modes → only Public should leak “offline/online”, Default/Strict must look identical for “offline vs nonexistent”.  
- **Clock skew**: Strict/TOTP behavior with ±3 min skew.  
- **Rate limit**: burst `/discover` & `/requestSession` → throttled.  
- **QR replay**: expired TOTP QR must fail.  
- **Mode flips** mid-request: ensure deterministic “not_found”.

---

# Quick client UX checklist

- Mode badge on profile (Public / Default / Strict).  
- One-tap “Share contact” → QR + copy button.  
- Strict: show **live code** with countdown; accessible description for reading aloud.  
- Settings: “Always require FVC (even for friends)” toggle for high-risk users.  
- Error toasts use neutral wording: “User not found or offline.”

If you want, I can draft the exact server handlers (pseudo-Go or Node) for `/discover` and `/requestSession` with the gating logic and TOTP verification next
---

## Competitors & Similar Apps

### **Wickr Me**

- Notable for **zero-knowledge logs** (server stores nothing) and **millisecond-level ephemeral chats**, ensuring messages vanish immediately after reading. Also offers screenshot protection and large file sharing.  [oai_citation:0‡Atlant | Security](https://atlantsecurity.com/learn/top-7-secure-messaging-apps/?utm_source=chatgpt.com) [oai_citation:1‡Code Brew Labs](https://www.code-brew.com/how-to-build-an-anonymous-messaging-app/?utm_source=chatgpt.com)

### **Confide**

- An **encrypted, self-destructing messenger** designed to mirror the privacy of spoken word. Notable features include **screenshot-proof messages** that disappear after being read.  [oai_citation:2‡Confide](https://getconfide.com/?utm_source=chatgpt.com)

### **Dust (formerly Cyber Dust)**

- Focuses on privacy by **automatically deleting messages shortly after reading**, with anti-screenshot protections and privacy-first design.  [oai_citation:3‡ClickUp](https://clickup.com/blog/secure-messaging-apps/?utm_source=chatgpt.com)

### **Snapchat**

- The pioneering **disappearing messages** app—texts, photos, and media vanish after viewing or within 24 hours by default. Very mainstream, but ephemeral by design.  [oai_citation:4‡AirDroid](https://www.airdroid.com/parent-control/apps-with-disappearing-messages/?utm_source=chatgpt.com) [oai_citation:5‡Kidslox](https://kidslox.com/guide-to/disappearing-messages/?utm_source=chatgpt.com) [oai_citation:6‡WIRED](https://www.wired.com/story/how-to-send-messages-that-automatically-disappear?utm_source=chatgpt.com)

### **Telegram (Secret Chats)**

- Offers **Secret Chats**: end-to-end encrypted sessions with customizable self-destruct timers. Messages vanish post-viewing and don’t sync across devices.  [oai_citation:7‡Popular Science](https://www.popsci.com/send-self-destructing-messages/?utm_source=chatgpt.com) [oai_citation:8‡WIRED](https://www.wired.com/story/how-to-send-messages-that-automatically-disappear?utm_source=chatgpt.com)

### **Session**

- A decentralized, anonymous messenger: **no phone, email, or PII** required. Uses blockchain-based transport and strong privacy protocols. Not strictly ephemeral but maximizes metadata protection.  [oai_citation:9‡Wikipedia](https://en.wikipedia.org/wiki/Session_%28software%29?utm_source=chatgpt.com) [oai_citation:10‡arXiv](https://arxiv.org/abs/2002.04609?utm_source=chatgpt.com)

### **Olvid**

- Privacy-focused app storing **no personal data**, and designed to prevent server compromise. While not ephemeral in message storage, it uses a decentralized model with extremely strong privacy guarantees.  [oai_citation:11‡Wikipedia](https://en.wikipedia.org/wiki/Olvid_%28software%29?utm_source=chatgpt.com)

### **Snow**

- A multimedia messaging app, similar to Snapchat, that features **self-destructing photo and message features** (e.g., images vanish after 48 hours).  [oai_citation:12‡Wikipedia](https://en.wikipedia.org/wiki/Snow_%28app%29?utm_source=chatgpt.com)

### **OnionShare**

- A Tor-based P2P tool for secure **ephemeral chat and file sharing**, commonly used for anonymous file transfers—less about chat UX, more about covert sharing.  [oai_citation:13‡Wikipedia](https://en.wikipedia.org/wiki/OnionShare?utm_source=chatgpt.com)

### **RetroShare**

- A **peer-to-peer, friend-to-friend encrypted chat and file-sharing network**. Chats and transfers occur directly between trusted nodes; no central server storage.  [oai_citation:14‡Wikipedia](https://en.wikipedia.org/wiki/Retroshare?utm_source=chatgpt.com)

---

## Quick Comparison Table

| App / Service   | Primary Focus                          | Ephemerality       | Anonymity / Privacy Highlights                          |
|-----------------|-----------------------------------------|---------------------|----------------------------------------------------------|
| Wickr Me        | Secure corporate-grade chat            | Yes, ultra short    | Zero-knowledge logs, screenshot blockade                |
| Confide         | Ephemeral, screenshot-proof chat       | Yes, after read     | Encrypted, no screen capture                            |
| Dust            | Privacy-first auto-deleting messaging | Yes, short-lived    | Anti-screenshot, delete after read                      |
| Snapchat        | Social ephemeral media & chat          | Yes, default        | Instant vanish; wide adoption, less technical encryption |
| Telegram (Secret Chat) | Secure chats with timers        | Yes, optional       | E2EE + self-destruct60; device-local                    |
| Session         | Anonymous encrypted messaging          | No *by default*     | No PII, decentralized, strong metadata protection       |
| Olvid           | Highly secure messaging                | No *non-ephemeral*  | No personal data collected, anti-backdoor architecture  |
| Snow            | Multimedia ephemeral chat              | Yes, short timeout  | Self-destructing media with fun filters                 |
| OnionShare      | File sharing + chat over Tor           | Yes, ephemeral      | Full anonymity via Tor, P2P                             |
| RetroShare      | F2F network encrypted chat/share       | Optional ephemeral  | Peer-to-peer, no central tracking                       |

---

### How Your App Can Differ

Your project is unique by offering:

- **Live, ephemeral messaging with no storage anywhere**—for both text and files (or camera capture) in real time.
- **Strict control over presence & history**—zero persistence once either party disconnects.
- **Flexible discovery modes**—public, default, and strict privacy.
- UX-first with optional **friend verification codes**, pushing privacy beyond just auto-deletion.

---

If you’d like, I can help you craft a one-liner positioning statement differentiating your app from one or two of the closest competitors—just say the word!

Exactly 👌 — the smartest path is to **ship the core MVP** (what you already scoped) and then **layer in competitor features one by one**. That way, you keep the app lean, test adoption early, and show continuous progress.  

Here’s a suggested **incremental feature roadmap** based on what competitors do:

---

## 🚀 Phase 1 (MVP — what you already have)

- **Account + single device** (username + device token).  
- **Friends list** (manual add).  
- **WebSocket live messaging** (text + file/image + camera capture).  
- **Ephemeral session**: messages only in memory, vanish on disconnect.  

---

## 🔒 Phase 2 (Privacy Basics)

- **Auto-delete timers** (like Telegram Secret Chats):  
  - Per-chat setting: 5s, 1m, 1h, 1d.  
  - Messages deleted locally on both ends after timer expires.  
- **No server logs**: keep only presence in memory; wipe events aggressively.  
- **“Panic close”**: one tap to wipe chat buffer immediately.  

---

## 📸 Phase 3 (User Trust & Control)

- **Screenshot protection**:  
  - On mobile: use platform APIs to block or detect screenshots (Android `FLAG_SECURE`, iOS screenshot detection callbacks).  
  - On web: watermark messages with friend’s username/session ID (makes leaks traceable).  
- **Safety number verification** (like Signal): show hash of keys for manual verification.  
- **Friend verification codes (FVC)**: Strict discovery mode as you designed.  

---

## 🔗 Phase 4 (Competitive Catch-up)

- **Self-destructing media** (like Snapchat/Dust):  
  - Images/videos can be opened once; vanish after view.  
- **Presence blur**: option to show only “recently active” instead of exact online.  
- **Multi-device sync**: support multiple linked devices per account.  

---

## 🌐 Phase 5 (Differentiators vs Competitors)

- **Custom discovery modes** (already in your design).  
- **Metadata hiding**: route all traffic through TURN relays by default.  
- **Optional group ephemeral chats**: small groups with vanish-on-exit.  
- **E2E encryption (Double Ratchet)** layered on top of WebSocket/WebRTC.  

---

## 🛡️ Phase 6 (Enterprise / Advanced Privacy)

- **Zero-trust file sharing**: large files chunked + E2EE, no server persist.  
- **Decentralized relay mode** (peer relays, Onion-style routing).  
- **Audit logs for nothing**: transparent proof that you don’t store user data.  

---

## 📊 Competitor Mapping

- **Phase 2–3** = parity with **Telegram Secret Chats / Confide / Dust**.  
- **Phase 4** = parity with **Snapchat / Wickr Me**.  
- **Phase 5–6** = surpass with **strict discovery modes + live-only sessions**.  

---

⚡️ Key idea: **you don’t have to chase all features at once** — your edge is “like a phone call but for chat”: live, ephemeral, no storage. Every added feature should *extend* that uniqueness, not dilute it.

---

Would you like me to prepare a **feature priority board** (like Trello/Notion style, Must-have → Nice-to-have) so you can track exactly which competitor feature to build in which sprint?

Perfect — here’s a **full feature board** laid out like a Trello/Notion roadmap, organized by **phases**, **priority tiers**, and with **details for each feature**. You can use this directly in your project management tool.  

---

# 🗂️ AnonChat Feature Board

---

## ✅ Phase 1 — Core MVP (Must-have)

*Goal: Get a working prototype live for early testing.*

- **Account & Identity**
  - Username registration (unique).
  - Single device per account (device token).
  - JWT login (short-lived sessions).

- **Friends**
  - Add friend manually by username.
  - Friends list with online/offline badge (in-memory presence).

- **Messaging**
  - Live WebSocket messaging (text only).
  - File sending (image rendered inline, others downloadable).
  - Camera capture → in-memory blob → send (no disk storage).
  - Delivery status (sent/offline).

- **Ephemerality**
  - Messages live in memory only (RAM buffer).
  - Messages vanish on disconnect or app close.
  - No server storage of content.

---

## 🔒 Phase 2 — Privacy Basics (Should-have, competitor catch-up)

*Goal: Strengthen privacy, match baseline of Wickr/Telegram.*

- **Auto-delete timers**
  - Per-chat configurable: 5s, 1m, 1h, 1d.
  - Deletes from both sender & recipient devices.
  - Visual countdown markers.

- **Server minimalism**
  - Presence only (RAM).
  - Wipe all events immediately after relay.
  - No logs of messages or metadata (except rate limiting counters).

- **Panic close**
  - One-tap button to wipe session buffer.
  - Optional "shake to wipe" on mobile.

---

## 📸 Phase 3 — Trust & Control (Must-have for differentiation)

*Goal: Protect users against leaks & build trust.*

- **Screenshot protection**
  - Android: `FLAG_SECURE` to block screenshots.
  - iOS: detect screenshot events, show warning to user.
  - Web: dynamic watermark (friend’s username/session hash).
  - Notify peer if screenshot attempt detected.

- **Friend Verification Codes (FVC)**
  - Strict discovery mode requires username + FVC.
  - FVC delivered via QR or one-time code.
  - TOTP or static modes.

- **Safety numbers**
  - Show hash of both users’ public keys.
  - Manual verification option (like Signal).

---

## 🔗 Phase 4 — Feature Parity with Big Players (Could-have)

*Goal: Reach parity with Snapchat / Telegram Secret Chats.*

- **Self-destructing media**
  - Open-once images/videos.
  - Auto-wipe after view.
  - Visual “tap to view” blur.

- **Presence controls**
  - “Exact online/offline” OR “last active recently”.
  - Stealth mode: appear offline while still reachable.

- **Multi-device support**
  - Add device via QR/OTP handoff.
  - Linked devices sync presence & friend list.
  - Messages remain ephemeral (per session).

- **Friendship model**
  - Requests + accepts (instead of unilateral add).
  - Block/report options.

---

## 🌐 Phase 5 — Differentiators (Must-have for unique brand)

*Goal: Go beyond existing competitors.*

- **Custom discovery modes**
  - Public (username + online/offline).
  - Default (username only, online = connect).
  - Strict (username + FVC).
  - User toggle in profile settings.

- **Metadata hiding**
  - All traffic via TURN relay (hide IPs).
  - Optional “direct P2P” mode for low-latency.

- **Small group ephemeral chats**
  - 3–10 users max.
  - All messages vanish at disconnect.
  - Auto-delete timers apply group-wide.

- **In-app ephemeral notes**
  - Scratchpad that wipes on exit.
  - Shareable temporarily in chats.

---

## 🛡️ Phase 6 — Advanced Privacy / Enterprise Features (Nice-to-have)

*Goal: Long-term trust, enterprise security, and compliance edge.*

- **E2E Encryption**
  - Implement Noise / Signal Double Ratchet.
  - Rotate session keys each connection.
  - Safety numbers per session.

- **Chunked file transfer**
  - Support >10 MB files in encrypted chunks.
  - Memory buffer only, no server storage.

- **Anonymous sign-in**
  - Account with no username (random alias).
  - Temporary “burner” mode.

- **Decentralized relays**
  - Onion-routed relays (Session/OnionShare-style).
  - P2P fallback for trusted peers.

- **Audit / Transparency**
  - Publish retention policy.
  - Server-side open source for verification.
  - “Data trust” dashboard (show nothing stored).

---

# 📊 Board View (Trello-Style)

### **To Do**

- Auto-delete timers
- Screenshot protection
- Friend Verification Codes
- Safety numbers
- Self-destructing media
- Presence controls
- Multi-device support
- Discovery modes
- Metadata hiding
- Group ephemeral chats
- Encryption (Noise/Signal)
- Chunked file transfer
- Anonymous sign-in
- Decentralized relays
- Audit dashboard

### **In Progress**

- MVP core (account, friends, text/file, camera, ephemeral)

### **Done**

- WebSocket backbone  
- Friends list + presence  
- In-memory ephemeral sessions  

---

⚡️ **Implementation suggestion:** Treat **Phase 2 + 3** as your immediate roadmap (auto-delete + screenshot protection + FVC). That alone puts you ahead of **Confide/Dust**.  

Would you like me to **rank the Phase 2–3 features by development complexity** (easy → hard) so you can prioritize engineering sprints?

Love it. Going native gives you the control you need for **hard memory wipes**, **tight networking**, and **zero residue**. Here’s a practical, ship-ready plan with platform-specific APIs and tiny code snippets you can drop in.

# Architecture choices (common)

- **Transport:** WebRTC DataChannel (preferred) or raw TLS/QUIC socket. Keep **no-cache**, **no logs**, and **no persistent queues**.  
- **Keys:** device/account keys in **Secure Enclave/Keychain (iOS)**, **Android Keystore**. Session keys in **RAM only**.  
- **Buffers:** use **direct/unsafe** buffers so you can **explicitly zero** and release them (NDK/C).  
- **Images/files:** capture → operate **in-memory** → send → **zero buffers**. Do **not** write temp files.  
- **Push:** silent/high-priority “wake pings.” Do not include content in notifications.  
- **Panic:** one action that:  
  1) **Zeroes all in-memory state** (messages, keys, images)  
  2) **Closes sockets** and **kills background tasks**  
  3) **Tears down views** and **clears OS caches** you control  
  4) Optionally **revokes device session** on server

---

# Android (Kotlin + a little NDK)

## Hardening the surface

- **Block screenshots & Recents thumbnail**

  ```kotlin
  window.setFlags(
      WindowManager.LayoutParams.FLAG_SECURE,
      WindowManager.LayoutParams.FLAG_SECURE
  )
  ```

- **Disable backups & auto-restore** (AndroidManifest.xml)

  ```xml
  <application
      android:allowBackup="false"
      android:fullBackupContent="false"
      android:usesCleartextTraffic="false"
      android:supportsRtl="true"
      android:networkSecurityConfig="@xml/network_security_config">
  </application>
  ```

- **No logs in release**
  - Strip logs with R8/proguard, wrap logging behind `if (BuildConfig.DEBUG)`.

## Memory discipline

- **Direct byte buffers for sensitive data**

  ```kotlin
  val buf = ByteBuffer.allocateDirect(1_048_576) // 1MB
  // ... use buf ...
  // Zero and free
  fun wipe(bb: ByteBuffer) {
      val dup = bb.duplicate()
      while (dup.remaining() > 0) dup.put(0.toByte())
      (bb as sun.nio.ch.DirectBuffer).cleaner()?.clean()
  }
  ```

- **NDK secure zero (recommended)**  
  Use a tiny C++ layer with `memset_s`/`explicit_bzero`:

  ```cpp
  extern "C" JNIEXPORT void JNICALL
  Java_com_app_Secure_wipe(JNIEnv*, jclass, jobject byteBuffer, jint len) {
      void* p = env->GetDirectBufferAddress(byteBuffer);
      if (p && len > 0) explicit_bzero(p, (size_t)len);
  }
  ```

- **Key storage**: Android Keystore

  ```kotlin
  val kpg = KeyPairGenerator.getInstance("EC","AndroidKeyStore")
  val spec = KeyGenParameterSpec.Builder("AK",
      PURPOSE_SIGN or PURPOSE_VERIFY)
      .setIsStrongBoxBacked(true) // if available
      .setUserAuthenticationRequired(false)
      .build()
  kpg.initialize(spec); val kp = kpg.generateKeyPair()
  ```

## Camera capture (no file on disk)

- **CameraX ImageCapture to in-memory**

  ```kotlin
  imageCapture.takePicture(
      cameraExecutor,
      object : ImageCapture.OnImageCapturedCallback() {
          override fun onCaptureSuccess(image: ImageProxy) {
              val jpegBytes = yuvToJpegBytes(image) // in-memory compress
              image.close()
              sendAndWipe(jpegBytes) // send → zero out byte[]
          }
      }
  )
  ```

- Avoid `OutputFileOptions` to file; convert YUV → JPEG in RAM.

## Networking (no caches, no logs)

- **OkHttp pinned + no cache**

  ```kotlin
  val client = OkHttpClient.Builder()
      .cache(null)
      .certificatePinner(
          CertificatePinner.Builder()
              .add("your.domain", "sha256/AAAAAAAA...=")
              .build()
      ).build()
  ```

- **WebRTC DataChannel**: set **maxRetransmits**, disable built-in logging in release.  
- **Foreground Service** for active chat → keeps process alive; **quick settings tile** for **Panic**.

## App lifecycle wipes

- Hook **onTrimMemory**, **onStop**, **onDestroy** to wipe volatile stores.

  ```kotlin
  override fun onTrimMemory(level: Int) { SessionMemory.wipeAll() }
  override fun onStop() { SessionMemory.wipeAll() }
  ```

## Panic button (global)

```kotlin
object Panic {
    fun trigger() {
        try { Transport.closeAll() } catch (_: Throwable) {}
        try { SessionMemory.wipeAll() } catch (_: Throwable) {}
        try { UI.resetToLockedScreen() } catch (_: Throwable) {}
        // Optional: tell server to revoke session
        AppScope.launch { Api.revokeThisDevice() }
        // Option: finish & kill (harsh, effective)
        exitProcess(0)
    }
}
```

---

# iOS (Swift / SwiftUI)

## Hardening the surface

- **Block screen recordings + blur app switcher snapshot**

  ```swift
  // Blur when backgrounded
  class BlurProtector {
      private var blur = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
      func install() {
          NotificationCenter.default.addObserver(forName: UIScene.willResignActiveNotification, object: nil, queue: .main) { _ in
              guard let w = UIApplication.shared.windows.first else { return }
              self.blur.frame = w.bounds; w.addSubview(self.blur)
          }
          NotificationCenter.default.addObserver(forName: UIScene.didBecomeActiveNotification, object: nil, queue: .main) { _ in
              self.blur.removeFromSuperview()
          }
      }
  }
  ```

- **Detect capture attempts** (best-effort)

  ```swift
  NotificationCenter.default.addObserver(forName: UIScreen.capturedDidChangeNotification, object: nil, queue: .main) { _ in
      if UIScreen.main.isCaptured { showCaptureAlert() }
  }
  ```

- **Disable backups**: mark any temp container as `.noFileProtection` and don’t write chat to disk at all.

## Memory discipline

- **Keychain + Secure Enclave**

  ```swift
  // Use SecKeyCreateRandomKey with kSecAttrTokenIDSecureEnclave
  ```

- **Zeroing Data**

  ```swift
  extension Data {
      mutating func wipe() {
          self.withUnsafeMutableBytes { ptr in
              guard let base = ptr.baseAddress else { return }
              memset_s(base, self.count, 0, self.count)
          }
      }
  }
  ```

- **Avoid autorelease spikes**: wrap heavy buffers in `@autoreleasepool { ... }`.

## Camera capture (no Photos write)

- **AVCapturePhotoOutput** → in-memory `Data`

  ```swift
  class PhotoHandler: NSObject, AVCapturePhotoCaptureDelegate {
      var onPhoto: ((Data)->Void)?
      func photoOutput(_ output: AVCapturePhotoOutput,
                       didFinishProcessingPhoto photo: AVCapturePhoto,
                       error: Error?) {
          if let d = photo.fileDataRepresentation() {
              onPhoto?(d) // send → wipe()
          }
      }
  }
  ```

- Do **not** save to `PHPhotoLibrary`.

## Networking (no caches, no logs)

- **URLSession ephemeral configuration**

  ```swift
  let config = URLSessionConfiguration.ephemeral
  config.requestCachePolicy = .reloadIgnoringLocalCacheData
  config.urlCache = nil
  let session = URLSession(configuration: config, delegate: PinningDelegate(), delegateQueue: nil)
  ```

- **TLS pinning** in `URLSessionDelegate` with `SecTrustEvaluate`.

## App lifecycle wipes

- **applicationWillResignActive / sceneWillResignActive** → wipe + blur.

  ```swift
  func sceneWillResignActive(_ scene: UIScene) {
      SessionMemory.shared.wipeAll()
  }
  ```

## Panic button

```swift
enum Panic {
    static func trigger() {
        Transport.shared.closeAll()
        SessionMemory.shared.wipeAll()
        UI.resetToLock()
        // Optional server revoke
        Task { await API.revokeThisDevice() }
        // Crash-safe terminate
        exit(EXIT_SUCCESS)
    }
}
```

---

# Shared “SessionMemory” pattern (simple & safe)

Keep *all* volatile things behind a single façade so one call wipes everything.

**Kotlin**

```kotlin
object SessionMemory {
    private val messageBuffers = mutableListOf<ByteBuffer>()
    private var sessionKey: ByteArray? = null

    fun registerBuffer(bb: ByteBuffer) { messageBuffers += bb }
    fun setSessionKey(k: ByteArray) { sessionKey = k }

    fun wipeAll() {
        try { sessionKey?.fill(0) } catch (_:Throwable) {}
        sessionKey = null
        messageBuffers.forEach { wipe(it) } // zero & free (NDK)
        messageBuffers.clear()
        InMemoryStores.clearAll() // e.g., chat lists in RAM
    }
}
```

**Swift**

```swift
final class SessionMemory {
    static let shared = SessionMemory()
    private var buffers = [UnsafeMutableRawPointer]()
    private var sessionKey = Data()

    func setSessionKey(_ d: Data) { sessionKey = d }
    func addPointer(_ p: UnsafeMutableRawPointer) { buffers.append(p) }

    func wipeAll() {
        sessionKey.wipe(); sessionKey.removeAll(keepingCapacity: false)
        for p in buffers { // size must be known in your allocator
            // call to your C zero function here, or track sizes
        }
        buffers.removeAll()
        InMemoryStores.clearAll()
    }
}
```

---

# UX bits that reinforce privacy

- **Panic UI**: floating button, quick settings tile (Android), lock-screen action (iOS Shortcut).  
- **Notifications**: silent or “New activity” with **no content**.  
- **Keyboard**: disable predictive suggestions on message field (`inputType=TEXT_FLAG_NO_SUGGESTIONS` on Android; `autocorrectionType = .no` on iOS).  
- **Clipboard**: never auto-copy.  
- **Error handling**: never include payloads in error messages/crash reports; disable crash reporters in release or scrub payloads.

---

# Test checklist (red team your build)

- Background/foreground transitions: verify **RAM wipe** and **blur**.  
- Screenshot/record on both platforms: blocked/detected; banner shown to peer.  
- Camera: ensure **no files** hit disk (watch `/sdcard/` and iOS container).  
- Network: inspect with proxy—**no caching headers**, no sensitive logs.  
- Panic: spam during large transfer → sockets closed, buffers wiped, app exits cleanly.  
- Low-memory kill: ensure OS snapshot doesn’t retain message content (FLAG_SECURE & blur cover this).

---

If you want, I can scaffold **two tiny native sample projects** (Android Studio + Xcode) that already include:

- Panic button wired to `SessionMemory.wipeAll()`
- Ephemeral `URLSession`/OkHttp client with pinning
- In-memory camera capture and send hooks  
Say the word and I’ll drop the starter code structure and key files.

---
Totally doable—let’s add **privacy-preserving telemetry** that never stores message content but still gives you solid product/ops reporting.

# What we’ll track (no content, no PII)

Define a **small set of events & counters**:

- `user_registered`
- `user_logged_in`
- `device_linked` / `device_unlinked`
- `session_started` / `session_ended` (chat session)
- `friend_added` / `friend_removed`
- `message_sent` (text)
- `file_sent` (with `bytes` + `is_image: bool`)
- `account_deleted`

> No message bodies, no file blobs, no IPs stored. Only **counts + coarse metadata**.

# Identity hygiene (pseudonyms, rotation)

- **Stable pseudonymous IDs:**  
  `user_pid = HMAC(server_secret, ak_pub || "user" || rotation_salt)`  
  `device_pid = HMAC(server_secret, deviceId || "device" || rotation_salt)`  
  - Rotate `rotation_salt` **monthly** → analytics can do month-over-month, but you can’t re-identify individuals across long periods.
  - Store only the **pid** in logs; never raw usernames/ids.
- **Account deletion:** in the product DB, rename `username` to `deleted-<random>`. In telemetry, emit `account_deleted` and **stop logging** any future events for that `user_pid`.

# Minimal data model (Postgres, partitioned by day)

```sql
-- events table (append-only; no content)
CREATE TABLE events (
  ts           timestamptz NOT NULL DEFAULT now(),
  name         text        NOT NULL,
  user_pid     bytea,              -- nullable for system events
  device_pid   bytea,
  peer_pid     bytea,              -- for session/message counterpart (optional)
  client       text,               -- 'android'|'ios'|'web'|'rn' etc.
  country      text,               -- 2-letter; coarse (optional)
  bytes        bigint,             -- for file_sent
  is_image     boolean,
  count        int        NOT NULL DEFAULT 1,
  details      jsonb      NOT NULL DEFAULT '{}'::jsonb
) PARTITION BY RANGE (ts);

-- daily partitions (create by cron)
CREATE TABLE events_2025_09_09 PARTITION OF events
  FOR VALUES FROM ('2025-09-09') TO ('2025-09-10');
```

### Optional: real-time Prometheus for ops

Expose running gauges/counters (no PII):

- `anonchat_users_online`
- `anonchat_sessions_active`
- `anonchat_messages_sent_total`
- `anonchat_files_sent_bytes_total`

# Event schemas (examples)

```json
// user_registered
{ "name":"user_registered", "user_pid":"<bytes>", "client":"android" }

// device_linked
{ "name":"device_linked", "user_pid":"<bytes>", "device_pid":"<bytes>", "client":"ios" }

// session_started
{ "name":"session_started", "user_pid":"<A>", "peer_pid":"<B>", "client":"web" }

// message_sent
{ "name":"message_sent", "user_pid":"<A>", "peer_pid":"<B>", "client":"android" }

// file_sent
{ "name":"file_sent", "user_pid":"<A>", "peer_pid":"<B>", "bytes":312312, "is_image":true }

// account_deleted
{ "name":"account_deleted", "user_pid":"<A>" }
```

# Node.js: drop-in logger (no blocking, no PII)

Use a **fire-and-forget** queue to avoid touching request latency.

```js
// telemetry.js
const crypto = require('crypto');
const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.PG_URL });

const SERVER_SECRET = Buffer.from(process.env.TELEMETRY_SECRET || 'change-me');
let ROTATION_SALT = Buffer.from(process.env.TELEMETRY_ROTATION_SALT || '2025-09'); // rotate monthly

function hmacPid(input) {
  return crypto.createHmac('sha256', Buffer.concat([SERVER_SECRET, ROTATION_SALT]))
               .update(input).digest();
}

function pidForUser(akPubBytes) { return hmacPid(Buffer.concat([akPubBytes, Buffer.from('user')])); }
function pidForDevice(deviceId) { return hmacPid(Buffer.from('device:' + deviceId)); }

async function logEvent(ev) {
  // Minimal guardrails; never include PII/content in ev
  const text = `
    INSERT INTO events (ts,name,user_pid,device_pid,peer_pid,client,country,bytes,is_image,count,details)
    VALUES (now(),$1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
  `;
  const vals = [
    ev.name,
    ev.user_pid || null,
    ev.device_pid || null,
    ev.peer_pid || null,
    ev.client || null,
    ev.country || null,
    ev.bytes || null,
    ev.is_image ?? null,
    ev.count ?? 1,
    ev.details || {}
  ];
  // Don’t await in request path; emit and forget
  pool.query(text, vals).catch(() => {/* swallow; optional sample */});
}

module.exports = { logEvent, pidForUser, pidForDevice };
```

### Where to call it (examples)

```js
// on register (server.js)
const { logEvent, pidForUser, pidForDevice } = require('./telemetry');
const akPubBytes = Buffer.from(u.ak_pub, 'base64'); // if you have it; else use userId
logEvent({ name:'user_registered', user_pid: pidForUser(akPubBytes), client: req.body.client });

// on WebSocket connect
logEvent({
  name:'device_linked',
  user_pid: pidForUser(akPubBytes),
  device_pid: pidForDevice(deviceId),
  client
});

// on message relay
logEvent({
  name:'message_sent',
  user_pid: pidForUser(senderAkPub),
  peer_pid: pidForUser(receiverAkPub),
  client: senderClient
});

// on file relay
logEvent({
  name:'file_sent',
  user_pid: pidForUser(senderAkPub),
  peer_pid: pidForUser(receiverAkPub),
  client: senderClient,
  bytes: fileSize,
  is_image: mime.startsWith('image/')
});

// on deletion
logEvent({ name:'account_deleted', user_pid: pidForUser(akPubBytes) });
```

> If you don’t expose `ak_pub` to the app, derive `user_pid` from the **server-side** immutable user ID (never the username) and keep that ID internal.

# Metric definitions (consistent & audit-able)

- **DAU / WAU / MAU**  
  Distinct `user_pid` with any event in the window (prefer `session_started` or `message_sent`).

  ```sql
  SELECT date_trunc('day', ts) d, COUNT(DISTINCT user_pid) dau
  FROM events
  WHERE name IN ('session_started','message_sent','file_sent')
    AND ts >= now() - interval '30 days'
  GROUP BY 1 ORDER BY 1;
  ```

- **New users**  
  `COUNT(*) WHERE name='user_registered'`.

- **Devices connected**  
  Distinct `device_pid` with `device_linked` in window.

- **Messages sent (lifetime & per day)**  
  Sum of `count` where `name='message_sent'`.

- **Files sent + bandwidth**  
  `SUM(bytes)` where `name='file_sent'`.

- **Churn (account_deleted)**  
  Count events; rate = deletions / (deletions + active in period).

- **Active sessions concurrently**  
  Prefer Prometheus gauge; or derive from `session_started`/`session_ended` with time-bucketed deltas.

# Privacy guarantees (document this)

- **No content** (messages/files never stored).  
- **No raw identifiers** (only HMAC’d pids).  
- **Rotation** breaks long-term linkage.  
- **Short retention:** e.g., 90 days on row-level, then aggregate to daily/weekly tables and **drop raw**.  
- **Opt-out:** user setting that disables analytics (don’t emit events for their `user_pid`).  
- **IP & geo:** if you want coarse country stats, map IP → country in memory and store **country only** (or not at all).

# Operational posture

- **Backpressure:** buffer telemetry to an in-process queue or Redis Stream; drop on overload (don’t break chat).  
- **Schema evolution:** add new event fields only to `details jsonb`.  
- **Access controls:** restrict telemetry DB to read-only roles for dashboards.  
- **Dashboards:** Grafana (Prometheus ops + Postgres SQL panels).

# “Deleted usernames changed to deleted”

- Product DB: on deletion, mutate username to `deleted-<random>`, clear profile fields.  
- Telemetry: emit `account_deleted` and (optionally) **hash-ban** that previous `user_pid` so future events from that device are ignored unless re-registered.

---

If you want, I can:

- add a **/metrics** endpoint (Prometheus) with sensible counters, and  
- ship ready-to-paste **Grafana SQL panels** for DAU/WAU/MAU, churn, messages/day, bandwidth, and device mix.

---
You’ll get WhatsApp-level reliability by treating notifications as a **wake signal** (never content), with **redundant paths, delivery receipts, and aggressive retries**. Here’s a battle-tested plan that fits your no-storage model.

# Targets (define them first)

- **Latency SLO:** p50 ≤ 2s, p95 ≤ 5s from event → device notification.
- **Success SLO:** ≥ 99.5% delivered (acknowledged by OS) within 10s.
- **Uptime:** Push service 99.95% (multi-region).

# Architecture (high level)

1. **Active socket first:** if app has a live WS/WebRTC data channel, deliver in-band (no push).
2. **Otherwise push-to-wake:** send *silent* push → app wakes → re-establish socket → show local notification (still no content from server).
3. **Fan-out:** push to **all registered devices** for that user; first to come online cancels the rest.

# Server side (push service)

- **Token handling**
  - Store **opaque push tokens** per device (rotated frequently).
  - On invalid tokens, **disable immediately** and ask client to refresh.
- **Retries & backoff**
  - Queue each push with `ttl` (e.g., 30s) and **idempotency key**.
  - Retry schedule: `0s, +1s, +2s, +4s, +8s` (stop on OS ack).
  - If still no ack, mark **undeliverable** (exposed in metrics).
- **Multi-region & HA**
  - Push workers in ≥2 regions; **active-active** with health-based routing.
  - Keep **APNs** and **FCM** connections warm (HTTP/2 keep-alive).
- **Observability**
  - Metrics: enqueue→ack latency, success rate, token error rate, per-OEM success.
  - Structured logs without PII (device PID only).
  - **Synthetic canaries:** devices on major OEMs that ping every minute.

# iOS (APNs)

- **Use silent pushes** (`content-available: 1`, no alert/sound; payload < 4KB).
- **Priority:** `apns-priority: 10` for immediate delivery; set `apns-push-type: background`.
- **Background fetch:** enable *Background Modes → Remote notifications*. On wake, app opens socket; if peer is calling you, you render local notif.
- **Avoid PushKit/VoIP** unless you truly present a CallKit experience; misuse risks App Store rejection.
- **Resilience**
  - Re-connect socket inside the **background execution window** (<30s).
  - Keep payload minimal; use **collapse-id** per conversation to coalesce bursts.
- **Example APNs JSON**

  ```json
  {
    "aps": { "content-available": 1 },
    "t": "wake", "v": 1, "chat": "u:alice"  // no content, just hints
  }
  ```

# Android (FCM)

- **High-priority data message** (`priority: "high"`, `content_available: true`) to break Doze.
- **Foreground service during active chats** to keep process alive and socket warm.
- **OEM quirks**
  - Create **high-importance channel** once (user-visible for ring events).
  - For brands that kill apps (Xiaomi, Oppo, Vivo, Huawei), prefer **Data + local notif** after socket is up; document battery optimizations toggle.
- **Example FCM**

  ```json
  {
    "to": "<token>",
    "priority": "high",
    "data": { "t":"wake", "v":"1", "chat":"u:alice" }
  }
  ```

# Client behavior (all platforms)

- **State machine**
  1. If socket alive → deliver in-band.
  2. If push received → **connect within 1–2s**, authenticate, fetch presence, and ring/chat.
  3. If connection fails → schedule **exponential reconnect** (<15s total).
- **Acks**
  - **OS-level ack:** treat APNs/FCM success as *enqueued*, not delivered.
  - **App-level ack:** client POST `/wake/ack` after socket is up; only then count as delivered.
- **Debounce**
  - Use **collapse keys** per peer to avoid push storms.
  - Client ignores duplicate wakes for the same chat within N seconds.

# Edge cases & fallbacks

- **Network transitions (Wi-Fi↔️cellular):** detect loss, fast-reconnect with **backoff jitter**; keep a **secondary DNS** and **0-RTT QUIC** for speed.
- **Locked devices / restricted background**
  - iOS Low Power Mode & Focus: still send silent; if the user is a “friend” and you need attention, escalate with **interruption level: time-sensitive** (only when user has enabled it in settings).
  - Android Doze: **high-priority** FCM + Foreground service when active.
- **No storage rule kept**
  - Push = wake only; **no message payload**.
  - If user doesn’t come online within TTL, **drop the intent** (no queueing).

# Delivery quality controls (like WhatsApp)

- **SLA monitors:** per-region latency p50/p95, per-OEM success.
- **Auto mitigation:**
  - If p95 latency spikes for a region, **shift traffic** to healthy region.
  - If a device misses 3 consecutive wakes, force **token refresh** and show in-app prompt next foreground.
- **User-visible reliability**
  - Show “Last reachable: <time>” per friend (computed locally from successful wake→socket acks).
  - Badge “May be unreachable” when device failed recent wakes.

# Minimal code hooks to add now

- **Backend:**
  - `/push/wake` (enqueue, retry, metrics) with `{ toUser, reason, collapseKey }`.
  - WebSocket “hello” must POST back `/wake/ack` with the wake id.
- **Client:**
  - Background handler that, upon wake, **connects socket within 2s** and acknowledges.
  - Foreground service (Android) when a chat is active.
  - Connection watchdog with **jittered backoff** (e.g., 0.5s, 1s, 2s, 4s, 8s).

# What not to do

- Don’t send message bodies in push (breaks your promise).
- Don’t rely solely on OS notifications when the app is already connected (wastes quota, adds latency).
- Don’t keep “pending messages” on the server; use **pending wake intent with short TTL** (e.g., 30s) only.

---

If you want, I can draft:

- a small **Node push worker** (APNs+FCM, collapse keys, retries, metrics),
- and **client skeletons** (iOS `UNUserNotificationCenter` + background reconnect; Android `FirebaseMessagingService` + ForegroundService)
that you can paste into the current codebase.

---

Great call. Here’s the **smallest set of changes** to flag when the peer is on the **web client**, so the other side sees a banner: “Your contact is on web — screenshots may be possible.”

---

# 1) Backend: tag connections with `client` and expose it

### A) Store client type in presence

Update the WebSocket connection in `server.js`:

```js
// replace the simple Map with meta
// username -> { ws, client }
const online = new Map();

// helper to parse query params
function parseParams(url) {
  const u = new URL(url, 'http://x');
  return Object.fromEntries(u.searchParams.entries());
}

wss.on('connection', (ws, req) => {
  const params = parseParams(req.url);
  const payload = verifyTokenFromUrl(req.url);
  if (!payload) { ws.close(1008, 'unauthorized'); return; }

  const username = payload.username;
  const client = (params.client || 'web').toLowerCase(); // 'web' | 'rn' | 'ios' | 'android' etc.

  // single device per user (MVP)
  const prev = online.get(username);
  if (prev) { try { prev.ws.close(4000, 'new session'); } catch {} }

  online.set(username, { ws, client });

  ws.send(JSON.stringify({ type: 'presence', self: username, online: true, client }));
  // ...
```

### B) Update message relay to use `peer.ws`

Wherever you had `peer.send(...)`, change to `peer.ws.send(...)`. Example:

```js
const peer = online.get(to);
if (!peer) { /* offline */ }
peer.ws.send(JSON.stringify({ type: 'chat', from: username, text, ts: Date.now() }));
```

Repeat similarly in the `file` relay branch.

### C) Return client type in `/friends`

In your `/friends` route, include `client`:

```js
app.get('/friends', auth, (req, res) => {
  const rows = listFriendsByUser.all(req.user.userId);
  const friends = rows.map(r => {
    const o = online.get(r.friend_username);
    return {
      username: r.friend_username,
      online: !!o,
      client: o ? o.client : null
    };
  });
  res.json({ friends });
});
```

### D) Optional: add a WS “whois” (if you don’t want to expose via `/friends`)

Add this handler (optional—skip if you use the `/friends` data):

```js
if (msg.type === 'whois') {
  const u = String(msg.username || '');
  const o = online.get(u);
  ws.send(JSON.stringify({
    type: 'whois',
    username: u,
    online: !!o,
    client: o ? o.client : null
  }));
  return;
}
```

---

# 2) React Native app: send `client=rn`, show a banner if peer is on web

### A) Connect with `client` flag

In your RN `connectWS`:

```js
const ws = new WebSocket(`${API_BASE.replace('http', 'ws')}/ws?token=${jwt}&client=rn`);
```

### B) Show the warning banner in Chat screen

When you enter the chat, you already have `friends`. Use it:

```jsx
// inside 'chat' stage render
const friendMeta = friends.find(f => f.username === selectedFriend);
const showWebWarning = friendMeta?.online && friendMeta?.client === 'web';

{showWebWarning && (
  <View style={{ padding: 8, marginVertical: 8, backgroundColor: '#FEF3C7', borderRadius: 6, borderWidth: 1, borderColor: '#F59E0B' }}>
    <Text style={{ color: '#92400E' }}>
      Heads up: {selectedFriend} is using the web client. Screenshots may be possible.
    </Text>
  </View>
)}
```

(If you prefer a live check, send `{"type":"whois","username":selectedFriend}` on entering the chat and use the `whois` response.)

---

# 3) Web Vue client: send `client=web`, show the same banner

### A) Connect with `client=web`

In Vue `connectWS()`:

```js
this.ws = new WebSocket(`${API_BASE.replace('http', 'ws')}/ws?token=${this.token}&client=web`);
```

### B) Banner in the Chat card

Use `friends` list (already fetched) to detect peer’s client:

```html
<div v-if="peerIsOnWeb" style="padding:8px; margin:8px 0; background:#FEF3C7; border:1px solid #F59E0B; border-radius:6px; color:#92400E;">
  Heads up: {{peer}} is using the web client. Screenshots may be possible.
</div>
```

```js
computed: {
  peerMeta() {
    return this.friends.find(f => f.username === this.peer) || null;
  },
  peerIsOnWeb() {
    return !!(this.peerMeta && this.peerMeta.online && this.peerMeta.client === 'web');
  }
}
```

(Or trigger `whois` on chat-open if you don’t want `/friends` to expose client type globally.)

---

# 4) UX copy & behavior (quick wins)

- **Copy:** “Heads up: <name> is using the web client. Screenshots may be possible.”  
- **When to show:** only in active chat with that peer; hide if they disconnect or switch to mobile.  
- **Optional hardening (later):**
  - On web, auto-apply **watermarks** and warn on **DevTools open** or **print-screen key** events (best-effort).
  - Add a “don’t show again for this chat” checkbox (local-only).

---

This change is **fully ephemeral** (no extra storage), adds negligible complexity, and gives users clear risk signaling. If you want, I can also add **web-side watermarking** (username + timestamp diagonal overlay) that toggles on whenever either side is on web.
