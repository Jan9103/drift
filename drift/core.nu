use ./error.nu ['render error']
use ./log.nu

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

  log info 'starting drift'
  try {
    do $code
  } catch {|nu_error|
    try {
      let drift_error = ($nu_error.msg | from json)
      if ($drift_error | columns | sort) != ["body","id","severity","title"] { 1 / 0 }
      render error $drift_error
    } catch {
      $nu_error.rendered
    }
  } | print $in
  log info 'drift ended'
}
