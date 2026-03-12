///|
pub let max_card_title : Int = 100

///|
pub let max_card_description : Int = 500

///|
pub let max_column_title : Int = 30

///|
pub let max_columns : Int = 10

///|
pub let max_cards_per_column : Int = 50

///|
pub let valid_colors : Array[String] = [
  "", "red", "orange", "yellow", "green", "blue", "purple",
]

///|
pub fn validate_card_title(title : String) -> Bool {
  title != "" && title.char_length() <= max_card_title
}

///|
pub fn validate_card_description(desc : String) -> Bool {
  desc.char_length() <= max_card_description
}

///|
pub fn validate_column_title(title : String) -> Bool {
  title != "" && title.char_length() <= max_column_title
}

///|
pub fn validate_color(color : String) -> Bool {
  for c in valid_colors {
    if c == color {
      return true
    }
  }
  false
}
