use ./error.nu ['render raw_error']
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
    render raw_error $nu_error
  } | print $in
  log info 'drift ended'
}
