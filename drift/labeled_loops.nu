use ./error.nu *

export def l_continue [
  label: string
  value?: any
]: nothing -> nothing {
  error make {
    'msg': ({
      'title': "you shouldn't see this - you probably used 'continue' outside of a 'l_' function"
      'body': ({'t': 'continue', 'value': $value} | to nuon --raw)
      'severity': 'CF'
      'id': $'@label:($label)'
    } | to json --raw)
  }
  null
}
export def l_break [
  label: string
]: nothing -> nothing {
  error make {
    'msg': ({
      'title': "you shouldn't see this - you probably used 'break' outside of a 'l_' function"
      'body': "{'t':'break'}"
      'severity': 'CF'
      'id': $'@label:($label)'
    } | to json --raw)
  }
  null
}

export def l_each [
  label: string
  handler: closure
]: list<any> -> list<any> {
  let In = $in
  mut Out = []
  for item in $In {
    let r = (builtin_try {
      $Out = ($Out | append (do $handler $item))
      null
    } catch {|err|
      let de = ($err | convert_raw_error_to_drift_error)
      if $de.severity == 'CF' and $de.id == $'@label:($label)' {
        $de.body | from nuon
      } else {
        $err.raw
      }
    })
    if $r == null {
      continue
    } else if $r.t == 'continue' {
      $Out = ($Out | append $r.value?)
      continue
    } else if $r == 'break' {
      break
    } else {
      throw panic $"l_each recieved unsupported CF: ($r | to nuon --raw --serialize)"
    }
  }
  $Out
}
