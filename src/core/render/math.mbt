///|
/// A small, email-safe TeX subset renderer.
///
/// The renderer emits inline-styled HTML instead of running a script in the
/// preview iframe, so formulas look the same in the preview and in exported
/// HTML. It supports fractions, roots, scripts, Greek letters, common operators
/// and function names, plus `\text{...}` for upright copy.
#derive(Eq)
priv enum MathNode {
  MRow(Array[MathNode])
  MText(String)
  MIdent(String)
  MFrac(MathNode, MathNode)
  MSqrt(MathNode?, MathNode)
  MScript(MathNode, MathNode?, MathNode?)
  MSpace(String)
}

///|
fn math_chars_text(chars : Array[Char], start : Int32, end : Int32) -> String {
  let builder = StringBuilder()
  let mut index = start
  while index < end && index < chars.length() {
    builder.write_char(chars[index])
    index = index + 1
  }
  builder.to_string()
}

///|
fn math_skip_spaces(chars : Array[Char], start : Int32) -> Int32 {
  let mut index = start
  while index < chars.length() && chars[index].is_whitespace() {
    index = index + 1
  }
  index
}

///|
fn math_command_text(name : String) -> String? {
  match name {
    "alpha" => Some("α")
    "beta" => Some("β")
    "gamma" => Some("γ")
    "delta" => Some("δ")
    "epsilon" => Some("ε")
    "varepsilon" => Some("ε")
    "zeta" => Some("ζ")
    "eta" => Some("η")
    "theta" => Some("θ")
    "vartheta" => Some("ϑ")
    "iota" => Some("ι")
    "kappa" => Some("κ")
    "lambda" => Some("λ")
    "mu" => Some("μ")
    "nu" => Some("ν")
    "xi" => Some("ξ")
    "pi" => Some("π")
    "varpi" => Some("ϖ")
    "rho" => Some("ρ")
    "sigma" => Some("σ")
    "varsigma" => Some("ς")
    "tau" => Some("τ")
    "upsilon" => Some("υ")
    "phi" => Some("φ")
    "varphi" => Some("ϕ")
    "chi" => Some("χ")
    "psi" => Some("ψ")
    "omega" => Some("ω")
    "Gamma" => Some("Γ")
    "Delta" => Some("Δ")
    "Theta" => Some("Θ")
    "Lambda" => Some("Λ")
    "Xi" => Some("Ξ")
    "Pi" => Some("Π")
    "Sigma" => Some("Σ")
    "Upsilon" => Some("Υ")
    "Phi" => Some("Φ")
    "Psi" => Some("Ψ")
    "Omega" => Some("Ω")
    "times" => Some("×")
    "cdot" => Some("·")
    "div" => Some("÷")
    "pm" => Some("±")
    "mp" => Some("∓")
    "le" | "leq" => Some("≤")
    "ge" | "geq" => Some("≥")
    "ne" | "neq" => Some("≠")
    "approx" => Some("≈")
    "equiv" => Some("≡")
    "sim" => Some("∼")
    "propto" => Some("∝")
    "infty" => Some("∞")
    "sum" => Some("∑")
    "prod" => Some("∏")
    "int" => Some("∫")
    "oint" => Some("∮")
    "partial" => Some("∂")
    "nabla" => Some("∇")
    "to" | "rightarrow" => Some("→")
    "leftarrow" => Some("←")
    "leftrightarrow" => Some("↔")
    "Rightarrow" => Some("⇒")
    "Leftarrow" => Some("⇐")
    "Leftrightarrow" => Some("⇔")
    "mapsto" => Some("↦")
    "in" => Some("∈")
    "notin" => Some("∉")
    "subset" => Some("⊂")
    "subseteq" => Some("⊆")
    "supset" => Some("⊃")
    "cup" => Some("∪")
    "cap" => Some("∩")
    "forall" => Some("∀")
    "exists" => Some("∃")
    "neg" => Some("¬")
    "land" => Some("∧")
    "lor" => Some("∨")
    "angle" => Some("∠")
    "perp" => Some("⊥")
    "degree" => Some("°")
    "prime" => Some("′")
    "ldots" | "dots" => Some("…")
    "cdots" => Some("⋯")
    "sin" => Some("sin")
    "cos" => Some("cos")
    "tan" => Some("tan")
    "cot" => Some("cot")
    "sec" => Some("sec")
    "csc" => Some("csc")
    "arcsin" => Some("arcsin")
    "arccos" => Some("arccos")
    "arctan" => Some("arctan")
    "sinh" => Some("sinh")
    "cosh" => Some("cosh")
    "tanh" => Some("tanh")
    "log" => Some("log")
    "ln" => Some("ln")
    "exp" => Some("exp")
    "lim" => Some("lim")
    "max" => Some("max")
    "min" => Some("min")
    "sup" => Some("sup")
    "inf" => Some("inf")
    "det" => Some("det")
    "gcd" => Some("gcd")
    _ => None
  }
}

///|
fn math_read_raw_group(chars : Array[Char], start : Int32) -> (String, Int32) {
  let length = chars.length()
  let open = math_skip_spaces(chars, start)
  if open >= length || chars[open] != '{' {
    return ("", start)
  }
  let builder = StringBuilder()
  let mut depth = 1
  let mut index = open + 1
  while index < length && depth > 0 {
    let ch = chars[index]
    if ch == '{' {
      depth = depth + 1
      if depth > 1 {
        builder.write_char(ch)
      }
    } else if ch == '}' {
      depth = depth - 1
      if depth > 0 {
        builder.write_char(ch)
      }
    } else {
      builder.write_char(ch)
    }
    index = index + 1
  }
  (builder.to_string(), index)
}

///|
fn math_parse_seq_until(
  chars : Array[Char],
  start : Int32,
  stop : Char?,
) -> (Array[MathNode], Int32) {
  let nodes : Array[MathNode] = []
  let length = chars.length()
  let mut pos = start
  while pos < length {
    let ch = chars[pos]
    let is_stop = match stop {
      Some(value) => ch == value
      None => false
    }
    if is_stop {
      break
    }
    if ch == '\n' {
      nodes.push(MSpace("0.8em"))
      pos = pos + 1
      continue
    }
    if ch.is_whitespace() {
      pos = pos + 1
      continue
    }
    let (atom, next) = math_parse_atom(chars, pos)
    let mut node = atom
    let mut sup : MathNode? = None
    let mut sub : MathNode? = None
    let mut cursor = next
    while true {
      let probe = math_skip_spaces(chars, cursor)
      if probe < length && (chars[probe] == '^' || chars[probe] == '_') {
        let (argument, after) = math_parse_argument(chars, probe + 1)
        if chars[probe] == '^' {
          sup = Some(argument)
        } else {
          sub = Some(argument)
        }
        cursor = after
      } else {
        break
      }
    }
    if sup != None || sub != None {
      node = MScript(node, sup, sub)
    }
    nodes.push(node)
    pos = cursor
  }
  (nodes, pos)
}

///|
fn math_parse_argument(chars : Array[Char], start : Int32) -> (MathNode, Int32) {
  let length = chars.length()
  let open = math_skip_spaces(chars, start)
  if open < length && chars[open] == '{' {
    let (nodes, after) = math_parse_seq_until(chars, open + 1, Some('}'))
    let next = if after < length && chars[after] == '}' {
      after + 1
    } else {
      after
    }
    (MRow(nodes), next)
  } else if open < length {
    math_parse_atom(chars, open)
  } else {
    (MRow([]), length)
  }
}

///|
fn math_parse_atom(chars : Array[Char], start : Int32) -> (MathNode, Int32) {
  let length = chars.length()
  if start >= length {
    return (MRow([]), length)
  }
  let ch = chars[start]
  if ch == '{' {
    let (nodes, after) = math_parse_seq_until(chars, start + 1, Some('}'))
    let next = if after < length && chars[after] == '}' {
      after + 1
    } else {
      after
    }
    (MRow(nodes), next)
  } else if ch == '\\' {
    math_parse_command(chars, start + 1)
  } else if ch.is_ascii_digit() {
    let mut end = start + 1
    while end < length &&
          (chars[end].is_ascii_digit() ||
            (chars[end] == '.' &&
              end + 1 < length &&
              chars[end + 1].is_ascii_digit())) {
      end = end + 1
    }
    (MText(math_chars_text(chars, start, end)), end)
  } else if ch.is_ascii_alphabetic() {
    let mut end = start + 1
    while end < length && chars[end].is_ascii_alphabetic() {
      end = end + 1
    }
    (MIdent(math_chars_text(chars, start, end)), end)
  } else {
    let value = if ch == '-' {
      "−"
    } else if ch == '*' {
      "⋅"
    } else if ch == '\'' {
      "′"
    } else {
      ch.to_string()
    }
    (MText(value), start + 1)
  }
}

///|
fn math_parse_command(chars : Array[Char], start : Int32) -> (MathNode, Int32) {
  let length = chars.length()
  if start >= length {
    return (MRow([]), length)
  }
  let ch = chars[start]
  if ch.is_ascii_alphabetic() {
    let mut end = start
    while end < length && chars[end].is_ascii_alphabetic() {
      end = end + 1
    }
    let name = math_chars_text(chars, start, end)
    match name {
      "frac" | "dfrac" | "tfrac" => {
        let (numerator, after_num) = math_parse_argument(chars, end)
        let (denominator, after_den) = math_parse_argument(chars, after_num)
        (MFrac(numerator, denominator), after_den)
      }
      "sqrt" => {
        let probe = math_skip_spaces(chars, end)
        let mut index : MathNode? = None
        let mut cursor = probe
        if cursor < length && chars[cursor] == '[' {
          let (nodes, after) = math_parse_seq_until(chars, cursor + 1, Some(']'))
          index = Some(MRow(nodes))
          cursor = if after < length && chars[after] == ']' {
            after + 1
          } else {
            after
          }
        }
        let (body, next) = math_parse_argument(chars, cursor)
        (MSqrt(index, body), next)
      }
      "text" | "textrm" | "mathrm" | "operatorname" | "mathbf" | "textbf" |
      "textit" | "mathit" => {
        let (text, next) = math_read_raw_group(chars, end)
        (MText(text), next)
      }
      "quad" => (MSpace("1em"), end)
      "qquad" => (MSpace("2em"), end)
      "left" | "right" => {
        let probe = math_skip_spaces(chars, end)
        if probe >= length {
          (MRow([]), length)
        } else if chars[probe] == '.' {
          (MRow([]), probe + 1)
        } else if chars[probe] == '\\' && probe + 1 < length {
          let delimiter = chars[probe + 1]
          if delimiter == '{' {
            (MText("{"), probe + 2)
          } else if delimiter == '}' {
            (MText("}"), probe + 2)
          } else {
            (MText(""), probe + 2)
          }
        } else {
          (MText(chars[probe].to_string()), probe + 1)
        }
      }
      _ =>
        match math_command_text(name) {
          Some(text) => (MText(text), end)
          None => (MText(name), end)
        }
    }
  } else if ch == '\\' {
    (MSpace("0.9em"), start + 1)
  } else if ch == ',' || ch == ';' || ch == ':' || ch == ' ' {
    (MSpace("0.24em"), start + 1)
  } else if ch == '!' {
    (MSpace("0em"), start + 1)
  } else {
    (MText(ch.to_string()), start + 1)
  }
}

///|
fn math_render_nodes(nodes : Array[MathNode]) -> String {
  let builder = StringBuilder()
  for node in nodes {
    builder.write_string(math_render_node(node))
  }
  builder.to_string()
}

///|
fn math_render_node(node : MathNode) -> String {
  match node {
    MRow(nodes) => math_render_nodes(nodes)
    MText(text) => escape_html(text)
    MIdent(text) => "<i>" + escape_html(text) + "</i>"
    MFrac(numerator, denominator) =>
      "<span style=\"display:inline-block;vertical-align:middle;text-align:center;margin:0 4px;\">" +
      "<span style=\"display:block;padding:0 5px;border-bottom:1px solid #222833;line-height:1.3;\">" +
      math_render_node(numerator) +
      "</span><span style=\"display:block;padding:0 5px;line-height:1.3;\">" +
      math_render_node(denominator) +
      "</span></span>"
    MSqrt(index, body) => {
      let index_html = match index {
        Some(value) =>
          "<sup style=\"font-size:0.62em;line-height:1;\">" +
          math_render_node(value) +
          "</sup>"
        None => ""
      }
      "<span style=\"display:inline-block;vertical-align:middle;white-space:nowrap;\">" +
      index_html +
      "<span style=\"font-size:1.1em;\">√</span>" +
      "<span style=\"display:inline-block;border-top:1px solid #222833;padding:0 3px;\">" +
      math_render_node(body) +
      "</span></span>"
    }
    MScript(base, sup, sub) => {
      let builder = StringBuilder()
      builder.write_string(math_render_node(base))
      match sup {
        Some(value) =>
          builder.write_string(
            "<sup style=\"font-size:0.7em;line-height:1;\">" +
            math_render_node(value) +
            "</sup>",
          )
        None => ()
      }
      match sub {
        Some(value) =>
          builder.write_string(
            "<sub style=\"font-size:0.7em;line-height:1;\">" +
            math_render_node(value) +
            "</sub>",
          )
        None => ()
      }
      builder.to_string()
    }
    MSpace(width) =>
      "<span style=\"display:inline-block;width:" +
      width +
      ";\"></span>"
  }
}

///|
/// Render a `$$ ... $$` block to centered, inline-styled HTML math.
pub fn render_formula_html(tex : String) -> String {
  let chars = tex.to_array()
  let (nodes, _) = math_parse_seq_until(chars, 0, None)
  "<div class=\"sigil-math\" data-sigil-math=\"1\" style=\"margin:20px 0;text-align:center;\">" +
  "<span style=\"display:inline-block;max-width:100%;font-family:'Times New Roman',Times,Georgia,serif;font-size:19px;line-height:1.6;color:#222833;\">" +
  math_render_nodes(nodes) +
  "</span></div>"
}
