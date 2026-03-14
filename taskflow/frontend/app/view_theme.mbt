///|
/// Get theme colors for current mode.
fn get_theme(dark : Bool) -> Theme {
  if dark {
    {
      bg: "#0f172a",
      card_bg: "#1e293b",
      card_border: "#334155",
      text: "#f1f5f9",
      text_secondary: "#94a3b8",
      text_muted: "#64748b",
      input_bg: "#1e293b",
      input_border: "#475569",
      filter_bg: "#1e293b",
      filter_inactive: "#334155",
      column_bg: "#1e293b",
    }
  } else {
    {
      bg: "#f8fafc",
      card_bg: "white",
      card_border: "#f0f0f5",
      text: "#1e293b",
      text_secondary: "#64748b",
      text_muted: "#94a3b8",
      input_bg: "white",
      input_border: "#e2e8f0",
      filter_bg: "white",
      filter_inactive: "#f1f5f9",
      column_bg: "#f8fafc",
    }
  }
}
