///|
test "api routes" {
  inspect(@shared.api_board, content="/api/board")
  inspect(@shared.api_columns, content="/api/columns")
  inspect(@shared.api_cards, content="/api/cards")
  inspect(@shared.api_column(42), content="/api/columns/42")
  inspect(@shared.api_column_move(7), content="/api/columns/7/move")
  inspect(@shared.api_card(99), content="/api/cards/99")
  inspect(@shared.api_card_move(5), content="/api/cards/5/move")
}
