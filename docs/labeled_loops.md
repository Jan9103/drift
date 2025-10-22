# Labeled loops

```nushell
use drift/prelude *

def foo [leach_item] {
  if $leach_item == 2 {
    l_continue 'my_label' 42
  }
  if $leach_item == 3 {
    l_break 'my_label'
  }
}

[1 2 3 4] | l_each 'my_label' {|leach_item|
  for i in 0..10 {
    foo
  }
  $leach_item
}
# => [1 42]
```
