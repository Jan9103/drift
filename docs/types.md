# types

drift includes a custom type system.

it is written as structured nuon data with lists as primary medium.

examples:
* a string: `['string']`
* a list of integers: `['list' ['int']]`

## types

universal:
* `any`: matches everything
* `==`: check for equality
  * example: `['==' 12]`, `['==' 'foo']`
* `nothing`
  * aliases: `null`
* `option`: either null or arg1
  * aliases: `optional`
  * argument 1: non-null type
  * example: `['option' ['string']]`
* `oneof`: multiple potential types
  * aliases: `union`
  * argument 1: a list of allowed types
  * example: `['oneof' [['string'] ['int']]]`

text:
* `string`
* `path` (for now a `string` alias)
* `glob`
* `=~`: regex match
  * example: `['=~' '^[a-zA-Z0-9]+$']`

numbers:
* `int`
* `float`
* `number`: either `int` or `float`
* `filesize`
* `duration`
* `datetime`

structured data:
* `list`
  * argument 1: the type of the contents
  * example: `['list' ['string']]` (a list of strings or a empty list)
* `array`: a list with a fixed size
  * argument 1: content type
  * argument 2: length
  * example: `['array' ['string'] 3]` would match `["foo" "bar" "baz"]`
* `tuple`: a list with a induvidual type definition for each entry
  * argument 1: list of content types
  * example: `['tuple' [['string'] ['int']]]` would match `['foo' 42]`
* `record`
  * argument 1: record mapping to either:
    * a type
    * a record with the keys:
      * `type`
      * `required` (optional, default = true): if false it can be omitted
  * argument 2 (optional): ignore/allow additional keys
  * example 1: `['record' {'foo': ['int'], 'bar': 'string'}]`
  * example 2: `['record' {'foo': {'type': ['int'], 'required': false}}]` would match both `{}` and `{'foo': 1}`
* `map`: aka associative array, dict, hashmap, etc
  * aliases: `dict`
  * argument 1: type of the key (nu currently only allows `string`)
  * argument 2: type of the value
  * example: `['map' ['string'] ['int']]` matches `{'foo': 1, 'bar': 2}`
* `table`: a list of records
  * argument 1: same as `record`

nu-code:
* `cell-path`
* `error`
* `range`
* `closure`

oddballs:
* `sqlite-in-memory`: currently used by nu for `stor open`

---

## the `typecheck` command

basic usage: `$data | typecheck $type`

example:
```nu
'foo' | typecheck ['string']

ls | typecheck ['table' {
  'name': ['string'],
  'type': ['string'],
  'size': ['filesize'],
  'modified': ['datetime']
}]
```

### type definitions

You can define type-aliases and pass those to `typecheck`.

This can be used for repetitive structures or to allow recursion.

example:

```nu
const COMMON_TYPES = {
  '$book': ['record' {
    'name': ['string']
    'author': ['$author']
  }]
  '$author': ['record' {
    'name': ['string']
  }]
}
open book_list.json | typecheck ['list' ['$book']] --typedefs $COMMON_TYPES

# verify that it is only lists and numbers
[[1] [] 1 [[[1]]]] | typecheck ['$a'] --typedefs {
  '$a': ['oneof' [
    ['list' ['$a']]
    ['int']
  ]]
}
```

### other arguments

* `--debug(-d)`: only type-check in [debug-runs](./debugging.md) (skip otherwise)
* `--error-id` (string, default=`'drift::typecheck'`): drift-error id
* `--panic` (default=`true`): should the drift-error be a panic?
* `--error-title` (string, default=`'TypeCheckError'`): drift-error title
