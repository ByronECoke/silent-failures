# Silent failures

Checks for the failures that do not announce themselves.

A job that exits zero while achieving nothing is the most common shape of outage
I see. Nothing alerts, every dashboard is green, and you find out weeks later.
The fix is always the same in principle: stop checking whether the process ran,
and check whether the thing it was supposed to produce actually exists and is
recent.

Each directory here is one check, with the incident that produced it.

| Check | Asks | Written up |
|---|---|---|
| [`artefact-age`](artefact-age/) | Is the newest backup actually new? | [Twenty-seven days with no backup](https://paxmentis.com/f) |
| [`cert-expiry`](cert-expiry/) | Does the certificate the world sees expire soon? | |

Plain POSIX shell, no dependencies beyond coreutils and openssl. Every check
exits 0 when healthy, 1 when it is not, and 2 on bad usage, so they drop into
cron, a monitoring agent, or a CI step without wrapping.

## Why these exist

I run a self-hosted estate: Docker, Caddy, Postgres, Redis, n8n in queue mode,
mail. Twice now something has been quietly broken for weeks while every
indicator I had said it was fine. Once it was a mail server with 534,686
delivery attempts and zero messages delivered. Once it was a backup job that had
produced nothing since 15 August and told nobody.

Neither was a hard problem. Both were invisible because I was monitoring the
wrong thing.

## Using them

    ./artefact-age/check-artefact-age.sh /srv/backups 26 '*.sql.gz'
    ./cert-expiry/check-cert-expiry.sh 21 example.com mail.example.com

Thresholds are arguments rather than configuration on purpose. A check you have
to configure is a check you will not deploy.

## Licence

MIT. Take them, change them, no attribution needed.

Byron Coke, [paxmentis.com/f](https://paxmentis.com/f)
