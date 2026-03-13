///|
test "routes" {
  inspect(@shared.api_board, content="/api/board")
  inspect(@shared.api_tasks, content="/api/tasks")
  inspect(@shared.api_task(42), content="/api/tasks/42")
  inspect(@shared.api_task_status(7), content="/api/tasks/7/status")
  inspect(@shared.api_task_comments(3), content="/api/tasks/3/comments")
  inspect(@shared.api_task_deps(5), content="/api/tasks/5/deps")
  inspect(@shared.api_task_deps_remove(5), content="/api/tasks/5/deps/remove")
  inspect(@shared.api_members, content="/api/members")
}

///|
test "auth routes" {
  inspect(@shared.api_register, content="/api/auth/register")
  inspect(@shared.api_login, content="/api/auth/login")
  inspect(@shared.api_logout, content="/api/auth/logout")
  inspect(@shared.api_me, content="/api/auth/me")
}
