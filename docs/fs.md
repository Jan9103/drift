# Filesystem

import: `use drift/fs`

## `with mktemp`

A `mktemp` wrapper, which ensures the temp file / directory gets deleted at the end.

```nu
with mktemp -d {|tmpdir|
  cd $tmpdir
  http get $url | save 'foo.png'
  ^image_viewer 'foo.png'
}
```

## `list_pardirs`

```nu
('/home/user' | list_pardirs) == ['/', '/home', '/home/user']
```

## `find_in_pardirs`

```nu
(pwd | find_in_pardirs '.git') == '/home/user/projects/drift'
(pwd | find_in_pardirs 'foo') == null
```
