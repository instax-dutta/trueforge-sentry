#!/usr/bin/env bash
# Shared chaos helpers. PROM_URL aware.

prom_wait() { # prom_url expr comparator threshold timeout_s
  local url="$1" expr="$2" cmp="$3" thr="$4" timeout="${5:-90}"
  local enc deadline=$(date +%s)
  enc=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$expr")
  while [ $(( $(date +%s) - deadline )) -lt "$timeout" ]; do
    val=$(curl -s --get "$url/api/v1/query" --data-urlencode "query=$expr" | \
      python3 -c "import json,sys;d=json.load(sys.stdin);r=d['data']['result'];print(r[0]['value'][1] if r else '')" 2>/dev/null || true)
    if [ -n "$val" ]; then
      if [ "$cmp" = "<" ]; then awk -v a="$val" -v b="$thr" 'BEGIN{exit !(a+0<b)}' && return 0
      elif [ "$cmp" = ">" ]; then awk -v a="$val" -v b="$thr" 'BEGIN{exit !(a+0>b)}' && return 0
      fi
    fi
    sleep 5
  done
  return 1
}
