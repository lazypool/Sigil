///|
/// One CSV table stored in the local workspace.
#derive(Eq, ToJson, FromJson)
struct TableAsset {
  id : String
  name : String
  csv : String
  folder : String
}

///|
/// Shape returned by the table picker after conversion and splitting.
#derive(Eq, FromJson)
struct IncomingTableAsset {
  id : String
  name : String
  csv : String
  split : Bool
  row_split : Bool
  column_split : Bool
  parts : Int32
  part_index : Int32
  long_cells : Int32
  original : String
}

///|
fn find_table(tables : Array[TableAsset], id : String) -> TableAsset? {
  for table in tables {
    if table.id == id {
      return Some(table)
    }
  }
  None
}

///|
fn has_table_name(tables : Array[TableAsset], name : String) -> Bool {
  for table in tables {
    if table.name == name {
      return true
    }
  }
  false
}

///|
fn table_name_with_suffix(name : String, suffix : Int32) -> String {
  match name.rev_split_once(".") {
    Some((stem, extension)) => stem.to_owned() + "-" + suffix.to_string() + "." + extension.to_owned()
    None => name + "-" + suffix.to_string()
  }
}

///|
fn unique_table_name(tables : Array[TableAsset], name : String) -> String {
  let base = if name == "" { "table.csv" } else { name }
  let mut candidate = base
  let mut suffix = 2
  while has_table_name(tables, candidate) {
    candidate = table_name_with_suffix(base, suffix)
    suffix = suffix + 1
  }
  candidate
}

///|
fn merge_tables(
  existing : Array[TableAsset],
  imported : Array[IncomingTableAsset],
) -> Array[TableAsset] {
  let result = existing.copy()
  for table in imported {
    let name = unique_table_name(result, table.name)
    result.push({ id: table.id, name, csv: table.csv, folder: "", })
  }
  result
}

///|
fn with_table_csv(
  tables : Array[TableAsset],
  id : String,
  csv : String,
) -> Array[TableAsset] {
  let result : Array[TableAsset] = []
  for table in tables {
    if table.id == id {
      result.push({ ..table, csv, })
    } else {
      result.push(table)
    }
  }
  result
}

///|
fn remove_table(tables : Array[TableAsset], id : String) -> Array[TableAsset] {
  let result : Array[TableAsset] = []
  for table in tables {
    if table.id != id {
      result.push(table)
    }
  }
  result
}

///|
fn table_map(tables : Array[TableAsset]) -> Map[String, String] {
  let result : Map[String, String] = Map([])
  for table in tables {
    result[table.name] = table.csv
  }
  result
}

///|
fn table_markup(name : String) -> String {
  "\n<table:" + name + ">\n"
}

///|
fn parse_tables(json : String) -> Array[IncomingTableAsset] {
  let parsed = @json.parse(json) catch { _ => return [] }
  let tables : Array[IncomingTableAsset] = @json.from_json(parsed) catch {
    _ => return []
  }
  tables
}

///|
extern "js" fn open_table_picker() -> Unit = "() => { const el = document.getElementById('sigil-table-input'); if (!el) return; el.value = ''; el.click(); }"

///|
extern "js" fn read_table_input_promise() -> @js_async.Promise[String] =
  #| () => new Promise((resolve) => {
  #|   const input = document.getElementById('sigil-table-input');
  #|   if (!input || !input.files || input.files.length === 0) {
  #|     resolve('[]');
  #|     return;
  #|   }
  #|   const files = Array.from(input.files);
  #|   const MAX_ROWS = 200;
  #|   const MAX_COLUMNS = 5;
  #|   const MAX_CELL_CHARS = 60;
  #|   const newId = () => 'tbl-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 8);
  #|   const encodeCsv = (rows) => rows.map((row) => row.map((cell) => {
  #|     const value = cell == null ? '' : String(cell);
  #|     return /[",\r\n]/.test(value) ? '"' + value.replace(/"/g, '""') + '"' : value;
  #|   }).join(',')).join('\r\n');
  #|   const normalize = (rows) => (rows || []).map((row) => {
  #|     if (Array.isArray(row)) return row.map((cell) => cell == null ? '' : String(cell));
  #|     return [String(row)];
  #|   });
  #|   (async () => {
  #|     const results = [];
  #|     for (const file of files) {
  #|       try {
  #|         const buffer = await file.arrayBuffer();
  #|         const extension = (file.name.split('.').pop() || '').toLowerCase();
  #|         let rows = null;
  #|         if (extension === 'json') {
  #|           const text = new TextDecoder().decode(buffer);
  #|           const data = JSON.parse(text);
  #|           if (Array.isArray(data)) {
  #|             if (Array.isArray(data[0])) {
  #|               rows = data;
  #|             } else {
  #|               const keys = Object.keys(data[0] || {});
  #|               rows = [keys].concat(data.map((item) => keys.map((key) => item[key])));
  #|             }
  #|           } else if (data && typeof data === 'object') {
  #|             rows = [['key', 'value']].concat(
  #|               Object.keys(data).map((key) => [key, data[key]])
  #|             );
  #|           }
  #|         } else if (window.XLSX) {
  #|           const workbook = window.XLSX.read(buffer, { type: 'array' });
  #|           const first = workbook.SheetNames[0];
  #|           const sheet = first ? workbook.Sheets[first] : null;
  #|           if (sheet) {
  #|             rows = window.XLSX.utils.sheet_to_json(sheet, {
  #|               header: 1,
  #|               raw: false,
  #|               defval: '',
  #|               blankrows: false
  #|             });
  #|           }
  #|         } else if (extension === 'csv' || extension === 'tsv') {
  #|           const text = new TextDecoder().decode(buffer);
  #|           rows = text
  #|             .split(/\r?\n/)
  #|             .filter((line) => line.length > 0)
  #|             .map((line) => line.split(extension === 'tsv' ? '\t' : ','));
  #|         }
  #|         rows = normalize(rows);
  #|         if (rows.length === 0) continue;
  #|         const base = (file.name.replace(/\.[^.]+$/, '') || 'table').trim() || 'table';
  #|         let longCells = 0;
  #|         rows = rows.map((row) => row.map((cell) => {
  #|           const chars = Array.from(String(cell));
  #|           if (chars.length > MAX_CELL_CHARS) {
  #|             longCells = longCells + 1;
  #|             return chars.slice(0, MAX_CELL_CHARS).join('');
  #|           }
  #|           return String(cell);
  #|         }));
  #|         let columns = 0;
  #|         rows.forEach((row) => {
  #|           if (row.length > columns) columns = row.length;
  #|         });
  #|         const columnGroups = [];
  #|         if (columns > MAX_COLUMNS) {
  #|           const perGroup = MAX_COLUMNS - 1;
  #|           let cursor = 0;
  #|           while (cursor < columns) {
  #|             const group = cursor === 0 ? [] : [0];
  #|             const end = cursor === 0
  #|               ? Math.min(MAX_COLUMNS, columns)
  #|               : Math.min(cursor + perGroup, columns);
  #|             const start = cursor;
  #|             for (let index = start; index < end; index = index + 1) {
  #|               group.push(index);
  #|             }
  #|             columnGroups.push(group);
  #|             cursor = end;
  #|           }
  #|         } else {
  #|           const group = [];
  #|           for (let index = 0; index < columns; index = index + 1) {
  #|             group.push(index);
  #|           }
  #|           columnGroups.push(group);
  #|         }
  #|         const rowSplit = rows.length - 1 > MAX_ROWS;
  #|         const columnSplit = columnGroups.length > 1;
  #|         const chunks = [];
  #|         columnGroups.forEach((group) => {
  #|           const projected = rows.map((row) => group.map((index) => row[index] == null ? '' : row[index]));
  #|           const header = projected[0];
  #|           const body = projected.slice(1);
  #|           const rowParts = Math.max(1, Math.ceil(body.length / MAX_ROWS));
  #|           for (let part = 0; part < rowParts; part = part + 1) {
  #|             const chunk = body.slice(part * MAX_ROWS, (part + 1) * MAX_ROWS);
  #|             chunks.push([header].concat(chunk));
  #|           }
  #|         });
  #|         const total = chunks.length;
  #|         chunks.forEach((chunk, index) => {
  #|           results.push({
  #|             id: newId(),
  #|             name: total > 1 ? base + '-' + (index + 1) + '.csv' : base + '.csv',
  #|             csv: encodeCsv(chunk),
  #|             split: total > 1,
  #|             row_split: rowSplit,
  #|             column_split: columnSplit,
  #|             parts: total,
  #|             part_index: index + 1,
  #|             long_cells: index === 0 ? longCells : 0,
  #|             original: file.name
  #|           });
  #|         });
  #|       } catch (error) {
  #|         // Unsupported or malformed files are skipped.
  #|       }
  #|     }
  #|     input.value = '';
  #|     resolve(JSON.stringify(results));
  #|   })();
  #| })

///|
async fn import_tables_task() -> String noraise {
  @js_async.run_promise(_ => read_table_input_promise()) catch {
    _ => "[]"
  }
}
