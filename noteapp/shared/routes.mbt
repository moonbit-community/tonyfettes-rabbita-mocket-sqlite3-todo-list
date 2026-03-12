///|
pub let api_notes : String = "/api/notes"

///|
pub fn api_note(id : Int) -> String {
  "/api/notes/\{id}"
}

///|
pub fn api_note_pin(id : Int) -> String {
  "/api/notes/\{id}/pin"
}
