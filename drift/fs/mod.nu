# a wrapper for `mktemp`, which ensures the file is deleted at the end
@example '' {|url|
  with mktemp -d {|tmpdir|
    cd $tmpdir
    http get $url | save 'foo.png'
    ^image_viewer 'foo.png'
  }
}
export def 'with mktemp' [
  code: closure
  --suffix: string  # Append suffix to template; must not contain a slash
  --tmpdir-path(-p): path  # Interpret TEMPLATE relative to tmpdir-path. If tmpdir-path is not set use $TMPDIR
  --tmpdir(-t)  # Interpret TEMPLATE relative to the system temporary directory.
  --directory(-d)  # Create a directory instead of a file.
  --template: string  # Optional pattern from which the name of the file or directory is derived. Must contain at least three 'X's in last component.
]: any -> any {
  let In = $in
  let tmp = (
    if $template == null {
      (mktemp
        --suffix=$suffix
        --tmpdir-path=$tmpdir_path
        --tmpdir=$tmpdir
        --directory=$directory)
    } else {
      (mktemp
        --suffix=$suffix
        --tmpdir-path=$tmpdir_path
        --tmpdir=$tmpdir
        --directory=$directory
        $template)
    }
  )
  try {
    let res = ($In | do $code $tmp)
    rm -rf $tmp
    return $res
  } catch {|err|
    rm -rf $tmp
    $err.raw
  }
}

@example '' {||
  ('/home/user' | list_pardirs) == ['/', '/home', '/home/user']
}
export def list_pardirs []: path -> list<path> {
  let parts = ($in | path split)
  0..(($parts | length) - 1)
  | each {|i| $parts | rangeslice 0..($i) | path join}
}

# find a file or directory in the parent directories
@example 'go to the base directory of a git-project' {
  cd (find_in_pardirs '.git' | default (pwd))
}
@example 'stdin can take directories to use as base instead of (pwd)' {
  cd ('/home/user/something' | find_in_pardirs '.bashrc' | default (pwd))
}
export def find_in_pardirs [name: string]: oneof<path, nothing> -> oneof<path, nothing> {
  for parent in ($in | default (pwd) | list_pardirs) {
    if ($parent | path join $name | path exists) {
      return $parent
    }
  }
  return null
}
