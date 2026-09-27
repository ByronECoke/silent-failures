#!/usr/bin/env bash
# Fail if the NEWEST file matching a pattern is older than a threshold.
#
# The point: a backup job that exits 0 while writing nothing looks identical to
# a healthy one. Exit status tells you the job ran. It does not tell you the job
# achieved anything. Check the artefact, not the process.
#
#   check-artefact-age.sh /srv/backups 26 '*.sql.gz'
#
# Exit 0 fresh · 1 stale or missing · 2 bad usage.
set -euo pipefail

die() { printf '%s\n' "$*" >&2; exit 2; }
[ $# -ge 2 ] || die "usage: $(basename "$0") <dir> <max-age-hours> [glob]"

dir=$1; max_hours=$2; glob=${3:-*}
[ -d "$dir" ] || die "not a directory: $dir"
case $max_hours in ''|*[!0-9]*) die "max-age-hours must be a whole number" ;; esac

# -print0 so filenames with spaces or newlines cannot split a record.
# NOT `| head -zn1`: head closes the pipe, sort takes SIGPIPE, and under
# `set -o pipefail` the whole script dies with 141 and prints NOTHING. That is
# silent failure, which is the exact thing this script exists to catch. Read the
# first record instead, so nothing closes the pipe early.
newest=$(find "$dir" -type f -name "$glob" -printf '%T@ %p\0' 2>/dev/null \
         | sort -zrn | { IFS= read -r -d '' first || true; printf '%s' "$first"; })

if [ -z "$newest" ]; then
  # No artefact at all is the case people forget to alert on. It is not "fine".
  printf 'CRITICAL  no file matching %s under %s\n' "$glob" "$dir"
  exit 1
fi

epoch=${newest%% *}; path=${newest#* }
age=$(( ( $(date +%s) - ${epoch%.*} ) / 60 ))
limit=$(( max_hours * 60 ))

if [ "$age" -gt "$limit" ]; then
  printf 'CRITICAL  newest is %dh%02dm old (limit %dh): %s\n' \
    $((age/60)) $((age%60)) "$max_hours" "$path"
  exit 1
fi
printf 'OK        newest is %dh%02dm old (limit %dh): %s\n' \
  $((age/60)) $((age%60)) "$max_hours" "$path"
