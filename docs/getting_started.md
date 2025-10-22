# Getting started

## What is drift?

Drift is a framework for scripting in nushell, which among other things changes the coding style.

It overwrites core functionality (like errors) of nu with custom implementations
and thus cannot be treated like a basic utility-library.

## Installing drift

it is just a module.  
there is a guide to modules in the [nu book](https://www.nushell.sh/book/modules/using_modules.html#overview).

## Making a script "drift"

Due to the way drift works it requires a "known environment", which gets set up by the `start_drift` function.

So your code should look like this:

```nushell
use drift/prelude *

def main [] {
  start_drift {
    YOUR_CODE
  }
}
```

You can call functions, etc - but everything using drift should be a child-scope of `start_drift`.

### Configuration

`start drift` accepts some arguments:
* `--typedefs: closure`: global type-definitions for the `typecheck` function (see [types](./types.md) for details).
* `--log-targets: list`: where to send log messages (see [log](./log.md) for details).

## What next?

You should read the chapters about things drift replaces:
* [errors](./error.md)

After that just read what you need / want:
* [debugging](./debugging.md)
* [labeled loops](./labeled_loops.md) (`break` or `continue` from within nested loops)
* [logs](./log.md)
* [typing](./types.md)
