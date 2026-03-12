///|
pub let max_question_length : Int = 200

///|
pub let max_option_length : Int = 100

///|
pub let min_options : Int = 2

///|
pub let max_options : Int = 6

/// Validate a poll question: non-empty and within length limit.
pub fn validate_question(q : String) -> Bool {
  q != "" && q.char_length() <= max_question_length
}

/// Validate a poll option text: non-empty and within length limit.
pub fn validate_option(text : String) -> Bool {
  text != "" && text.char_length() <= max_option_length
}
