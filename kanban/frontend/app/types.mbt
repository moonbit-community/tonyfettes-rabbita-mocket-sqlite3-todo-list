///|
/// Application state for the Kanban board MVU architecture.
pub(all) struct Model {
  columns : Array[@shared.Column]
  cards : Array[@shared.Card]
  // Card creation
  adding_to_column : Int
  new_card_title : String
  new_card_desc : String
  new_card_color : String
  // Card editing
  editing_card : Int
  edit_title : String
  edit_desc : String
  edit_color : String
  // Column creation
  adding_column : Bool
  new_column_title : String
  // Column renaming
  renaming_column : Int
  rename_column_title : String
  // Move mode
  moving_card : Int
  loading : Bool
} derive(Debug)

///|
/// All possible user actions and server responses.
pub(all) enum Msg {
  Init
  GotBoard(Result[@shared.Board, String])
  // Column CRUD
  ShowAddColumn
  HideAddColumn
  NewColumnTitleChanged(String)
  AddColumn
  ColumnAdded(Result[@shared.Column, String])
  StartRenameColumn(Int, String)
  CancelRenameColumn
  RenameColumnTitleChanged(String)
  ConfirmRenameColumn
  ColumnRenamed
  DeleteColumn(Int)
  ColumnDeleted
  MoveColumnLeft(Int)
  MoveColumnRight(Int)
  ColumnMoved
  // Card CRUD
  ShowAddCard(Int)
  HideAddCard
  NewCardTitleChanged(String)
  NewCardDescChanged(String)
  NewCardColorChanged(String)
  AddCard
  CardAdded(Result[@shared.Card, String])
  StartEditCard(@shared.Card)
  CancelEditCard
  EditTitleChanged(String)
  EditDescChanged(String)
  EditColorChanged(String)
  SaveEditCard
  CardUpdated
  DeleteCard(Int)
  CardDeleted
  // Move mode
  SelectCardToMove(Int)
  CancelMove
  MoveCardTo(Int, Int)
  CardMoved
} derive(Debug)
