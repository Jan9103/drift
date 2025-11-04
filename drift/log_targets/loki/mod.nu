# <https://grafana.com/oss/loki>
# NOTE: a "Unauthorized error might occur if you do not pass a tenant-id"
export def log_output_target_loki [
  base_url: string = 'http://localhost:3102'
  --tenant_id: string
  --extra-labels: record = {}
  --log-dumps
]: nothing -> record<msg: closure, dump: closure> {
  http get --redirect-mode=f $'($base_url)/ready' | ignore

  let headers: record = (
    if $tenant_id == null { {} } else { {'X-Scope-OrgID': $tenant_id} }
  )

  {
    'msg': {|log_entry|
      let ns: string = ($log_entry.time | format date '%s' | $'($in)000000000')
      let payload = {
        'streams': [
          {
            'stream': ({
              'job_id': $log_entry.job_id
              'job_tag': $log_entry.job_tag
              'level': $log_entry.level
            } | merge $extra_labels)
            'values': [[$ns $log_entry.msg]]
          }
        ]
      }

      0 | tee {|| ignore; (
        http post
          --full
          --allow-errors
          --content-type='application/json'
          --redirect-mode='f'
          --headers=$headers
          $'($base_url)/loki/api/v1/push'
          $payload
      ) } | ignore
    }
    'dump': {|data,message|
      if not $log_dumps { return }
      let ns: string = (date now | format date '%s' | $'($in)000000000')
      let jid = (job id)
      let payload = {
        'streams': [
          {
            'stream': ({
              'job_id': $jid
              'job_tag': (if $jid == 0 { '[main]' } else { job list | where $it.id == $jid | $in.tag?.0? | default '[no tag]' })
              'level': 'info'
            } | merge $extra_labels)
            'values': [
              [$ns $"Dump title=($message) [base64]: ($data | into binary | encode base64)"]
            ]
          }
        ]
      }
      0 | tee {|| ignore; (
        http post
          --full
          --allow-errors
          --content-type='application/json'
          --redirect-mode='f'
          --headers=$headers
          $'($base_url)/loki/api/v1/push'
          $payload
      ) } | ignore
    }
  }
}
