///|
fn view_header(dispatch : @rabbita.Dispatch[Msg]) -> @rabbita.Html {
  @html.div(
    style=[
      "display: flex", "justify-content: space-between", "align-items: center", "padding: 16px 0",
      "margin-bottom: 32px",
    ],
    [
      @html.div(style=["cursor: pointer"], on_click=dispatch(GoToList), [
        @html.h1(
          style=[
            "font-size: 24px", "font-weight: 700", "color: #1a1a2e", "letter-spacing: -0.5px",
          ],
          "Blog",
        ),
      ]),
      @html.button(
        on_click=dispatch(GoToNewPost),
        style=[
          "padding: 10px 24px", "background: #1a1a2e", "color: white", "border: none",
          "border-radius: 8px", "cursor: pointer", "font-size: 14px", "font-weight: 500",
          "letter-spacing: 0.3px", "transition: all 0.2s",
        ],
        "Write",
      ),
    ],
  )
}

///|
fn Model::view_post_list(
  self : Model,
  dispatch : @rabbita.Dispatch[Msg],
) -> @rabbita.Html {
  @html.div([
    view_header(dispatch),
    if self.loading {
      @html.div(
        style=[
          "text-align: center", "padding: 60px 0", "color: #94a3b8", "font-size: 15px",
        ],
        [@html.text("Loading...")],
      )
    } else if self.posts.length() == 0 {
      @html.div(
        style=["text-align: center", "padding: 80px 0", "color: #94a3b8"],
        [
          @html.p(
            style=["font-size: 18px", "margin-bottom: 8px"],
            "No posts yet",
          ),
          @html.p(style=["font-size: 14px"], "Write your first post!"),
        ],
      )
    } else {
      @html.div(
        self.posts.map(fn(post) {
          @html.div(
            style=[
              "padding: 24px 28px", "margin-bottom: 12px", "background: white", "border-radius: 12px",
              "border: 1px solid #f0f0f5", "cursor: pointer", "transition: all 0.2s",
            ],
            on_click=dispatch(GoToViewPost(post.id)),
            [
              @html.div(
                style=[
                  "display: flex", "align-items: center", "margin-bottom: 12px",
                ],
                [
                  @html.span(
                    style=[
                      "font-size: 12px", "color: #94a3b8", "text-transform: uppercase",
                      "letter-spacing: 0.5px",
                    ],
                    post.created_at,
                  ),
                ],
              ),
              @html.h2(
                style=[
                  "margin-bottom: 10px", "color: #1a1a2e", "font-size: 20px", "font-weight: 600",
                  "line-height: 1.4",
                ],
                post.title,
              ),
              @html.p(
                style=["color: #64748b", "font-size: 15px", "line-height: 1.6"],
                @shared.truncate(post.content, 120),
              ),
            ],
          )
        }),
      )
    },
  ])
}

///|
fn Model::view_comments_section(
  self : Model,
  dispatch : @rabbita.Dispatch[Msg],
  post_id : Int,
) -> @rabbita.Html {
  @html.div(style=["margin-top: 40px"], [
    @html.h3(
      style=[
        "font-size: 18px", "font-weight: 600", "color: #1a1a2e", "margin-bottom: 20px",
      ],
      "Comments (\{self.comments.length()})",
    ),
    // Comment form
    @html.div(
      style=[
        "margin-bottom: 28px", "padding: 20px", "background: #f8f9fc", "border-radius: 12px",
      ],
      [
        @html.div(style=["margin-bottom: 12px"], [
          @html.input(
            input_type=Text,
            placeholder="Name (optional)",
            value=self.comment_author,
            on_input=fn(value) { dispatch(CommentAuthorChanged(value)) },
            style=[
              "width: 100%", "padding: 10px 14px", "border: 1px solid #e2e8f0", "border-radius: 8px",
              "font-size: 14px", "outline: none", "background: white",
            ],
            "",
          ),
        ]),
        @html.div(style=["margin-bottom: 12px"], [
          @html.textarea(
            placeholder="Write a comment...",
            value=self.comment_content,
            on_input=fn(value) { dispatch(CommentContentChanged(value)) },
            rows=3,
            style=[
              "width: 100%", "padding: 10px 14px", "border: 1px solid #e2e8f0", "border-radius: 8px",
              "font-size: 14px", "outline: none", "resize: vertical", "font-family: inherit",
              "background: white",
            ],
            "",
          ),
        ]),
        @html.button(
          on_click=dispatch(AddComment(post_id)),
          style=[
            "padding: 10px 20px", "background: #1a1a2e", "color: white", "border: none",
            "border-radius: 8px", "cursor: pointer", "font-size: 14px", "font-weight: 500",
          ],
          "Post Comment",
        ),
      ],
    ),
    // Comment list
    if self.comments.length() == 0 {
      @html.p(
        style=["color: #94a3b8", "font-size: 14px", "padding: 8px 0"],
        "No comments yet. Be the first!",
      )
    } else {
      @html.div(
        self.comments.map(fn(comment) {
          @html.div(
            style=[
              "padding: 16px 20px", "margin-bottom: 8px", "background: white", "border-radius: 10px",
              "border: 1px solid #f0f0f5",
            ],
            [
              @html.div(
                style=[
                  "display: flex", "justify-content: space-between", "align-items: center",
                  "margin-bottom: 8px",
                ],
                [
                  @html.div(
                    style=["display: flex", "align-items: center", "gap: 10px"],
                    [
                      @html.span(
                        style=[
                          "font-weight: 600", "color: #1a1a2e", "font-size: 14px",
                        ],
                        comment.author,
                      ),
                      @html.span(
                        style=["color: #94a3b8", "font-size: 12px"],
                        comment.created_at,
                      ),
                    ],
                  ),
                  @html.button(
                    on_click=dispatch(DeleteComment(post_id, comment.id)),
                    style=[
                      "padding: 4px 10px", "background: transparent", "color: #94a3b8",
                      "border: 1px solid #e2e8f0", "border-radius: 6px", "cursor: pointer",
                      "font-size: 12px",
                    ],
                    "Delete",
                  ),
                ],
              ),
              @html.p(
                style=["color: #475569", "font-size: 14px", "line-height: 1.6"],
                comment.content,
              ),
            ],
          )
        }),
      )
    },
  ])
}

///|
fn Model::view_post_detail(
  self : Model,
  dispatch : @rabbita.Dispatch[Msg],
  id : Int,
) -> @rabbita.Html {
  @html.div([
    view_header(dispatch),
    if self.loading {
      @html.div(
        style=[
          "text-align: center", "padding: 60px 0", "color: #94a3b8", "font-size: 15px",
        ],
        [@html.text("Loading...")],
      )
    } else {
      match self.current_post {
        None =>
          @html.div(
            style=["text-align: center", "padding: 60px 0", "color: #94a3b8"],
            [@html.text("Post not found.")],
          )
        Some(post) =>
          @html.div([
            @html.div(
              style=[
                "background: white", "padding: 36px 40px", "border-radius: 12px",
                "border: 1px solid #f0f0f5",
              ],
              [
                @html.div(style=["margin-bottom: 24px"], [
                  @html.span(
                    style=[
                      "font-size: 12px", "color: #94a3b8", "text-transform: uppercase",
                      "letter-spacing: 0.5px",
                    ],
                    "Created \{post.created_at}  |  Updated \{post.updated_at}",
                  ),
                ]),
                @html.h1(
                  style=[
                    "margin-bottom: 28px", "color: #1a1a2e", "font-size: 32px", "font-weight: 700",
                    "line-height: 1.3", "letter-spacing: -0.5px",
                  ],
                  post.title,
                ),
                @html.div(
                  style=[
                    "white-space: pre-wrap", "line-height: 1.8", "font-size: 16px",
                    "color: #334155",
                  ],
                  [@html.text(post.content)],
                ),
                @html.div(
                  style=[
                    "margin-top: 36px", "padding-top: 20px", "border-top: 1px solid #f0f0f5",
                    "display: flex", "gap: 10px",
                  ],
                  [
                    @html.button(
                      on_click=dispatch(GoToEditPost(id)),
                      style=[
                        "padding: 10px 20px", "background: white", "color: #1a1a2e",
                        "border: 1px solid #e2e8f0", "border-radius: 8px", "cursor: pointer",
                        "font-size: 14px", "font-weight: 500",
                      ],
                      "Edit",
                    ),
                    @html.button(
                      on_click=dispatch(DeletePost(id)),
                      style=[
                        "padding: 10px 20px", "background: white", "color: #dc2626",
                        "border: 1px solid #fecaca", "border-radius: 8px", "cursor: pointer",
                        "font-size: 14px", "font-weight: 500",
                      ],
                      "Delete",
                    ),
                    @html.button(
                      on_click=dispatch(GoToList),
                      style=[
                        "padding: 10px 20px", "background: white", "color: #64748b",
                        "border: 1px solid #e2e8f0", "border-radius: 8px", "cursor: pointer",
                        "font-size: 14px", "font-weight: 500",
                      ],
                      "Back",
                    ),
                  ],
                ),
              ],
            ),
            self.view_comments_section(dispatch, id),
          ])
      }
    },
  ])
}

///|
fn Model::view_post_form(
  self : Model,
  dispatch : @rabbita.Dispatch[Msg],
  edit_id : Int?,
) -> @rabbita.Html {
  let is_edit = match edit_id {
    Some(_) => true
    None => false
  }
  let heading = if is_edit { "Edit Post" } else { "New Post" }
  let submit_label = if is_edit { "Update" } else { "Publish" }
  @html.div([
    view_header(dispatch),
    @html.div(
      style=[
        "background: white", "padding: 36px 40px", "border-radius: 12px", "border: 1px solid #f0f0f5",
      ],
      [
        @html.h2(
          style=[
            "margin-bottom: 28px", "color: #1a1a2e", "font-size: 24px", "font-weight: 700",
          ],
          heading,
        ),
        if self.loading && is_edit && self.current_post is None {
          @html.div(
            style=["text-align: center", "padding: 40px 0", "color: #94a3b8"],
            [@html.text("Loading...")],
          )
        } else {
          @html.div([
            @html.div(style=["margin-bottom: 20px"], [
              @html.label(
                style=[
                  "display: block", "margin-bottom: 6px", "font-weight: 500", "color: #475569",
                  "font-size: 14px",
                ],
                "Title",
              ),
              @html.input(
                input_type=Text,
                placeholder="Post title",
                value=self.title_input,
                on_input=fn(value) { dispatch(TitleChanged(value)) },
                style=[
                  "width: 100%", "padding: 12px 16px", "border: 1px solid #e2e8f0",
                  "border-radius: 8px", "font-size: 16px", "outline: none", "background: #f8f9fc",
                ],
                "",
              ),
            ]),
            @html.div(style=["margin-bottom: 24px"], [
              @html.label(
                style=[
                  "display: block", "margin-bottom: 6px", "font-weight: 500", "color: #475569",
                  "font-size: 14px",
                ],
                "Content",
              ),
              @html.textarea(
                placeholder="Write your post...",
                value=self.content_input,
                on_input=fn(value) { dispatch(ContentChanged(value)) },
                rows=14,
                style=[
                  "width: 100%", "padding: 14px 16px", "border: 1px solid #e2e8f0",
                  "border-radius: 8px", "font-size: 15px", "line-height: 1.7", "outline: none",
                  "resize: vertical", "font-family: inherit", "background: #f8f9fc",
                ],
                "",
              ),
            ]),
            @html.div(style=["display: flex", "gap: 10px"], [
              @html.button(
                on_click=match edit_id {
                  Some(id) => dispatch(UpdatePost(id))
                  None => dispatch(CreatePost)
                },
                style=[
                  "padding: 12px 28px", "background: #1a1a2e", "color: white", "border: none",
                  "border-radius: 8px", "cursor: pointer", "font-size: 15px", "font-weight: 500",
                ],
                submit_label,
              ),
              @html.button(
                on_click=dispatch(GoToList),
                style=[
                  "padding: 12px 28px", "background: white", "color: #64748b", "border: 1px solid #e2e8f0",
                  "border-radius: 8px", "cursor: pointer", "font-size: 15px", "font-weight: 500",
                ],
                "Cancel",
              ),
            ]),
          ])
        },
      ],
    ),
  ])
}

///|
pub fn Model::view(self : Model, dispatch : @rabbita.Dispatch[Msg]) -> @rabbita.Html {
  @html.div(
    style=["max-width: 720px", "margin: 0 auto", "padding: 24px 20px"],
    [
      match self.page {
        PostList => self.view_post_list(dispatch)
        ViewPost(id) => self.view_post_detail(dispatch, id)
        NewPost => self.view_post_form(dispatch, None)
        EditPost(id) => self.view_post_form(dispatch, Some(id))
      },
    ],
  )
}
