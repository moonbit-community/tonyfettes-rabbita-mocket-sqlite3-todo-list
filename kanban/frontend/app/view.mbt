///|
/// Render the top header bar with title and action buttons.
fn Model::view_header(
  self : Model,
  dispatch : @rabbita.Dispatch[Msg],
) -> @rabbita.Html {
  @html.div(
    style=[
      "background: linear-gradient(135deg, #0d9488 0%, #0891b2 100%)", "padding: 20px 32px",
      "margin-bottom: 24px", "border-radius: 12px", "display: flex", "justify-content: space-between",
      "align-items: center",
    ],
    [
      @html.h1(
        style=[
          "color: white", "font-size: 22px", "font-weight: 700", "letter-spacing: -0.3px",
        ],
        "Kanban Board",
      ),
      @html.div(style=["display: flex", "gap: 8px"], [
        if self.moving_card != 0 {
          @html.button(
            on_click=dispatch(CancelMove),
            style=[
              "padding: 8px 16px", "background: rgba(255,255,255,0.2)", "color: white",
              "border: 1px solid rgba(255,255,255,0.3)", "border-radius: 6px", "cursor: pointer",
              "font-size: 13px",
            ],
            "Cancel Move",
          )
        } else {
          @html.text("")
        },
        if self.adding_column {
          @html.text("")
        } else {
          @html.button(
            on_click=dispatch(ShowAddColumn),
            style=[
              "padding: 8px 16px", "background: rgba(255,255,255,0.2)", "color: white",
              "border: 1px solid rgba(255,255,255,0.3)", "border-radius: 6px", "cursor: pointer",
              "font-size: 13px",
            ],
            "+ Column",
          )
        },
      ]),
    ],
  )
}

///|
/// Render the inline form for adding a new column.
fn Model::view_add_column_form(
  self : Model,
  dispatch : @rabbita.Dispatch[Msg],
) -> @rabbita.Html {
  @html.div(
    style=[
      "min-width: 272px", "max-width: 272px", "background: white", "border-radius: 10px",
      "padding: 16px", "border: 2px dashed #cbd5e1",
    ],
    [
      @html.input(
        input_type=Text,
        placeholder="Column title",
        value=self.new_column_title,
        on_input=fn(v) { dispatch(NewColumnTitleChanged(v)) },
        style=[
          "width: 100%", "padding: 8px 10px", "border: 1px solid #e2e8f0", "border-radius: 6px",
          "font-size: 14px", "outline: none", "margin-bottom: 8px",
        ],
        "",
      ),
      @html.div(style=["display: flex", "gap: 6px"], [
        @html.button(
          on_click=dispatch(AddColumn),
          style=[
            "padding: 6px 14px", "background: #0d9488", "color: white", "border: none",
            "border-radius: 6px", "cursor: pointer", "font-size: 13px",
          ],
          "Add",
        ),
        @html.button(
          on_click=dispatch(HideAddColumn),
          style=[
            "padding: 6px 14px", "background: #f1f5f9", "color: #64748b", "border: none",
            "border-radius: 6px", "cursor: pointer", "font-size: 13px",
          ],
          "Cancel",
        ),
      ]),
    ],
  )
}

///|
/// Render a clickable drop zone for card placement during move mode.
fn view_drop_zone(
  dispatch : @rabbita.Dispatch[Msg],
  column_id : Int,
  index : Int,
) -> @rabbita.Html {
  @html.div(
    on_click=dispatch(MoveCardTo(column_id, index)),
    style=[
      "height: 6px", "margin: 4px 0", "border-radius: 3px", "background: #99f6e4",
      "border: 2px dashed #14b8a6", "cursor: pointer", "transition: all 0.15s",
    ],
    [@html.text("")],
  )
}

///|
/// Render a row of color swatches for card label selection.
fn view_color_picker(
  dispatch : @rabbita.Dispatch[Msg],
  current : String,
  on_change : (String) -> Msg,
) -> @rabbita.Html {
  @html.div(
    style=["display: flex", "gap: 4px", "margin-bottom: 8px", "flex-wrap: wrap"],
    @shared.valid_colors.map(fn(c) {
      let bg = if c == "" { "#f1f5f9" } else { @shared.color_to_css(c) }
      let is_selected = c == current
      let border = if is_selected {
        "2px solid #1a1a2e"
      } else {
        "2px solid transparent"
      }
      @html.div(
        on_click=dispatch(on_change(c)),
        style=[
          "width: 24px",
          "height: 24px",
          "border-radius: 50%",
          "background: \{bg}",
          "cursor: pointer",
          "border: \{border}",
        ],
        [@html.text("")],
      )
    }),
  )
}

///|
/// Render a single card; shows inline edit form when editing this card.
fn Model::view_card_item(
  self : Model,
  dispatch : @rabbita.Dispatch[Msg],
  card : @shared.Card,
) -> @rabbita.Html {
  let is_moving = self.moving_card == card.id
  let border_left = match @shared.color_to_css(card.color) {
    "" => "3px solid #e2e8f0"
    css => "3px solid \{css}"
  }
  let bg = if is_moving { "#f0fdfa" } else { "white" }
  if self.editing_card == card.id {
    // Inline edit form
    @html.div(
      style=[
        "background: white", "border-radius: 8px", "padding: 12px", "border: 1px solid #0d9488",
        "margin-bottom: 6px",
      ],
      [
        @html.input(
          input_type=Text,
          placeholder="Card title",
          value=self.edit_title,
          on_input=fn(v) { dispatch(EditTitleChanged(v)) },
          style=[
            "width: 100%", "padding: 6px 8px", "border: 1px solid #e2e8f0", "border-radius: 4px",
            "font-size: 13px", "outline: none", "margin-bottom: 6px",
          ],
          "",
        ),
        @html.textarea(
          placeholder="Description (optional)",
          value=self.edit_desc,
          on_input=fn(v) { dispatch(EditDescChanged(v)) },
          rows=2,
          style=[
            "width: 100%", "padding: 6px 8px", "border: 1px solid #e2e8f0", "border-radius: 4px",
            "font-size: 12px", "outline: none", "resize: vertical", "font-family: inherit",
            "margin-bottom: 6px",
          ],
          "",
        ),
        view_color_picker(dispatch, self.edit_color, fn(c) {
          EditColorChanged(c)
        }),
        @html.div(style=["display: flex", "gap: 6px"], [
          @html.button(
            on_click=dispatch(SaveEditCard),
            style=[
              "padding: 5px 12px", "background: #0d9488", "color: white", "border: none",
              "border-radius: 4px", "cursor: pointer", "font-size: 12px",
            ],
            "Save",
          ),
          @html.button(
            on_click=dispatch(CancelEditCard),
            style=[
              "padding: 5px 12px", "background: #f1f5f9", "color: #64748b", "border: none",
              "border-radius: 4px", "cursor: pointer", "font-size: 12px",
            ],
            "Cancel",
          ),
        ]),
      ],
    )
  } else {
    @html.div(
      style=[
        "background: \{bg}",
        "border-radius: 8px",
        "padding: 10px 12px",
        "border-left: \{border_left}",
        "margin-bottom: 6px",
        "border: 1px solid #f0f0f5",
        "transition: all 0.15s",
      ],
      [
        @html.div(
          style=[
            "font-size: 14px", "font-weight: 500", "color: #1e293b", "margin-bottom: 4px",
          ],
          [@html.text(card.title)],
        ),
        if card.description != "" {
          @html.div(
            style=[
              "font-size: 12px", "color: #64748b", "margin-bottom: 6px", "line-height: 1.4",
            ],
            [@html.text(card.description)],
          )
        } else {
          @html.text("")
        },
        @html.div(
          style=["display: flex", "gap: 4px", "justify-content: flex-end"],
          [
            {
              let move_bg = if is_moving { "#0d9488" } else { "#f8fafc" }
              let move_fg = if is_moving { "white" } else { "#64748b" }
              @html.button(
                on_click=dispatch(SelectCardToMove(card.id)),
                style=[
                  "padding: 3px 8px",
                  "font-size: 11px",
                  "cursor: pointer",
                  "border-radius: 4px",
                  "border: 1px solid #e2e8f0",
                  "background: \{move_bg}",
                  "color: \{move_fg}",
                ],
                if is_moving {
                  "Moving..."
                } else {
                  "Move"
                },
              )
            },
            @html.button(
              on_click=dispatch(StartEditCard(card)),
              style=[
                "padding: 3px 8px", "font-size: 11px", "cursor: pointer", "border-radius: 4px",
                "border: 1px solid #e2e8f0", "background: #f8fafc", "color: #64748b",
              ],
              "Edit",
            ),
            @html.button(
              on_click=dispatch(DeleteCard(card.id)),
              style=[
                "padding: 3px 8px", "font-size: 11px", "cursor: pointer", "border-radius: 4px",
                "border: 1px solid #fecaca", "background: #fef2f2", "color: #dc2626",
              ],
              "Del",
            ),
          ],
        ),
      ],
    )
  }
}

///|
/// Render the inline form for creating a new card in a column.
fn Model::view_add_card_form(
  self : Model,
  dispatch : @rabbita.Dispatch[Msg],
) -> @rabbita.Html {
  @html.div(
    style=[
      "padding: 10px", "background: #f8fafc", "border-radius: 8px", "border: 1px solid #e2e8f0",
      "margin-top: 6px",
    ],
    [
      @html.input(
        input_type=Text,
        placeholder="Card title",
        value=self.new_card_title,
        on_input=fn(v) { dispatch(NewCardTitleChanged(v)) },
        style=[
          "width: 100%", "padding: 6px 8px", "border: 1px solid #e2e8f0", "border-radius: 4px",
          "font-size: 13px", "outline: none", "margin-bottom: 6px",
        ],
        "",
      ),
      @html.textarea(
        placeholder="Description (optional)",
        value=self.new_card_desc,
        on_input=fn(v) { dispatch(NewCardDescChanged(v)) },
        rows=2,
        style=[
          "width: 100%", "padding: 6px 8px", "border: 1px solid #e2e8f0", "border-radius: 4px",
          "font-size: 12px", "outline: none", "resize: vertical", "font-family: inherit",
          "margin-bottom: 6px",
        ],
        "",
      ),
      view_color_picker(dispatch, self.new_card_color, fn(c) {
        NewCardColorChanged(c)
      }),
      @html.div(style=["display: flex", "gap: 6px"], [
        @html.button(
          on_click=dispatch(AddCard),
          style=[
            "padding: 5px 12px", "background: #0d9488", "color: white", "border: none",
            "border-radius: 4px", "cursor: pointer", "font-size: 12px",
          ],
          "Add Card",
        ),
        @html.button(
          on_click=dispatch(HideAddCard),
          style=[
            "padding: 5px 12px", "background: #f1f5f9", "color: #64748b", "border: none",
            "border-radius: 4px", "cursor: pointer", "font-size: 12px",
          ],
          "Cancel",
        ),
      ]),
    ],
  )
}

///|
/// Render a single column with its header, card list, and add-card button.
fn Model::view_column(
  self : Model,
  dispatch : @rabbita.Dispatch[Msg],
  column : @shared.Column,
  col_index : Int,
  total_cols : Int,
) -> @rabbita.Html {
  let col_cards = @shared.cards_in_column(self.cards, column.id)
  let is_moving = self.moving_card != 0
  @html.div(
    style=[
      "min-width: 272px", "max-width: 272px", "background: #f1f5f9", "border-radius: 10px",
      "padding: 12px", "display: flex", "flex-direction: column", "max-height: calc(100vh - 140px)",
    ],
    [
      // Column header
      if self.renaming_column == column.id {
        @html.div(style=["margin-bottom: 10px"], [
          @html.input(
            input_type=Text,
            value=self.rename_column_title,
            on_input=fn(v) { dispatch(RenameColumnTitleChanged(v)) },
            style=[
              "width: 100%", "padding: 6px 8px", "border: 1px solid #0d9488", "border-radius: 4px",
              "font-size: 14px", "outline: none", "font-weight: 600",
            ],
            "",
          ),
          @html.div(style=["display: flex", "gap: 4px", "margin-top: 4px"], [
            @html.button(
              on_click=dispatch(ConfirmRenameColumn),
              style=[
                "padding: 3px 10px", "background: #0d9488", "color: white", "border: none",
                "border-radius: 4px", "cursor: pointer", "font-size: 11px",
              ],
              "Save",
            ),
            @html.button(
              on_click=dispatch(CancelRenameColumn),
              style=[
                "padding: 3px 10px", "background: #e2e8f0", "color: #64748b", "border: none",
                "border-radius: 4px", "cursor: pointer", "font-size: 11px",
              ],
              "Cancel",
            ),
          ]),
        ])
      } else {
        @html.div(
          style=[
            "display: flex", "justify-content: space-between", "align-items: center",
            "margin-bottom: 10px", "padding: 0 2px",
          ],
          [
            @html.div(
              on_click=dispatch(StartRenameColumn(column.id, column.title)),
              style=[
                "font-size: 14px", "font-weight: 600", "color: #334155", "cursor: pointer",
              ],
              [
                @html.text(column.title),
                @html.span(
                  style=[
                    "color: #94a3b8", "font-weight: 400", "margin-left: 6px",
                  ],
                  "\{col_cards.length()}",
                ),
              ],
            ),
            @html.div(style=["display: flex", "gap: 2px"], [
              if col_index > 0 {
                @html.button(
                  on_click=dispatch(MoveColumnLeft(column.id)),
                  style=[
                    "padding: 2px 6px", "background: transparent", "color: #94a3b8",
                    "border: none", "cursor: pointer", "font-size: 12px",
                  ],
                  "\u{25C0}",
                )
              } else {
                @html.text("")
              },
              if col_index < total_cols - 1 {
                @html.button(
                  on_click=dispatch(MoveColumnRight(column.id)),
                  style=[
                    "padding: 2px 6px", "background: transparent", "color: #94a3b8",
                    "border: none", "cursor: pointer", "font-size: 12px",
                  ],
                  "\u{25B6}",
                )
              } else {
                @html.text("")
              },
              @html.button(
                on_click=dispatch(DeleteColumn(column.id)),
                style=[
                  "padding: 2px 6px", "background: transparent", "color: #dc2626",
                  "border: none", "cursor: pointer", "font-size: 12px",
                ],
                "\u{2715}",
              ),
            ]),
          ],
        )
      },
      // Cards list with optional drop zones
      @html.div(
        style=["flex: 1", "overflow-y: auto"],
        {
          let items : Array[@rabbita.Html] = []
          for i, card in col_cards {
            if is_moving {
              items.push(view_drop_zone(dispatch, column.id, i))
            }
            items.push(self.view_card_item(dispatch, card))
          }
          // Bottom drop zone
          if is_moving {
            items.push(view_drop_zone(dispatch, column.id, col_cards.length()))
          }
          items
        },
      ),
      // Add card button/form
      if self.adding_to_column == column.id {
        self.view_add_card_form(dispatch)
      } else {
        @html.button(
          on_click=dispatch(ShowAddCard(column.id)),
          style=[
            "width: 100%", "padding: 8px", "background: transparent", "color: #94a3b8",
            "border: 1px dashed #cbd5e1", "border-radius: 6px", "cursor: pointer",
            "font-size: 13px", "margin-top: 6px",
          ],
          "+ Add Card",
        )
      },
    ],
  )
}

///|
/// MVU view: render the full board from current model state.
pub fn Model::view(self : Model, dispatch : @rabbita.Dispatch[Msg]) -> @rabbita.Html {
  let sorted_columns = @shared.sort_by_position(self.columns, fn(c) {
    c.position
  })
  @html.div(style=["padding: 16px 24px", "min-height: 100vh"], [
    self.view_header(dispatch),
    if self.loading {
      @html.div(
        style=[
          "text-align: center", "padding: 60px 0", "color: #94a3b8", "font-size: 15px",
        ],
        [@html.text("Loading...")],
      )
    } else {
      @html.div(
        style=[
          "display: flex", "gap: 16px", "overflow-x: auto", "padding-bottom: 16px",
          "align-items: flex-start",
        ],
        {
          let cols : Array[@rabbita.Html] = sorted_columns.mapi(fn(i, col) {
            self.view_column(dispatch, col, i, sorted_columns.length())
          })
          if self.adding_column {
            cols.push(self.view_add_column_form(dispatch))
          }
          cols
        },
      )
    },
  ])
}
