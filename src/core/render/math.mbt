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
  MTextStyle(String, String)
  MIdent(String)
  MFrac(MathNode, MathNode)
  MSqrt(MathNode?, MathNode)
  MScript(MathNode, MathNode?, MathNode?)
  MSpace(String)
  MStyle(String, MathNode)
  MAccent(String, MathNode)
  MEnv(Array[Array[MathNode]])
  MMatrix(String, String, Array[Array[MathNode]])
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
    "vdots" => Some("⋮")
    "ddots" => Some("⋱")
    "iddots" => Some("⋰")
    "vert" => Some("|")
    "Vert" => Some("‖")
    "langle" => Some("⟨")
    "rangle" => Some("⟩")
    "lceil" => Some("⌈")
    "rceil" => Some("⌉")
    "lfloor" => Some("⌊")
    "rfloor" => Some("⌋")
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
fn math_map_text(text : String, mapper : (Char) -> String?) -> String {
  let builder = StringBuilder()
  for ch in text {
    match mapper(ch) {
      Some(mapped) => builder.write_string(mapped)
      None => builder.write_char(ch)
    }
  }
  builder.to_string()
}

///|
fn math_identity_mapper(_ch : Char) -> String? {
  None
}

///|
fn math_map_text_node(node : MathNode, mapper : (Char) -> String?) -> MathNode {
  match node {
    MRow(nodes) => MRow(math_map_text_nodes(nodes, mapper))
    MText(text) => MText(math_map_text(text, mapper))
    MTextStyle(style, text) =>
      MTextStyle(style, math_map_text(text, mapper))
    MIdent(text) => MText(math_map_text(text, mapper))
    MFrac(numerator, denominator) =>
      MFrac(
        math_map_text_node(numerator, mapper),
        math_map_text_node(denominator, mapper),
      )
    MSqrt(index, body) =>
      MSqrt(
        math_map_text_option(index, mapper),
        math_map_text_node(body, mapper),
      )
    MScript(base, sup, sub) =>
      MScript(
        math_map_text_node(base, mapper),
        math_map_text_option(sup, mapper),
        math_map_text_option(sub, mapper),
      )
    MSpace(width) => MSpace(width)
    MStyle(style, inner) =>
      MStyle(style, math_map_text_node(inner, mapper))
    MAccent(mark, inner) =>
      MAccent(mark, math_map_text_node(inner, mapper))
    MEnv(rows) => MEnv(math_map_text_rows(rows, mapper))
    MMatrix(open, close, rows) =>
      MMatrix(open, close, math_map_text_rows(rows, mapper))
  }
}

///|
fn math_map_text_nodes(
  nodes : Array[MathNode],
  mapper : (Char) -> String?,
) -> Array[MathNode] {
  let result : Array[MathNode] = []
  for node in nodes {
    result.push(math_map_text_node(node, mapper))
  }
  result
}

///|
fn math_map_text_rows(
  rows : Array[Array[MathNode]],
  mapper : (Char) -> String?,
) -> Array[Array[MathNode]] {
  let result : Array[Array[MathNode]] = []
  for row in rows {
    result.push(math_map_text_nodes(row, mapper))
  }
  result
}

///|
fn math_map_text_option(
  node : MathNode?,
  mapper : (Char) -> String?,
) -> MathNode? {
  match node {
    Some(value) => Some(math_map_text_node(value, mapper))
    None => None
  }
}

///|
fn math_upright_node(node : MathNode) -> MathNode {
  math_map_text_node(node, math_identity_mapper)
}

///|
fn math_double_struck(ch : Char) -> String? {
  match ch {
    'A' => Some("𝔸")
    'B' => Some("𝔹")
    'C' => Some("ℂ")
    'D' => Some("𝔻")
    'E' => Some("𝔼")
    'F' => Some("𝔽")
    'G' => Some("𝔾")
    'H' => Some("ℍ")
    'I' => Some("𝕀")
    'J' => Some("𝕁")
    'K' => Some("𝕂")
    'L' => Some("𝕃")
    'M' => Some("𝕄")
    'N' => Some("ℕ")
    'O' => Some("𝕆")
    'P' => Some("ℙ")
    'Q' => Some("ℚ")
    'R' => Some("ℝ")
    'S' => Some("𝕊")
    'T' => Some("𝕋")
    'U' => Some("𝕌")
    'V' => Some("𝕍")
    'W' => Some("𝕎")
    'X' => Some("𝕏")
    'Y' => Some("𝕐")
    'Z' => Some("ℤ")
    'a' => Some("𝕒")
    'b' => Some("𝕓")
    'c' => Some("𝕔")
    'd' => Some("𝕕")
    'e' => Some("𝕖")
    'f' => Some("𝕗")
    'g' => Some("𝕘")
    'h' => Some("𝕙")
    'i' => Some("𝕚")
    'j' => Some("𝕛")
    'k' => Some("𝕜")
    'l' => Some("𝕝")
    'm' => Some("𝕞")
    'n' => Some("𝕟")
    'o' => Some("𝕠")
    'p' => Some("𝕡")
    'q' => Some("𝕢")
    'r' => Some("𝕣")
    's' => Some("𝕤")
    't' => Some("𝕥")
    'u' => Some("𝕦")
    'v' => Some("𝕧")
    'w' => Some("𝕨")
    'x' => Some("𝕩")
    'y' => Some("𝕪")
    'z' => Some("𝕫")
    '0' => Some("𝟘")
    '1' => Some("𝟙")
    '2' => Some("𝟚")
    '3' => Some("𝟛")
    '4' => Some("𝟜")
    '5' => Some("𝟝")
    '6' => Some("𝟞")
    '7' => Some("𝟟")
    '8' => Some("𝟠")
    '9' => Some("𝟡")
    _ => None
  }
}

///|
fn math_script_letter(ch : Char) -> String? {
  match ch {
    'A' => Some("𝒜")
    'B' => Some("ℬ")
    'C' => Some("𝒞")
    'D' => Some("𝒟")
    'E' => Some("ℰ")
    'F' => Some("ℱ")
    'G' => Some("𝒢")
    'H' => Some("ℋ")
    'I' => Some("ℐ")
    'J' => Some("𝒥")
    'K' => Some("𝒦")
    'L' => Some("ℒ")
    'M' => Some("ℳ")
    'N' => Some("𝒩")
    'O' => Some("𝒪")
    'P' => Some("𝒫")
    'Q' => Some("𝒬")
    'R' => Some("ℛ")
    'S' => Some("𝒮")
    'T' => Some("𝒯")
    'U' => Some("𝒰")
    'V' => Some("𝒱")
    'W' => Some("𝒲")
    'X' => Some("𝒳")
    'Y' => Some("𝒴")
    'Z' => Some("𝒵")
    'a' => Some("𝒶")
    'b' => Some("𝒷")
    'c' => Some("𝒸")
    'd' => Some("𝒹")
    'e' => Some("ℯ")
    'f' => Some("𝒻")
    'g' => Some("ℊ")
    'h' => Some("𝒽")
    'i' => Some("𝒾")
    'j' => Some("𝒿")
    'k' => Some("𝓀")
    'l' => Some("𝓁")
    'm' => Some("𝓂")
    'n' => Some("𝓃")
    'o' => Some("ℴ")
    'p' => Some("𝓅")
    'q' => Some("𝓆")
    'r' => Some("𝓇")
    's' => Some("𝓈")
    't' => Some("𝓉")
    'u' => Some("𝓊")
    'v' => Some("𝓋")
    'w' => Some("𝓌")
    'x' => Some("𝓍")
    'y' => Some("𝓎")
    'z' => Some("𝓏")
    _ => None
  }
}

///|
fn math_fraktur_letter(ch : Char) -> String? {
  match ch {
    'A' => Some("𝔄")
    'B' => Some("𝔅")
    'C' => Some("ℭ")
    'D' => Some("𝔇")
    'E' => Some("𝔈")
    'F' => Some("𝔉")
    'G' => Some("𝔊")
    'H' => Some("ℌ")
    'I' => Some("ℑ")
    'J' => Some("𝔍")
    'K' => Some("𝔎")
    'L' => Some("𝔏")
    'M' => Some("𝔐")
    'N' => Some("𝔑")
    'O' => Some("𝔒")
    'P' => Some("𝔓")
    'Q' => Some("𝔔")
    'R' => Some("ℜ")
    'S' => Some("𝔖")
    'T' => Some("𝔗")
    'U' => Some("𝔘")
    'V' => Some("𝔙")
    'W' => Some("𝔚")
    'X' => Some("𝔛")
    'Y' => Some("𝔜")
    'Z' => Some("ℨ")
    'a' => Some("𝔞")
    'b' => Some("𝔟")
    'c' => Some("𝔠")
    'd' => Some("𝔡")
    'e' => Some("𝔢")
    'f' => Some("𝔣")
    'g' => Some("𝔤")
    'h' => Some("𝔥")
    'i' => Some("𝔦")
    'j' => Some("𝔧")
    'k' => Some("𝔨")
    'l' => Some("𝔩")
    'm' => Some("𝔪")
    'n' => Some("𝔫")
    'o' => Some("𝔬")
    'p' => Some("𝔭")
    'q' => Some("𝔮")
    'r' => Some("𝔯")
    's' => Some("𝔰")
    't' => Some("𝔱")
    'u' => Some("𝔲")
    'v' => Some("𝔳")
    'w' => Some("𝔴")
    'x' => Some("𝔵")
    'y' => Some("𝔶")
    'z' => Some("𝔷")
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
    let (node, next) = math_parse_scripted_atom(chars, pos)
    nodes.push(node)
    pos = next
  }
  (nodes, pos)
}

///|
fn math_parse_scripted_atom(chars : Array[Char], start : Int32) -> (MathNode, Int32) {
  let length = chars.length()
  let (atom, next) = math_parse_atom(chars, start)
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
  (node, cursor)
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
fn math_is_aligned_environment(name : String) -> Bool {
  name == "aligned" || name == "align" || name == "align*" || name == "split"
}

///|
fn math_matrix_delimiters(name : String) -> (String, String)? {
  match name {
    "matrix" | "smallmatrix" => Some(("", ""))
    "pmatrix" => Some(("(", ")"))
    "bmatrix" => Some(("[", "]"))
    "Bmatrix" => Some(("{", "}"))
    "vmatrix" => Some(("|", "|"))
    "Vmatrix" => Some(("‖", "‖"))
    "cases" => Some(("{", ""))
    _ => None
  }
}

///|
fn math_environment_end(chars : Array[Char], start : Int32) -> (Bool, Int32) {
  let length = chars.length()
  if start + 1 >= length || !chars[start + 1].is_ascii_alphabetic() {
    return (false, start)
  }
  let mut end = start + 1
  while end < length && chars[end].is_ascii_alphabetic() {
    end = end + 1
  }
  if math_chars_text(chars, start + 1, end) != "end" {
    return (false, start)
  }
  let (_, after) = math_read_raw_group(chars, end)
  (true, after)
}

///|
fn math_parse_environment(chars : Array[Char], start : Int32) -> (Array[Array[MathNode]], Int32) {
  let length = chars.length()
  let rows : Array[Array[MathNode]] = []
  let mut row_cells : Array[MathNode] = []
  let mut cells : Array[MathNode] = []
  let mut pos = start
  let mut ended = false
  while pos < length && !ended {
    let ch = chars[pos]
    if ch == '&' {
      row_cells.push(MRow(cells))
      cells = []
      pos = pos + 1
      continue
    }
    if ch == '\\' && pos + 1 < length && chars[pos + 1] == '\\' {
      row_cells.push(MRow(cells))
      rows.push(row_cells)
      row_cells = []
      cells = []
      pos = pos + 2
      let probe = math_skip_spaces(chars, pos)
      if probe < length && chars[probe] == '[' {
        let mut end = probe + 1
        while end < length && chars[end] != ']' {
          end = end + 1
        }
        pos = if end < length { end + 1 } else { end }
      }
      continue
    }
    if ch == '\\' {
      let (is_end, after) = math_environment_end(chars, pos)
      if is_end {
        pos = after
        ended = true
        continue
      }
    }
    if ch.is_whitespace() {
      let mut next = pos
      while next < length && chars[next].is_whitespace() {
        next = next + 1
      }
      if !cells.is_empty() {
        cells.push(MSpace("0.24em"))
      }
      pos = next
      continue
    }
    let (node, next) = math_parse_scripted_atom(chars, pos)
    cells.push(node)
    pos = next
  }
  if !cells.is_empty() || !row_cells.is_empty() {
    row_cells.push(MRow(cells))
    rows.push(row_cells)
  }
  (rows, pos)
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
      "begin" => {
        let (environment, after) = math_read_raw_group(chars, end)
        let aligned = math_is_aligned_environment(environment)
        let delimiters = math_matrix_delimiters(environment)
        if aligned || delimiters != None {
          let (rows, next) = math_parse_environment(chars, after)
          if aligned {
            (MEnv(rows), next)
          } else {
            match delimiters {
              Some(pair) => {
                let (open, close) = pair
                (MMatrix(open, close, rows), next)
              }
              None => (MEnv(rows), next)
            }
          }
        } else {
          (MText("begin"), end)
        }
      }
      "text" | "textrm" | "operatorname" => {
        let (text, next) = math_read_raw_group(chars, end)
        (MText(text), next)
      }
      "textbf" => {
        let (text, next) = math_read_raw_group(chars, end)
        (MTextStyle("font-weight:700;", text), next)
      }
      "textit" => {
        let (text, next) = math_read_raw_group(chars, end)
        (MTextStyle("font-style:italic;", text), next)
      }
      "mathrm" => {
        let (argument, next) = math_parse_argument(chars, end)
        (math_upright_node(argument), next)
      }
      "mathbf" => {
        let (argument, next) = math_parse_argument(chars, end)
        (MStyle("font-weight:700;", math_upright_node(argument)), next)
      }
      "boldsymbol" => {
        let (argument, next) = math_parse_argument(chars, end)
        (MStyle("font-weight:700;font-style:italic;", argument), next)
      }
      "mathit" => {
        let (argument, next) = math_parse_argument(chars, end)
        (MStyle("font-style:italic;", argument), next)
      }
      "mathbb" => {
        let (argument, next) = math_parse_argument(chars, end)
        (math_map_text_node(argument, math_double_struck), next)
      }
      "mathcal" => {
        let (argument, next) = math_parse_argument(chars, end)
        (math_map_text_node(argument, math_script_letter), next)
      }
      "mathfrak" => {
        let (argument, next) = math_parse_argument(chars, end)
        (math_map_text_node(argument, math_fraktur_letter), next)
      }
      "mathsf" => {
        let (argument, next) = math_parse_argument(chars, end)
        (
          MStyle(
            "font-family:'Helvetica Neue',Arial,sans-serif;",
            math_upright_node(argument),
          ),
          next,
        )
      }
      "mathtt" => {
        let (argument, next) = math_parse_argument(chars, end)
        (
          MStyle(
            "font-family:'SFMono-Regular',Consolas,monospace;",
            math_upright_node(argument),
          ),
          next,
        )
      }
      "overline" => {
        let (argument, next) = math_parse_argument(chars, end)
        (MStyle("text-decoration:overline;", argument), next)
      }
      "underline" => {
        let (argument, next) = math_parse_argument(chars, end)
        (MStyle("text-decoration:underline;", argument), next)
      }
      "bar" => {
        let (argument, next) = math_parse_argument(chars, end)
        (MStyle("text-decoration:overline;", argument), next)
      }
      "hat" | "widehat" => {
        let (argument, next) = math_parse_argument(chars, end)
        (MAccent("\u{0302}", argument), next)
      }
      "tilde" | "widetilde" => {
        let (argument, next) = math_parse_argument(chars, end)
        (MAccent("\u{0303}", argument), next)
      }
      "dot" => {
        let (argument, next) = math_parse_argument(chars, end)
        (MAccent("\u{0307}", argument), next)
      }
      "ddot" => {
        let (argument, next) = math_parse_argument(chars, end)
        (MAccent("\u{0308}", argument), next)
      }
      "vec" => {
        let (argument, next) = math_parse_argument(chars, end)
        (MAccent("\u{20D7}", argument), next)
      }
      "label" => {
        let (_, next) = math_read_raw_group(chars, end)
        (MRow([]), next)
      }
      "displaystyle" | "textstyle" | "scriptstyle" | "scriptscriptstyle" |
      "limits" | "nolimits" | "nonumber" | "notag" => (MRow([]), end)
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
          } else if delimiter == '|' {
            (MText("‖"), probe + 2)
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
    MEnv(rows) => {
      let builder = StringBuilder()
      builder.write_string(
        "<span style=\"display:inline-table;vertical-align:middle;border-collapse:collapse;text-align:left;\">",
      )
      for row in rows {
        builder.write_string("<span style=\"display:table-row;\">")
        let mut column = 0
        for cell in row {
          let alignment = if column % 2 == 0 { "right" } else { "left" }
          builder.write_string(
            "<span style=\"display:table-cell;text-align:" +
            alignment +
            ";padding:0 0.22em;white-space:nowrap;vertical-align:middle;\">",
          )
          builder.write_string(math_render_node(cell))
          builder.write_string("</span>")
          column = column + 1
        }
        builder.write_string("</span>")
      }
      builder.write_string("</span>")
      builder.to_string()
    }
    MMatrix(open, close, rows) => {
      let builder = StringBuilder()
      builder.write_string(
        "<span style=\"display:inline-table;vertical-align:middle;\"><span style=\"display:table-row;\">",
      )
      let delimiter_size = (rows.length() + 1).to_string() + "em"
      if open != "" {
        builder.write_string(
          "<span style=\"display:table-cell;vertical-align:middle;font-size:" +
          delimiter_size +
          ";line-height:1;\">" +
          escape_html(open) +
          "</span>",
        )
      }
      builder.write_string(
        "<span style=\"display:table-cell;vertical-align:middle;\"><span style=\"display:inline-table;vertical-align:middle;border-collapse:collapse;\">",
      )
      for row in rows {
        builder.write_string("<span style=\"display:table-row;\">")
        for cell in row {
          builder.write_string(
            "<span style=\"display:table-cell;padding:2px 6px;text-align:center;vertical-align:middle;white-space:nowrap;\">",
          )
          builder.write_string(math_render_node(cell))
          builder.write_string("</span>")
        }
        builder.write_string("</span>")
      }
      builder.write_string("</span></span>")
      if close != "" {
        builder.write_string(
          "<span style=\"display:table-cell;vertical-align:middle;font-size:" +
          delimiter_size +
          ";line-height:1;\">" +
          escape_html(close) +
          "</span>",
        )
      }
      builder.write_string("</span></span>")
      builder.to_string()
    }
    MStyle(style, inner) =>
      "<span style=\"" + style + "\">" + math_render_node(inner) + "</span>"
    MAccent(mark, inner) => math_render_node(inner) + mark
    MText(text) => escape_html(text)
    MTextStyle(style, text) =>
      "<span style=\"" + style + "\">" + escape_html(text) + "</span>"
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
