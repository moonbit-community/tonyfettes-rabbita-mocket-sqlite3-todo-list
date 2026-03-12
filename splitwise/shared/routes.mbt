///|
/// API endpoint for fetching the full application state (people, expenses, settlements).
pub let api_state : String = "/api/state"

///|
/// API endpoint for creating people.
pub let api_people : String = "/api/people"

///|
/// API endpoint for listing and creating expenses.
pub let api_expenses : String = "/api/expenses"

///|
/// Build the API endpoint path for a specific expense by its id.
pub fn api_expense(id : Int) -> String {
  "/api/expenses/\{id}"
}
