use ./error.nu *
use ./log.nu
use ./fs

export def 'start_drift' [
  code: closure
  --typedefs: record = {}
  --log-targets: list  # defaults to only 'print'
]: nothing -> nothing {
  $env.DRIFT_TYPEDEFS = $typedefs
  $env.DRIFT_LOG_TARGETS = (
    if $log_targets == null {
      [(log output_target print)]
    } else { $log_targets }
  )

  let res = (builtin_try {
    $env.STRUCTURED_NU_OUTPUT_FILE = null
    do $code
    | if $in != null { [$in] }
  } catch {|err|
    if $err.code == '^drift::exit' {
      [ ($err.help | from nuon) ]
    } else {
      print -e $err.rendered
      exit 1
    }
  })
  if $res != null {
    let res = $res.0
    # for some reason this errors when done via `in` even tho the second statement should not run then..
    if $env.STRUCTURED_NU_OUTPUT_FILE? != null and $env.STRUCTURED_NU_OUTPUT_FILE_TARGET? == $env.PROCESS_PATH? {
      $res | save $env.STRUCTURED_NU_OUTPUT_FILE
    } else {
      print $res
    }
  }
}

export def find_binary_in_path [name: string]: nothing -> string {
  which $name | where type == "external" | get 0?.path?
}

export def sexec --wrapped [cmd: string, ...args: string]: nothing -> any {
  let cmd: path = (if '/' in $cmd { $cmd | path expand } else { $cmd | find_in_path })
  let t: path = (mktemp --directory)
  $env.STRUCTURED_NU_OUTPUT_FILE_TARGET = $cmd
  $env.STRUCTURED_NU_OUTPUT_FILE = ($t | path join 'out.msgpack')
  builtin_try {
    if ($cmd | str ends-with '.nu') {
      ^$nu.current-exe $cmd ...$args
    } else {
      ^$cmd ...$args
    }
  } catch {|err|
    rm -rf $t
    $err.raw
  }
  if ($env.STRUCTURED_NU_OUTPUT_FILE | path exists) {
    return (open $env.STRUCTURED_NU_OUTPUT_FILE)
  } else {
    throw panic "sexec target did not use structured output" --id 'drift::sexec::no_output'
  }
}
