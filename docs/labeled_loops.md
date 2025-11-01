# Labeled loops

The same thing as in every other language:  
you can label loops and you can `continue`, `break`, etc them from within other loops.  
With the small addition that there are no scope-checks and you thus can even call it from inside other functions, etc.

## loop types

### `l_each`

`l_map_find <loop-label> <closure>`

like each, but with support for `l_continue` and `l_break`

### `l_map_find`

`l_map_find <loop-label> <closure>`

apply `$handler` for each item and return the result if it is non-null.

```nushell
([null null 1 2 null] | l_map_find 'my_label' {|i| $i }) == 1
```

### `l_peach`

multi-threaded `l_each` (uses jobs under the hood).

does not support `l_skip` for obvious reasons.

## in-loop commands

### `l_continue`

`l_continue <loop-label>`

### `l_break`

`l_break <loop-label>`

### `l_skip`

`l_skip <loop-label> <count>`

skip this item plus the next `$count` items (with `count=0` it is equivalent to `l_continue`).
