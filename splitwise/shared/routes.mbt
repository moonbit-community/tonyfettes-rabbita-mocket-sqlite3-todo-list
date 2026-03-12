///|
pub let api_state : String = "/api/state"

///|
pub let api_people : String = "/api/people"

///|
pub let api_expenses : String = "/api/expenses"

///|
pub fn api_expense(id : Int) -> String {
  "/api/expenses/\{id}"
}
