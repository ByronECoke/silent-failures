# cert-expiry

Fails if a live certificate expires within N days.

    check-cert-expiry.sh <min-days-left> <host> [host...]
    check-cert-expiry.sh 21 example.com mail.example.com

## Why not just check the renewal job

Because the renewal job reports on itself. It tells you it ran. It does not tell
you that the certificate being served on port 443 was replaced, and those come
apart more often than you would expect: a reload that never happened, a renewed
certificate written to a path nothing reads, a service holding the old one in
memory.

This opens a TLS connection and reads the expiry off the certificate actually
presented. It is the only answer that reflects what a visitor gets.

## Behaviour

Checks every host given and reports on all of them before exiting, so one bad
host does not hide the rest. Exits 1 if any host is inside the threshold **or
if the certificate cannot be read at all**, because an unreachable endpoint is
not a pass. Connection attempts time out after ten seconds.

With certificate lifetimes dropping to 47 days from 2029, the margin between
"renewal is late" and "the site is down" gets thinner. Worth checking the
outcome rather than the intent.
