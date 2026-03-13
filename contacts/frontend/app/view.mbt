///|
/// Render the full contacts UI: header, search bar, add-contact form,
/// favorites section, and all-contacts section.
pub fn Model::view(self : Model, dispatch : @rabbita.Dispatch[Msg]) -> @rabbita.Html {
  let sorted = @shared.sort_contacts(self.contacts)
  let filtered = @shared.filter_contacts(sorted, self.search_query)
  let favorites = filtered.filter(fn(c) { c.favorite })
  let non_favorites = filtered.filter(fn(c) { !c.favorite })
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
          style=[
            "text-align: center", "margin-bottom: 24px", "padding-top: 12px",
          ],
          [
            @html.h1(
              style=[
                "color: white", "font-size: 26px", "font-weight: 800",
                "margin-bottom: 4px", "letter-spacing: -0.5px",
              ],
              "Contacts",
            ),
            @html.p(
              style=["color: rgba(255,255,255,0.75)", "font-size: 13px"],
              "Your address book",
            ),
          ],
        ),
      )
      // Search bar
      sections.push(
        @html.div(
          style=["margin-bottom: 14px"],
          [
            @html.input(
              input_type=Text,
              placeholder="Search contacts...",
              value=self.search_query,
              on_input=fn(v) { dispatch(SearchChanged(v)) },
              style=[
                "width: 100%", "padding: 12px 16px", "border: 2px solid #eee",
                "border-radius: 10px", "font-size: 14px", "outline: none",
                "background: white",
              ],
              "",
            ),
          ],
        ),
      )
      // Contact count + Add button
      sections.push(
        view_card(
          "",
          [
            @html.div(
              style=[
                "display: flex", "justify-content: space-between",
                "align-items: center",
              ],
              [
                @html.span(
                  style=[
                    "font-size: 14px", "color: #666", "font-weight: 500",
                  ],
                  {
                    let count = self.contacts.length()
                    let suffix = if count != 1 { "s" } else { "" }
                    "\{count} contact\{suffix}"
                  },
                ),
                @html.button(
                  on_click=dispatch(ToggleForm),
                  style=[
                    "padding: 8px 18px",
                    "background: linear-gradient(135deg, #667eea, #764ba2)",
                    "color: white", "border: none", "border-radius: 10px",
                    "cursor: pointer", "font-size: 13px", "font-weight: 600",
                  ],
                  if self.show_form { "Cancel" } else { "+ Add Contact" },
                ),
              ],
            ),
            // Add contact form (toggled)
            if self.show_form {
              @html.form(
                on_submit=dispatch(AddContact),
                style=[
                  "display: flex", "flex-direction: column", "gap: 10px",
                  "margin-top: 16px", "padding-top: 16px",
                  "border-top: 1px solid #f0f0f0",
                ],
                [
                  @html.input(
                    input_type=Text,
                    placeholder="Name",
                    value=self.name_input,
                    on_input=fn(v) { dispatch(NameInputChanged(v)) },
                    style=[
                      "padding: 10px 14px", "border: 2px solid #eee",
                      "border-radius: 10px", "font-size: 14px",
                      "outline: none",
                    ],
                    "",
                  ),
                  @html.input(
                    input_type=Text,
                    placeholder="Email",
                    value=self.email_input,
                    on_input=fn(v) { dispatch(EmailInputChanged(v)) },
                    style=[
                      "padding: 10px 14px", "border: 2px solid #eee",
                      "border-radius: 10px", "font-size: 14px",
                      "outline: none",
                    ],
                    "",
                  ),
                  @html.input(
                    input_type=Text,
                    placeholder="Phone",
                    value=self.phone_input,
                    on_input=fn(v) { dispatch(PhoneInputChanged(v)) },
                    style=[
                      "padding: 10px 14px", "border: 2px solid #eee",
                      "border-radius: 10px", "font-size: 14px",
                      "outline: none",
                    ],
                    "",
                  ),
                  @html.button(
                    type_="submit",
                    style=[
                      "padding: 12px",
                      "background: linear-gradient(135deg, #667eea, #764ba2)",
                      "color: white", "border: none", "border-radius: 10px",
                      "cursor: pointer", "font-size: 15px", "font-weight: 600",
                      "margin-top: 2px",
                    ],
                    "Save Contact",
                  ),
                ],
              )
            } else {
              @html.div(style=[], "")
            },
          ],
        ),
      )
      // Favorites section
      if favorites.length() > 0 {
        sections.push(
          view_card(
            "Favorites",
            favorites.map(fn(c) { view_contact_row(dispatch, c) }),
          ),
        )
      }
      // All contacts section
      if non_favorites.length() > 0 {
        sections.push(
          view_card(
            if favorites.length() > 0 { "Other Contacts" } else { "All Contacts" },
            non_favorites.map(fn(c) { view_contact_row(dispatch, c) }),
          ),
        )
      } else if favorites.length() == 0 && self.contacts.length() > 0 && self.search_query != "" {
        sections.push(
          view_card(
            "Contacts",
            [
              @html.p(
                style=[
                  "color: #aaa", "font-size: 13px", "text-align: center",
                  "padding: 12px 0",
                ],
                "No contacts match your search",
              ),
            ],
          ),
        )
      } else if self.contacts.length() == 0 {
        sections.push(
          view_card(
            "Contacts",
            [
              @html.p(
                style=[
                  "color: #aaa", "font-size: 13px", "text-align: center",
                  "padding: 12px 0",
                ],
                "No contacts yet. Add your first contact!",
              ),
            ],
          ),
        )
      }
      sections
    },
  )
}

/// Render a single contact row.
fn view_contact_row(
  dispatch : @rabbita.Dispatch[Msg],
  contact : @shared.Contact,
) -> @rabbita.Html {
  let color = person_color(contact.id)
  let initials = @shared.get_initials(contact.name)
  @html.div(
    style=[
      "display: flex", "align-items: center", "gap: 12px", "padding: 10px 0",
      "border-bottom: 1px solid #f5f5f5",
    ],
    [
      // Avatar circle with initials
      @html.div(
        style=[
          "width: 42px", "height: 42px", "border-radius: 50%",
          "flex-shrink: 0", "background: \{color}", "color: white",
          "font-size: 15px", "font-weight: 700", "display: flex",
          "align-items: center", "justify-content: center",
        ],
        initials,
      ),
      // Name, email, phone
      @html.div(
        style=["flex: 1", "min-width: 0"],
        [
          @html.div(
            style=[
              "font-weight: 600", "font-size: 14px", "margin-bottom: 2px",
            ],
            contact.name,
          ),
          @html.div(
            style=["font-size: 12px", "color: #999", "margin-bottom: 1px"],
            contact.email,
          ),
          @html.div(
            style=["font-size: 12px", "color: #999"],
            @shared.format_phone(contact.phone),
          ),
        ],
      ),
      // Favorite star button
      @html.button(
        on_click=dispatch(ToggleFavorite(contact.id)),
        style=[
          "width: 32px", "height: 32px", "background: none",
          "border: none", "cursor: pointer", "font-size: 18px",
          "flex-shrink: 0", "display: flex", "align-items: center",
          "justify-content: center",
        ],
        if contact.favorite { "★" } else { "☆" },
      ),
      // Delete button
      @html.button(
        on_click=dispatch(DeleteContact(contact.id)),
        style=[
          "width: 28px", "height: 28px", "background: #fee",
          "color: #e53935", "border: none", "border-radius: 8px",
          "cursor: pointer", "font-size: 13px", "font-weight: 700",
          "flex-shrink: 0", "display: flex", "align-items: center",
          "justify-content: center",
        ],
        "X",
      ),
    ],
  )
}

/// Render a white card with a section title.
fn view_card(
  title : String,
  children : Array[@rabbita.Html],
) -> @rabbita.Html {
  @html.div(
    style=[
      "background: white", "border-radius: 14px", "padding: 18px 20px",
      "margin-bottom: 14px", "box-shadow: 0 1px 8px rgba(0,0,0,0.06)",
    ],
    {
      let all : Array[@rabbita.Html] = []
      if title != "" {
        all.push(
          @html.h2(
            style=[
              "font-size: 13px", "font-weight: 700", "color: #999",
              "margin-bottom: 14px", "text-transform: uppercase",
              "letter-spacing: 0.5px",
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

/// Pick a consistent color for a contact based on their id.
fn person_color(id : Int) -> String {
  let colors = [
    "#667eea", "#e91e63", "#00bcd4", "#ff9800", "#8bc34a",
    "#9c27b0", "#009688", "#f44336", "#3f51b5", "#795548",
  ]
  colors[(id - 1) % colors.length()]
}
