#!/usr/bin/env bash
# Fail if a live TLS certificate expires within N days.
#
# The point: the same lesson as artefact-age, one layer up. Your renewal job
# reports success. That says the job ran, not that the certificate the world
# actually sees was replaced. Ask the socket, not the scheduler.
#
#   check-cert-expiry.sh 21 paxmentis.com n8n.byroncoke.com
#
# Exit 0 all fine · 1 one or more expiring or unreachable · 2 bad usage.
set -uo pipefail

die() { printf '%s\n' "$*" >&2; exit 2; }
[ $# -ge 2 ] || die "usage: $(basename "$0") <min-days-left> <host> [host...]"
command -v openssl >/dev/null || die "openssl not found"

min_days=$1; shift
case $min_days in ''|*[!0-9]*) die "min-days-left must be a whole number" ;; esac

rc=0
for host in "$@"; do
  end=$(echo | timeout 10 openssl s_client -servername "$host" -connect "$host:443" 2>/dev/null \
        | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
  if [ -z "$end" ]; then
    printf 'CRITICAL  %-28s could not read a certificate\n' "$host"; rc=1; continue
  fi
  left=$(( ( $(date -d "$end" +%s) - $(date +%s) ) / 86400 ))
  if [ "$left" -lt "$min_days" ]; then
    printf 'CRITICAL  %-28s %d days left (want %d+)\n' "$host" "$left" "$min_days"; rc=1
  else
    printf 'OK        %-28s %d days left\n' "$host" "$left"
  fi
done
exit $rc
