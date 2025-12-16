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
      'body': '{"t":"break"}'
      'severity': 'CF'
      'id': $'@label:($label)'
    } | to json --raw)
  }
  null
}
export def l_skip [
  label: string
  count: int  # 0 is equivalent to l_continue
]: nothing -> nothing {
  error make {
    'msg': ({
      'title': "you shouldn't see this - you probably used 'skip' outside of a 'l_' function"
      'body': ({'t': 'skip', 'count': $count} | to json --raw)
      'severity': 'CF'
      'id': $'@label:($label)'
    } | to json --raw)
  }
  null
}

# WARNING: not streaming
export def l_each [
  label: string
  handler: closure
]: list<any> -> list<any> {
  let In = $in
  mut Out = []
  mut skip: int = 0
  for item in $In {
    if $skip != 0 {
      $skip -= 1
      continue
    }
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
    } else if $r.t == 'skip' {
      $skip = $r.count
      continue
    } else {
      throw panic $"l_each recieved unsupported CF: ($r | to nuon --raw --serialize)"
    }
  }
  $Out
}

# runs a closure for each element and returns the first result that is not equal `null`.
# essentially a more efficient version of `| each $handler | where $it != null | first`.
# essentially <https://doc.rust-lang.org/std/iter/trait.Iterator.html#method.find_map>
export def l_map_find [
  label: string
  handler: closure
]: list<any> -> oneof<any, nothing> {
  let In = $in
  mut skip: int = 0
  for item in $in {
    if $skip != 0 {
      $skip -= 1
      continue
    }
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
    } else if $r.t == 'skip' {
      $skip = $r.count
      continue
    } else {
      throw panic $"l_each recieved unsupported CF: ($r | to nuon --raw --serialize)"
    }
  }
  null
}

# WARNING: not streaming
# does not support `l_skip`
export def l_peach [
  label: string
  handler: closure
  --threads(-t): int = 2
  --default: any = null
]: list<any> -> list<any> {
  let In: list<any> = $in
  let msg_tag: int = (random int)
  let main_job: int = (job id)
  mut idx: int = 0
  mut recieved: int = 0
  mut workers: table<job: int, working: bool, idx: int> = (
    1..=$threads | each --keep-empty {
      {
        'job': (
          job spawn --tag 'drift::l_peach worker' {||
            loop {
              let msg: oneof<nothing, record<item: any, idx: int>> = (job recv --tag $msg_tag)
              if $msg == null {
                break
              }
              try {
                {
                  'job': (job id)
                  'ok': (do $handler $msg.item)
                  'idx': $msg.idx
                }
              } catch {|err|
                {
                  'job': (job id)
                  'err': $err
                  'idx': $msg.idx
                }
              } | job send $main_job --tag $msg_tag
            }
          }
        )
        'working': false
        'idx': 0
      }
    }
  )

  mut Out: list<any> = (1..=($In | length) | each --keep-empty { $default })

  for i in 0..<([($In | length) ($workers | length)] | math min) {
    {
      'item': ($In | get $idx)
      'idx': $idx
    } | job send ($workers | get $i).job --tag $msg_tag
    $idx += 1
  }

  while $recieved < ($In | length) {
    let res: record = (job recv --tag $msg_tag)
    if 'ok' in $res {
      $Out = ($Out | update $res.idx $res.ok)
    } else {
      let err = $res.err
      let de = ($err | unpack_to_drift_error)
      if $de.severity == 'CF' and $de.id == $'@label:($label)' {
        let r = ($de.body | from nuon)
        if $r.t == 'continue' {
          $Out = ($Out | update $res.idx $r.value?)
          continue
        } else if $r == 'break' {
          return null
        } else if $r.t == 'skip' {
          throw panic $"l_peach does not support l_skip"
        } else {
          throw panic $"l_peach recieved unsupported CF: ($r | to nuon --raw --serialize)"
        }
      } else {
        $err.raw
      }
    }
    # $result = ($result | update $res.idx $res.result)
    $recieved += 1
    if $idx < ($In | length) {
      {
        'item': ($In | get $idx)
        'idx': $idx
      } | job send $res.job --tag $msg_tag
      $idx += 1
    }
  }
  for worker in $workers {
    null | job send $worker.job --tag $msg_tag
  }

  $Out
}
