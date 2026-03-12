///|
pub let max_todo_length : Int = 256

///|
pub fn validate_text(text : String) -> Bool {
  text != "" && text.char_length() <= max_todo_length
}
