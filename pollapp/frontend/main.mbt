///|
struct Model {
  polls : Array[@shared.Poll]
  /// Create poll form: question input
  question_input : String
  /// Create poll form: option inputs (start with 2 empty strings)
  option_inputs : Array[String]
  /// Set of poll IDs the user has voted on (tracked client-side)
  voted : Array[Int]
}

///|
enum Msg {
  Init
  GotPolls(Result[Array[@shared.Poll], String])
  // Create poll form
  QuestionInputChanged(String)
  OptionInputChanged(Int, String)
  AddOptionInput
  RemoveOptionInput(Int)
  CreatePoll
  PollCreated(Result[@shared.Poll, String])
  // Voting
  Vote(Int, Int)
  Voted(Result[@shared.Poll, String])
  // Delete
  DeletePoll(Int)
  PollDeleted(Result[Int, String])
}

///|
fn fetch_polls(dispatch : @rabbita.Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get(
    @shared.api_polls,
    expect=Json(result => dispatch(GotPolls(result)), json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Failed to decode polls")
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
    Init => (fetch_polls(dispatch), model)
    GotPolls(Ok(polls)) => (@rabbita.none, { ..model, polls })
    GotPolls(Err(_)) => (@rabbita.none, model)
    QuestionInputChanged(v) => (@rabbita.none, { ..model, question_input: v })
    OptionInputChanged(idx, v) => {
      let new_opts = model.option_inputs.copy()
      new_opts[idx] = v
      (@rabbita.none, { ..model, option_inputs: new_opts })
    }
    AddOptionInput => {
      if model.option_inputs.length() >= @shared.max_options {
        return (@rabbita.none, model)
      }
      let new_opts = model.option_inputs.copy()
      new_opts.push("")
      (@rabbita.none, { ..model, option_inputs: new_opts })
    }
    RemoveOptionInput(idx) => {
      if model.option_inputs.length() <= @shared.min_options {
        return (@rabbita.none, model)
      }
      let new_opts : Array[String] = []
      for i in 0..<model.option_inputs.length() {
        if i != idx {
          new_opts.push(model.option_inputs[i])
        }
      }
      (@rabbita.none, { ..model, option_inputs: new_opts })
    }
    CreatePoll => {
      if !@shared.validate_question(model.question_input) {
        return (@rabbita.none, model)
      }
      // Filter out empty options and validate
      let valid_options : Array[String] = []
      for text in model.option_inputs {
        let trimmed = text
        if trimmed != "" {
          valid_options.push(trimmed)
        }
      }
      if valid_options.length() < @shared.min_options {
        return (@rabbita.none, model)
      }
      for text in valid_options {
        if !@shared.validate_option(text) {
          return (@rabbita.none, model)
        }
      }
      let options_json = valid_options.map(fn(t) { t.to_json() })
      let body : Json = {
        "question": model.question_input,
        "options": options_json,
      }
      let cmd = @http.post(
        @shared.api_polls,
        Json(body),
        expect=Json(fn(r) { dispatch(PollCreated(r)) }, fn(json) {
          Ok(@json.from_json(json)) catch {
            _ => Err("Failed to decode poll")
          }
        }),
      )
      (cmd, { ..model, question_input: "", option_inputs: ["", ""] })
    }
    PollCreated(Ok(poll)) => {
      let polls = model.polls.copy()
      // Insert at the beginning (newest first, matching backend ORDER BY id DESC)
      let new_polls : Array[@shared.Poll] = [poll]
      for p in polls {
        new_polls.push(p)
      }
      (@rabbita.none, { ..model, polls: new_polls })
    }
    PollCreated(Err(_)) => (@rabbita.none, model)
    Vote(poll_id, option_id) => {
      // Check if already voted
      for v in model.voted {
        if v == poll_id {
          return (@rabbita.none, model)
        }
      }
      let body : Json = { "option_id": option_id.to_double() }
      let cmd = @http.post(
        @shared.api_poll_vote(poll_id),
        Json(body),
        expect=Json(fn(r) { dispatch(Voted(r)) }, fn(json) {
          Ok(@json.from_json(json)) catch {
            _ => Err("Failed to decode poll")
          }
        }),
      )
      let new_voted = model.voted.copy()
      new_voted.push(poll_id)
      (cmd, { ..model, voted: new_voted })
    }
    Voted(Ok(updated_poll)) => {
      let polls = model.polls.map(fn(p) {
        if p.id == updated_poll.id {
          updated_poll
        } else {
          p
        }
      })
      (@rabbita.none, { ..model, polls })
    }
    Voted(Err(_)) => (@rabbita.none, model)
    DeletePoll(id) => {
      let cmd = @http.delete(
        @shared.api_poll(id),
        expect=Text(fn(result) {
          dispatch(
            PollDeleted(
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
    PollDeleted(Ok(id)) => {
      let polls = model.polls.filter(fn(p) { p.id != id })
      (@rabbita.none, { ..model, polls })
    }
    PollDeleted(Err(_)) => (@rabbita.none, model)
  }
}

/// Check if the user has voted on a specific poll.
fn has_voted(model : Model, poll_id : Int) -> Bool {
  for v in model.voted {
    if v == poll_id {
      return true
    }
  }
  false
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
              "Poll App",
            ),
            @html.p(
              style=["color: rgba(255,255,255,0.75)", "font-size: 13px"],
              "Create polls and vote",
            ),
          ],
        ),
      )
      // Create Poll card
      sections.push(view_create_poll(dispatch, model))
      // Poll cards
      for poll in model.polls {
        sections.push(view_poll_card(dispatch, model, poll))
      }
      // Empty state
      if model.polls.length() == 0 {
        sections.push(
          view_card(
            "Polls",
            [
              @html.p(
                style=["color: #aaa", "font-size: 13px", "text-align: center", "padding: 12px 0"],
                "No polls yet. Create one above!",
              ),
            ],
          ),
        )
      }
      sections
    },
  )
}

/// Render the "Create Poll" form card.
fn view_create_poll(
  dispatch : @rabbita.Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let option_fields : Array[@rabbita.Html] = []
  for i in 0..<model.option_inputs.length() {
    let idx = i
    option_fields.push(
      @html.div(
        style=["display: flex", "gap: 8px", "align-items: center"],
        [
          @html.input(
            input_type=Text,
            placeholder="Option \{idx + 1}",
            value=model.option_inputs[idx],
            on_input=fn(v) { dispatch(OptionInputChanged(idx, v)) },
            style=[
              "flex: 1", "padding: 10px 14px", "border: 2px solid #eee", "border-radius: 10px",
              "font-size: 14px", "outline: none",
            ],
            "",
          ),
          if model.option_inputs.length() > @shared.min_options {
            @html.button(
              on_click=dispatch(RemoveOptionInput(idx)),
              type_="button",
              style=[
                "width: 32px", "height: 32px", "background: #fee", "color: #e53935",
                "border: none", "border-radius: 8px", "cursor: pointer",
                "font-size: 16px", "font-weight: 700", "flex-shrink: 0",
                "display: flex", "align-items: center", "justify-content: center",
              ],
              "-",
            )
          } else {
            @html.span(style=[], "")
          },
        ],
      ),
    )
  }
  view_card(
    "Create Poll",
    [
      @html.form(
        on_submit=dispatch(CreatePoll),
        style=["display: flex", "flex-direction: column", "gap: 10px"],
        {
          let children : Array[@rabbita.Html] = []
          children.push(
            @html.input(
              input_type=Text,
              placeholder="What's your question?",
              value=model.question_input,
              on_input=fn(v) { dispatch(QuestionInputChanged(v)) },
              style=[
                "padding: 10px 14px", "border: 2px solid #eee", "border-radius: 10px",
                "font-size: 14px", "outline: none",
              ],
              "",
            ),
          )
          children.push(
            @html.div(
              style=["font-size: 12px", "font-weight: 700", "color: #999", "text-transform: uppercase", "letter-spacing: 0.5px", "margin-top: 4px"],
              "Options",
            ),
          )
          for field in option_fields {
            children.push(field)
          }
          if model.option_inputs.length() < @shared.max_options {
            children.push(
              @html.button(
                on_click=dispatch(AddOptionInput),
                type_="button",
                style=[
                  "padding: 8px", "background: #f0f0ff", "color: #667eea",
                  "border: 2px dashed #ccc", "border-radius: 10px", "cursor: pointer",
                  "font-size: 13px", "font-weight: 600",
                ],
                "+ Add Option",
              ),
            )
          }
          children.push(
            @html.button(
              type_="submit",
              style=[
                "padding: 12px", "background: linear-gradient(135deg, #667eea, #764ba2)", "color: white",
                "border: none", "border-radius: 10px", "cursor: pointer", "font-size: 15px",
                "font-weight: 600", "margin-top: 2px",
              ],
              "Create Poll",
            ),
          )
          children
        },
      ),
    ],
  )
}

/// Render a single poll card with voting bars.
fn view_poll_card(
  dispatch : @rabbita.Dispatch[Msg],
  model : Model,
  poll : @shared.Poll,
) -> @rabbita.Html {
  let total = @shared.compute_total_votes(poll.options)
  let voted = has_voted(model, poll.id)
  let option_bars : Array[@rabbita.Html] = []
  for opt in poll.options {
    let pct = @shared.compute_percentage(opt.votes, total)
    let poll_id = poll.id
    let option_id = opt.id
    if voted {
      // Show results bar (non-clickable)
      option_bars.push(
        @html.div(
          style=[
            "position: relative", "padding: 12px 14px", "border-radius: 10px",
            "background: #f5f5f8", "overflow: hidden", "margin-bottom: 6px",
          ],
          [
            // Fill bar
            @html.div(
              style=[
                "position: absolute", "top: 0", "left: 0", "bottom: 0",
                "width: \{pct}%",
                "background: linear-gradient(135deg, rgba(102,126,234,0.2), rgba(118,75,162,0.2))",
                "border-radius: 10px", "transition: width 0.3s ease",
              ],
              "",
            ),
            // Text content
            @html.div(
              style=["position: relative", "display: flex", "justify-content: space-between", "align-items: center"],
              [
                @html.span(
                  style=["font-size: 14px", "font-weight: 500", "color: #333"],
                  opt.text,
                ),
                @html.span(
                  style=["font-size: 13px", "font-weight: 600", "color: #667eea"],
                  "\{opt.votes} votes (\{pct}%)",
                ),
              ],
            ),
          ],
        ),
      )
    } else {
      // Clickable vote bar
      option_bars.push(
        @html.div(
          on_click=dispatch(Vote(poll_id, option_id)),
          style=[
            "position: relative", "padding: 12px 14px", "border-radius: 10px",
            "background: #f5f5f8", "overflow: hidden", "margin-bottom: 6px",
            "cursor: pointer", "transition: background 0.2s ease",
          ],
          [
            @html.span(
              style=["font-size: 14px", "font-weight: 500", "color: #333"],
              opt.text,
            ),
          ],
        ),
      )
    }
  }
  view_card(
    "",
    {
      let children : Array[@rabbita.Html] = []
      // Poll question as title
      children.push(
        @html.div(
          style=[
            "display: flex", "justify-content: space-between", "align-items: flex-start",
            "margin-bottom: 14px",
          ],
          [
            @html.h3(
              style=["font-size: 16px", "font-weight: 700", "color: #333", "flex: 1"],
              poll.question,
            ),
            @html.button(
              on_click=dispatch(DeletePoll(poll.id)),
              style=[
                "width: 28px", "height: 28px", "background: #fee", "color: #e53935",
                "border: none", "border-radius: 8px", "cursor: pointer",
                "font-size: 13px", "font-weight: 700", "flex-shrink: 0",
                "display: flex", "align-items: center", "justify-content: center",
                "margin-left: 12px",
              ],
              "X",
            ),
          ],
        ),
      )
      for bar in option_bars {
        children.push(bar)
      }
      // Total votes footer
      if total > 0 {
        children.push(
          @html.div(
            style=["font-size: 12px", "color: #999", "margin-top: 8px", "text-align: right"],
            "\{total} total votes",
          ),
        )
      }
      if !voted && total == 0 {
        children.push(
          @html.div(
            style=["font-size: 12px", "color: #999", "margin-top: 8px", "text-align: center"],
            "Click an option to vote",
          ),
        )
      }
      children
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
      let all : Array[@rabbita.Html] = []
      if title != "" {
        all.push(
          @html.h2(
            style=[
              "font-size: 13px", "font-weight: 700", "color: #999", "margin-bottom: 14px",
              "text-transform: uppercase", "letter-spacing: 0.5px",
            ],
            title,
          ),
        )
      }
      for child in children {
        all.push(child)
      }
      all
    },
  )
}

///|
fn main {
  let (dispatch, app_cell) = @rabbita.cell_with_dispatch(
    model={
      polls: [],
      question_input: "",
      option_inputs: ["", ""],
      voted: [],
    },
    update~,
    view~,
  )
  let app = @rabbita.new(app_cell)
  app.with_init(dispatch(Init))
  app.mount("app")
}
