typeset -g CX_HOME="$HOME/.codex"
typeset -g CX_AUTH="$CX_HOME/auth"
typeset -g CX_HOMES="$CX_HOME/homes"

_cx_home() {
  local home="$CX_HOMES/$1" file

  mkdir -p "$home" || return
  for file in "$CX_HOME"/*(ND); do
    ln -sfn "$file" "$home/${file:t}" || return
  done
  ln -sfn "$CX_AUTH/$1.auth.json" "$home/auth.json"
}

_cx_run() {
  local name=$1
  shift

  _cx_home "$name" || return
  CODEX_HOME="$CX_HOMES/$name" command codex "$@"
}

_cx_rows() {
  {
    local auth name access

    for auth in "$CX_AUTH"/*.auth.json(N); do
      name=${auth:t:r:r}
      (
        access=$(jq -er '.tokens.access_token' "$auth" 2>/dev/null) || exit
        curl -fsS -H "Authorization: Bearer $access" https://chatgpt.com/backend-api/wham/usage |
          jq -r --arg name "$name" '
            .rate_limit.primary_window as $short
            | .rate_limit.secondary_window as $week
            | [$name, $short.used_percent, ($short.reset_at // ""), $week.used_percent, ($week.reset_at // "")]
            | @tsv
          '
      ) &
    done
    wait
  }
}

_cx_select_account() {
  local rows=$1 now week=$((7 * 24 * 60 * 60))
  local fallback first_inactive best
  local n=0 newest=0 best_score=0 score reset used
  local -a f

  now=$(date +%s) || return
  while IFS=$'\t' read -rA f; do
    [[ -n ${f[1]} ]] || continue

    (( n++ ))
    fallback=${fallback:-${f[1]}}
    used=$(( f[2] > f[4] ? f[2] : f[4] ))
    (( used < 100 )) || continue

    reset=${f[5]:-0}
    if (( reset <= now )); then
      first_inactive=${first_inactive:-${f[1]}}
      continue
    fi

    (( reset - now > newest )) && newest=$(( reset - now ))
    score=$(( (100 - f[4]) / 100.0 - (reset - now) / (week * 1.0) ))
    if [[ -z $best ]] || (( score > best_score )); then
      best=${f[1]}
      best_score=$score
    fi
  done <<< "$rows"

  if [[ -n $first_inactive ]] && { [[ -z $best ]] || (( newest <= week * (n - 1) / n )); }; then
    print -r -- "$first_inactive"
  else
    print -r -- "${best:-$fallback}"
  fi
}

cx() {
  local name rows

  case $1 in
    @?*)
      name=${1#@}
      shift
      _cx_run "$name" "$@"
      return
      ;;
    list)
      shift
      _cx_list "$@"
      return
      ;;
    refresh)
      shift
      _cx_refresh "$@"
      return
      ;;
  esac

  rows=$(_cx_rows)
  name=$(_cx_select_account "$rows")
  [[ -n $name ]] || return 1

  _cx_run "$name" "$@"
}

_cx_refresh() {
  local auth name

  for auth in "$CX_AUTH"/*.auth.json(N); do
    name=${auth:t:r:r}
    (
      _cx_home "$name" || exit
      CODEX_HOME="$CX_HOMES/$name" command script -q /dev/null codex >/dev/null 2>&1 &
      sleep 3
      kill $! 2>/dev/null || true
      wait $! 2>/dev/null || true
    ) &
  done

  wait
}

_cx_print_window() {
  local rows=$1 used=$2 reset=$3 pct filled bar width=0 gray=$'\033[90m' off=$'\033[0m'
  local -a f

  while IFS=$'\t' read -rA f; do
    (( ${#f[1]} > width )) && width=${#f[1]}
  done <<< "$rows"

  print -r -- "$rows" | sort -t $'\t' -k${used},${used}n | while IFS=$'\t' read -rA f; do
    pct=$(( 100 - f[$used] ))
    filled=$(( pct / 5 ))
    bar=$(printf '%*s' "$filled" '' | tr ' ' '█')$(printf '%*s' "$((20 - filled))" '' | tr ' ' '░')
    printf '%-*s [%s] %3s%% left %s(resets %s)%s\n' "$width" "${f[1]}" "$bar" "$pct" "$gray" "$(date -r "${f[$reset]}" '+%H:%M on %d %b')" "$off"
  done
}

_cx_list() {
  local rows

  rows=$(_cx_rows)
  [[ -n $rows ]] || return

  _cx_print_window "$rows" 2 3
  echo
  _cx_print_window "$rows" 4 5
}

_cx_complete() {
  local -a commands accounts

  commands=(
    'list:list account quota usage and refresh times'
    'refresh:refresh auth tokens for all accounts'
  )
  accounts=("$CX_AUTH"/*.auth.json(N:t:r:r))

  (( CURRENT == 2 )) || return
  _describe -t commands 'command' commands
  compadd -P @ -a accounts
}

(( $+functions[compdef] )) && compdef _cx_complete cx
