///|
/// Wraps rendered body HTML in the email-safe preview document shell.
///
/// The shell follows SPEC.md §5.2: one 100% width table, a centered reading
/// column capped at 640px, a 16px body font, 1.7 line height, 14px paragraph
/// spacing, and only inline CSS. It intentionally contains no script element.
pub fn build_preview_shell(body_html : String) -> String {
  let head =
    #|<!doctype html>
    #|<html lang="en">
    #|<head>
    #|<meta charset="utf-8">
    #|<meta name="viewport" content="width=device-width, initial-scale=1">
    #|<title>Sigil Preview</title>
    #|<style>
    #|html, body { margin: 0; padding: 0; background: #f4f4f4; }
    #|body { color: #2f2f2f; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; }
    #|table { border-collapse: collapse; }
    #|td { vertical-align: top; }
    #|.sigil-outer { width: 100%; background: #f4f4f4; }
    #|.sigil-outer-cell { padding: 24px 12px; }
    #|.sigil-column { width: 100%; max-width: 640px; margin: 0 auto; background: #ffffff; }
    #|.sigil-body { padding: 32px; font-size: 16px; line-height: 1.7; color: #2f2f2f; }
    #|.sigil-body p { margin: 0 0 14px; }
    #|.sigil-body p:last-child { margin-bottom: 0; }
    #|.sigil-body strong { font-weight: 600; }
    #|</style>
    #|</head>
    #|<body>
    #|<table role="presentation" class="sigil-outer" width="100%" cellpadding="0" cellspacing="0" border="0">
    #|<tr>
    #|<td class="sigil-outer-cell" align="center">
    #|<table role="presentation" class="sigil-column" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:640px;width:100%;margin:0 auto;">
    #|<tr>
    #|<td class="sigil-body" style="font-size:16px;line-height:1.7;">
    #|
  let tail =
    #|
    #|</td>
    #|</tr>
    #|</table>
    #|</td>
    #|</tr>
    #|</table>
    #|</body>
    #|</html>
    #|
  head + body_html + tail
}
