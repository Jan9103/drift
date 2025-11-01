use ./types.nu *
use ./error.nu *

def default_reversals []: nothing -> record { {
  'from json': [[] {|| from json} {|| to json}]
  'to json': [[] {|| to json} {|| from json}]
  'get': [['cell-path'] {|path| get $path } {|original,path| let In = $in; $original | update $path $In }]
} }

# uiua inspired function to auto un-apply a change.
# in here as a experiment. there is a good chance that i will remove it.
# also very basic implementation so far.
@example '' {
  ls | to json | under 'from json' { get name }
  # equal to
  ls | get name
}
@example '' {
  ls | under 'get' $.name { str camel-case }
  # equal to
  ls | update name {|i| $i.name | str camel-case }
}
export def under [
  action: string
  ...args: any
]: any -> any {
  let In: any = $in
  let code: closure = ($args | last)
  $code | typecheck ['closure']
  let args: list<any> = ($args | drop 1)
  let rev = (default_reversals | get -o $action)
  if $rev == null {
    # throw errror --id 'drift::under::undefined' $'Undefined "under" action: ($action)'
    1 / 0
  }
  # assert ($rev.0 | length) '==' ($args | length) --error-id 'drift::under::arg-count-mismatch' --error-title $'"under" recieved unexpected argument count [($args | length)] - expected: ($rev.0)'

  $In
  | do $rev.1 ...$args
  | do $code
  | do $rev.2 $In ...$args
}
