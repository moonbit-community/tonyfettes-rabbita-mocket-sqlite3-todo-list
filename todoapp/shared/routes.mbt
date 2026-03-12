///|
pub let api_todos : String = "/api/todos"

///|
pub fn api_todo(id : Int) -> String {
  "/api/todos/\{id}"
}

///|
pub fn api_todo_toggle(id : Int) -> String {
  "/api/todos/\{id}/toggle"
}
