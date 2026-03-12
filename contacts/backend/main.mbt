///|
/// Create the contacts table if it does not already exist.
/// Text columns are stored as BLOB for UTF-8 safety.
fn init_db(conn : @sqlite3.Connection) -> Unit raise @sqlite3.SqliteError {
  let stmt = conn.prepare(
    (
      #|CREATE TABLE IF NOT EXISTS contacts (
      #|  id INTEGER PRIMARY KEY AUTOINCREMENT,
      #|  name BLOB NOT NULL,
      #|  email BLOB NOT NULL,
      #|  phone BLOB NOT NULL,
      #|  favorite INTEGER NOT NULL DEFAULT 0
      #|)
    ),
  )
  stmt.step_once()
  stmt.finalize()
}

///|
/// Retrieve all contacts from the database, ordered by id.
fn get_all_contacts(
  conn : @sqlite3.Connection,
) -> Array[@shared.Contact] raise @sqlite3.SqliteError {
  let stmt = conn.prepare(
    "SELECT id, name, email, phone, favorite FROM contacts ORDER BY id",
  )
  let contacts : Array[@shared.Contact] = []
  while stmt.step() {
    let id : Int = stmt.column(index=0)
    let name : String = stmt.column_blob_as_string(index=1)
    let email : String = stmt.column_blob_as_string(index=2)
    let phone : String = stmt.column_blob_as_string(index=3)
    let fav : Int = stmt.column(index=4)
    contacts.push({ id, name, email, phone, favorite: fav != 0 })
  }
  stmt.finalize()
  contacts
}

///|
/// Insert a new contact and return the created record with its assigned id.
fn create_contact(
  conn : @sqlite3.Connection,
  name : String,
  email : String,
  phone : String,
) -> @shared.Contact raise @sqlite3.SqliteError {
  let stmt = conn.prepare(
    "INSERT INTO contacts (name, email, phone) VALUES (?, ?, ?)",
  )
  stmt.bind_string_as_blob(index=1, val=name)
  stmt.bind_string_as_blob(index=2, val=email)
  stmt.bind_string_as_blob(index=3, val=phone)
  stmt.step_once()
  stmt.finalize()
  let stmt2 = conn.prepare("SELECT last_insert_rowid()")
  guard stmt2.step()
  let id : Int = stmt2.column(index=0)
  stmt2.finalize()
  { id, name, email, phone, favorite: false }
}

///|
/// Flip the favorite flag for the given contact and return the updated record.
fn toggle_favorite(
  conn : @sqlite3.Connection,
  id : Int,
) -> @shared.Contact raise @sqlite3.SqliteError {
  let stmt = conn.prepare(
    "UPDATE contacts SET favorite = CASE WHEN favorite = 0 THEN 1 ELSE 0 END WHERE id = ?",
  )
  stmt.bind(index=1, val=id)
  stmt.step_once()
  stmt.finalize()
  // Fetch the updated contact
  let stmt2 = conn.prepare(
    "SELECT id, name, email, phone, favorite FROM contacts WHERE id = ?",
  )
  stmt2.bind(index=1, val=id)
  guard stmt2.step()
  let name : String = stmt2.column_blob_as_string(index=1)
  let email : String = stmt2.column_blob_as_string(index=2)
  let phone : String = stmt2.column_blob_as_string(index=3)
  let fav : Int = stmt2.column(index=4)
  stmt2.finalize()
  { id, name, email, phone, favorite: fav != 0 }
}

///|
/// Delete a contact by id.
fn delete_contact(
  conn : @sqlite3.Connection,
  id : Int,
) -> Unit raise @sqlite3.SqliteError {
  let stmt = conn.prepare("DELETE FROM contacts WHERE id = ?")
  stmt.bind(index=1, val=id)
  stmt.step_once()
  stmt.finalize()
}

///|
/// Entry point. Parses CLI args, opens the SQLite database, registers
/// REST API routes and static file handlers, then starts the Mocket server.
fn main raise {
  guard @argparse.parse(
      Command("contacts", about="Contact Manager backend", options=[
        OptionArg("port", short='p', long="port", about="Port to listen on", default_values=[
          "4004",
        ]),
      ]),
    )
    is { values: { "port": [port], .. }, .. } else {
    println("Failed to parse arguments")
    return
  }
  let port = @strconv.parse_int(port)

  let conn = @sqlite3.Connection::open("contacts.db")
  println("Database opened: contacts.db")

  init_db(conn)
  println("Database initialized")

  let app = @mocket.new()
  app
  ..use_middleware(@cors.handle_cors())
  ..get("/", _ => {
    println("GET /")
    let html =
      #|<!DOCTYPE html>
      #|<html>
      #|<head>
      #|  <meta charset="UTF-8">
      #|  <meta name="viewport" content="width=device-width, initial-scale=1.0">
      #|  <title>Contacts</title>
      #|  <style>
      #|    * { margin: 0; padding: 0; box-sizing: border-box; }
      #|    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); background-attachment: fixed; min-height: 100vh; color: #333; }
      #|  </style>
      #|</head>
      #|<body>
      #|  <div id="app"></div>
      #|  <script src="/frontend.js"></script>
      #|</body>
      #|</html>
    @mocket.HttpResponse::new(
      OK,
      headers={ "Content-Type": "text/html; charset=utf-8" },
      raw_body=@utf8.encode(html),
    )
  })
  ..get("/frontend.js", _ => {
    println("GET /frontend.js")
    try {
      let bytes = @fs.read_file_to_bytes("./public/frontend.js")
      @mocket.HttpResponse::new(
        OK,
        headers={ "Content-Type": "application/javascript; charset=utf-8" },
        raw_body=bytes,
      )
    } catch {
      _ => {
        println("  -> 404 Not Found")
        @mocket.HttpResponse::new(NotFound).body("Not Found")
      }
    }
  })
  ..get(@shared.api_contacts, _ => {
    println("GET \{@shared.api_contacts}")
    try {
      let contacts = get_all_contacts(conn)
      println("  -> 200 (\{contacts.length()} contacts)")
      @mocket.HttpResponse::new(OK).json(contacts)
    } catch {
      e => {
        println("  -> 500 \{e}")
        @mocket.HttpResponse::new(InternalServerError).body("\{e}")
      }
    }
  })
  ..post(@shared.api_contacts, event => {
    println("POST \{@shared.api_contacts}")
    try {
      let json : Json = event.req.body()
      let name = match json {
        { "name": String(n), .. } => n
        _ => {
          println("  -> 400 Missing name")
          return @mocket.HttpResponse::new(BadRequest).body("Missing name field")
        }
      }
      let email = match json {
        { "email": String(e), .. } => e
        _ => {
          println("  -> 400 Missing email")
          return @mocket.HttpResponse::new(BadRequest).body(
            "Missing email field",
          )
        }
      }
      let phone = match json {
        { "phone": String(p), .. } => p
        _ => {
          println("  -> 400 Missing phone")
          return @mocket.HttpResponse::new(BadRequest).body(
            "Missing phone field",
          )
        }
      }
      if !@shared.validate_name(name) {
        println("  -> 400 Invalid name")
        return @mocket.HttpResponse::new(BadRequest).body(
          "Name must be 1-\{@shared.max_name_length} characters",
        )
      }
      if !@shared.validate_email(email) {
        println("  -> 400 Invalid email")
        return @mocket.HttpResponse::new(BadRequest).body(
          "Email must be valid (contain @ and . after @)",
        )
      }
      if !@shared.validate_phone(phone) {
        println("  -> 400 Invalid phone")
        return @mocket.HttpResponse::new(BadRequest).body(
          "Phone must contain only digits, spaces, hyphens, parens, and +",
        )
      }
      let contact = create_contact(conn, name, email, phone)
      println("  -> 201 created contact: \{name}")
      @mocket.HttpResponse::new(Created).json(contact)
    } catch {
      e => {
        println("  -> 500 \{e}")
        @mocket.HttpResponse::new(InternalServerError).body("\{e}")
      }
    }
  })
  ..post("\{@shared.api_contacts}/:id/favorite", event => {
    let id_str = event.params.get("id").unwrap().to_string()
    println("POST /api/contacts/\{id_str}/favorite")
    try {
      let id = @strconv.parse_int(id_str)
      let contact = toggle_favorite(conn, id)
      println("  -> 200 toggled favorite for contact \{id}")
      @mocket.HttpResponse::new(OK).json(contact)
    } catch {
      e => {
        println("  -> 500 \{e}")
        @mocket.HttpResponse::new(InternalServerError).body("\{e}")
      }
    }
  })
  .delete("\{@shared.api_contacts}/:id", fn(event) noraise {
    let id_str = event.params.get("id").unwrap().to_string()
    println("DELETE /api/contacts/\{id_str}")
    try {
      let id = @strconv.parse_int(id_str)
      delete_contact(conn, id)
      println("  -> 204 deleted contact \{id}")
      @mocket.HttpResponse::new(NoContent)
    } catch {
      e => {
        println("  -> 500 \{e}")
        @mocket.HttpResponse::new(InternalServerError).body("\{e}")
      }
    }
  })
  println("Server running at http://localhost:\{port}")
  app.serve(port~)
}
