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
      let de = ($err | unpack_to_drift_error)
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

# runs a closure for each element and returns the first result that is not equal `null`.
# essentially a more efficient version of `| each $handler | where $it != null | first`.
export def l_map_find [
  label: string
  handler: closure
]: list<any> -> oneof<any, nothing> {
  let In = $in
  for item in $in {
    let r = (builtin_try {
      let r = (do $handler $item)
      if $r != null { return $r }
      null
    } catch {|err|
      let de = ($err | unpack_to_drift_error)
      if $de.severity == 'CF' and $de.id == $'@label:($label)' {
        $de.body | from nuon
      } else {
        $err.raw
      }
    })
    if $r == null {
      continue
    } else if $r.t == 'continue' {
      if $r.value? != null { return $r.value }
      continue
    } else if $r == 'break' {
      return null
    } else {
      throw panic $"l_each recieved unsupported CF: ($r | to nuon --raw --serialize)"
    }
  }
  null
}
