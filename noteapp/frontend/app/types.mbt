///|
/// Application state for the notes frontend, following the Elm architecture.
pub(all) struct Model {
  notes : Array[@shared.Note]
  /// New note form
  title_input : String
  content_input : String
  /// Currently selected note id for detail view (0 = none)
  selected_note_id : Int
} derive(Debug)

///|
/// Messages that drive state transitions in the update loop.
pub(all) enum Msg {
  /// Trigger initial data fetch on app startup.
  Init
  /// Response from fetching all notes from the API.
  GotNotes(Result[Array[@shared.Note], String])
  /// User typed in the title input field.
  TitleInputChanged(String)
  /// User typed in the content textarea.
  ContentInputChanged(String)
  /// User submitted the new-note form.
  SaveNote
  /// Response after creating a note via the API.
  NoteSaved(Result[@shared.Note, String])
  /// User clicked a note to view its detail.
  SelectNote(Int)
  /// User clicked back from the detail view.
  DeselectNote
  /// User toggled a note's pinned status.
  TogglePin(Int)
  /// Response after toggling pin via the API.
  NotePinToggled(Result[@shared.Note, String])
  /// User requested deletion of a note.
  DeleteNote(Int)
  /// Response after deleting a note via the API.
  NoteDeleted(Result[Int, String])
} derive(Debug)
