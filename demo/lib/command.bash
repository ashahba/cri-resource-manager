# Hooks for displaying and logging how shell commands (local and
# remote) are executed, and handling their output and exit status.
#
# Example in a Bash script, run-on-mytargethost function:
#   command-start mytargethost "ls -la"
#   ssh mytargethost $COMMAND 2>&1 | command-handle-output
#   command-end ${PIPESTATUS[0]}
#   [ "$COMMAND_STATUS" == "0" ] || command-error "non-zero exit status"
#
# command-start and command-end set environment variables:
# COMMAND, COMMAND_STATUS, COMMAND_OUTPUT
COMMAND_COUNTER=0
command_init_time=$EPOCHREALTIME

command-start() {
    # example: command-start vm prompt "mkdir $MYDIR"
    COMMAND_TARGET="$1"
    COMMAND_PROMPT="$2"
    COMMAND="$3"
    COMMAND_STATUS=""
    COMMAND_OUTPUT=""
    COMMAND_COUNTER=$(( COMMAND_COUNTER + 1 ))
    local command_start_time=$EPOCHREALTIME
    local time_since_start=$(echo "$command_start_time - $command_init_time" | bc)
    COMMAND_OUT_FILE="$COMMAND_OUTPUT_DIR/$(printf %04g $COMMAND_COUNTER)-$COMMAND_TARGET"
    echo "# start time: $time_since_start" > "$COMMAND_OUT_FILE" || {
        echo "cannot write command output to file \"$COMMAND_OUT_FILE\""
        exit 1
    }
    echo "# command: $COMMAND" >> "$COMMAND_OUT_FILE"
    echo -e -n "${COMMAND_PROMPT}"
    if [ -n "$PV" ]; then
        echo "$COMMAND" | $PV $speed
    else
        echo "$COMMAND"
    fi
    if [ -n "$outcolor" ]; then
        COMMAND_OUTSTART="\e[38;5;${outcolor}m"
        COMMAND_OUTEND="\e[0m"
    else
        COMMAND_OUTSTART=""
        COMMAND_OUTEND=""
    fi
}

command-handle-output() {
    # example: sh -c $command | command-handle-output
    tee "$COMMAND_OUT_FILE.tmp" | ( echo -e -n "$COMMAND_OUTSTART"; cat; echo -e -n "$COMMAND_OUTEND" )
    cat "$COMMAND_OUT_FILE.tmp" >> "$COMMAND_OUT_FILE"
    if [ -n "$PV" ]; then
        echo | $PV $speed
    fi
}

command-runs-in-bg() {
    echo "(runs in background)"
    echo ""
}

command-end() {
    # example: command-end EXIT_STATUS
    COMMAND_STATUS=$1
    local command_end_time=$EPOCHREALTIME
    local time_since_start=$(echo "$command_end_time - $command_init_time" | bc)
    ( echo "# exit status: $COMMAND_STATUS"; echo "# end time: $time_since_start" ) >> "$COMMAND_OUT_FILE"
    COMMAND_OUTPUT=$(<"$COMMAND_OUT_FILE.tmp")
    rm -f "$COMMAND_OUT_FILE.tmp"
}

command-error() {
    # example: command-error "creating directory failed"
    ( echo "command:     $COMMAND";
      echo "output:      $COMMAND_OUTPUT";
      echo "exit status: $COMMAND_STATUS";
      echo "error:       $1" ) >&2
    exit 1
}
