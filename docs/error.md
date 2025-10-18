# Drift: Error

Drift has its own error system on top of nu's error system.

A Drift-Error looks like this:

```json5
{
  "id": "http::404",  // used for programatic recognition
  "title": "Page not found",
  "body": "url: https://example.com",
  "severity": "error",
  "nu_error": {}  // classic nu error - used by drift itself, you should ignore it
}
```

The error codes by drift itself can be found [here](./error_codes.md)

You can create a error using: `throw error $title $body --id $id`

## Panics

A panic is a error, which is not intended to be catched.

Internally the difference is that `"severity"` is `"panic"`.

You can create a panic using: `throw panic $title $body --id $id`

## Try

```nushell
# catch by error type
try {
  some_code
} catch {
  'http::404': {|drift_error|
    some_code
  }
  'http::303': {|drift_error|
    some_code
  }
  # fallback (if not defined it will rethrow uncaught errors)
  '_': {|drift_error|
    some_code
  }
}

# traditional catch
try {
  some_code
} catch {|drift_error|
  some_code
}

# ignore errors
try {
  throw error ''
}

# ensure a file is deleted - even if a error occurs
let temp_file = mktemp
try {
  some_stuff
} finally {
  rm -f $temp_file
}
```

`try` arguments:
* the attempted block, which may error
* `catch` (just decoration - you could also write `except`, `''`, or whatever else you want)
* a error handler, which can be either:
  * a closure
  * a error-id to handler map
    * `_` is handled as "any error without a specific error"
    * if a error is not handled it will just be rethrown
* (optional) a `--finally` closure, which always gets executed after both `try` and `catch` finish, but due to nu-limits before the error gets handled.
  * if this closure throws a error its error will be given priority (unless the other error is a `panic` and this one is not)

if you leave out the `catch` + catch-closure all errors will just be swallowed and ignored.

**WARNING:** The attempted block is a closure and not a block. Thus you cant use `mut` with it, opposed to nu's `try`.

### Retry

Within a `catch` block you can use `retry` to re-attempt the try-block.

Example:

```nushell
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
```

If no `--max-attempts` is provided it will retry forever.

## Rethrow

`rethrow $drift_error`
