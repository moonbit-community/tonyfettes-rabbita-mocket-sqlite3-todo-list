///|
fn init_db(conn : @sqlite3.Connection) -> Unit raise @sqlite3.SqliteError {
  let stmt = conn.prepare(
    (
      #|CREATE TABLE IF NOT EXISTS polls (
      #|  id INTEGER PRIMARY KEY AUTOINCREMENT,
      #|  question BLOB NOT NULL
      #|)
    ),
  )
  stmt.step_once()
  stmt.finalize()
  let stmt2 = conn.prepare(
    (
      #|CREATE TABLE IF NOT EXISTS poll_options (
      #|  id INTEGER PRIMARY KEY AUTOINCREMENT,
      #|  poll_id INTEGER NOT NULL REFERENCES polls(id),
      #|  text BLOB NOT NULL,
      #|  votes INTEGER NOT NULL DEFAULT 0
      #|)
    ),
  )
  stmt2.step_once()
  stmt2.finalize()
}

///|
fn get_options_for_poll(
  conn : @sqlite3.Connection,
  poll_id : Int,
) -> Array[@shared.PollOption] raise @sqlite3.SqliteError {
  let stmt = conn.prepare(
    "SELECT id, text, votes FROM poll_options WHERE poll_id = ? ORDER BY id",
  )
  stmt.bind(index=1, val=poll_id)
  let options : Array[@shared.PollOption] = []
  while stmt.step() {
    let id : Int = stmt.column(index=0)
    let text : String = stmt.column_blob_as_string(index=1)
    let votes : Int = stmt.column(index=2)
    options.push({ id, text, votes })
  }
  stmt.finalize()
  options
}

///|
fn get_all_polls(
  conn : @sqlite3.Connection,
) -> Array[@shared.Poll] raise @sqlite3.SqliteError {
  let stmt = conn.prepare("SELECT id, question FROM polls ORDER BY id DESC")
  let polls : Array[@shared.Poll] = []
  while stmt.step() {
    let id : Int = stmt.column(index=0)
    let question : String = stmt.column_blob_as_string(index=1)
    let options = get_options_for_poll(conn, id)
    polls.push({ id, question, options })
  }
  stmt.finalize()
  polls
}

///|
fn create_poll(
  conn : @sqlite3.Connection,
  question : String,
  option_texts : Array[String],
) -> @shared.Poll raise @sqlite3.SqliteError {
  let stmt = conn.prepare("INSERT INTO polls (question) VALUES (?)")
  stmt.bind_string_as_blob(index=1, val=question)
  stmt.step_once()
  stmt.finalize()
  let stmt2 = conn.prepare("SELECT last_insert_rowid()")
  guard stmt2.step()
  let poll_id : Int = stmt2.column(index=0)
  stmt2.finalize()
  let options : Array[@shared.PollOption] = []
  for text in option_texts {
    let stmt3 = conn.prepare(
      "INSERT INTO poll_options (poll_id, text, votes) VALUES (?, ?, 0)",
    )
    stmt3.bind(index=1, val=poll_id)
    stmt3.bind_string_as_blob(index=2, val=text)
    stmt3.step_once()
    stmt3.finalize()
    let stmt4 = conn.prepare("SELECT last_insert_rowid()")
    guard stmt4.step()
    let opt_id : Int = stmt4.column(index=0)
    stmt4.finalize()
    options.push({ id: opt_id, text, votes: 0 })
  }
  { id: poll_id, question, options }
}

///|
fn vote_on_option(
  conn : @sqlite3.Connection,
  option_id : Int,
) -> Unit raise @sqlite3.SqliteError {
  let stmt = conn.prepare(
    "UPDATE poll_options SET votes = votes + 1 WHERE id = ?",
  )
  stmt.bind(index=1, val=option_id)
  stmt.step_once()
  stmt.finalize()
}

///|
fn delete_poll(
  conn : @sqlite3.Connection,
  id : Int,
) -> Unit raise @sqlite3.SqliteError {
  // Delete options first (no FK cascade in this SQLite binding)
  let stmt = conn.prepare("DELETE FROM poll_options WHERE poll_id = ?")
  stmt.bind(index=1, val=id)
  stmt.step_once()
  stmt.finalize()
  let stmt2 = conn.prepare("DELETE FROM polls WHERE id = ?")
  stmt2.bind(index=1, val=id)
  stmt2.step_once()
  stmt2.finalize()
}

///|
fn get_poll_by_id(
  conn : @sqlite3.Connection,
  id : Int,
) -> @shared.Poll? raise @sqlite3.SqliteError {
  let stmt = conn.prepare("SELECT id, question FROM polls WHERE id = ?")
  stmt.bind(index=1, val=id)
  if stmt.step() {
    let poll_id : Int = stmt.column(index=0)
    let question : String = stmt.column_blob_as_string(index=1)
    stmt.finalize()
    let options = get_options_for_poll(conn, poll_id)
    Some({ id: poll_id, question, options })
  } else {
    stmt.finalize()
    None
  }
}

///|
fn main raise {
  guard @argparse.parse(
      Command("pollapp", about="Poll/Voting App backend", options=[
        OptionArg("port", short='p', long="port", about="Port to listen on", default_values=[
          "4002",
        ]),
      ]),
    )
    is { values: { "port": [port], .. }, .. } else {
    println("Failed to parse arguments")
    return
  }
  let port = @strconv.parse_int(port)

  let conn = @sqlite3.Connection::open("polls.db")
  println("Database opened: polls.db")

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
      #|  <title>Poll App</title>
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
  ..get(@shared.api_polls, _ => {
    println("GET \{@shared.api_polls}")
    try {
      let polls = get_all_polls(conn)
      println("  -> 200")
      @mocket.HttpResponse::new(OK).json(polls)
    } catch {
      e => {
        println("  -> 500 \{e}")
        @mocket.HttpResponse::new(InternalServerError).body("\{e}")
      }
    }
  })
  ..post(@shared.api_polls, event => {
    println("POST \{@shared.api_polls}")
    try {
      let json : Json = event.req.body()
      let question = match json {
        { "question": String(q), .. } => q
        _ => {
          println("  -> 400 Missing question")
          return @mocket.HttpResponse::new(BadRequest).body(
            "Missing question field",
          )
        }
      }
      if !@shared.validate_question(question) {
        println("  -> 400 Invalid question")
        return @mocket.HttpResponse::new(BadRequest).body(
          "Question must be 1-\{@shared.max_question_length} characters",
        )
      }
      let option_texts : Array[String] = match json {
        { "options": Array(arr), .. } => {
          let texts : Array[String] = []
          for item in arr {
            match item {
              String(s) => texts.push(s)
              _ => ()
            }
          }
          texts
        }
        _ => {
          println("  -> 400 Missing options")
          return @mocket.HttpResponse::new(BadRequest).body(
            "Missing options array",
          )
        }
      }
      if option_texts.length() < @shared.min_options {
        println("  -> 400 Too few options")
        return @mocket.HttpResponse::new(BadRequest).body(
          "Must have at least \{@shared.min_options} options",
        )
      }
      if option_texts.length() > @shared.max_options {
        println("  -> 400 Too many options")
        return @mocket.HttpResponse::new(BadRequest).body(
          "Must have at most \{@shared.max_options} options",
        )
      }
      for text in option_texts {
        if !@shared.validate_option(text) {
          println("  -> 400 Invalid option text")
          return @mocket.HttpResponse::new(BadRequest).body(
            "Each option must be 1-\{@shared.max_option_length} characters",
          )
        }
      }
      let poll = create_poll(conn, question, option_texts)
      println("  -> 201 created poll: \{question}")
      @mocket.HttpResponse::new(Created).json(poll)
    } catch {
      e => {
        println("  -> 500 \{e}")
        @mocket.HttpResponse::new(InternalServerError).body("\{e}")
      }
    }
  })
  ..post("\{@shared.api_polls}/:id/vote", fn(event) noraise {
    let id_str = event.params.get("id").unwrap().to_string()
    println("POST /api/polls/\{id_str}/vote")
    try {
      let json : Json = event.req.body()
      let option_id = match json {
        { "option_id": Number(n, ..), .. } => n.to_int()
        _ => {
          println("  -> 400 Missing option_id")
          return @mocket.HttpResponse::new(BadRequest).body(
            "Missing option_id field",
          )
        }
      }
      vote_on_option(conn, option_id)
      let poll_id = @strconv.parse_int(id_str)
      match get_poll_by_id(conn, poll_id) {
        Some(poll) => {
          println("  -> 200 voted on option \{option_id}")
          @mocket.HttpResponse::new(OK).json(poll)
        }
        None => {
          println("  -> 404 Poll not found")
          @mocket.HttpResponse::new(NotFound).body("Poll not found")
        }
      }
    } catch {
      e => {
        println("  -> 500 \{e}")
        @mocket.HttpResponse::new(InternalServerError).body("\{e}")
      }
    }
  })
  .delete("\{@shared.api_polls}/:id", fn(event) noraise {
    let id_str = event.params.get("id").unwrap().to_string()
    println("DELETE /api/polls/\{id_str}")
    try {
      let id = @strconv.parse_int(id_str)
      delete_poll(conn, id)
      println("  -> 204 deleted poll \{id}")
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
