# Security policy

## Supported versions

Only the latest committed version is supported while this MVP is being validated.

## Reporting a vulnerability

Please do not disclose suspected vulnerabilities in a public issue. Use the
repository's private GitHub Security Advisory form at
`https://github.com/jcd1991/contact-orbit/security/advisories/new`.
Include reproduction steps, affected metadata, and the smallest safe proof of
impact; maintainers will coordinate a fix and disclosure timeline privately.

Do not include credentials, access tokens, production data, or customer data in
a report. Rotate any credential that was exposed during reproduction.

## Product security boundary

Contact Orbit treats a sender address as an identity signal, not authentication.
Verification is an administrator attestation recorded with actor, time, and
method. Auto-linking does not grant customer access or authorize sensitive
actions. Report incorrect routing, verification bypass, permission escalation,
raw sender-address persistence, or retention failures through the private
advisory path above.
