# job-completed

Fails unless a completion marker appears in a log, dated within a threshold.

    check-job-completed.sh <logfile> <marker> [max_age_hours]
    check-job-completed.sh /var/log/vps-backup.log '==> Done:' 26

## The incident

A nightly backup uploaded a database dump offsite, and for thirty-five days it
did not. The script is `set -euo pipefail`. Its upload order was:

1. encrypted secrets
2. some Docker volumes
3. the database

The secrets upload started returning `InvalidAccessKeyId`. Under `set -e` that
killed the run before the database was ever uploaded. The least valuable
artefact in the job was positioned to destroy the most valuable one.

Everything a person would look at stayed reassuring. The local dump directory
had files dated that morning, because the dump happens before the upload. The
log was full of progress lines. The only evidence was the absence of the last
line, `==> Done:`, and nothing was looking for it.

Across 188 runs, 143 completed and 45 did not. Nobody was told, once.

## What it checks

That the marker is present, and that the timestamp it carries is recent. Not
that the process ran, not its exit code, not the age of the files it left
behind — a half-finished job leaves fresh files from the steps that did work.

Exits 1 on all of:

- the marker is present but too old
- **the marker never appears at all**
- the log is missing, unreadable, or not a regular file
- the newest marker is dated in the future

The last one sounds pedantic. A clock skewed forward reads as "very fresh
indeed" and passes for as long as the skew lasts.

## Notes

Recognises `YYYYMMDD`, `YYYYMMDD-HHMMSS` and `YYYY-MM-DD HH:MM:SS`. If the
marker carries no date it falls back to the log's mtime and says so in the
output, because an undated marker in an append-only log is weaker evidence and
the check should not pretend otherwise.

The marker is matched with `grep -F`, so `==> Done:` and `[ok]` match literally
instead of being read as patterns.

Dates are extracted with `grep -o` rather than a `sed` backreference. A leading
`.*` is greedy: it walks past the start of the date and captures a window
shifted right by a digit or two. `20260927-030001` came back as `0927030001`,
which then failed to parse and reported a corrupt log — a broken check
complaining about healthy input. The test that caught it was the one asserting
a *future* date is rejected: it passed, but because parsing failed rather than
because the future was detected. A test that passes for the wrong reason is
worth as little as no test.
