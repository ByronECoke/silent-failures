# artefact-age

Fails if the newest file matching a pattern is older than a threshold.

    check-artefact-age.sh <dir> <max-age-hours> [glob]
    check-artefact-age.sh /srv/backups 26 '*.sql.gz'

## The incident

A backup job ran every night for four weeks and produced nothing. It exited
zero every time. The container it was meant to dump had been renamed, so the
dump command failed inside a pipeline whose exit status came from the last
command, `gzip`, which succeeded at compressing an empty stream.

Twenty-seven days later I found it by accident. Nothing was lost, and that was
timing rather than design: the sixty-day prune had not yet reached the last good
snapshot. Four more weeks and it is a different story.

## What it checks

The age of the newest matching file, and nothing else. It deliberately does not
look at exit codes, log lines, or whether a service is running.

Two cases matter and both exit 1:

- the newest file is older than the threshold
- **there is no matching file at all**

The second is the one people forget. An empty directory is not a pass.

## Notes

Uses `find -printf '%T@ %p\0'` and sorts on the null-delimited stream, so
filenames containing spaces or newlines cannot split a record. Takes the
threshold in whole hours; give it a little more than your job interval so a
single slow run does not page you.
