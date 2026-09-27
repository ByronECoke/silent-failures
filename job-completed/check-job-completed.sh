#!/bin/sh
# check-job-completed.sh — did the job actually FINISH, not just start?
#
# A job that dies two thirds of the way through leaves a log full of
# encouraging progress lines and a directory full of yesterday's artefacts.
# Nothing is missing, nothing is empty, nothing exits non-zero anywhere you
# look. The only evidence is the absence of the last line.
#
# This asserts that a completion marker appears in a log, carrying a timestamp
# no older than a threshold. It is deliberately stricter than checking a file's
# age: the file can be fresh because an earlier step wrote it before a later
# step failed.
#
# Usage: check-job-completed.sh <logfile> <marker> [max_age_hours]
#        max_age_hours defaults to 26 (a daily job, plus slack)
#
# Exit: 0 healthy, 1 unhealthy, 2 bad usage.

set -eu

PROG=${0##*/}

usage() {
	printf '%s: usage: %s <logfile> <marker> [max_age_hours]\n' "$PROG" "$PROG" >&2
	printf '  e.g. %s /var/log/vps-backup.log "==> Done:" 26\n' "$PROG" >&2
	exit 2
}

[ $# -ge 2 ] && [ $# -le 3 ] || usage

log=$1
marker=$2
max_age_hours=${3:-26}

case $max_age_hours in
	'' | *[!0-9]*) printf '%s: max_age_hours must be a whole number, got: %s\n' \
		"$PROG" "$max_age_hours" >&2; exit 2 ;;
esac
[ "$max_age_hours" -gt 0 ] || { printf '%s: max_age_hours must be > 0\n' "$PROG" >&2; exit 2; }
[ -n "$marker" ] || { printf '%s: marker must not be empty\n' "$PROG" >&2; exit 2; }

# A missing or unreadable log is a failure, never a pass. A check that cannot
# see is not a check that agrees with you.
[ -e "$log" ] || { printf 'CRITICAL %s: log does not exist\n' "$log"; exit 1; }
[ -f "$log" ] || { printf 'CRITICAL %s: not a regular file\n' "$log"; exit 1; }
[ -r "$log" ] || { printf 'CRITICAL %s: not readable (running as %s)\n' "$log" "$(id -un)"; exit 1; }

# Fixed-string, so a marker containing regex metacharacters ("==> Done:", "[ok]")
# matches literally rather than silently matching nothing.
matches=$(grep -F -- "$marker" "$log" || true)

if [ -z "$matches" ]; then
	printf 'CRITICAL %s: marker never appears: %s\n' "$log" "$marker"
	exit 1
fi

# Pull the newest YYYYMMDD[-HHMMSS] or YYYY-MM-DD[ HH:MM:SS] out of the matching
# lines. Sorting the normalised digits is safe: fixed-width, zero-padded, and
# lexical order equals chronological order.
#
# grep -o, not a sed backreference: a leading `.*` is greedy, so it walks past
# the start of the date and captures a window shifted a digit or two to the
# right. "20260927-030001" came back as "0927030001" and then failed to parse,
# which read as a corrupt log rather than a broken check.
stamp=$(printf '%s\n' "$matches" \
	| grep -oE '[0-9]{4}-?[0-9]{2}-?[0-9]{2}([-T ][0-9]{2}:?[0-9]{2}:?[0-9]{2})?' \
	| tr -cd '0-9\n' \
	| awk 'length($0) == 8 || length($0) == 14 { while (length($0) < 14) $0 = $0 "0"; print }' \
	| sort | tail -1)

if [ -z "$stamp" ]; then
	# The marker is present but carries no date. Fall back to the log's own
	# mtime, and say so — an unlabelled marker in an append-only log is weak
	# evidence, and the output must not pretend otherwise.
	now=$(date +%s)
	mtime=$(date -r "$log" +%s 2>/dev/null || stat -c %Y "$log" 2>/dev/null || echo '')
	[ -n "$mtime" ] || { printf 'CRITICAL %s: marker has no timestamp and mtime unreadable\n' "$log"; exit 1; }
	age_h=$(( (now - mtime) / 3600 ))
	if [ "$age_h" -gt "$max_age_hours" ]; then
		printf 'CRITICAL %s: marker present but undated; log last written %dh ago (limit %dh)\n' \
			"$log" "$age_h" "$max_age_hours"
		exit 1
	fi
	printf 'OK %s: marker present but undated; log written %dh ago (limit %dh)\n' \
		"$log" "$age_h" "$max_age_hours"
	exit 0
fi

# awk above emits only 14-digit stamps; anything else is a bug, not a date.
[ ${#stamp} -eq 14 ] || { printf 'CRITICAL %s: unusable timestamp %s\n' "$log" "$stamp"; exit 1; }

y=$(printf '%s' "$stamp" | cut -c1-4)
mo=$(printf '%s' "$stamp" | cut -c5-6)
d=$(printf '%s' "$stamp" | cut -c7-8)
h=$(printf '%s' "$stamp" | cut -c9-10)
mi=$(printf '%s' "$stamp" | cut -c11-12)
s=$(printf '%s' "$stamp" | cut -c13-14)

when=$(date -d "$y-$mo-$d $h:$mi:$s" +%s 2>/dev/null \
	|| date -j -f '%Y-%m-%d %H:%M:%S' "$y-$mo-$d $h:$mi:$s" +%s 2>/dev/null \
	|| echo '')
[ -n "$when" ] || { printf 'CRITICAL %s: could not parse timestamp %s\n' "$log" "$stamp"; exit 1; }

now=$(date +%s)
age_h=$(( (now - when) / 3600 ))
age_m=$(( ((now - when) / 60) % 60 ))
human="$y-$mo-$d $h:$mi:$s"

# A marker dated in the future means a clock or timezone problem, and it would
# otherwise read as "very fresh indeed" and pass forever.
if [ "$when" -gt "$((now + 3600))" ]; then
	printf 'CRITICAL %s: last completion is in the future (%s) — check the clock\n' "$log" "$human"
	exit 1
fi

if [ "$age_h" -gt "$max_age_hours" ]; then
	printf 'CRITICAL %s: last completed %s (%dh%dm ago, limit %dh)\n' \
		"$log" "$human" "$age_h" "$age_m" "$max_age_hours"
	exit 1
fi

printf 'OK %s: last completed %s (%dh%dm ago, limit %dh)\n' \
	"$log" "$human" "$age_h" "$age_m" "$max_age_hours"
