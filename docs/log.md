# Drift log

## init

Before sending your first message run `log init` with at least one output target specified.

Afterwards make sure the `$env` variable set by that function gets passed to everything
writing to the log.


## messages

* `log` + level + message
  * example: `log info "Foo bar"`
  * levels: `trace`, `debug`, `info`, `warn`, `error`

## dumps

dumps are intended for big pieces of data which can help with debugging.
examples:
* `http` responses
* generated `png` files
* `cargo build` logs
* `selenium`, `playwright`, or `puppeteer` screenshots

example: `cargo build --release | log dump "cargo build log"`

## Output targets

Drift can log to any number of targets.

The targets get defined via `start_drift` argument:

```nu
use drift/prelude *

def main [] {
  start_drift --log-targets [
    (log output_target stdout)
    (log output_target file "./log.txt")
  ] {
    log info "foo"
  }
}
```

### Built in targets

* `stdout`: similar to `std/log`, just sends messages to `stdout`.
  * `--format` (see `help format pattern`)
    * default: `$'{datetime} | {color}{level}:(ansi reset) {msg}'`
    * available: `level`, `msg`, `job_id`, `job_tag`, `time` (timestamp), `datetime`, `color`
  * `--filter` (closure taking `log_entry` and returning `bool`)
    * default: `{|log_entry| $log_entry.level in ['info', 'warn', 'error'] }`
  * `--colors` (record log-level to ansi-code)
    * default: trace=grey, debug=grey, info=white, warn=yellow, error=red
  * `--datetime-format` (`format date` argument)
    * default: `%c`
* `file`: a traditional log file (`jsonl`, dumps as `nuon` within that)
  * `file` (path)
  * `--dump-log-level` (log-level string): as which log-level should `log dump` be stored?
    * default: `info`
* `directory`: split the log into multiple files to make inspecting `log dump` easier (`jsonl`)
  * `directory` (path)

### Custom target

Example:

```nu
use drift/prelude *

start_drift --log-targets [
  {
    'msg': {|log_entry|
      print $log_entry.msg
    }
    'dump': {|data,description|
      # data could be binary, etc
    }
  }
] {
  log info "foo"
}
```
