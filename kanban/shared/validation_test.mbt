///|
test "validate_card_title" {
  inspect(@shared.validate_card_title(""), content="false")
  inspect(@shared.validate_card_title("Hello"), content="true")
  let long = "a".repeat(100)
  inspect(@shared.validate_card_title(long), content="true")
  let too_long = "a".repeat(101)
  inspect(@shared.validate_card_title(too_long), content="false")
}

///|
test "validate_card_description" {
  inspect(@shared.validate_card_description(""), content="true")
  inspect(@shared.validate_card_description("Short desc"), content="true")
  let long = "a".repeat(500)
  inspect(@shared.validate_card_description(long), content="true")
  let too_long = "a".repeat(501)
  inspect(@shared.validate_card_description(too_long), content="false")
}

///|
test "validate_column_title" {
  inspect(@shared.validate_column_title(""), content="false")
  inspect(@shared.validate_column_title("To Do"), content="true")
  let long = "a".repeat(30)
  inspect(@shared.validate_column_title(long), content="true")
  let too_long = "a".repeat(31)
  inspect(@shared.validate_column_title(too_long), content="false")
}

///|
test "validate_color" {
  inspect(@shared.validate_color(""), content="true")
  inspect(@shared.validate_color("red"), content="true")
  inspect(@shared.validate_color("blue"), content="true")
  inspect(@shared.validate_color("purple"), content="true")
  inspect(@shared.validate_color("pink"), content="false")
  inspect(@shared.validate_color("RGB"), content="false")
}
