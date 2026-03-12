///|
pub let api_contacts : String = "/api/contacts"

///|
pub fn api_contact(id : Int) -> String {
  "/api/contacts/\{id}"
}

///|
pub fn api_contact_favorite(id : Int) -> String {
  "/api/contacts/\{id}/favorite"
}
