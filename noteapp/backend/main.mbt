///|
/// Create the `notes` table if it does not already exist. Title and content
/// are stored as BLOB columns to preserve UTF-8 encoding.
fn init_db(conn : @sqlite3.Connection) -> Unit raise @sqlite3.SqliteError {
  let stmt = conn.prepare(
    (
      #|CREATE TABLE IF NOT EXISTS notes (
      #|  id INTEGER PRIMARY KEY AUTOINCREMENT,
      #|  title BLOB NOT NULL,
      #|  content BLOB NOT NULL,
      #|  pinned INTEGER NOT NULL DEFAULT 0
      #|)
    ),
  )
  stmt.step_once()
  stmt.finalize()
}

///|
/// Retrieve all notes from the database, ordered by pinned status (descending)
/// then by id (descending). Uses `column_blob_as_string` for UTF-8 safety.
fn get_all_notes(
  conn : @sqlite3.Connection,
) -> Array[@shared.Note] raise @sqlite3.SqliteError {
  let stmt = conn.prepare(
    "SELECT id, title, content, pinned FROM notes ORDER BY pinned DESC, id DESC",
  )
  let notes : Array[@shared.Note] = []
  while stmt.step() {
    let id : Int = stmt.column(index=0)
    let title : String = stmt.column_blob_as_string(index=1)
    let content : String = stmt.column_blob_as_string(index=2)
    let pinned_int : Int = stmt.column(index=3)
    let pinned = pinned_int != 0
    notes.push({ id, title, content, pinned })
  }
  stmt.finalize()
  notes
}

///|
/// Insert a new note with the given title and content. Returns the created
/// note with its auto-generated id. Uses `bind_string_as_blob` for UTF-8 safety.
fn create_note(
  conn : @sqlite3.Connection,
  title : String,
  content : String,
) -> @shared.Note raise @sqlite3.SqliteError {
  let stmt = conn.prepare(
    "INSERT INTO notes (title, content) VALUES (?, ?)",
  )
  stmt.bind_string_as_blob(index=1, val=title)
  stmt.bind_string_as_blob(index=2, val=content)
  stmt.step_once()
  stmt.finalize()
  let stmt2 = conn.prepare("SELECT last_insert_rowid()")
  guard stmt2.step()
  let id : Int = stmt2.column(index=0)
  stmt2.finalize()
  { id, title, content, pinned: false }
}

///|
/// Toggle the pinned status of the note with the given id and return
/// the updated note.
fn toggle_pin(
  conn : @sqlite3.Connection,
  id : Int,
) -> @shared.Note raise @sqlite3.SqliteError {
  let stmt = conn.prepare(
    "UPDATE notes SET pinned = CASE WHEN pinned = 0 THEN 1 ELSE 0 END WHERE id = ?",
  )
  stmt.bind(index=1, val=id)
  stmt.step_once()
  stmt.finalize()
  let stmt2 = conn.prepare(
    "SELECT id, title, content, pinned FROM notes WHERE id = ?",
  )
  stmt2.bind(index=1, val=id)
  guard stmt2.step()
  let note_id : Int = stmt2.column(index=0)
  let title : String = stmt2.column_blob_as_string(index=1)
  let content : String = stmt2.column_blob_as_string(index=2)
  let pinned_int : Int = stmt2.column(index=3)
  stmt2.finalize()
  { id: note_id, title, content, pinned: pinned_int != 0 }
}

///|
/// Delete the note with the given id from the database.
fn delete_note(
  conn : @sqlite3.Connection,
  id : Int,
) -> Unit raise @sqlite3.SqliteError {
  let stmt = conn.prepare("DELETE FROM notes WHERE id = ?")
  stmt.bind(index=1, val=id)
  stmt.step_once()
  stmt.finalize()
}

///|
/// Entry point. Parses CLI args for the port, opens the SQLite database,
/// initializes the schema, registers all HTTP routes (HTML shell, static JS,
/// and REST API), then starts the Mocket server.
fn main raise {
  guard @argparse.parse(
      Command("noteapp", about="Note Taking App backend", options=[
        OptionArg("port", short='p', long="port", about="Port to listen on", default_values=[
          "4003",
        ]),
      ]),
    )
    is { values: { "port": [port], .. }, .. } else {
    println("Failed to parse arguments")
    return
  }
  let port = @strconv.parse_int(port)

  let conn = @sqlite3.Connection::open("notes.db")
  println("Database opened: notes.db")

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
      #|  <title>Notes</title>
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
  ..get(@shared.api_notes, _ => {
    println("GET \{@shared.api_notes}")
    try {
      let notes = get_all_notes(conn)
      println("  -> 200 (\{notes.length()} notes)")
      @mocket.HttpResponse::new(OK).json(notes)
    } catch {
      e => {
        println("  -> 500 \{e}")
        @mocket.HttpResponse::new(InternalServerError).body("\{e}")
      }
    }
  })
  ..post(@shared.api_notes, event => {
    println("POST \{@shared.api_notes}")
    try {
      let json : Json = event.req.body()
      let title = match json {
        { "title": String(t), .. } => t
        _ => {
          println("  -> 400 Missing title")
          return @mocket.HttpResponse::new(BadRequest).body("Missing title field")
        }
      }
      let content = match json {
        { "content": String(c), .. } => c
        _ => {
          println("  -> 400 Missing content")
          return @mocket.HttpResponse::new(BadRequest).body(
            "Missing content field",
          )
        }
      }
      if !@shared.validate_title(title) {
        println("  -> 400 Invalid title")
        return @mocket.HttpResponse::new(BadRequest).body(
          "Title must be 1-\{@shared.max_title_length} characters",
        )
      }
      if !@shared.validate_content(content) {
        println("  -> 400 Invalid content")
        return @mocket.HttpResponse::new(BadRequest).body(
          "Content must be 1-\{@shared.max_content_length} characters",
        )
      }
      let note = create_note(conn, title, content)
      println("  -> 201 created note: \{title}")
      @mocket.HttpResponse::new(Created).json(note)
    } catch {
      e => {
        println("  -> 500 \{e}")
        @mocket.HttpResponse::new(InternalServerError).body("\{e}")
      }
    }
  })
  ..post("\{@shared.api_notes}/:id/pin", event => {
    let id_str = event.params.get("id").unwrap().to_string()
    println("POST /api/notes/\{id_str}/pin")
    try {
      let id = @strconv.parse_int(id_str)
      let note = toggle_pin(conn, id)
      println("  -> 200 toggled pin for note \{id} (pinned=\{note.pinned})")
      @mocket.HttpResponse::new(OK).json(note)
    } catch {
      e => {
        println("  -> 500 \{e}")
        @mocket.HttpResponse::new(InternalServerError).body("\{e}")
      }
    }
  })
  .delete("\{@shared.api_notes}/:id", fn(event) noraise {
    let id_str = event.params.get("id").unwrap().to_string()
    println("DELETE /api/notes/\{id_str}")
    try {
      let id = @strconv.parse_int(id_str)
      delete_note(conn, id)
      println("  -> 204 deleted note \{id}")
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
