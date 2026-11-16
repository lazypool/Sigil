///|
/// Wraps rendered body HTML in the email-safe preview document shell.
///
/// The shell follows SPEC.md §5.2: one 100% width table, a centered reading
/// column capped at 640px, a 16px body font, 1.7 line height, 14px paragraph
/// spacing, and only inline CSS. It intentionally contains no script element.
pub fn build_preview_shell(body_html : String) -> String {
  build_letter_shell(body_html, "#2563EB", "minimal")
}

///|
fn letter_style(accent : String, letter : String) -> String {
  if letter == "card" {
    "width:100%;max-width:640px;margin:0 auto;background:#FFFFFF;border-width:3px 0 0 0;border-style:solid;border-color:" +
    accent +
    ";border-radius:6px;table-layout:fixed;box-sizing:border-box;"
  } else {
    "width:100%;max-width:640px;margin:0 auto;background:#FFFFFF;table-layout:fixed;box-sizing:border-box;"
  }
}

///|
pub fn build_letter_shell(
  body_html : String,
  accent : String,
  letter : String,
) -> String {
  let outer_bg = if letter == "card" {
    "#F5F6F8"
  } else {
    "#F4F4F4"
  }
  let header =
    #|<!doctype html>
    #|<html lang="en">
    #|<head>
    #|<meta charset="utf-8">
    #|<meta name="viewport" content="width=device-width, initial-scale=1">
    #|<title>Sigil Preview</title>
    #|<style>
    #|html, body { margin: 0; padding: 0; }
    #|body { color: #222833; font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Microsoft YaHei", "Segoe UI", Helvetica, Arial, sans-serif; }
    #|table { border-collapse: collapse; }
    #|td { vertical-align: top; }
    #|.sigil-outer { width: 100%; table-layout: fixed; }
    #|.sigil-outer-cell { padding: 28px 12px; }
    #|.sigil-column { width: 100%; max-width: 640px; margin: 0 auto; box-sizing: border-box; table-layout: fixed; }
    #|.sigil-body { padding: 32px 36px; font-size: 16px; line-height: 1.7; color: #222833; box-sizing: border-box; overflow-wrap: break-word; word-break: break-word; }
    #|.sigil-body p { margin: 0 0 14px; }
    #|.sigil-body p:last-child { margin-bottom: 0; }
    #|.sigil-body strong { font-weight: 600; }
    #|.sigil-body img, .sigil-body svg { max-width: 100%; height: auto; }
    #|.sigil-signature, .sigil-chart, .sigil-math, .sigil-table-scroll { max-width: 100%; box-sizing: border-box; }
    #|.sigil-math, .sigil-table-scroll, .sigil-chart { overflow-x: auto; -webkit-overflow-scrolling: touch; }
    #|a { text-decoration: none; overflow-wrap: anywhere; }
    #|@media (max-width: 640px) {
    #|  .sigil-outer-cell { padding: 16px 8px; }
    #|  .sigil-body { padding: 24px 20px; }
    #|}
    #|@media (max-width: 400px) {
    #|  .sigil-outer-cell { padding: 10px 0; }
    #|  .sigil-body { padding: 20px 14px; }
    #|}
    #|</style>
    #|</head>
    #|<body>
    #|
  let outer_table = "<table role=\"presentation\" class=\"sigil-outer\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" bgcolor=\"" +
    outer_bg +
    "\" style=\"background:" +
    outer_bg +
    ";table-layout:fixed;\">" +
    "<tr>" +
    "<td class=\"sigil-outer-cell\" align=\"center\">"
  let column_table = "<table role=\"presentation\" class=\"sigil-column\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" border=\"0\" style=\"" +
    letter_style(accent, letter) +
    "\">" +
    "<tr><td class=\"sigil-body\" style=\"font-size:16px;line-height:1.7;\">"
  let tail =
    #|</td></tr>
    #|</table>
    #|</td>
    #|</tr>
    #|</table>
    #|</body>
    #|</html>
    #|
  header + outer_table + column_table + body_html + tail
}
