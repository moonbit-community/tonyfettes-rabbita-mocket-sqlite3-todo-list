///|
/// Base path for the notes REST API. Used by both frontend and backend.
pub let api_notes : String = "/api/notes"

///|
/// Build the API path for a single note by id (e.g. `/api/notes/42`).
pub fn api_note(id : Int) -> String {
  "/api/notes/\{id}"
}

///|
/// Build the API path to toggle a note's pin status (e.g. `/api/notes/42/pin`).
pub fn api_note_pin(id : Int) -> String {
  "/api/notes/\{id}/pin"
}
