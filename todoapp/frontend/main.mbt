///|
fn main {
  let (dispatch, app_cell) = @rabbita.cell_with_dispatch(
    model=@app.Model::{ todos: [], input: "", loading: false },
    update=fn(dispatch, msg : @app.Msg, model) { msg.update(dispatch, model) },
    view=fn(dispatch, model) { model.view(dispatch) },
  )
  let app = @rabbita.new(app_cell)
  app.with_init(dispatch(@app.Init))
  app.mount("app")
}
