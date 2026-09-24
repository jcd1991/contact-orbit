# Contact Orbit — Verified Contact Email Routing

Contact Orbit is a focused Salesforce package for the long-standing IdeaExchange request [Multiple email addresses for a contact](https://ideas.salesforce.com/s/idea/a0B8W00000Gde7FUAR/multiple-email-addresses-for-a-contact). The idea page currently shows 31,630 points and 3,191 votes. Contact Orbit addresses the packageable core: purpose-specific Contact identities, a verified Flow resolver, and safe Email-to-Case suggestions.

## v1 contract

- Store multiple active or inactive addresses per Contact, using public subscriber-extensible purpose metadata.
- Require a purpose key for Flow resolution. A resolver request returns one deterministic result in request order and never returns an address the running user cannot access.
- Resolve only active, verified identities. `Contact.Email` is used only when a Flow request explicitly enables fallback.
- Require an audited administrator attestation before an identity participates in routing. Email changes and Contact moves automatically reset verification.
- Enforce one active primary per Contact and purpose with Contact row locking plus a unique derived scope key.
- Keep Email-to-Case off by default. Suggestion mode writes a sender-address-free audit record; verified auto-linking is a separate explicit opt-in.
- Confirming a suggestion rechecks verification, locks the Case, respects Case sharing/FLS, and supersedes conflicting suggestions.

Sender email is an identity signal, not cryptographic authentication. A suggestion or auto-link must never grant customer access or authorize a sensitive action.

## Support matrix

| IdeaExchange need | v1 status | Boundary |
|---|---|---|
| Multiple purpose-specific addresses on one Contact | Supported | `Contact_Email__c` sidecar identities |
| Identify Email-to-Case from an alternate address | Supported | Verified identities only; suggestion-first |
| Avoid duplicate Contacts | Partial | Routing does not deduplicate or merge Contacts |
| Relationship/account-specific routing | Not supported | Contact-only v1 |
| Native email composer / outbound address choice | Not supported | No composer replacement |
| Einstein Activity Capture or Sales Engagement | Not supported | No activity integration |
| Account Engagement / prospect identity | Not supported | No marketing identity integration |
| Person Account UI | Not supported | Contact UI only in v1 |

## Permission and operations model

Assign one of the packaged permission sets:

- **Contact Orbit User** — manage non-verification identity fields, read suggestions, and confirm/reject when the user already has standard Case edit access.
- **Contact Orbit Verifier** — User permissions plus `Verify Contact Email Identity` for audited Verify/Revoke actions.
- **Contact Orbit Administrator** — custom-object administration, settings, retention scheduling, and deletion. Standard Case and Contact permissions are deliberately not granted broadly.

The setup component reports the current routing mode, retention range, and Case/Contact preflight. Email-to-Case remains disabled after install until an administrator enables Suggestions. Verified auto-link is ignored unless Suggestions is enabled. Retention is clamped to 30–730 days and is scheduled explicitly from setup; installation does not create a recurring job automatically.

## Validation

```sh
sf project deploy start --source-dir force-app --target-org YOUR_ORG \
  --test-level RunLocalTests --wait 30
sf apex run test --test-level RunLocalTests --target-org YOUR_ORG --wait 30
PATH=/opt/homebrew/bin:/usr/bin:$PATH sf code-analyzer run \
  --rule-selector Recommended --rule-selector AppExchange \
  --severity-threshold 2 --output-file reports/code-analyzer.sarif
npm install
npm test
```

The connected validation run completed with 26 passing Apex tests (26/26), including an unauthorized-user permission check, with 91.4% coverage across the Contact Orbit Apex classes and 100% coverage on both triggers. Code Analyzer v5 completed with no High or Critical findings; remaining findings are Moderate/Low hygiene items and are retained in SARIF for CI review. A clean subscriber install, namespaced Flow discovery, FLS/sharing matrix, and managed upgrade remain release gates.

## Managed 2GP gate

The package display name is **Contact Orbit** and the intended namespace is **ContactOrbit**, subject to Salesforce namespace availability. This repository intentionally contains no Dev Hub alias, org ID, installation key, or real authentication material. Set the namespace only after a separate Developer Edition namespace org has been linked to the Dev Hub; the exact commands and irreversible promotion gates are in [docs/managed-package-setup.md](docs/managed-package-setup.md).

Do not promote a beta version until a clean subscriber scratch org verifies the namespaced Apex Actions REST resource, Flow discovery, permission sets, UI smoke path, uninstall/reinstall behavior, package coverage of at least 75%, every-trigger coverage, and no unresolved routing failures. The first true upgrade test begins after a released baseline because Salesforce beta versions cannot be upgraded.

## Security and support

See [SECURITY.md](SECURITY.md) for the private vulnerability-reporting path, and [CONTRIBUTING.md](CONTRIBUTING.md) for source and scratch-org checks. The package intentionally excludes native composer replacement, Contact deduplication, Einstein Activity Capture, Account Engagement, Person Account UI, and relationship-specific routing from v1.

## License

Apache License 2.0. See [LICENSE](LICENSE).
