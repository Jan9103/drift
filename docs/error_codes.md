# Drift's error codes

## Typecheck

* `drift::typecheck`: typecheck found a violation

## Error module

* `drift::assert`: default error thrown by `assert`
* `drift::assert::invalid_comparison_operator`: `assert` only supports specific comparison operators - the one given is not one of them
* `drift::error::missing_nu_error`: expected to get passed a drift-error with nu-error attached
* `drift::UNREACHABLE_marker`: executed a `UNREACHABLE` marker
* `drift::TODO_marker`: executed a `TODO` marker
