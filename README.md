# Drift

A Nushell Scripting-Framework.

```nu
use drift/prelude *

def main []: nothing -> nothing {
  # drift the script (sets up everything drift needs to work)
  start_drift --log-targets [
    # you can define as many log targets as you want
    # including custom targets like grafana-loki
    (log output_target stdout)
    (log output_target file "./log.jsonl")
  ] {
    print (get_felt_temperature)
  }
}

export def get_felt_temperature []: nothing -> float {
  try {
    http get 'http://wttr.in/?format=j1'
    | get current_condition.FeelsLikeC.0
  } catch {
    # errors now have types.
    # thus you can have induvidual catch cases based
    # on the type of error or just a catch-all, etc.
    'http::403': {|err|
      log info 'Hit wttr.in ratelimit, waiting before retrying'
      sleep 3sec
      retry --max-attempts 3

      log error 'Failed 3 times, giving up'
      rethrow $err
    }
  }
}

#[test]
def test_get_felt_temperature []: nothing -> nothing {
  get_felt_temperature
  | typecheck ['number']
  | ignore  # typecheck is transparent -> fix type-annotation
}
```

## Project status

It is a alpha at best.  
Expect:
* Bugs
* Breaking changes with every update
* Removal of features
* New features

Is it active?
As I am writing this: yes.
But currently I am not (yet) very committed to bringing this to a usable state.

## Should i use this?

Right now for something requiring **stability**? **no**. (see `Project Status`)

For a **tiny script**? probably **no**.  
You won't be able to use most of it and will have to deal with `start_drift`, etc.

In a **high performance** environment? **no**.  
Drift sacrifices speed for convenience in many places.

If you want to **experience a different way to use nu** in a test project? **sure**.

## Docs

* [getting started](./docs/getting_started.md)
