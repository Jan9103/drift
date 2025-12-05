export module 'output_target' {
  alias builtin_print = print
  export def 'print' [
    --stderr  # log to stderr instead of stdout
    --format: string = $'{datetime} | {color}{level}:(ansi reset) {msg}'
    --filter: closure  # everything where this returns true will be logged. default: {|log_entry| $log_entry.level in ['info', 'warn', 'error'] }
    --colors: record = {
      'trace': (ansi grey),
      'debug': (ansi grey),
      'info': (ansi white),
      'warn': (ansi yellow),
      'error': (ansi red),
    }
    --datetime-format: string = '%c'  # see `format date --help`
  ] {
    let filter = ($filter | default {|| {|log_entry| $log_entry.level in ['info', 'warn', 'error'] } })
    {
      'msg': {|log_entry|
        if (do $filter $log_entry) {
          builtin_print --stderr=$stderr (
            $log_entry
            | insert 'color' ($colors | get $log_entry.level)
            | insert 'datetime' ($log_entry.time | format date $datetime_format)
            | format pattern $format
          )
        }
      }
      'dump': {|data,message| }
    }
  }

  export def 'file' [
    file: path
    --dump-log-level: string = 'info'
  ] {
    let file: path = ($file | path expand)
    {
      'msg': {|log_entry|
        $log_entry
        | update 'time' {|le| $le.time | format date '%s' | into int }
        | to json --raw
        | str trim
        | $"($in)\n"
        | save --append $file
      }
      'dump': {|data,message|
        let jid = (job id)
        {
          'level': $dump_log_level
          'msg': $"DUMP ($message | to json --raw): ($data | to nuon --raw)"
          'job_id': $jid
          'job_tag': (if $jid == 0 { '[main]' } else { job list | where $it.id == $jid | $in.tag?.0? | default '[no tag]' })
          'time': (date now | format date '%s' | into int)
        }
        | to json --raw
        | str trim
        | $"($in)\n"
        | save --append $file
      }
    }
  }

  export def 'directory' [
    directory: path
  ] {
    let directory: path = ($directory | path expand)
    mkdir $directory

    let main_file: path = ($directory | path join 'main.jsonl')

    {
      'msg': {|log_entry|
        $log_entry
        | update 'time' {|le| $le.time | format date '%s' | into int }
        | to json --raw
        | str trim
        | $"($in)\n"
        | save --append $main_file
      }
      'dump': {|data,message|
        let res: path = ($directory | path join $'(random uuid).bin')
        write_log 'info' $'($message) @($res)'
        $res
        $data | save --raw (ruid $message)
      }
    }
  }
}


export def trace [message: string]: nothing -> nothing {
  write_log 'trace' $message
}
export def debug [message: string]: nothing -> nothing {
  write_log 'debug' $message
}
export def info [message: string]: nothing -> nothing {
  write_log 'info' $message
}
export def warn [message: string]: nothing -> nothing {
  write_log 'warn' $message
}
export def error [message: string]: nothing -> nothing {
  write_log 'error' $message
}

# dump some data into log-files to make debugging easier.
# this is intended to be used in ADDITION to a normal log message.
@example 'dump http response' {
  let url = 'https://127.0.0.1/foo.json'
  let response = (http get --full --allow-errors $url)
  if $response.status != 200 {
    log error $'API fetch for ($url) failed'
    $response | to json | log dump "failed http response"
  }
}
export def dump [description: string]: oneof<binary, string> -> nothing {
  let In = $in
  for target in ($env.DRIFT_LOG_TARGETS? | default []) {
    do $target.dump $In $description
  }
}

def write_log [
  level: string
  message: string
]: nothing -> nothing {
  let jid = (job id)
  let msg = {
    'level': $level
    'msg': $message
    'job_id': $jid
    'job_tag': (if $jid == 0 { '[main]' } else { job list | where $it.id == $jid | $in.tag?.0? | default '[no tag]' })
    'time': (date now)
  }
  for target in ($env.DRIFT_LOG_TARGETS? | default []) {
    do $target.msg $msg
  }
}
