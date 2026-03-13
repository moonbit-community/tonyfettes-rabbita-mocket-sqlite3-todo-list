///|
/// Monotonic counter for generating unique session tokens.
let token_counter : Ref[Int] = Ref::new(0)

///|
/// Hash a password with a salt using SHA256.
fn hash_password(password : String, salt : String) -> String {
  let input = "\{salt}:\{password}"
  let hash = @crypto.sha256(@utf8.encode(input))
  @crypto.bytes_to_hex_string(hash)
}

///|
/// Generate a unique session token using SHA256 of timestamp + username + counter.
fn generate_token(username : String) -> String {
  token_counter.update(fn(c) { c + 1 })
  let input = "\{username}:\{token_counter.val}"
  let hash = @crypto.sha256(@utf8.encode(input))
  @crypto.bytes_to_hex_string(hash)
}

///|
/// Create users and sessions tables.
fn init_auth_db(conn : @sqlite3.Connection) -> Unit raise @sqlite3.SqliteError {
  let s1 = conn.prepare(
    (
      #|CREATE TABLE IF NOT EXISTS users (
      #|  id INTEGER PRIMARY KEY AUTOINCREMENT,
      #|  username BLOB NOT NULL UNIQUE,
      #|  password_hash BLOB NOT NULL,
      #|  salt BLOB NOT NULL,
      #|  color BLOB NOT NULL
      #|)
    ),
  )
  s1.step_once()
  s1.finalize()
  let s2 = conn.prepare(
    (
      #|CREATE TABLE IF NOT EXISTS sessions (
      #|  token BLOB PRIMARY KEY,
      #|  user_id INTEGER NOT NULL,
      #|  created_at BLOB NOT NULL,
      #|  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      #|)
    ),
  )
  s2.step_once()
  s2.finalize()
  let s3 = conn.prepare(
    "CREATE INDEX IF NOT EXISTS idx_users_username ON users(username)",
  )
  s3.step_once()
  s3.finalize()
}

///|
/// Available colors for new user avatars.
let user_colors : Array[String] = [
  "blue", "green", "orange", "purple", "red", "yellow",
]

///|
/// Pick a color based on user ID (round-robin).
fn pick_color(id : Int) -> String {
  user_colors[id % user_colors.length()]
}

///|
/// Register a new user. Returns the User on success.
fn register_user(
  conn : @sqlite3.Connection,
  username : String,
  password : String,
) -> @shared.User raise @sqlite3.SqliteError {
  // Generate salt from username + "salt" (deterministic but per-user)
  let salt_hash = @crypto.sha256(@utf8.encode("salt:\{username}"))
  let salt = @crypto.bytes_to_hex_string(salt_hash)
  let pw_hash = hash_password(password, salt)
  let stmt = conn.prepare(
    (
      #|INSERT INTO users (username, password_hash, salt, color)
      #|VALUES (?, ?, ?, ?)
    ),
  )
  stmt.bind_string_as_blob(index=1, val=username)
  stmt.bind_string_as_blob(index=2, val=pw_hash)
  stmt.bind_string_as_blob(index=3, val=salt)
  // Temporary color, will update after we get the ID
  stmt.bind_string_as_blob(index=4, val="blue")
  stmt.step_once()
  stmt.finalize()
  // Get the new user's ID
  let id_stmt = conn.prepare("SELECT last_insert_rowid()")
  guard id_stmt.step()
  let id : Int = id_stmt.column(index=0)
  id_stmt.finalize()
  // Update color based on ID
  let color = pick_color(id)
  let upd = conn.prepare("UPDATE users SET color = ? WHERE id = ?")
  upd.bind_string_as_blob(index=1, val=color)
  upd.bind(index=2, val=id)
  upd.step_once()
  upd.finalize()
  // Also create a member record for this user
  let mem_stmt = conn.prepare("INSERT INTO members (name, color) VALUES (?, ?)")
  mem_stmt.bind_string_as_blob(index=1, val=username)
  mem_stmt.bind_string_as_blob(index=2, val=color)
  mem_stmt.step_once()
  mem_stmt.finalize()
  { id, username, color }
}

///|
/// Authenticate a user by username and password. Returns the User on success.
fn login_user(
  conn : @sqlite3.Connection,
  username : String,
  password : String,
) -> @shared.User? raise @sqlite3.SqliteError {
  let stmt = conn.prepare(
    "SELECT id, username, password_hash, salt, color FROM users WHERE username = ?",
  )
  stmt.bind_string_as_blob(index=1, val=username)
  if not(stmt.step()) {
    stmt.finalize()
    return None
  }
  let id : Int = stmt.column(index=0)
  let uname : String = stmt.column_blob_as_string(index=1)
  let stored_hash : String = stmt.column_blob_as_string(index=2)
  let salt : String = stmt.column_blob_as_string(index=3)
  let color : String = stmt.column_blob_as_string(index=4)
  stmt.finalize()
  let pw_hash = hash_password(password, salt)
  if pw_hash != stored_hash {
    return None
  }
  Some({ id, username: uname, color })
}

///|
/// Create a session for a user and return the token.
fn create_session(
  conn : @sqlite3.Connection,
  user_id : Int,
  username : String,
) -> String raise @sqlite3.SqliteError {
  let token = generate_token(username)
  let today = get_today(conn)
  let stmt = conn.prepare(
    "INSERT INTO sessions (token, user_id, created_at) VALUES (?, ?, ?)",
  )
  stmt.bind_string_as_blob(index=1, val=token)
  stmt.bind(index=2, val=user_id)
  stmt.bind_string_as_blob(index=3, val=today)
  stmt.step_once()
  stmt.finalize()
  token
}

///|
/// Get the logged-in user from a session token. Returns None if invalid.
fn get_session_user(
  conn : @sqlite3.Connection,
  token : String,
) -> @shared.User? raise @sqlite3.SqliteError {
  let stmt = conn.prepare(
    (
      #|SELECT u.id, u.username, u.color FROM users u
      #|INNER JOIN sessions s ON s.user_id = u.id
      #|WHERE s.token = ?
    ),
  )
  stmt.bind_string_as_blob(index=1, val=token)
  if not(stmt.step()) {
    stmt.finalize()
    return None
  }
  let id : Int = stmt.column(index=0)
  let username : String = stmt.column_blob_as_string(index=1)
  let color : String = stmt.column_blob_as_string(index=2)
  stmt.finalize()
  Some({ id, username, color })
}

///|
/// Delete a session (logout).
fn delete_session(
  conn : @sqlite3.Connection,
  token : String,
) -> Unit raise @sqlite3.SqliteError {
  let stmt = conn.prepare("DELETE FROM sessions WHERE token = ?")
  stmt.bind_string_as_blob(index=1, val=token)
  stmt.step_once()
  stmt.finalize()
}

///|
/// Extract the current user from a request's session cookie.
fn get_request_user(
  conn : @sqlite3.Connection,
  req : @mocket.HttpRequest,
) -> @shared.User? raise @sqlite3.SqliteError {
  match req.get_cookie("session") {
    Some(cookie) => get_session_user(conn, cookie.value)
    None => None
  }
}
