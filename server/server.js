const express = require('express')
const cors = require('cors')
const { WebSocketServer } = require('ws')
const jwt = require('jsonwebtoken')
const { v4: uuid } = require('uuid')
const db = require('./db')

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change'
const PORT = process.env.PORT || 4000

const app = express()
app.use(cors())
app.use(express.json())

// --- DB helpers ---
const insertUser = db.prepare(
  'INSERT INTO users (id, username, device_token, created_at) VALUES (?, ?, ?, ?)'
)
const getUserByUsername = db.prepare('SELECT * FROM users WHERE username = ?')
const getUserById = db.prepare('SELECT * FROM users WHERE id = ?')
const insertFriend = db.prepare(
  'INSERT OR IGNORE INTO friends (user_id, friend_username, created_at) VALUES (?, ?, ?)'
)
const listFriendsByUser = db.prepare(
  'SELECT friend_username FROM friends WHERE user_id = ?'
)
const listAllUsernames = db.prepare('SELECT username FROM users')

// --- In-memory presence ---
/** username -> ws */
const online = new Map()

// --- Auth middleware ---
function auth(req, res, next) {
  const authz = req.headers.authorization || ''
  const token = authz.startsWith('Bearer ') ? authz.slice(7) : null
  if (!token) return res.status(401).json({ error: 'No token' })
  try {
    const payload = jwt.verify(token, JWT_SECRET)
    req.user = payload // { userId, username }
    next()
  } catch {
    return res.status(401).json({ error: 'Invalid token' })
  }
}

// --- Routes ---
// Register: create account + single device token (store locally on client)
app.post('/register', (req, res) => {
  const { username } = req.body || {}
  if (!username || !/^[a-z0-9_]{3,20}$/i.test(username)) {
    return res.status(400).json({ error: 'Invalid username' })
  }
  if (getUserByUsername.get(username)) {
    return res.status(409).json({ error: 'Username taken' })
  }
  const id = uuid()
  const deviceToken = uuid().replace(/-/g, '')
  insertUser.run(id, username, deviceToken, Date.now())
  // client stores deviceToken securely and exchanges for JWT via /login
  return res.json({ username, deviceToken })
})

// Login: exchange deviceToken -> JWT
app.post('/login', (req, res) => {
  const { username, deviceToken } = req.body || {}
  const u = getUserByUsername.get(username)
  if (!u || u.device_token !== deviceToken) {
    return res.status(401).json({ error: 'Invalid credentials' })
  }
  const token = jwt.sign({ userId: u.id, username: u.username }, JWT_SECRET, {
    expiresIn: '7d',
  })
  res.json({ token })
})

// Add friend (local contact). No request/accept yet; simple list.
app.post('/friends/add', auth, (req, res) => {
  const { friendUsername } = req.body || {}
  if (!friendUsername || friendUsername === req.user.username) {
    return res.status(400).json({ error: 'Invalid friend' })
  }
  const exists = getUserByUsername.get(friendUsername)
  if (!exists) return res.status(404).json({ error: 'User not found' })
  insertFriend.run(req.user.userId, friendUsername, Date.now())
  res.json({ ok: true })
})

// List friends + online status
app.get('/friends', auth, (req, res) => {
  const rows = listFriendsByUser.all(req.user.userId)
  const friends = rows.map((r) => ({
    username: r.friend_username,
    online: online.has(r.friend_username),
  }))
  res.json({ friends })
})

// Optional: list all users (for quick testing)
app.get('/users', (req, res) => {
  res.json({ users: listAllUsernames.all().map((r) => r.username) })
})

// --- HTTP server + WebSocket for live messaging (no storage) ---
const server = app.listen(PORT, () => console.log(`API on :${PORT}`))

const wss = new WebSocketServer({
  server,
  path: '/ws',
  perMessageDeflate: false,
  maxPayload: 10 * 1024 * 1024, // 10MB
})

// Verify JWT from query ?token=...
function verifyTokenFromUrl(url) {
  try {
    const q = new URL(url, 'http://x')
    const token = q.searchParams.get('token')
    if (!token) return null
    return jwt.verify(token, JWT_SECRET) // { userId, username }
  } catch {
    return null
  }
}

wss.on('connection', (ws, req) => {
  const payload = verifyTokenFromUrl(req.url)
  if (!payload) {
    ws.close(1008, 'unauthorized')
    return
  }
  const username = payload.username

  // one device per user: close previous if exists
  if (online.has(username)) {
    try {
      online.get(username).close(4000, 'new session')
    } catch {}
  }
  online.set(username, ws)

  // Notify self: you are online + who of your friends is online (client can also poll /friends)
  ws.send(JSON.stringify({ type: 'presence', self: username, online: true }))

  ws.on('message', (data) => {
    // expected protocol:
    // { type:'chat', to:'bob', text:'hello' }
    // { type:'ping' }
    let msg
    try {
      msg = JSON.parse(data.toString())
    } catch {
      return
    }

    if (msg.type === 'ping') {
      ws.send(JSON.stringify({ type: 'pong', t: Date.now() }))
      return
    }

    if (msg.type === 'chat') {
      const to = String(msg.to || '')
      const text = String(msg.text || '')
      if (!to || !text) return

      const peer = online.get(to)
      if (!peer) {
        // optional: tell sender that peer is offline
        ws.send(JSON.stringify({ type: 'delivery', to, status: 'offline' }))
        return
      }
      // Relay (no persistence)
      peer.send(
        JSON.stringify({
          type: 'chat',
          from: username,
          text,
          ts: Date.now(),
        })
      )
      // Acknowledge
      ws.send(JSON.stringify({ type: 'delivery', to, status: 'sent' }))
      return
    }

    if (msg.type === 'file') {
      const to = String(msg.to || '')
      const name = String(msg.name || 'file')
      const mime = String(msg.mime || 'application/octet-stream')
      const dataB64 = String(msg.dataB64 || '')
      const size = Number(msg.size || 0)
      if (!to || !dataB64 || !name || !mime || !Number.isFinite(size)) return

      if (dataB64.length > 14 * 1024 * 1024) {
        // ~10MB base64 guard
        ws.send(JSON.stringify({ type: 'delivery', to, status: 'too_large' }))
        return
      }

      const peer = online.get(to)
      if (!peer) {
        ws.send(JSON.stringify({ type: 'delivery', to, status: 'offline' }))
        return
      }

      peer.send(
        JSON.stringify({
          type: 'file',
          from: username,
          name,
          mime,
          size,
          dataB64: dataB64, // still E2E-capable later; for now plain relay
          ts: Date.now(),
        })
      )
      ws.send(JSON.stringify({ type: 'delivery', to, status: 'sent' }))
      return
    }
  })

  ws.on('close', () => {
    if (online.get(username) === ws) {
      online.delete(username)
    }
  })
})
