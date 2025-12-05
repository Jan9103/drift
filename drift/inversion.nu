use ./types.nu *
use ./error.nu *

def default_reversals []: nothing -> record { {
  # file formats
  'from csv': [[] {|| from csv} {|| to csv}]
  'from json': [[] {|| from json} {|| to json}]
  'from msgpack': [[] {|| from msgpack} {|| to msgpack}]
  'from msgpackz': [[] {|| from msgpackz} {|| to msgpackz}]
  'from nuon': [[] {|| from nuon} {|| to nuon}]
  'from tsv': [[] {|| from tsv} {|| to tsv}]
  'from xml': [[] {|| from xml} {|| to xml}]
  'from yaml': [[] {|| from yaml} {|| to yaml}]
  'to csv': [[] {|| to csv} {|| from csv}]
  'to json': [[] {|| to json} {|| from json}]
  'to msgpack': [[] {|| to msgpack} {|| from msgpack}]
  'to msgpackz': [[] {|| to msgpackz} {|| from msgpackz}]
  'to nuon': [[] {|| to nuon} {|| from nuon}]
  'to tsv': [[] {|| to tsv} {|| from tsv}]
  'to xml': [[] {|| to xml} {|| from xml}]
  'to yaml': [[] {|| to yaml} {|| from yaml}]

  # data-types
  'path parse': [[] {|| path parse} {|| path join}]
  'path unparse': [[] {|| path join} {|| path parse}]
  'path split': [[] {|| path split} {|| path join}]
  'path unsplit': [[] {|| path join} {|| path split}]
  'url decode': [[] {|| url decode} {|| url encode}]
  'url encode': [[] {|| url encode} {|| url decode}]
  'url parse': [[] {|| url parse} {|| url join}]

  'int2str': [[] {|| into string} {|| into int}]
  'str2int': [[] {|| into int} {|| into string}]
  'float2str': [[] {|| into string} {|| into float}]
  'str2float': [[] {|| into float} {|| into string}]

  # subset
  'columns': [[] {|| columns} {|original| zip ($original | values) | into record}]
  'drop': [['int'] {|count| drop $count} {|original,count| append ($original | last $count)}]
  'first': [['int'] {|count| first $count} {|original,count| append ($original | skip $count)}]
  'get': [['cell-path'] {|path| get $path } {|original,path| let In = $in; $original | update $path $In }]
  'last': [['int'] {|count| last $count} {|original,count| prepend ($original | drop $count)}]
  'reject': [['list'] {|cols| reject ...$cols} {|original,cols| let In = $in; $original | merge $In}]
  'select': [['list'] {|cols| select ...$cols} {|original,cols| let In = $in; $original | merge $In}]
  'skip': [['int'] {|count| skip $count} {|original,count| prepend ($original | first $count)}]
  'values': [[] {|| values} {|original| let In = $in; $original | columns | zip $In | into record}]
  'wrap': [['string'] {|column_name| wrap $column_name} {|original,column_name| get $column_name}]

  # other
  'open --raw': [['path'] {|file| open --raw $file} {|original,file| $in | save --raw --force $file}]  # $in is to force-collect it, to avoid bugs
  'open': [['path'] {|file| open $file} {|original,file| $in | save --force $file}]  # $in is to force-collect it, to avoid bugs
  'reverse': [[] {|| reverse} {|| reverse}]
  'split column': [['string'] {|seperator| split column $seperator} {|original,seperator| str join $seperator}]
  'lines': [[] {|| lines} {|| str join "\n"}]
} }

# uiua inspired function to auto un-apply a change.
# support for each action has to be pre-defined.
# in here as a experiment. there is a good chance that i will remove it.
# also very basic implementation so far.
@example 'change a file extension' {
  './foo.png' | under 'path parse' { update $.extension 'jpg' }
  # is equal to
  './foo.png' | path parse | update $.extension 'jpg' | path join
}
@example 'send data to a external tool' {
  ls | under 'to json' { ^jq '.[0]' }
}
@example 'Append to a file' {
  under 'open' 'log.json' { append {'message': 'foo'} }

  under 'open' $nu.config-path { under 'lines' { append 'source some_file.nu' } }
}
@example 'Do not apply something to the first 3 items of a list' {
  ls | under 'skip' 3 { str camel-case $.name }
}
@example 'camelCase all the column names' {
  ls | under 'columns' { str camel-case }
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
    throw errror --id 'drift::under::undefined' $'Undefined "under" action: ($action)'
  }
  assert ($rev.0 | length) '==' ($args | length) --error-id 'drift::under::arg-count-mismatch' --error-title $'"under" recieved unexpected argument count [($args | length)] - expected: ($rev.0)'

  $In
  | do $rev.1 ...$args
  | do $code
  | do $rev.2 $In ...$args
}
