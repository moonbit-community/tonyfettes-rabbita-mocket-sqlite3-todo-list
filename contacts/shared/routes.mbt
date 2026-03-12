///|
/// Base API path for the contacts collection endpoint.
pub let api_contacts : String = "/api/contacts"

///|
/// Build the API path for a single contact by id.
pub fn api_contact(id : Int) -> String {
  "/api/contacts/\{id}"
}

///|
/// Build the API path for toggling a contact's favorite status by id.
pub fn api_contact_favorite(id : Int) -> String {
  "/api/contacts/\{id}/favorite"
}
