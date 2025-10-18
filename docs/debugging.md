# Debugging

To improve performance you can have debugging-specific code in drift.

For performance reasons that code gets toggled at nu compile-time and
cannot be changed mid-execution.

To enable debug mode execute your script with a `nu` binary called `nu_drift_debug`.
You can achieve this by (for example) symlinking it:
```nu
# linux:
^ln -s $nu.current-exe ($nu.home-path | path join '.local' 'bin' 'nu_drift_debug')
```

You can check if you are in debug mode using the `const` `$is_in_debug_mode` from `use drift/prelude *`.
