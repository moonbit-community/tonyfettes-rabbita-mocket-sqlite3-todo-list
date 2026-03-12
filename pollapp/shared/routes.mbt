///|
/// Base API endpoint for listing and creating polls.
pub let api_polls : String = "/api/polls"

///|
/// Build the API endpoint for a single poll by ID (used for GET and DELETE).
pub fn api_poll(id : Int) -> String {
  "/api/polls/\{id}"
}

///|
/// Build the API endpoint for voting on a poll by ID.
pub fn api_poll_vote(id : Int) -> String {
  "/api/polls/\{id}/vote"
}
