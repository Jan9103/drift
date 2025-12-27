use ./log.nu
use ./globs.nu [is_in_debug_mode]

export alias builtin_try = try

# a placeholder to avoid LSP warnings while writing code
@example '' {
  def foo []: nothing -> string {
    TODO implement foo
  }
}
export def TODO [...args: oneof<string, int, float>]: any -> any {
  throw panic $'Hit TODO marker: ($args | str join " ")' --id 'drift::TODO_marker'
}

# for making the LSP happy while also avoiding issues if you are wrong
@example '' {
  def my_func []: nothing -> string {
    loop {
      return ""
    }
    UNREACHABLE 'my_func'
  }
}
export def UNREACHABLE [location: string, why_unreachable?: string]: nothing -> any {
  throw panic $'Hit UNREACHABLE marker: ($location)' ($why_unreachable | default '[no explanation]') --id 'drift::UNREACHABLE_marker'
}

# error if a condition fails
@example 'compare within assert' {
  assert (1 + 1) '==' 2 -t 'Math just broke.' --panic
  assert 10 '>' 0
  assert 'Alice' '=~' '^[A-Z][a-z]+$'
}
@example 'pass a boolean to assert' {
  assert true
  let foo = true
  assert $foo
  assert (1 + 1 == 2)
}
export def assert [
  lhs: any
  comparison_operator?: string = '=='
  rhs?: any = true

  --error-title(-t): string = 'Assertion failed'
  --error-id(-i): string = 'drift::assert'
  --panic(-p)  # panic instead of error
  --debug-only(-d)  # only check if debug is enabled
]: nothing -> nothing {
  if $debug_only and not $is_in_debug_mode { return }

  let success: bool = (match $comparison_operator {
    '==' => { $lhs == $rhs }
    '!=' => { $lhs != $rhs }
    '>'  => { $lhs >  $rhs }
    '>=' => { $lhs >= $rhs }
    '<'  => { $lhs <  $rhs }
    '<=' => { $lhs <= $rhs }
    '=~' => { $lhs =~ $rhs }
    '!~' => { $lhs !~ $rhs }
    _ => { throw panic $'assert: invalid comparison_operator: ($comparison_operator)' --id 'drift::assert::invalid_comparison_operator' }
  })
  if not $success {
    if $panic {
      throw panic $error_title $'assertion: ($lhs | to nuon --raw --serialize) ($comparison_operator) ($rhs | to nuon --raw --serialize)' --id $error_id
    } else {
      throw error $error_title $'assertion: ($lhs | to nuon --raw --serialize) ($comparison_operator) ($rhs | to nuon --raw --serialize)' --id $error_id
    }
  }
}

@example 'basic' {
  let file = "/foo"
  throw panic $"can't open file ($file)"
}
@example 'hit ratelimit' {
  let bar = "/foo"
  (throw panic
    'invalid argument'
    $'function: foo, argument: bar, argument-value: ($bar)'
    --id 'invalid_argument')
}
export def 'throw panic' [
  title: string
  body: string = ""
  --id(-i): string = ""
]: nothing -> nothing {
  error make {
    msg: $title
    help: $body
    code: $"!($id)"
  }
  null
}

@example 'basic' {
  let file = 'foo.txt'
  throw error $"can't open file ($file)"
}
@example 'hit ratelimit' {
  let url = 'https://foo'
  throw error 'hit ratelimit' $'target: ($url)' --id 'http::503'
}
export def 'throw error' [
  title: string
  body: string = ""
  --id(-i): string = ""
]: nothing -> nothing {
  error make {
    msg: $title
    help: $body
    code: $id
  }
  null
}

@example 'with drift catch' {
  try {
    throw error 'test'
  } catch {|error|
    rethrow $error
  }
}
export def 'rethrow' [err]: nothing -> nothing {
  $err.raw
  null
}

@example 'basic catch' {
  try {
    throw error 'test error'
  } catch {|error|
    # handling
  }
}
@example 'catch-record' {
  try {
    throw error 'test error' --id 'example::test'
  } catch {
    'example::test': {|error|
      print 'You shall pass'
    }
    '_': {|error|
      rethrow $error
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
      if ($err.code | str starts-with '!') and not $handle_panics {
        if $finally != null {
          builtin_try { do $finally } catch {|f_err|
            if not ($f_err.code | str starts-with '!') {
              log error $"[drift::error::try] 'try' panicked and 'finally' also produced a error - swallowing the 'finally' error: ($f_err.json)"
              $err.raw
            }
            log error $"[drift::error::try] both 'try' and 'finally' produced a panic - swallowing the 'try' error: ($err.json)"
            $f_err.raw
          }
        }
        $err.raw
      }
      if ($err.code | str starts-with '^') {
        if $finally != null { do $finally }
        $err.raw
      }
      let eht = ($error_handling | describe)
      let handler = (
        if ($eht | str starts-with "record") {
          $error_handling
          | get --optional ($err.code | str trim --left --char '!')
          | default { $error_handling.'_'? }
        } else if ($eht | str starts-with 'closure') {
          $error_handling
        } else { null }
      )
      if $handler != null {
        builtin_try {
          [ (do $handler $err) ]
        } catch {|eh_err|
          if not ($eh_err.code | starts-with '^') or $eh_err.code != '^drift::retry' {
            if $finally != null {
              builtin_try { do $finally } catch {|f_err|
                if ($eh_err.code | str starts-with '!') and not ($f_err.code | str starts-with '!') {
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
      if $finally != null { do $finally }
      return $res.0
    }
    $attempt_no = ($attempt_no + 1)
  }
}

@example '' {
  let result = (
    try {
      my_api get '/foo'
    } catch {
      "my_api::503": {|error|
        print 'Hit rate-limit. waiting 1sec before retrying.'
        sleep 1sec
        retry --max-attempts 3
        print 'failed 3 times, giving up.'
        rethrow $error
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
    'msg': "you shouldn't see this - you probably used 'retry' outside of a 'catch'"
    'code': '^drift::retry'
  }
  null
}
