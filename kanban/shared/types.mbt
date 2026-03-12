///|
pub(all) struct Card {
  id : Int
  column_id : Int
  title : String
  description : String
  color : String
  position : Int
} derive(ToJson, FromJson, Show)

///|
pub(all) struct Column {
  id : Int
  title : String
  position : Int
} derive(ToJson, FromJson, Show)

///|
pub(all) struct Board {
  columns : Array[Column]
  cards : Array[Card]
} derive(ToJson, FromJson, Show)

///|
pub(all) struct MoveCardRequest {
  card_id : Int
  target_column_id : Int
  new_position : Int
} derive(ToJson, FromJson, Show)
