A concrete, privacy-first design for a "phone-call style" messaging app with zero server storage.

1) Core principles
	•	No content on servers: server only does discovery + signaling; never sees message payloads.
	•	Ephemeral sessions: chats exist only while both peers are online; session keys die when either leaves.
	•	Identity = keys, not PII: usernames are public aliases; trust is anchored in device/account keys.
	•	Metadata minimization: store only what’s essential for reachability; aggressively rotate/expire the rest.

2) System components
	•	Directory/Signaling server (stateless-ish):
	•	Maps username → currently online deviceIDs (volatile in-memory store).
	•	Handles friend requests, session offers (SDP/ICE), push wakeups.
	•	Keeps no message content, no chat history.
	•	TURN/STUN:
	•	NAT traversal for P2P; fallback to TURN relay (still E2E-encrypted).
	•	Clients (devices):
	•	Hold keys, contact list, and minimal logs locally.
	•	Establish WebRTC/WebTransport/QUIC data channels for live encrypted messages.

3) Keys & identity
	•	Account keypair (AK) (long-term, per user): Ed25519 (identity). Stored on each device after trusted enrollment.
	•	Device keypair (DK) (long-term, per device): Ed25519 (device auth) + Curve25519 (X25519) for ECDH.
	•	Pre-keys (ephemeral, per device): short-lived X25519 bundle advertised only while online to enable fast AKE (Authenticated Key Exchange).
	•	Session keys: derived via X3DH → Double Ratchet (Signal-style) or Noise IK/XX + Double Ratchet for continuous PFS.

Server only ever sees public AK/DK and transient pre-keys during online presence.

4) User & device lifecycle

Register new account (on first device)
	1.	Client generates AK, DK, and an initial pre-key bundle.
	2.	Pick a username (check availability).
	3.	Server records: username, AK_pub, deviceID, DK_pub. (No private keys. No PII.)
	4.	Device stores its AK_priv, DK_priv locally (Secure Enclave/KeyStore).

Add another device to same account
	•	Use QR handoff (online, both devices present):
	1.	Old device displays a short-lived enrollment token (signed with AK_priv) as a QR.
	2.	New device scans, proves possession by completing a mutual challenge signed by its DK_priv.
	3.	Server verifies AK_pub signature and links the new deviceID to the account.
	•	Or OTP handoff (if remote), still signed by AK_priv.

5) Contacting someone

Add contact
	1.	Enter usernameB.
	2.	Server returns “online?” + safety number (a hash of both AK_pubs) so clients can verify out-of-band if they wish.

First connect (not yet friends)
	1.	A → Server: “request session with usernameB”.
	2.	If B has any online devices, server forwards a connection request (no content).
	3.	B accepts → both sides fetch each other’s pre-keys (from server’s volatile store).
	4.	Run X3DH/Noise to derive session key, then switch to Double Ratchet on the P2P channel.

Friends (subsequent connects)
	•	If B is offline:
	•	Server triggers push wakeup using a stored, rotating, blinded push token (no username in payload).
	•	If B comes online within a window, signaling proceeds; else A sees “user offline”.

6) Messaging channel
	•	Transport: WebRTC DataChannel (desktop/mobile/web) or QUIC (native).
	•	Encryption: Double Ratchet (PFS + post-compromise security). Message headers contain only a counter and ratchet data—no metadata like names.
	•	No storage policy:
	•	Clients keep messages only in memory (ring buffer). On app close/OS kill/lock → buffer cleared.
	•	Optional “blur mode”: render from RAM; screenshots/notifications redact content.

7) What the server stores (and how long)
	•	Persistent (minimal):
	•	username, AK_pub
	•	Per device: deviceID, DK_pub, public capabilities (supported transports), and rotating push token envelope (opaque).
	•	Ephemeral (memory; TTL seconds–minutes):
	•	Online presence: username → [deviceIDs]
	•	Pre-key bundles (public) for online devices
	•	Outstanding session offers (SDP/ICE), expiring quickly
	•	Never: messages, contact lists, safety numbers, IP logs (beyond short rolling window for abuse control).

8) Privacy, threat model & mitigations
	•	Server compromise: only public keys and minimal routing info leak—no content, no history.
	•	MITM on first contact: prevent via authenticated AKE (X3DH ties to AK) + show safety number; allow optional QR key verify when meeting IRL.
	•	Metadata leakage (IP): prefer TURN-only mode to hide peer IPs from each other; or multi-hop relays. Allow user toggle.
	•	Spam/abuse: require “know the exact username” + rate-limits + PoW/puzzles for first contact; auto-blocklist locally.
	•	Device loss: revoke a device by signing a revocation with AK_priv from another device; server stops advertising that deviceID.
	•	Push privacy: store tokens encrypted with a server key; rotate frequently; payloads carry only a wake hint.

9) Notifications without storing chats
	•	Store only a friendship flag on both accounts (signed by both AKs at the moment of friending). This lets server send “wake” pings to offline friends—still no content or history.
	•	Friendship removal = both sides publish a signed “unfriend” to the server.

10) Data model (lean)

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

11) Protocol sketch (first secure session)
	1.	Discover: A asks server for B’s online devices.
	2.	Offer: A → server → B: SDP offer + A’s pre-key ref.
	3.	Accept: B responds with SDP answer + pre-key ref.
	4.	X3DH: Both pull each other’s pre-keys (public), compute shared secret bound to AK_pub.
	5.	Double Ratchet: Start ratchet; verify safety number (optional).
	6.	Chat: E2E over DataChannel; no persistence.

12) Tech stack options
	•	Mobile: Kotlin/Jetpack + iOS Swift; React Native if cross-platform.
	•	Transport: WebRTC (Pion/aiortc/libwebrtc) or QUIC (Quiche/msquic).
	•	Crypto: libsodium / Noise Protocol Framework / libsignal.
	•	Server: Go/Rust/Node—small service with TLS, Redis (in-memory) for presence; Postgres for persistent minimal rows.
	•	Push: APNs / FCM using opaque tokens.

13) “No storage” UX details
	•	Show a prominent “This chat is ephemeral” banner.
	•	Disable screenshots by default (best-effort on Android; can’t fully prevent on iOS/web).
	•	When either side disconnects: both tear down ratchet state and wipe RAM buffers.
	•	Provide a “panic close” (instant memory wipe) and an inactivity timeout.

14) Compliance & ops
	•	Publish a short Data Retention Policy (presence ≤ N minutes; logs ≤ 24–72h for DoS debugging; configurable to 0 in strict mode).
	•	Open-source client crypto; third-party audits for the protocol.
	•	Enable transparency reports (counts only, no content).

15) MVP cut-list (2–3 sprints)
	•	✅ Account creation, username claim, AK/DK gen & local secure storage
	•	✅ Add device via QR handoff
	•	✅ Friend request + accept (with safety number)
	•	✅ Online-only chat using WebRTC + Double Ratchet (in-memory buffers)
	•	✅ TURN fallback; basic push wake (friends only)
	•	✅ Device revoke; panic close; ephemeral presence

16) Edge cases to decide now
	•	Multi-device fan-out: when B has 3 devices online, pick one (last active) or ring all?
	•	Offline invites: do you allow A to create a pending friend request that wakes B? (It leaks “A knows B’s username”; still no content.)
	•	Strict mode: TURN-only relaying, zero server logs, no push (fully pull-based). Heavier battery, best privacy.

---


Discovery modes (account-level, overridable per-contact)
	1.	Public
	•	Directory shows: username, online/offline.
	•	Anyone can initiate a request when you’re online.
	•	Offline lookups return “offline” (prevents guesswork about existence).
	2.	Default (privacy-preserving)
	•	Server only responds to exact username with:
	•	Online → can send request
	•	Not found → indistinguishable between “offline” and “no such user”
	•	No public directory listing.
	3.	Strict (username + Friend Verification Code)
	•	First contact requires: username and FVC (short code).
	•	If either is wrong (or user is offline), server returns Not found.
	•	Prevents user enumeration and spray-requests.

Users can optionally whitelist specific friends to bypass strict for subsequent reconnects.

⸻

How the Friend Verification Code (FVC) works (privacy-first)
	•	Goal: server can verify a short code for a username without storing secrets per user.
	•	Design:
	•	Let seed = HMAC(server_secret, ak_pub || fvc_salt) (no PII, deterministic; fvc_salt is a random per-user 16B value stored with the profile).
	•	Use TOTP (time-based one-time password) over seed with a 60–120s step to generate a 6–8 digit/char code.
	•	Code format: digits or Crockford base32 (better for voice).
	•	Users can switch to Static FVC (printed once) if they dislike time codes—store only a salted hash of the static string.
	•	Sharing UX: show a QR/deep link that bundles username + current FVC, or display the code as text. Never shown in notifications.

⸻

Server behavior by mode (high-level)

/discover (POST)
Input: { username, fvc? }
Output (all modes): { result: "ok" | "not_found", online?: boolean }
	•	Public:
	•	If username exists: return { ok, online }.
	•	Default:
	•	If username online: { ok, online: true }; otherwise { not_found }.
	•	Strict:
	•	Validate fvc: if correct and user online → { ok, online: true }; else { not_found }.

/requestSession (POST)
Input: { fromDeviceId, toUsername, fvc? }
	•	Gate exactly as /discover. If gate passes, forward request to target’s online devices (or ring policy).

/mode (PUT, auth required)
Input: { mode: "PUBLIC" | "DEFAULT" | "STRICT", strictOptions? }
	•	strictOptions: { scheme: "TOTP" | "STATIC", codeLength?: 6|7|8 }
	•	Rotate fvc_salt on switch to STRICT (TOTP), or update hashed code if STATIC.

⸻

Data model additions (minimal + privacy conscious)

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

No message content. Presence and offers remain ephemeral (memory/short TTL).

⸻

UX rules & copy (crisp)
	•	Mode picker during onboarding + settings, clearly explained:
	•	Public: easy to reach, shows online/offline.
	•	Default: can only be reached if you’re online and they know your username.
	•	Strict: requires your username and your code; best for journalists/targets.
	•	Share contact:
	•	Public/Default: share username (QR/text).
	•	Strict: share “username + short code” (as QR that auto-fills both).
	•	Errors (user-visible): always say “User not found or offline.” (never reveal which).
	•	Friends: after mutual accept, subsequent wake/requests don’t require FVC (unless user keeps “Always FVC” toggle on).

⸻

Signaling & notifications with modes
	•	Public: offline lookups may return online:false; you can optionally allow “offline invite” (sends privacy-minimal wake).
	•	Default & Strict:
	•	No offline invites before friendship.
	•	After friendship, server can send a wake ping (opaque token only).

⸻

Anti-abuse safeguards
	•	Rate limits on /discover and /requestSession per IP/device/account.
	•	Proof-of-Work or CAPTCHA on repeated failures in STRICT.
	•	Backoff on any not_found to make enumeration expensive.
	•	Local autoblock for N failed requests from same origin.

⸻

Multi-device & “ring” policy
	•	Public: can ring all online devices (throttled) or last-active first.
	•	Default/Strict: same, but only after gating passes.
	•	For Strict, the FVC is checked once per request, not per device.

⸻

Migration & compatibility
	•	Default is DEFAULT mode for all new users.
	•	Older clients (pre-modes) behave as DEFAULT.
	•	If a user flips to STRICT, server immediately enforces FVC on first-contact requests; existing friends unaffected unless “Always FVC” is on.
	•	Rotating fvc_salt invalidates old QR links—warn the user before rotate.

⸻

API sketches (concise)

POST /discover
{ "username":"alice", "fvc":"123456" }  -> { "result":"ok", "online":true }
                                      or { "result":"not_found" }

POST /requestSession
{ "toUsername":"alice", "fvc":"123456", "offer":{...} } -> { "result":"delivered" | "not_found" }

PUT /mode
{ "mode":"STRICT", "strictOptions":{"scheme":"TOTP","codeLength":6} } -> { "result":"ok" }

GET /myMode  -> { "mode":"STRICT", "strictOptions":{"scheme":"TOTP","codeLength":6} }


⸻

Cryptography fit
	•	Modes do not change E2E: keep X3DH/Noise + Double Ratchet for sessions.
	•	FVC sits before key exchange as an access gate; never used as crypto material.
	•	TOTP window: 60–120s; skew tolerance ±1 step.
	•	If you want zero per-user secrets on server: the HMAC-seed approach above + stored fvc_salt is enough.

⸻

Tests you should run
	•	Enumeration: brute force usernames under all modes → only Public should leak “offline/online”, Default/Strict must look identical for “offline vs nonexistent”.
	•	Clock skew: Strict/TOTP behavior with ±3 min skew.
	•	Rate limit: burst /discover & /requestSession → throttled.
	•	QR replay: expired TOTP QR must fail.
	•	Mode flips mid-request: ensure deterministic “not_found”.

⸻

Quick client UX checklist
	•	Mode badge on profile (Public / Default / Strict).
	•	One-tap “Share contact” → QR + copy button.
	•	Strict: show live code with countdown; accessible description for reading aloud.
	•	Settings: “Always require FVC (even for friends)” toggle for high-risk users.
	•	Error toasts use neutral wording: “User not found or offline.”
