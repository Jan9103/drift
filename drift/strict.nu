use ./error.nu *

export-env {
  for filepath in (
    view files
    | get $.filename
    | where ($it | str contains (char path_sep))
    | where ($it | path exists)
  ) {
    check $filepath
  }
}


# returns: [row, column]
def get_rc [raw_code: string, span: int]: nothing -> list<int> {
  let before: string = ($raw_code | str substring 0..$span)
  let tmp: list<string> = ($before | split row "\n")
  let row: int = ($tmp | length)
  let column: int = ($tmp | last | str length)
  [$row, $column]
}

def check [file: path]: nothing -> nothing {
  let raw: string = (open --raw $file)
  let flat_ast: table<content: string, shape: string, span: record<start: int, end: int>> = (ast $raw --json --flatten | from json)
  for external in ($flat_ast | where $it.shape == 'shape_external') {
    let i: int = ([($external.span.start - 1) 0] | math max)
    if ($raw | str substring $i..$i) != '^' {
      let rc = (get_rc $raw $i)
      let command: string = ($external.content | str trim | ansi strip)
      throw panic "Drift-Strict detected a violation" $"($file):($rc.0):($rc.1) \(span=($i)\): Running external command without `^` \(`($command)`\)"
    }
  }
}
