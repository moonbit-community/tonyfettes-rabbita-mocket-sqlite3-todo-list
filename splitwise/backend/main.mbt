///|
fn init_db(conn : @sqlite3.Connection) -> Unit raise @sqlite3.SqliteError {
  let stmt = conn.prepare(
    (
      #|CREATE TABLE IF NOT EXISTS people (
      #|  id INTEGER PRIMARY KEY AUTOINCREMENT,
      #|  name BLOB NOT NULL
      #|)
    ),
  )
  stmt.step_once()
  stmt.finalize()
  let stmt2 = conn.prepare(
    (
      #|CREATE TABLE IF NOT EXISTS expenses (
      #|  id INTEGER PRIMARY KEY AUTOINCREMENT,
      #|  description BLOB NOT NULL,
      #|  amount INTEGER NOT NULL,
      #|  paid_by INTEGER NOT NULL REFERENCES people(id)
      #|)
    ),
  )
  stmt2.step_once()
  stmt2.finalize()
  let stmt3 = conn.prepare(
    (
      #|CREATE TABLE IF NOT EXISTS expense_splits (
      #|  expense_id INTEGER NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
      #|  person_id INTEGER NOT NULL REFERENCES people(id),
      #|  PRIMARY KEY (expense_id, person_id)
      #|)
    ),
  )
  stmt3.step_once()
  stmt3.finalize()
}

///|
fn get_all_people(
  conn : @sqlite3.Connection,
) -> Array[@shared.Person] raise @sqlite3.SqliteError {
  let stmt = conn.prepare("SELECT id, name FROM people ORDER BY id")
  let people : Array[@shared.Person] = []
  while stmt.step() {
    let id : Int = stmt.column(index=0)
    let name : String = stmt.column_blob_as_string(index=1)
    people.push({ id, name })
  }
  stmt.finalize()
  people
}

///|
fn create_person(
  conn : @sqlite3.Connection,
  name : String,
) -> @shared.Person raise @sqlite3.SqliteError {
  let stmt = conn.prepare("INSERT INTO people (name) VALUES (?)")
  stmt.bind_string_as_blob(index=1, val=name)
  stmt.step_once()
  stmt.finalize()
  let stmt2 = conn.prepare("SELECT last_insert_rowid()")
  guard stmt2.step()
  let id : Int = stmt2.column(index=0)
  stmt2.finalize()
  { id, name }
}

///|
fn get_splits_for_expense(
  conn : @sqlite3.Connection,
  expense_id : Int,
) -> Array[Int] raise @sqlite3.SqliteError {
  let stmt = conn.prepare(
    "SELECT person_id FROM expense_splits WHERE expense_id = ?",
  )
  stmt.bind(index=1, val=expense_id)
  let ids : Array[Int] = []
  while stmt.step() {
    let pid : Int = stmt.column(index=0)
    ids.push(pid)
  }
  stmt.finalize()
  ids
}

///|
fn get_all_expenses(
  conn : @sqlite3.Connection,
) -> Array[@shared.Expense] raise @sqlite3.SqliteError {
  let stmt = conn.prepare(
    "SELECT id, description, amount, paid_by FROM expenses ORDER BY id",
  )
  let expenses : Array[@shared.Expense] = []
  while stmt.step() {
    let id : Int = stmt.column(index=0)
    let description : String = stmt.column_blob_as_string(index=1)
    let amount : Int = stmt.column(index=2)
    let paid_by : Int = stmt.column(index=3)
    let split_among = get_splits_for_expense(conn, id)
    expenses.push({ id, description, amount, paid_by, split_among })
  }
  stmt.finalize()
  expenses
}

///|
fn create_expense(
  conn : @sqlite3.Connection,
  description : String,
  amount : Int,
  paid_by : Int,
  split_among : Array[Int],
) -> @shared.Expense raise @sqlite3.SqliteError {
  let stmt = conn.prepare(
    "INSERT INTO expenses (description, amount, paid_by) VALUES (?, ?, ?)",
  )
  stmt.bind_string_as_blob(index=1, val=description)
  stmt.bind(index=2, val=amount)
  stmt.bind(index=3, val=paid_by)
  stmt.step_once()
  stmt.finalize()
  let stmt2 = conn.prepare("SELECT last_insert_rowid()")
  guard stmt2.step()
  let id : Int = stmt2.column(index=0)
  stmt2.finalize()
  for person_id in split_among {
    let stmt3 = conn.prepare(
      "INSERT INTO expense_splits (expense_id, person_id) VALUES (?, ?)",
    )
    stmt3.bind(index=1, val=id)
    stmt3.bind(index=2, val=person_id)
    stmt3.step_once()
    stmt3.finalize()
  }
  { id, description, amount, paid_by, split_among }
}

///|
fn delete_expense(
  conn : @sqlite3.Connection,
  id : Int,
) -> Unit raise @sqlite3.SqliteError {
  // Delete splits first (no FK cascade in this SQLite binding)
  let stmt = conn.prepare("DELETE FROM expense_splits WHERE expense_id = ?")
  stmt.bind(index=1, val=id)
  stmt.step_once()
  stmt.finalize()
  let stmt2 = conn.prepare("DELETE FROM expenses WHERE id = ?")
  stmt2.bind(index=1, val=id)
  stmt2.step_once()
  stmt2.finalize()
}

///|
fn get_state(conn : @sqlite3.Connection) -> @shared.AppState raise @sqlite3.SqliteError {
  let people = get_all_people(conn)
  let expenses = get_all_expenses(conn)
  let settlements = @shared.compute_settlements(people, expenses)
  { people, expenses, settlements }
}

///|
fn main raise {
  guard @argparse.parse(
      Command("splitwise", about="Expense Splitter backend", options=[
        OptionArg("port", short='p', long="port", about="Port to listen on", default_values=[
          "4001",
        ]),
      ]),
    )
    is { values: { "port": [port], .. }, .. } else {
    println("Failed to parse arguments")
    return
  }
  let port = @strconv.parse_int(port)

  let conn = @sqlite3.Connection::open("splitwise.db")
  println("Database opened: splitwise.db")

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
      #|  <title>Splitwise</title>
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
  ..get(@shared.api_state, _ => {
    println("GET \{@shared.api_state}")
    try {
      let state = get_state(conn)
      println("  -> 200")
      @mocket.HttpResponse::new(OK).json(state)
    } catch {
      e => {
        println("  -> 500 \{e}")
        @mocket.HttpResponse::new(InternalServerError).body("\{e}")
      }
    }
  })
  ..post(@shared.api_people, event => {
    println("POST \{@shared.api_people}")
    try {
      let json : Json = event.req.body()
      let name = match json {
        { "name": String(n), .. } => n
        _ => {
          println("  -> 400 Missing name")
          return @mocket.HttpResponse::new(BadRequest).body("Missing name field")
        }
      }
      if !@shared.validate_name(name) {
        println("  -> 400 Invalid name")
        return @mocket.HttpResponse::new(BadRequest).body(
          "Name must be 1-\{@shared.max_name_length} characters",
        )
      }
      let person = create_person(conn, name)
      println("  -> 201 created person: \{name}")
      @mocket.HttpResponse::new(Created).json(person)
    } catch {
      e => {
        println("  -> 500 \{e}")
        @mocket.HttpResponse::new(InternalServerError).body("\{e}")
      }
    }
  })
  ..post(@shared.api_expenses, event => {
    println("POST \{@shared.api_expenses}")
    try {
      let json : Json = event.req.body()
      let description = match json {
        { "description": String(d), .. } => d
        _ => {
          println("  -> 400 Missing description")
          return @mocket.HttpResponse::new(BadRequest).body(
            "Missing description",
          )
        }
      }
      let amount = match json {
        { "amount": Number(a, ..), .. } => a.to_int()
        _ => {
          println("  -> 400 Missing amount")
          return @mocket.HttpResponse::new(BadRequest).body("Missing amount")
        }
      }
      let paid_by = match json {
        { "paid_by": Number(p, ..), .. } => p.to_int()
        _ => {
          println("  -> 400 Missing paid_by")
          return @mocket.HttpResponse::new(BadRequest).body("Missing paid_by")
        }
      }
      let split_among : Array[Int] = match json {
        { "split_among": Array(arr), .. } => {
          let ids : Array[Int] = []
          for item in arr {
            match item {
              Number(n, ..) => ids.push(n.to_int())
              _ => ()
            }
          }
          ids
        }
        _ => {
          println("  -> 400 Missing split_among")
          return @mocket.HttpResponse::new(BadRequest).body(
            "Missing split_among",
          )
        }
      }
      if !@shared.validate_description(description) {
        println("  -> 400 Invalid description")
        return @mocket.HttpResponse::new(BadRequest).body(
          "Description must be 1-\{@shared.max_description_length} characters",
        )
      }
      if !@shared.validate_amount(amount) {
        println("  -> 400 Invalid amount")
        return @mocket.HttpResponse::new(BadRequest).body(
          "Amount must be positive",
        )
      }
      if split_among.length() == 0 {
        println("  -> 400 No participants")
        return @mocket.HttpResponse::new(BadRequest).body(
          "Must split among at least one person",
        )
      }
      let expense = create_expense(conn, description, amount, paid_by, split_among)
      println("  -> 201 created expense: \{description}")
      @mocket.HttpResponse::new(Created).json(expense)
    } catch {
      e => {
        println("  -> 500 \{e}")
        @mocket.HttpResponse::new(InternalServerError).body("\{e}")
      }
    }
  })
  .delete("\{@shared.api_expenses}/:id", fn(event) noraise {
    let id_str = event.params.get("id").unwrap().to_string()
    println("DELETE /api/expenses/\{id_str}")
    try {
      let id = @strconv.parse_int(id_str)
      delete_expense(conn, id)
      println("  -> 204 deleted expense \{id}")
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
