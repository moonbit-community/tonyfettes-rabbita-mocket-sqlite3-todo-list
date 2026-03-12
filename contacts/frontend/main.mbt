///|
/// Application state for the contacts frontend.
/// Holds the contact list, search query, and add-contact form fields.
struct Model {
  contacts : Array[@shared.Contact]
  /// Search query
  search_query : String
  /// Add contact form fields
  name_input : String
  email_input : String
  phone_input : String
  /// Whether the add contact form is visible
  show_form : Bool
}

///|
/// Messages that drive the Elm-architecture update loop.
enum Msg {
  /// Fired on app start to trigger the initial contact fetch.
  Init
  /// Response from fetching all contacts from the server.
  GotContacts(Result[Array[@shared.Contact], String])
  /// User changed the search input text.
  SearchChanged(String)
  /// Toggle visibility of the add-contact form.
  ToggleForm
  /// User changed the name field in the add-contact form.
  NameInputChanged(String)
  /// User changed the email field in the add-contact form.
  EmailInputChanged(String)
  /// User changed the phone field in the add-contact form.
  PhoneInputChanged(String)
  /// User submitted the add-contact form.
  AddContact
  /// Response from the server after creating a new contact.
  ContactAdded(Result[@shared.Contact, String])
  /// User clicked the favorite star on a contact.
  ToggleFavorite(Int)
  /// Response from the server after toggling favorite status.
  FavoriteToggled(Result[@shared.Contact, String])
  /// User clicked the delete button on a contact.
  DeleteContact(Int)
  /// Response from the server after deleting a contact.
  ContactDeleted(Result[Int, String])
}

///|
/// Fetch all contacts from the backend via GET /api/contacts.
fn fetch_contacts(dispatch : @rabbita.Dispatch[Msg]) -> @rabbita.Cmd {
  @http.get(
    @shared.api_contacts,
    expect=Json(result => dispatch(GotContacts(result)), json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Failed to decode contacts")
      }
    }),
  )
}

///|
/// Elm-architecture update function. Processes each `Msg` and returns the
/// next command and model state.
fn update(
  dispatch : @rabbita.Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    Init => (fetch_contacts(dispatch), model)
    GotContacts(Ok(contacts)) =>
      (@rabbita.none, { ..model, contacts })
    GotContacts(Err(_)) => (@rabbita.none, model)
    SearchChanged(v) => (@rabbita.none, { ..model, search_query: v })
    ToggleForm =>
      (@rabbita.none, { ..model, show_form: !model.show_form })
    NameInputChanged(v) => (@rabbita.none, { ..model, name_input: v })
    EmailInputChanged(v) => (@rabbita.none, { ..model, email_input: v })
    PhoneInputChanged(v) => (@rabbita.none, { ..model, phone_input: v })
    AddContact => {
      if !@shared.validate_name(model.name_input) {
        return (@rabbita.none, model)
      }
      if !@shared.validate_email(model.email_input) {
        return (@rabbita.none, model)
      }
      if !@shared.validate_phone(model.phone_input) {
        return (@rabbita.none, model)
      }
      let body : Json = {
        "name": model.name_input,
        "email": model.email_input,
        "phone": model.phone_input,
      }
      let cmd = @http.post(
        @shared.api_contacts,
        Json(body),
        expect=Json(fn(r) { dispatch(ContactAdded(r)) }, fn(json) {
          Ok(@json.from_json(json)) catch {
            _ => Err("Failed to decode contact")
          }
        }),
      )
      (
        cmd,
        {
          ..model,
          name_input: "",
          email_input: "",
          phone_input: "",
          show_form: false,
        },
      )
    }
    ContactAdded(Ok(contact)) => {
      let contacts = model.contacts.copy()
      contacts.push(contact)
      (@rabbita.none, { ..model, contacts })
    }
    ContactAdded(Err(_)) => (@rabbita.none, model)
    ToggleFavorite(id) => {
      let cmd = @http.post(
        @shared.api_contact_favorite(id),
        Json(({  } : Json)),
        expect=Json(fn(r) { dispatch(FavoriteToggled(r)) }, fn(json) {
          Ok(@json.from_json(json)) catch {
            _ => Err("Failed to decode contact")
          }
        }),
      )
      (cmd, model)
    }
    FavoriteToggled(Ok(updated)) => {
      let contacts = model.contacts.map(fn(c) {
        if c.id == updated.id {
          updated
        } else {
          c
        }
      })
      (@rabbita.none, { ..model, contacts })
    }
    FavoriteToggled(Err(_)) => (@rabbita.none, model)
    DeleteContact(id) => {
      let cmd = @http.delete(
        @shared.api_contact(id),
        expect=Text(fn(result) {
          dispatch(
            ContactDeleted(
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
    ContactDeleted(Ok(id)) => {
      let contacts = model.contacts.filter(fn(c) { c.id != id })
      (@rabbita.none, { ..model, contacts })
    }
    ContactDeleted(Err(_)) => (@rabbita.none, model)
  }
}

///|
/// Render the full contacts UI: header, search bar, add-contact form,
/// favorites section, and all-contacts section.
fn view(dispatch : @rabbita.Dispatch[Msg], model : Model) -> @rabbita.Html {
  let sorted = @shared.sort_contacts(model.contacts)
  let filtered = @shared.filter_contacts(sorted, model.search_query)
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
              value=model.search_query,
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
                    let count = model.contacts.length()
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
                  if model.show_form { "Cancel" } else { "+ Add Contact" },
                ),
              ],
            ),
            // Add contact form (toggled)
            if model.show_form {
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
                    value=model.name_input,
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
                    value=model.email_input,
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
                    value=model.phone_input,
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
      } else if favorites.length() == 0 && model.contacts.length() > 0 && model.search_query != "" {
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
      } else if model.contacts.length() == 0 {
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

///|
/// Entry point. Initializes the Rabbita app with the Model-Update-View
/// cell and mounts it to the "app" DOM element.
fn main {
  let (dispatch, app_cell) = @rabbita.cell_with_dispatch(
    model={
      contacts: [],
      search_query: "",
      name_input: "",
      email_input: "",
      phone_input: "",
      show_form: false,
    },
    update~,
    view~,
  )
  let app = @rabbita.new(app_cell)
  app.with_init(dispatch(Init))
  app.mount("app")
}
