///|
pub let api_polls : String = "/api/polls"

///|
pub fn api_poll(id : Int) -> String {
  "/api/polls/\{id}"
}

///|
pub fn api_poll_vote(id : Int) -> String {
  "/api/polls/\{id}/vote"
}
