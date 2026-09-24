# Contact Orbit 🪐

## Verified Contact Email Routing for Salesforce

[![Salesforce API 67.0](https://img.shields.io/badge/Salesforce-API%2067.0-032D60?logo=salesforce&logoColor=white)](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_intro.htm)
[![LWC Jest](https://img.shields.io/badge/LWC%20Jest-passing-2ea44f?logo=jest&logoColor=white)](https://github.com/salesforce/sfdx-lwc-jest)
[![Code Analyzer](https://img.shields.io/badge/Code%20Analyzer-0%20High%2FCritical-2ea44f)](https://developer.salesforce.com/docs/platform/salesforce-code-analyzer/overview)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

Give one Salesforce Contact the right email identity for every context—work, billing, support, personal, or a subscriber-defined purpose—without turning an email address into a security credential.

Contact Orbit is an open-source Salesforce DX package built around the [IdeaExchange request for multiple email addresses on a Contact](https://ideas.salesforce.com/s/idea/a0B8W00000Gde7FUAR/multiple-email-addresses-for-a-contact). It adds a verified identity layer, a subscriber-visible Flow resolver, and a conservative Email-to-Case suggestion pipeline.

> **Status:** source-validated and beta-ready; managed namespace and clean subscriber installation remain release gates.

## The short version

```text
Contact_Email__c
       │  purpose + verification + primary scope
       ▼
Global Flow/Apex resolver ───────► deterministic email identity
       │
       └─ Email-to-Case signal ──► suggestion ──► human confirmation
```

The safe default is always the same: unverified identities do not route, suggestions do not change a Case, auto-linking is off, and sender email never grants access.

## What ships in v1

| Capability | What it does |
|---|---|
| Purpose-specific identities | Stores multiple active or inactive addresses per Contact using public custom metadata. |
| Verified routing | Requires audited administrator attestation before an identity participates in resolution. |
| Global resolver | `CEI_ContactEmailService` is Flow-visible and Apex-reusable, with deterministic ordering and explicit `Contact.Email` fallback. |
| Primary integrity | Enforces one active primary per Contact and purpose using Contact locking, validation, and a unique derived key. |
| Email-to-Case suggestions | Matches only active, verified identities and records a sender-address-free audit row. |
| Human confirmation | Case users can confirm or reject a suggestion after a fresh verification and access check. |
| Retention operations | Schedulable batch removes terminal match records after a bounded 30–730 day retention period. |
| Setup and permissions | Setup preflight reports Case/Contact access without packaging broad standard-object permissions. |

## Why it is safe to reuse

The package exposes stable contracts rather than asking subscriber code to reach into implementation details:

- Global `ResolveRequest` and `ResolveResult` DTOs for Flow and Apex.
- `resolveOne()` for single-request Apex integrations and `resolve()` for bulk Flow inputs.
- `isPurposeActive()` for subscriber-created purpose validation.
- `CEI_ContactEmailContract` constants for source, outcome, verification, and match-status vocabulary.
- `Contact_Email_Purpose__mdt` for subscriber-extensible routing categories.

The triggers stay thin. `CEI_TriggerDispatcher` owns action partitioning and `CEI_TriggerRuntime` prevents re-entry without exposing a user-facing bypass. The package intentionally does not load arbitrary subscriber class names at runtime; trust-sensitive routing must remain deterministic across managed upgrades.

## Bulkification and governor-limit posture

Contact Orbit follows Salesforce’s bulk Apex guidance: collect IDs, query outside loops, perform collection DML, and keep trigger work bounded. See Salesforce’s guidance on [bulk Apex](https://developer.salesforce.com/blogs/2014/08/understanding-bulk-salesforce1-platform) and [SOQL/DML governor limits](https://developer.salesforce.com/blogs/2022/08/working-with-salesforce-records-using-soql-and-dml).

- Contact identity before-save logic uses set-based Contact locking and one existing-primary query for the entire trigger batch.
- The resolver uses one Contact query and one identity query for a 200-request input, then returns results in the original order without DML.
- Email-to-Case groups messages by Case, performs one identity lookup, one audit insert, one grouped Case update, and one grouped audit-status update.
- Idempotency is keyed by source EmailMessage ID, so retries do not create duplicate audit rows.
- Retention runs in Batch Apex with an explicit scope size of 200.
- UI reads are bounded to 200 identities or actionable suggestions per view; terminal history is handled by retention.
- Regression tests exercise 200 resolver requests and 200 EmailMessages while asserting fixed query/DML budgets.

## Security model

Sender email is an identity signal, not cryptographic authentication. A suggestion or auto-link must never grant customer access or authorize a sensitive action.

- User-facing queries and DML use `WITH USER_MODE` or `AccessLevel.USER_MODE`.
- The EmailMessage automation has one documented, narrow system-mode lookup that reads only fields needed to match verified identities.
- Verification is an audited administrator attestation with actor, timestamp, and method.
- Email or Contact changes reset verification automatically.
- Raw sender addresses are not stored in routing logs.
- Verification fields are read-only outside the bounded attestation service.
- No broad Case or Contact permissions are packaged.

Assign one packaged permission set per responsibility:

| Permission set | Intended use |
|---|---|
| **Contact Orbit User** | Manage non-verification identity fields and review/confirm suggestions when standard Case access already exists. |
| **Contact Orbit Verifier** | User permissions plus audited Verify/Revoke permission. |
| **Contact Orbit Administrator** | Custom-object administration, settings, retention scheduling, and controlled deletion. |

## Product boundary

| IdeaExchange need | v1 status |
|---|---|
| Multiple purpose-specific addresses on one Contact | **Supported** — sidecar identity object |
| Identify Email-to-Case from an alternate address | **Supported** — verified identities, suggestion-first |
| Avoid duplicate Contacts | **Partial** — no merge or deduplication engine |
| Relationship/account-specific routing | **Not supported** — Contact-only v1 |
| Native composer or outbound address selection | **Not supported** |
| Einstein Activity Capture / Sales Engagement | **Not supported** |
| Account Engagement / prospect identity | **Not supported** |
| Person Account UI | **Not supported** |

## Developer quick start

This is a Salesforce DX source project. The repository deliberately has no real Dev Hub alias, org ID, session material, namespace, or installation key.

```sh
npm install
npm test

sf project deploy start --source-dir force-app --target-org YOUR_ORG \
  --test-level RunLocalTests --wait 30

sf apex run test --test-level RunLocalTests --target-org YOUR_ORG \
  --wait 30 --code-coverage

sf code-analyzer run --workspace . --target force-app \
  --rule-selector Recommended --rule-selector AppExchange \
  --severity-threshold 2 --output-file reports/code-analyzer.sarif
```

Current connected validation: **29/29 Apex tests passing**, **91.7% Contact Orbit Apex coverage**, **100% coverage on both package triggers**, **2/2 LWC Jest tests passing**, and **zero High/Critical Code Analyzer findings**.

## Documentation

- [Architecture review](docs/architecture-review.md)
- [Managed-package setup](docs/managed-package-setup.md)
- [Managed-package release TODO](TODO.md)
- [Opportunity and IdeaExchange research](OPPORTUNITY.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

## Contributing and reporting

Keep changes Contact-focused, preserve the v1 boundary, add scoped Apex/LWC tests, and never commit credentials, customer data, or generated Salesforce state. Please use the private advisory path in [SECURITY.md](SECURITY.md) for vulnerabilities rather than opening a public issue.

## License

Apache License 2.0. See [LICENSE](LICENSE).
