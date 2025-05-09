#!/usr/bin/env bash
##############################################################################
# tmux_log.sh
#   Interactive helper to start/stop pane logging for any tmux session.
#   ────────────────────────────────────────────────────────────────────────
#   • Lists sessions with an index (0,1,2…). Sessions that are already
#     being logged are marked [LOGGING].
#   • User input:
#       <n>   : start logging for session n
#       -<n>  : stop logging for session n
#       a     : stop logging for *all* sessions
#       q     : quit without changes
#   • Log file pattern:
#       log-tmux-<sessionStart>_trackStart_<loggingStart>.log
##############################################################################

LOGDIR="${LOGDIR:-$HOME/logs/tmux}"   # directory where logs are stored
mkdir -p "$LOGDIR"

# ---------------------------------------------------------------------------
list_sessions() {
  local idx=0
  tmux list-sessions -F '#{session_name}' | while read -r sname; do
    local created pipeline_flag
    created=$(tmux display-message -p -t "$sname" '#{session_created:%F %T}')
    pipeline_flag=$(tmux list-panes -t "$sname" -F '#{pane_pipe}' | grep -qv '^$' && echo "[LOGGING]" || echo "")
    printf "[%d] %-20s %s %s\n" "$idx" "$sname" "$created" "$pipeline_flag"
    idx=$((idx+1))
  done
}

# ---------------------------------------------------------------------------
start_logging() {
  local session="$1"

  # Convert epoch to formatted timestamp
  local epoch start_ts now logfile
  epoch=$(tmux display-message -p -t "$session" '#{session_created}')
  start_ts=$(date -d @"$epoch" +%Y%m%d_%H%M%S)
  now=$(date +%Y%m%d_%H%M%S)
  logfile="$LOGDIR/log-tmux-${start_ts}_trackStart_${now}.log"

  echo "▶ Logging '$session' → $logfile"
  tmux list-panes -t "$session" -F '#{pane_id}' | while read -r pane; do
    tmux pipe-pane -o -t "$pane" "cat >> '$logfile'"
  done
}

# ---------------------------------------------------------------------------
stop_logging() {
  local session="$1"
  echo "▶ Stopping logging for '$session'"
  tmux list-panes -t "$session" -F '#{pane_id}' | while read -r pane; do
    tmux pipe-pane -t "$pane" ''
  done
}

# ---------------------------------------------------------------------------
stop_logging_all() {
  echo "▶ Stopping logging for ALL sessions"
  tmux list-panes -a -F '#{pane_id}' | while read -r pane; do
    tmux pipe-pane -t "$pane" ''
  done
}

# ---------------------------------------------------------------------------
main() {
  if ! tmux ls &>/dev/null; then
    echo "❌ No tmux server running."
    exit 1
  fi

  echo "=== tmux log helper ==="
  list_sessions
  echo
  echo "number : log start | -number : log stop"
  echo "a    : stop all log | q     : exit"
  read -rp "> " choice

  case "$choice" in
    q) exit 0 ;;
    a) stop_logging_all ; exit 0 ;;
    -[0-9]*)
        idx=${choice#-}
        session=$(tmux list-sessions -F '#{session_name}' | sed -n "$((idx+1))p")
        [[ -z $session ]] && { echo "INVALID NUMBER"; exit 1; }
        stop_logging "$session"
        ;;
    [0-9]*)
        idx=$choice
        session=$(tmux list-sessions -F '#{session_name}' | sed -n "$((idx+1))p")
        [[ -z $session ]] && { echo "INVALID NUMBER"; exit 1; }
        start_logging "$session"
        ;;
    *) echo "INVALID INPUT!"; exit 1 ;;
  esac
}

main "$@"
