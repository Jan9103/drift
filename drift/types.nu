use ./globs.nu [is_in_debug_mode]
use ./error.nu ['throw error', 'throw panic']

def typecheck_error [
  expected: string
  got: any
  title: string
  panic: bool
  error_id
]: nothing -> nothing {
  use ./error.nu

  let got: string = (
    $got
    | to nuon --raw --serialize
    | if ($in | str length) >= 80 { $'($in | str substring 0..79)…' } else { $in }
  )
  if $panic {
    throw panic $title $'expected ($expected), got ($got)' --id $error_id
  } else {
    throw error $title $'expected ($expected), got ($got)' --id $error_id
  }
}

# essentially a 'assert' for validating types
#
# throws a error if not matched
#
# since nu's typing system is pretty limited and slow to parse it uses its own format:
# every type is a list with its first item beeing the types name (string) and the rest beeing arguments:
#   'any': matches everything
#   'string'
#   'path': a alias for 'string' (for now)
#   'int'
#   'float'
#   'filesize'
#   'duration'
#   'datetime'
#   'cell-path'
#   'error'
#   'glob'
#   'range'
#   'sqlite-in-memory': same as the nu type (returned by `stor open`)
#   'closure'
#   'binary'
#   'nothing':
#      alias: 'null'
#   'number': either 'int' or 'float'
#   'list':
#     argument 1: the type of the list items (another list)
#     example: ['list' ['string']] matches ['foo' 'bar'] and also empty lists
#   'array': a list with a fixed length
#     argument 1: the type of the list items (another list)
#     argument 2: length
#     example: ['array' ['string'] 2] matches ['foo' 'bar'], but not ['foo']
#   'tuple': a list where each item has a specific type
#     argument 1: the types (as list)
#     example: ['tuple' [['string'] ['list' ['string']]]] matches ['foo' ['bar']]
#   'record':
#     argument 1: a record containing the types for all the types
#       the value of each entry can either be:
#         a list (type definition)
#         a record:
#           'type' (required, type definition)
#           'required' (optional, bool, default = true)
#     argument 2 (optional): allow keys not defined in arg1 (default: false)
#     example: ['record' {'foo': ['int'], 'bar': ['string']}] matches {'foo': 1, 'bar': 'hi'}
#   'map': see <https://en.wikipedia.org/wiki/Associative_array> (made in nu using a record)
#     alias: 'dict' (python's name)
#     argument 1: the key type
#     argument 2: the value type
#     example: ['map' ['string'] ['int']] matches {'foo': 1, 'bar': 2}
#   'table': a list of records
#     argument 1: same as for 'record': a record containing the types
#     example: ['table' {'foo': ['string'], 'bar': ['int']}] matches [{"foo": "a", "bar": 1}]
#   'option': either null or arg1
#     alias: 'optional'
#     argument 1: the allowed non-null type
#     example: ['option' ['string']] matches both null and 'foo'
#   'oneof': allow multiple types
#     alias: 'union' (python's name)
#     argument 1: a list of allowed types
#     example: ['oneof' [['string'] ['int']] matches both 'foo' and 1
#   '==': the value (not the type) should match exactly
#     argument 1: the value it should match
#     examples: ['==' 'foo'], ['==', 12], ['==' {"foo": "bar"}]
#   '=~': regex match the value
#     argument 1: the regex it should match
#     example: ['=~' '^[a-z]+$']
#
# typedefinitions:
#   intended for:
#   * saving common complex types to a const and passing it along
#   * allowing recursion
#   a record with:
#   * the name (string) as key (prefixed with '$')
#   * the type definition (list) as value
#   example:
#   {
#     '$author': ['record' {'name': ['string']}]
#     '$book': ['record' {'title': ['string'], 'author': ['$author']}]
#   }
@example 'check if the input is a string' {||
  "foo" | typecheck ['string']
}
@example "match 'ls'" {||
  ls
  | typecheck ['table' {
    'name': ['string'],
    'type': ['string'],
    'size': ['filesize'],
    'modified': ['datetime']
  }]
}
@example '(recursion) check that its only lists and ints' {||
  [[1] [] 1 [[[1]]]]
  | typecheck ['$a'] --typedefs {
    '$a': ['oneof'
      ['list' ['$a']]
      ['int']
    ]
  }
}
export def 'typecheck' [
  type: list  # read the '--help' - its to long for here
  --typedefs: record  # map name -> typedef (see '--help')
  --error-title: string = 'TypeCheckError'
  --panic(-p)
  --error-id: string = 'drift::typecheck'
  --debug(-d)  # only typecheck in debug scenarios
]: any -> any {
  let In = $in
  if $debug and $is_in_debug_mode { return $In }
  $In | (tc
    $type
    --typedefs=(if $typedefs == null { $env.DRIFT_TYPEDEFS } else { $env.DRIFT_TYPEDEFS | merge $typedefs })
    --error-title=$error_title
    --panic=$panic
    --error-id=$error_id
    --debug=$debug
  )
  $In
}

def 'tc' [
  type: list
  --typedefs: record
  --error-title: string
  --panic = true
  --error-id: string
  --debug
]: any -> nothing {
  let i = $in
  let d = ($i | describe | split row ' ' | first | split row '<' | first)
  let type = (if ($type.0 | str starts-with '$') { $typedefs | get $type.0 } else { $type })

  match $type.0 {
    'any' => { }
    'nothing'
    | 'null'    => { if $d != 'nothing'   { typecheck_error 'nothing'   $i $error_title $panic $error_id } }
    'string'
    | 'path'
    | 'regex'   => { if $d != 'string'    { typecheck_error $type.0     $i $error_title $panic $error_id } }
    'bool'
    | 'boolean' => { if $d != 'bool'      { typecheck_error 'boolean'   $i $error_title $panic $error_id } }
    'int'       => { if $d != 'int'       { typecheck_error 'int'       $i $error_title $panic $error_id } }
    'float'     => { if $d != 'float'     { typecheck_error 'float'     $i $error_title $panic $error_id } }
    'filesize'  => { if $d != 'filesize'  { typecheck_error 'filesize'  $i $error_title $panic $error_id } }
    'duration'  => { if $d != 'duration'  { typecheck_error 'duration'  $i $error_title $panic $error_id } }
    'datetime'  => { if $d != 'datetime'  { typecheck_error 'datetime'  $i $error_title $panic $error_id } }
    'cell-path' => { if $d != 'cell-path' { typecheck_error 'cell-path' $i $error_title $panic $error_id } }
    'error'     => { if $d != 'error'     { typecheck_error 'error'     $i $error_title $panic $error_id } }
    'glob'      => { if $d != 'glob'      { typecheck_error 'glob'      $i $error_title $panic $error_id } }
    'range'     => { if $d != 'range'     { typecheck_error 'range'     $i $error_title $panic $error_id } }
    'closure'   => { if $d != 'closure'   { typecheck_error 'closure'   $i $error_title $panic $error_id } }
    'binary'    => { if $d != 'binary'    { typecheck_error 'binary'    $i $error_title $panic $error_id } }
    'sqlite-in-memory' => { if $d != 'sqlite-in-memory' { typecheck_error 'sqlite-in-memory' $i $error_title $panic $error_id } }

    'number' => { if $d not-in ['float', 'int'] { typecheck_error 'number' $i $error_title $panic $error_id } }

    'list' => {
      if $d not-in ['list' 'table'] { typecheck_error 'list' $i $error_title $panic $error_id }
      for z in $i { $z | tc $type.1 --typedefs $typedefs --error-title $error_title --panic=$panic --error-id=$error_id }
    }
    'array' => {
      if $d not-in ['list' 'table'] { typecheck_error 'list' $i $error_title $panic $error_id }
      if ($i | length) != $type.2 { typecheck_error $"array \(length: ($type.2)\)" $i $error_title $panic $error_id }
      for z in $i { $z | tc $type.1 --typedefs $typedefs --error-title $error_title --panic=$panic --error-id=$error_id }
    }
    'tuple' => {
      if $d not-in ['list' 'table'] { typecheck_error 'tuple (a list)' $i $error_title $panic $error_id }
      if ($i | length) != ($type.1 | length) { typecheck_error 'tuple (length mismatch)' $i $error_title $panic $error_id }
      for z in ($i | zip $type.1) { $z.0 | tc $z.1 --typedefs $typedefs --error-title $error_title --panic=$panic --error-id=$error_id }
    }
    'map' | 'dict' => {
      if $d != 'record' { typecheck_error 'map (record)' $i $error_title $panic $error_id }
      for z in ($i | transpose k v) {
        $z.k | tc $type.1 --typedefs $typedefs --error-title $error_title --panic=$panic --error-id=$error_id
        $z.v | tc $type.2 --typedefs $typedefs --error-title $error_title --panic=$panic --error-id=$error_id
      }
    }
    'record' => {
      if ($d) != 'record' { typecheck_error 'record' $i $error_title $panic $error_id }
      for m in ($type.1 | transpose k v) {
        let v = if ($m.v | describe) =~ '^record' { {
          'type': $m.v.type
          'required': ($m.v.required | default true)
        } } else { {
          'type': $m.v
          'required': true
        } }
        if $v.required and ($m.k not-in $i) { typecheck_error $"record \(missing key: ($m.k)\)" $i $error_title $panic $error_id }
        $i | get $m.k | tc $v.type --typedefs $typedefs --error-title $error_title --panic=$panic --error-id=$error_id
      }
      if $type.2? != true {
        let wanted_keys = ($type.1 | columns)
        for k in ($i | columns) {
          if $k not-in $wanted_keys { typecheck_error $"record \(unexpected key: ($k)\)" $i $error_title $panic $error_id }
        }
      }
    }
    'table' => {
      # 'list' has to be allowed in case the table is empty
      if $d not-in ['table', 'list'] { typecheck_error 'table' $i $error_title $panic $error_id }
      for z in $i {
        $z | tc ['record' $type.1] --typedefs $typedefs --error-title $error_title --panic=$panic --error-id=$error_id
      }
    }

    'oneof' | 'union' => {
      if not ($type.1 | any {|t|
        try {
          $i | tc $t --typedefs $typedefs --error-title $error_title --panic=$panic --error-id=$error_id
          true
        } catch { false }
      }) {
        typecheck_error ($type | to nuon --raw) $i $error_title $panic $error_id
      }
    }
    'option' | 'optional' => {
      if $i == null { return }
      $i | tc $type.1 --typedefs $typedefs --error-title $error_title --panic=$panic --error-id=$error_id
    }

    '==' => { if $i != $type.1 { typecheck_error $"== ($type.1)" $i $error_title $panic $error_id } }
    '=~' => {
      if $d != 'string' { typecheck_error 'string (regex match)' $i $error_title $panic $error_id }
      if $i !~ $type.1 { typecheck_error $"=~ ($type.1)" $i $error_title $panic $error_id }
    }
  }
}
