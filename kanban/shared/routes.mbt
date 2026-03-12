///|
pub let api_board : String = "/api/board"

///|
pub let api_columns : String = "/api/columns"

///|
pub fn api_column(id : Int) -> String {
  "/api/columns/\{id}"
}

///|
pub fn api_column_move(id : Int) -> String {
  "/api/columns/\{id}/move"
}

///|
pub let api_cards : String = "/api/cards"

///|
pub fn api_card(id : Int) -> String {
  "/api/cards/\{id}"
}

///|
pub fn api_card_move(id : Int) -> String {
  "/api/cards/\{id}/move"
}
