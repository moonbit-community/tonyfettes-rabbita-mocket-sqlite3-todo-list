///|
/// Application state for the todo list UI.
pub(all) struct Model {
  todos : Array[@shared.Todo]
  input : String
  loading : Bool
} derive(Debug)

///|
/// Messages that drive state transitions in the update loop.
pub(all) enum Msg {
  Init
  GotTodos(Result[Array[@shared.Todo], String])
  InputChanged(String)
  AddTodo
  TodoAdded(Result[@shared.Todo, String])
  ToggleTodo(Int)
  TodoToggled(Result[@shared.Todo, String])
  DeleteTodo(Int)
  TodoDeleted(Result[Int, String])
} derive(Debug)
