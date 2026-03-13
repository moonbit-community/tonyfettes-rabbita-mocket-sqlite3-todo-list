/// Check if the user has voted on a specific poll.
fn Model::has_voted(self : Model, poll_id : Int) -> Bool {
  for v in self.voted {
    if v == poll_id {
      return true
    }
  }
  false
}

///|
/// Top-level view: renders the header, create-poll form, and all poll cards.
pub fn Model::view(self : Model, dispatch : @rabbita.Dispatch[Msg]) -> @rabbita.Html {
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
      sections.push(self.view_create_poll(dispatch))
      // Poll cards
      for poll in self.polls {
        sections.push(self.view_poll_card(dispatch, poll))
      }
      // Empty state
      if self.polls.length() == 0 {
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
fn Model::view_create_poll(
  self : Model,
  dispatch : @rabbita.Dispatch[Msg],
) -> @rabbita.Html {
  let option_fields : Array[@rabbita.Html] = []
  for i in 0..<self.option_inputs.length() {
    let idx = i
    option_fields.push(
      @html.div(
        style=["display: flex", "gap: 8px", "align-items: center"],
        [
          @html.input(
            input_type=Text,
            placeholder="Option \{idx + 1}",
            value=self.option_inputs[idx],
            on_input=fn(v) { dispatch(OptionInputChanged(idx, v)) },
            style=[
              "flex: 1", "padding: 10px 14px", "border: 2px solid #eee", "border-radius: 10px",
              "font-size: 14px", "outline: none",
            ],
            "",
          ),
          if self.option_inputs.length() > @shared.min_options {
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
              value=self.question_input,
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
          if self.option_inputs.length() < @shared.max_options {
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
fn Model::view_poll_card(
  self : Model,
  dispatch : @rabbita.Dispatch[Msg],
  poll : @shared.Poll,
) -> @rabbita.Html {
  let total = @shared.compute_total_votes(poll.options)
  let voted = self.has_voted(poll.id)
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
