const Database = require('better-sqlite3');
const db = new Database('anonchat.sqlite');

// tables: users, friends
db.exec(`
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  device_token TEXT NOT NULL,  -- secret per-device (single device for MVP)
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS friends (
  user_id TEXT NOT NULL,
  friend_username TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  UNIQUE(user_id, friend_username)
);
`);

module.exports = db;