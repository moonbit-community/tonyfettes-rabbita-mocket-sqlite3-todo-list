///|
struct Model {
  people : Array[@shared.Person]
  expenses : Array[@shared.Expense]
  settlements : Array[@shared.Settlement]
  /// Add person form
  person_input : String
  /// Add expense form
  desc_input : String
  amount_input : String
  paid_by_input : Int
}

///|
enum Msg {
  Init
  GotState(Result[@shared.AppState, String])
  // Person form
  PersonInputChanged(String)
  AddPerson
  PersonAdded(Result[@shared.Person, String])
  // Expense form
  DescInputChanged(String)
  AmountInputChanged(String)
  PaidByChanged(Int)
  AddExpense
  ExpenseAdded(Result[@shared.Expense, String])
  // Actions
  DeleteExpense(Int)
  ExpenseDeleted(Result[Int, String])
}

///|
fn fetch_state(dispatch : @rabbita.Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get(
    @shared.api_state,
    expect=Json(result => dispatch(GotState(result)), json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Failed to decode state")
      }
    }),
  )
}

///|
fn update(
  dispatch : @rabbita.Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    Init => (fetch_state(dispatch), model)
    GotState(Ok(state)) => {
      let settlements = @shared.compute_settlements(state.people, state.expenses)
      (
        @rabbita.none,
        {
          ..model,
          people: state.people,
          expenses: state.expenses,
          settlements,
        },
      )
    }
    GotState(Err(_)) => (@rabbita.none, model)
    PersonInputChanged(v) => (@rabbita.none, { ..model, person_input: v })
    AddPerson => {
      if !@shared.validate_name(model.person_input) {
        return (@rabbita.none, model)
      }
      let name = model.person_input
      let cmd = @http.post(
        @shared.api_people,
        Json(({ "name": name } : Json)),
        expect=Json(fn(r) { dispatch(PersonAdded(r)) }, fn(json) {
          Ok(@json.from_json(json)) catch {
            _ => Err("Failed to decode person")
          }
        }),
      )
      (cmd, { ..model, person_input: "" })
    }
    PersonAdded(Ok(person)) => {
      let people = model.people.copy()
      people.push(person)
      (@rabbita.none, { ..model, people })
    }
    PersonAdded(Err(_)) => (@rabbita.none, model)
    DescInputChanged(v) => (@rabbita.none, { ..model, desc_input: v })
    AmountInputChanged(v) => (@rabbita.none, { ..model, amount_input: v })
    PaidByChanged(id) => (@rabbita.none, { ..model, paid_by_input: id })
    AddExpense => {
      if !@shared.validate_description(model.desc_input) {
        return (@rabbita.none, model)
      }
      // Parse amount: accept "12.50" format, convert to cents
      let cents = parse_dollars_to_cents(model.amount_input)
      if !@shared.validate_amount(cents) {
        return (@rabbita.none, model)
      }
      if model.people.length() == 0 {
        return (@rabbita.none, model)
      }
      let paid_by = if model.paid_by_input == 0 {
        model.people[0].id
      } else {
        model.paid_by_input
      }
      let split_among = model.people.map(fn(p) { p.id.to_json() })
      let body : Json = {
        "description": model.desc_input,
        "amount": cents.to_double(),
        "paid_by": paid_by.to_double(),
        "split_among": split_among,
      }
      let cmd = @http.post(
        @shared.api_expenses,
        Json(body),
        expect=Json(fn(r) { dispatch(ExpenseAdded(r)) }, fn(json) {
          Ok(@json.from_json(json)) catch {
            _ => Err("Failed to decode expense")
          }
        }),
      )
      (cmd, { ..model, desc_input: "", amount_input: "" })
    }
    ExpenseAdded(Ok(expense)) => {
      let expenses = model.expenses.copy()
      expenses.push(expense)
      let settlements = @shared.compute_settlements(model.people, expenses)
      (@rabbita.none, { ..model, expenses, settlements })
    }
    ExpenseAdded(Err(_)) => (@rabbita.none, model)
    DeleteExpense(id) => {
      let cmd = @http.delete(
        @shared.api_expense(id),
        expect=Text(fn(result) {
          dispatch(
            ExpenseDeleted(
              match result {
                Ok(_) => Ok(id)
                Err(e) => Err(e)
              },
            ),
          )
        }),
      )
      (cmd, model)
    }
    ExpenseDeleted(Ok(id)) => {
      let expenses = model.expenses.filter(fn(e) { e.id != id })
      let settlements = @shared.compute_settlements(model.people, expenses)
      (@rabbita.none, { ..model, expenses, settlements })
    }
    ExpenseDeleted(Err(_)) => (@rabbita.none, model)
  }
}

/// Parse a string of digits into an integer.
fn parse_int(input : String) -> Int {
  let mut result = 0
  for ch in input {
    if ch >= '0' && ch <= '9' {
      result = result * 10 + (ch.to_int() - '0'.to_int())
    }
  }
  result
}

/// Parse a dollar string like "12.50" or "7" into cents.
fn parse_dollars_to_cents(input : String) -> Int {
  // Split on '.'
  let mut dollars = 0
  let mut cents = 0
  let mut after_dot = false
  let mut cent_digits = 0
  for ch in input {
    if ch == '.' {
      after_dot = true
    } else if ch >= '0' && ch <= '9' {
      let digit = ch.to_int() - '0'.to_int()
      if after_dot {
        if cent_digits < 2 {
          cents = cents * 10 + digit
          cent_digits += 1
        }
      } else {
        dollars = dollars * 10 + digit
      }
    }
  }
  // If user typed "12.5", treat as "12.50"
  if cent_digits == 1 {
    cents = cents * 10
  }
  dollars * 100 + cents
}

///|
fn view(dispatch : @rabbita.Dispatch[Msg], model : Model) -> @rabbita.Html {
  @html.div(
    style=[
      "max-width: 520px", "margin: 0 auto", "padding: 24px 16px",
      "font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
    ],
    {
      let sections : Array[@rabbita.Html] = []
      // Header
      sections.push(
        @html.div(
          style=["text-align: center", "margin-bottom: 24px", "padding-top: 12px"],
          [
            @html.h1(
              style=[
                "color: white", "font-size: 26px", "font-weight: 800",
                "margin-bottom: 4px", "letter-spacing: -0.5px",
              ],
              "Splitwise",
            ),
            @html.p(
              style=["color: rgba(255,255,255,0.75)", "font-size: 13px"],
              "Split expenses with friends",
            ),
          ],
        ),
      )
      // Total banner (only when there are expenses)
      if model.expenses.length() > 0 {
        let total = compute_total(model.expenses)
        sections.push(
          @html.div(
            style=[
              "background: rgba(255,255,255,0.15)", "border-radius: 12px",
              "padding: 16px 20px", "margin-bottom: 16px", "text-align: center",
              "backdrop-filter: blur(10px)",
            ],
            [
              @html.div(
                style=["color: rgba(255,255,255,0.7)", "font-size: 12px", "margin-bottom: 4px", "text-transform: uppercase", "letter-spacing: 1px"],
                "Total Expenses",
              ),
              @html.div(
                style=["color: white", "font-size: 32px", "font-weight: 800"],
                "$\{@shared.format_amount(total)}",
              ),
            ],
          ),
        )
      }
      // People card
      sections.push(
        view_card(
          "People",
          [
            @html.form(
              on_submit=dispatch(AddPerson),
              style=["display: flex", "gap: 8px", "margin-bottom: 12px"],
              [
                @html.input(
                  input_type=Text,
                  placeholder="Enter a name...",
                  value=model.person_input,
                  on_input=fn(v) { dispatch(PersonInputChanged(v)) },
                  style=[
                    "flex: 1", "padding: 10px 14px", "border: 2px solid #eee", "border-radius: 10px",
                    "font-size: 14px", "outline: none",
                  ],
                  "",
                ),
                @html.button(
                  type_="submit",
                  style=[
                    "padding: 10px 20px", "background: #667eea", "color: white", "border: none",
                    "border-radius: 10px", "cursor: pointer", "font-size: 14px", "font-weight: 600",
                  ],
                  "Add",
                ),
              ],
            ),
            if model.people.length() > 0 {
              @html.div(
                style=["display: flex", "flex-wrap: wrap", "gap: 8px"],
                model.people.map(fn(p) {
                  let initial = p.name.iter().collect()[0].to_string().to_upper()
                  let color = person_color(p.id)
                  @html.div(
                    style=[
                      "display: inline-flex", "align-items: center", "gap: 8px",
                      "padding: 6px 14px 6px 6px", "background: #f8f8ff",
                      "border-radius: 24px", "font-size: 13px", "color: #333",
                    ],
                    [
                      @html.div(
                        style=[
                          "width: 26px", "height: 26px", "border-radius: 50%",
                          "background: \{color}", "color: white", "font-size: 12px",
                          "font-weight: 700", "display: flex", "align-items: center",
                          "justify-content: center",
                        ],
                        initial,
                      ),
                      @html.span(style=["font-weight: 500"], p.name),
                    ],
                  )
                }),
              )
            } else {
              @html.p(
                style=["color: #aaa", "font-size: 13px", "text-align: center", "padding: 12px 0"],
                "Add at least 2 people to get started",
              )
            },
          ],
        ),
      )
      // Add expense card (only when >= 2 people)
      if model.people.length() >= 2 {
        sections.push(
          view_card(
            "Add Expense",
            [
              @html.form(
                on_submit=dispatch(AddExpense),
                style=["display: flex", "flex-direction: column", "gap: 10px"],
                [
                  @html.input(
                    input_type=Text,
                    placeholder="What was it for?",
                    value=model.desc_input,
                    on_input=fn(v) { dispatch(DescInputChanged(v)) },
                    style=[
                      "padding: 10px 14px", "border: 2px solid #eee", "border-radius: 10px",
                      "font-size: 14px", "outline: none",
                    ],
                    "",
                  ),
                  @html.div(
                    style=["display: flex", "gap: 10px"],
                    [
                      @html.input(
                        input_type=Text,
                        placeholder="0.00",
                        value=model.amount_input,
                        on_input=fn(v) { dispatch(AmountInputChanged(v)) },
                        style=[
                          "flex: 1", "padding: 10px 14px", "border: 2px solid #eee", "border-radius: 10px",
                          "font-size: 14px", "outline: none",
                        ],
                        "",
                      ),
                      @html.select(
                        on_change=fn(v) { dispatch(PaidByChanged(parse_int(v))) },
                        style=[
                          "flex: 1", "padding: 10px 14px", "border: 2px solid #eee", "border-radius: 10px",
                          "font-size: 14px", "outline: none", "background: white", "color: #333",
                        ],
                        model.people.map(fn(p) {
                          @html.option(
                            value=p.id.to_string(),
                            selected=p.id == model.paid_by_input || (model.paid_by_input == 0 && p.id == model.people[0].id),
                            "\{p.name} paid",
                          )
                        }),
                      ),
                    ],
                  ),
                  @html.div(
                    style=["font-size: 12px", "color: #999", "padding: 0 2px"],
                    "Split equally among all \{model.people.length()} people",
                  ),
                  @html.button(
                    type_="submit",
                    style=[
                      "padding: 12px", "background: linear-gradient(135deg, #667eea, #764ba2)", "color: white",
                      "border: none", "border-radius: 10px", "cursor: pointer", "font-size: 15px",
                      "font-weight: 600", "margin-top: 2px",
                    ],
                    "Add Expense",
                  ),
                ],
              ),
            ],
          ),
        )
      }
      // Expenses list
      if model.expenses.length() > 0 {
        sections.push(
          view_card(
            "Expenses",
            model.expenses.map(fn(expense) {
              let payer_color = person_color(expense.paid_by)
              let payer_initial = {
                let name = find_person_name(model.people, expense.paid_by)
                name.iter().collect()[0].to_string().to_upper()
              }
              @html.div(
                style=[
                  "display: flex", "align-items: center", "gap: 12px",
                  "padding: 10px 0", "border-bottom: 1px solid #f5f5f5",
                ],
                [
                  // Payer avatar
                  @html.div(
                    style=[
                      "width: 36px", "height: 36px", "border-radius: 50%", "flex-shrink: 0",
                      "background: \{payer_color}", "color: white", "font-size: 14px",
                      "font-weight: 700", "display: flex", "align-items: center",
                      "justify-content: center",
                    ],
                    payer_initial,
                  ),
                  // Description + subtitle
                  @html.div(
                    style=["flex: 1", "min-width: 0"],
                    [
                      @html.div(
                        style=["font-weight: 600", "font-size: 14px", "margin-bottom: 1px"],
                        expense.description,
                      ),
                      @html.div(
                        style=["font-size: 12px", "color: #999"],
                        "\{find_person_name(model.people, expense.paid_by)} paid · \{expense.split_among.length()} way split",
                      ),
                    ],
                  ),
                  // Amount
                  @html.span(
                    style=["font-weight: 700", "font-size: 15px", "color: #333", "white-space: nowrap"],
                    "$\{@shared.format_amount(expense.amount)}",
                  ),
                  // Delete
                  @html.button(
                    on_click=dispatch(DeleteExpense(expense.id)),
                    style=[
                      "width: 28px", "height: 28px", "background: #fee", "color: #e53935",
                      "border: none", "border-radius: 8px", "cursor: pointer",
                      "font-size: 13px", "font-weight: 700", "flex-shrink: 0",
                      "display: flex", "align-items: center", "justify-content: center",
                    ],
                    "X",
                  ),
                ],
              )
            }),
          ),
        )
      }
      // Settlements
      if model.settlements.length() > 0 {
        sections.push(
          view_card(
            "Who Owes Who",
            model.settlements.map(fn(s) {
              @html.div(
                style=[
                  "display: flex", "align-items: center", "gap: 10px",
                  "padding: 12px 0", "border-bottom: 1px solid #f5f5f5",
                ],
                [
                  // From person
                  @html.div(
                    style=[
                      "display: flex", "align-items: center", "gap: 6px", "flex: 1",
                    ],
                    [
                      @html.div(
                        style=[
                          "width: 30px", "height: 30px", "border-radius: 50%",
                          "background: \{person_color(s.from_id)}", "color: white",
                          "font-size: 12px", "font-weight: 700", "display: flex",
                          "align-items: center", "justify-content: center",
                        ],
                        s.from_name.iter().collect()[0].to_string().to_upper(),
                      ),
                      @html.span(style=["font-weight: 600", "font-size: 14px"], s.from_name),
                    ],
                  ),
                  // Arrow
                  @html.div(
                    style=[
                      "color: #ccc", "font-size: 18px", "padding: 0 4px",
                    ],
                    "->",
                  ),
                  // To person
                  @html.div(
                    style=[
                      "display: flex", "align-items: center", "gap: 6px", "flex: 1",
                    ],
                    [
                      @html.div(
                        style=[
                          "width: 30px", "height: 30px", "border-radius: 50%",
                          "background: \{person_color(s.to_id)}", "color: white",
                          "font-size: 12px", "font-weight: 700", "display: flex",
                          "align-items: center", "justify-content: center",
                        ],
                        s.to_name.iter().collect()[0].to_string().to_upper(),
                      ),
                      @html.span(style=["font-weight: 600", "font-size: 14px"], s.to_name),
                    ],
                  ),
                  // Amount
                  @html.span(
                    style=[
                      "font-weight: 700", "font-size: 15px", "color: #43a047",
                      "background: #e8f5e9", "padding: 4px 10px", "border-radius: 8px",
                    ],
                    "$\{@shared.format_amount(s.amount)}",
                  ),
                ],
              )
            }),
          ),
        )
      } else if model.expenses.length() > 0 {
        sections.push(
          view_card(
            "Settlements",
            [
              @html.p(
                style=["text-align: center", "color: #43a047", "padding: 20px 0", "font-weight: 600", "font-size: 15px"],
                "All settled up!",
              ),
            ],
          ),
        )
      }
      sections
    },
  )
}

/// Render a white card with a section title.
fn view_card(
  title : String,
  children : Array[@rabbita.Html],
) -> @rabbita.Html {
  @html.div(
    style=[
      "background: white", "border-radius: 14px", "padding: 18px 20px", "margin-bottom: 14px",
      "box-shadow: 0 1px 8px rgba(0,0,0,0.06)",
    ],
    {
      let all : Array[@rabbita.Html] = [
        @html.h2(
          style=[
            "font-size: 13px", "font-weight: 700", "color: #999", "margin-bottom: 14px",
            "text-transform: uppercase", "letter-spacing: 0.5px",
          ],
          title,
        ),
      ]
      for child in children {
        all.push(child)
      }
      all
    },
  )
}

/// Pick a consistent color for a person based on their id.
fn person_color(id : Int) -> String {
  let colors = [
    "#667eea", "#e91e63", "#00bcd4", "#ff9800", "#8bc34a",
    "#9c27b0", "#009688", "#f44336", "#3f51b5", "#795548",
  ]
  colors[(id - 1) % colors.length()]
}

/// Sum all expense amounts.
fn compute_total(expenses : Array[@shared.Expense]) -> Int {
  let mut total = 0
  for e in expenses {
    total += e.amount
  }
  total
}

///|
fn find_person_name(people : Array[@shared.Person], id : Int) -> String {
  for p in people {
    if p.id == id {
      return p.name
    }
  }
  "Unknown"
}

///|
fn main {
  let (dispatch, app_cell) = @rabbita.cell_with_dispatch(
    model={
      people: [],
      expenses: [],
      settlements: [],
      person_input: "",
      desc_input: "",
      amount_input: "",
      paid_by_input: 0,
    },
    update~,
    view~,
  )
  let app = @rabbita.new(app_cell)
  app.with_init(dispatch(Init))
  app.mount("app")
}
