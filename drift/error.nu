use ./log.nu

export alias builtin_try = try

@example 'basic' {|file|
  throw panic $"can't open file ($file)"
}
@example 'hit ratelimit' {|bar|
  (throw panic
    'invalid argument'
    $'function: foo, argument: bar, argument-value: ($bar)'
    --id 'invalid_argument')
}
export def 'throw panic' [
  title: string
  body: string = ""
  --id(-i): string
]: nothing -> nothing {
  error make {
    'msg': ({
      'title': $title
      'body': $body
      'severity': 'panic'
      'id': $id
    } | to json --raw)
  }
  null
}

def 'convert_to_drift_error' []: record<msg: string, debug: string, raw: error, rendered: string, json: string> -> record {
  let In = $in
  let j = ($In.json | from json)
  let id = (match $j.code {
    null | '' => 'nu_error',
    'nu::shell::network_failure' => {
      let http_code = ($j.labels.0.text | parse -r '\((?P<a>\d\d\d)\)').0?.a?
      if $http_code != null {
        $'http::($http_code)'
      } else { $j.code }
    }
    _ => $j.code
  })
  let r = {
    'title': $j.msg
    'body': $j.help
    'severity': 'error'
    'id': $id
  }
  builtin_try {
    error make {
      msg: ($r | to json --raw)
      label: $j.labels.0?
    }
  } catch {|e|
    $r | insert 'nu_error' $e
  }
}

@example 'basic' {|file|
  throw error $"can't open file ($file)"
}
@example 'hit ratelimit' {|url|
  throw error 'hit ratelimit' $'target: ($url)' --id 'http::503'
}
export def 'throw error' [
  title: string
  body: string = ""
  --id(-i): string
]: nothing -> nothing {
  error make {
    'msg': ({
      'title': $title
      'body': $body
      'severity': 'error'
      'id': $id
    } | to json --raw)
  }
  null
}

@example 'with drift catch' {||
  try {
    throw error 'test'
  } catch {|drift_error|
    rethrow $drift_error
  }
}
export def 'rethrow' [err] {
  if 'nu_error' in $err { $err.nu_error.raw }  # drift error with nu error attached
  if 'msg' in $err { $err.raw }  # normal nu error
  make 'Tried to rethrow something without a nu error attached' $'Passed thing: ($err | to nuon --raw --serialize)' --id 'drift::error::missing_nu_error'
}

def unpack_to_drift_error []: record<msg: string, debug: string, raw: error, rendered: string, json: string> -> record {
  let In = $in
  builtin_try {
    let r = $In.msg | from json
    if ($r | columns | sort) != ["body","id","severity","title"] { 1 / 0 }
    $r | insert 'nu_error' $In
  } catch {
    $In | convert_to_drift_error
  }
}

@example 'basic catch' {||
  try {
    throw error 'test error'
  } catch {|drift_error|
    # handling
  }
}
@example 'catch-record' {||
  try {
    throw error 'test error' --id 'example::test'
  } catch {
    'example::test': {|drift_error|
      print 'You shall pass'
    }
    '_': {|drift_error|
      rethrow $drift_error
    }
  }
}
export def try [
  code: closure
  _phrase_catch?: string
  error_handling?: oneof<record, closure>  # error id -> handling closure
  --finally: closure
  --handle-panics  # highly discouraged - only intended for tests testing drift itself
]: any -> any {
  let In = $in
  mut attempt_no: int = 1
  loop {
    $env.DRIFT_ATTEMPT_NO = $attempt_no
    let res = (builtin_try {
      [ ($In | do $code) ]
    } catch {|err|
      let error = ($err | unpack_to_drift_error)
      if $error.severity == 'panic' and not $handle_panics {
        if $finally != null {
          builtin_try { do $finally } catch {|f_err|
            let f_error = ($f_err | unpack_to_drift_error)
            if $f_error.type != 'panic' {
              log error $"[drift::error::try] 'try' panicked and 'finally' also produced a error - swallowing the 'finally' error: ($f_err.json)"
              $err.raw
            }
            log error $"[drift::error::try] both 'try' and 'finally' produced a panic - swallowing the 'try' error: ($err.json)"
            $f_err.raw
          }
        }
        $err.raw
      }
      if $error.severity == 'CF' {
        if $finally != null { do $finally }
        $err.raw
      }
      let eht = ($error_handling | describe)
      let handler = (
        if ($eht | str starts-with "record") {
          $error_handling
          | get --optional $error.id
          | default { $error_handling.'_'? }
        } else if ($eht | str starts-with 'closure') {
          $error_handling
        } else { null }
      )
      let handler = ($error_handling | get --optional $error.id)
      if $handler != null {
        builtin_try {
          [ (do $handler $error) ]
        } catch {|eh_err|
          let eh_error = ($eh_err | unpack_to_drift_error)
          if $eh_error.severity != 'CF' or $eh_error.id != 'drift::retry' {
            if $finally != null {
              builtin_try { do $finally } catch {|f_err|
                let f_error = ($f_err | unpack_to_drift_error)
                if $eh_err.type == 'panic' and $f_error.type != 'panic' {
                  log error $"[drift::error::try] both 'catch' and 'finally' produced a error - swallowing the 'finally' error since the catch error is a panic: ($eh_err.json)"
                  $eh_err.raw
                }
                log error $"[drift::error::try] both 'catch' and 'finally' produced a error - swallowing the 'catch' error: ($eh_err.json)"
                $f_err.raw
              }
            }
            $eh_err.raw
          }
          true
        }
      } else {
        if $finally != null { do $finally }
        if $error_handling == null { return null }
        $err.raw
      }
    })
    if $res != true {
      do $finally
      return $res.0
    }
    $attempt_no = ($attempt_no + 1)
  }
}

@example '' {|url|
  let result = (
    try {
      http get $url
    } catch {
      "http::503": {|drift_error|
        print 'Hit rate-limit. waiting 1sec before retrying.'
        sleep 1sec
        retry --max-attempts 3
        print 'failed 3 times, giving up.'
        rethrow $drift_error
      }
    }
  )
}
export def retry [
  --max-attempts: int  # default: infinite
]: nothing -> nothing {
  # if you see this in a error message you probably used 'retry' outside of a 'catch'
  if $max_attempts != null and $env.DRIFT_ATTEMPT_NO >= $max_attempts {
    return
  }
  error make {
    'msg': ({
      'title': "you shouldn't see this - you probably used 'retry' outside of a 'catch'"
      'body': ""
      'severity': 'CF'
      'id': 'drift::retry'
    } | to json --raw)
  }
  null
}

export def 'render error' [drift_error: record]: nothing -> string {
  # since the "span" in the nu error is for the "error make" within "drift error make" i can't point anywhere :(
  $"Drift-Error: (ansi red)($drift_error.id? | default '[no id]')(ansi reset)

(ansi cyan)Title: (ansi reset)($drift_error.title | ansi strip)
(ansi cyan)Body: (ansi reset)($drift_error.body? | default '[no body]' | ansi strip)
(ansi cyan)Severity: (ansi reset)($drift_error.severity | ansi strip)"
}
