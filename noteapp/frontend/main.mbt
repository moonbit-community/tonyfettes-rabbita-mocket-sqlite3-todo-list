///|
/// Application state for the notes frontend, following the Elm architecture.
struct Model {
  notes : Array[@shared.Note]
  /// New note form
  title_input : String
  content_input : String
  /// Currently selected note id for detail view (0 = none)
  selected_note_id : Int
}

///|
/// Messages that drive state transitions in the update loop.
enum Msg {
  /// Trigger initial data fetch on app startup.
  Init
  /// Response from fetching all notes from the API.
  GotNotes(Result[Array[@shared.Note], String])
  /// User typed in the title input field.
  TitleInputChanged(String)
  /// User typed in the content textarea.
  ContentInputChanged(String)
  /// User submitted the new-note form.
  SaveNote
  /// Response after creating a note via the API.
  NoteSaved(Result[@shared.Note, String])
  /// User clicked a note to view its detail.
  SelectNote(Int)
  /// User clicked back from the detail view.
  DeselectNote
  /// User toggled a note's pinned status.
  TogglePin(Int)
  /// Response after toggling pin via the API.
  NotePinToggled(Result[@shared.Note, String])
  /// User requested deletion of a note.
  DeleteNote(Int)
  /// Response after deleting a note via the API.
  NoteDeleted(Result[Int, String])
}

///|
/// Fetch all notes from the backend API and dispatch `GotNotes` with the result.
fn fetch_notes(dispatch : @rabbita.Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get(
    @shared.api_notes,
    expect=Json(result => dispatch(GotNotes(result)), json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Failed to decode notes")
      }
    }),
  )
}

///|
/// Elm-architecture update function. Processes each `Msg` and returns the
/// next model state along with any side-effect commands (HTTP requests).
fn update(
  dispatch : @rabbita.Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    Init => (fetch_notes(dispatch), model)
    GotNotes(Ok(notes)) => {
      let sorted = @shared.sort_notes(notes)
      (@rabbita.none, { ..model, notes: sorted })
    }
    GotNotes(Err(_)) => (@rabbita.none, model)
    TitleInputChanged(v) => (@rabbita.none, { ..model, title_input: v })
    ContentInputChanged(v) => (@rabbita.none, { ..model, content_input: v })
    SaveNote => {
      if !@shared.validate_title(model.title_input) {
        return (@rabbita.none, model)
      }
      if !@shared.validate_content(model.content_input) {
        return (@rabbita.none, model)
      }
      let title = model.title_input
      let content = model.content_input
      let body : Json = { "title": title, "content": content }
      let cmd = @http.post(
        @shared.api_notes,
        Json(body),
        expect=Json(fn(r) { dispatch(NoteSaved(r)) }, fn(json) {
          Ok(@json.from_json(json)) catch {
            _ => Err("Failed to decode note")
          }
        }),
      )
      (cmd, { ..model, title_input: "", content_input: "" })
    }
    NoteSaved(Ok(note)) => {
      let notes = model.notes.copy()
      notes.push(note)
      let sorted = @shared.sort_notes(notes)
      (@rabbita.none, { ..model, notes: sorted })
    }
    NoteSaved(Err(_)) => (@rabbita.none, model)
    SelectNote(id) => (@rabbita.none, { ..model, selected_note_id: id })
    DeselectNote => (@rabbita.none, { ..model, selected_note_id: 0 })
    TogglePin(id) => {
      let cmd = @http.post(
        @shared.api_note_pin(id),
        Json(({} : Json)),
        expect=Json(fn(r) { dispatch(NotePinToggled(r)) }, fn(json) {
          Ok(@json.from_json(json)) catch {
            _ => Err("Failed to decode note")
          }
        }),
      )
      (cmd, model)
    }
    NotePinToggled(Ok(updated)) => {
      let notes = model.notes.map(fn(n) {
        if n.id == updated.id {
          updated
        } else {
          n
        }
      })
      let sorted = @shared.sort_notes(notes)
      (@rabbita.none, { ..model, notes: sorted })
    }
    NotePinToggled(Err(_)) => (@rabbita.none, model)
    DeleteNote(id) => {
      let cmd = @http.delete(
        @shared.api_note(id),
        expect=Text(fn(result) {
          dispatch(
            NoteDeleted(
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
    NoteDeleted(Ok(id)) => {
      let notes = model.notes.filter(fn(n) { n.id != id })
      let selected = if model.selected_note_id == id {
        0
      } else {
        model.selected_note_id
      }
      (@rabbita.none, { ..model, notes, selected_note_id: selected })
    }
    NoteDeleted(Err(_)) => (@rabbita.none, model)
  }
}

/// Format reading time as a human-readable string.
fn format_reading_time(secs : Int) -> String {
  if secs < 60 {
    "< 1 min read"
  } else {
    let mins = secs / 60
    "\{mins} min read"
  }
}

/// Find a note by id.
fn find_note(notes : Array[@shared.Note], id : Int) -> @shared.Note? {
  for n in notes {
    if n.id == id {
      return Some(n)
    }
  }
  None
}

///|
/// Render the entire UI: header, new-note form or detail view, and notes list.
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
              "Notes",
            ),
            @html.p(
              style=["color: rgba(255,255,255,0.75)", "font-size: 13px"],
              "Quick thoughts, organized",
            ),
          ],
        ),
      )
      // Note detail view (when a note is selected)
      if model.selected_note_id != 0 {
        match find_note(model.notes, model.selected_note_id) {
          Some(note) => {
            let stats = @shared.compute_stats(note.content)
            sections.push(
              view_card(
                "Note Detail",
                [
                  // Back button
                  @html.button(
                    on_click=dispatch(DeselectNote),
                    style=[
                      "padding: 6px 14px", "background: #f0f0f5", "color: #667eea",
                      "border: none", "border-radius: 8px", "cursor: pointer",
                      "font-size: 13px", "font-weight: 600", "margin-bottom: 14px",
                    ],
                    "Back",
                  ),
                  // Title
                  @html.h1(
                    style=[
                      "font-size: 20px", "font-weight: 700", "color: #333",
                      "margin-bottom: 8px",
                    ],
                    note.title,
                  ),
                  // Pinned badge
                  if note.pinned {
                    @html.div(
                      style=[
                        "display: inline-block", "padding: 3px 10px",
                        "background: #fff3e0", "color: #f57c00",
                        "border-radius: 12px", "font-size: 11px", "font-weight: 600",
                        "margin-bottom: 12px",
                      ],
                      "Pinned",
                    )
                  } else {
                    @html.nothing
                  },
                  // Content
                  @html.div(
                    style=[
                      "font-size: 14px", "line-height: 1.7", "color: #555",
                      "margin-bottom: 16px", "white-space: pre-wrap",
                    ],
                    note.content,
                  ),
                  // Stats bar
                  @html.div(
                    style=[
                      "display: flex", "gap: 16px", "padding: 12px 0",
                      "border-top: 1px solid #f0f0f0",
                    ],
                    [
                      view_stat_badge(
                        "\{stats.word_count} words",
                        "#667eea",
                        "#f0f0ff",
                      ),
                      view_stat_badge(
                        "\{stats.char_count} chars",
                        "#9c27b0",
                        "#f5f0ff",
                      ),
                      view_stat_badge(
                        format_reading_time(stats.reading_time_secs),
                        "#43a047",
                        "#e8f5e9",
                      ),
                    ],
                  ),
                ],
              ),
            )
          }
          None => ()
        }
      } else {
        // New Note card
        sections.push(
          view_card(
            "New Note",
            [
              @html.form(
                on_submit=dispatch(SaveNote),
                style=["display: flex", "flex-direction: column", "gap: 10px"],
                [
                  @html.input(
                    input_type=Text,
                    placeholder="Note title...",
                    value=model.title_input,
                    on_input=fn(v) { dispatch(TitleInputChanged(v)) },
                    style=[
                      "padding: 10px 14px", "border: 2px solid #eee", "border-radius: 10px",
                      "font-size: 14px", "outline: none",
                    ],
                    "",
                  ),
                  @html.textarea(
                    placeholder="Write your note...",
                    value=model.content_input,
                    on_input=fn(v) { dispatch(ContentInputChanged(v)) },
                    rows=5,
                    style=[
                      "padding: 10px 14px", "border: 2px solid #eee", "border-radius: 10px",
                      "font-size: 14px", "outline: none", "resize: vertical",
                      "font-family: inherit",
                    ],
                    "",
                  ),
                  @html.button(
                    type_="submit",
                    style=[
                      "padding: 12px", "background: linear-gradient(135deg, #667eea, #764ba2)", "color: white",
                      "border: none", "border-radius: 10px", "cursor: pointer", "font-size: 15px",
                      "font-weight: 600", "margin-top: 2px",
                    ],
                    "Save Note",
                  ),
                ],
              ),
            ],
          ),
        )
        // Notes list
        if model.notes.length() > 0 {
          sections.push(
            view_card(
              "All Notes",
              model.notes.map(fn(note) {
                let preview = @shared.truncate(note.content, 80)
                let stats = @shared.compute_stats(note.content)
                let bg = if note.pinned {
                  "background: #fffdf5"
                } else {
                  "background: white"
                }
                @html.div(
                  style=[
                    "padding: 12px 0", "border-bottom: 1px solid #f5f5f5",
                  ],
                  [
                    @html.div(
                      style=["display: flex", "align-items: flex-start", "gap: 10px"],
                      [
                        // Main content area (clickable)
                        @html.div(
                          style=[
                            "flex: 1", "min-width: 0", "cursor: pointer",
                            "padding: 8px 12px", "border-radius: 10px", bg,
                          ],
                          [
                            // Title row
                            @html.div(
                              style=["display: flex", "align-items: center", "gap: 8px", "margin-bottom: 4px"],
                              [
                                if note.pinned {
                                  @html.span(
                                    style=["color: #f57c00", "font-size: 14px"],
                                    "* ",
                                  )
                                } else {
                                  @html.nothing
                                },
                                @html.button(
                                  on_click=dispatch(SelectNote(note.id)),
                                  style=[
                                    "font-weight: 700", "font-size: 15px", "color: #333",
                                    "background: none", "border: none", "cursor: pointer",
                                    "text-align: left", "padding: 0",
                                  ],
                                  note.title,
                                ),
                              ],
                            ),
                            // Preview
                            @html.div(
                              style=["font-size: 13px", "color: #888", "margin-bottom: 6px", "line-height: 1.4"],
                              preview,
                            ),
                            // Word count badge
                            @html.span(
                              style=[
                                "font-size: 11px", "color: #667eea", "background: #f0f0ff",
                                "padding: 2px 8px", "border-radius: 10px", "font-weight: 600",
                              ],
                              "\{stats.word_count} words",
                            ),
                          ],
                        ),
                        // Action buttons
                        @html.div(
                          style=["display: flex", "flex-direction: column", "gap: 6px", "padding-top: 8px"],
                          [
                            // Pin button
                            @html.button(
                              on_click=dispatch(TogglePin(note.id)),
                              style=[
                                "width: 32px", "height: 32px",
                                if note.pinned {
                                  "background: #fff3e0"
                                } else {
                                  "background: #f5f5f5"
                                },
                                if note.pinned {
                                  "color: #f57c00"
                                } else {
                                  "color: #bbb"
                                },
                                "border: none", "border-radius: 8px", "cursor: pointer",
                                "font-size: 14px", "font-weight: 700",
                                "display: flex", "align-items: center", "justify-content: center",
                              ],
                              if note.pinned { "*" } else { "o" },
                            ),
                            // Delete button
                            @html.button(
                              on_click=dispatch(DeleteNote(note.id)),
                              style=[
                                "width: 32px", "height: 32px", "background: #fee", "color: #e53935",
                                "border: none", "border-radius: 8px", "cursor: pointer",
                                "font-size: 13px", "font-weight: 700",
                                "display: flex", "align-items: center", "justify-content: center",
                              ],
                              "X",
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                )
              }),
            ),
          )
        }
      }
      sections
    },
  )
}

/// Render a stat badge with colored text and background.
fn view_stat_badge(
  text : String,
  color : String,
  bg : String,
) -> @rabbita.Html {
  @html.span(
    style=[
      "font-size: 12px", "font-weight: 600", "color: \{color}",
      "background: \{bg}", "padding: 4px 10px", "border-radius: 10px",
    ],
    text,
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

///|
/// Entry point. Initializes the Rabbita app with MVU wiring and mounts it
/// into the `#app` DOM element, then triggers the initial notes fetch.
fn main {
  let (dispatch, app_cell) = @rabbita.cell_with_dispatch(
    model={
      notes: [],
      title_input: "",
      content_input: "",
      selected_note_id: 0,
    },
    update~,
    view~,
  )
  let app = @rabbita.new(app_cell)
  app.with_init(dispatch(Init))
  app.mount("app")
}
