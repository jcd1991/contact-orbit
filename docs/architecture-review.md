# Contact Orbit architecture review

This review records the final design decisions against the [Trigger Actions Framework](https://github.com/mitchspano/trigger-actions-framework) and the [Salesforce Well-Architected Framework](https://architect.salesforce.com/docs/architect/well-architected/guide/framework.html).

## Trigger architecture

Contact Orbit uses a small package-owned dispatcher rather than taking a runtime dependency on a trigger framework. `CEI_ContactEmailTrigger` and `CEI_EmailMessageTrigger` are deliberately thin; `CEI_TriggerDispatcher` partitions the before-save and after-insert actions, and `CEI_TriggerRuntime` prevents re-entry with a transaction-scoped action key and `try/finally` cleanup.

| Pattern | Implementation | Why it is safe for a managed package |
|---|---|---|
| One trigger entry point | One trigger per package-owned object | No subscriber trigger ordering assumptions |
| Explicit action partitioning | Dispatcher methods for Contact Email and EmailMessage | Business logic remains testable and reusable outside trigger context |
| Recursion protection | Runtime guard keyed by object and phase | Prevents duplicate work without a user-facing bypass |
| Bulk discipline | Set/map collection, one identity query, one audit write, grouped Case updates | Supports 200-record batches and bounded governor usage |
| Bypass control | No ordinary-user bypass; attestation is permission-gated and automation uses a narrow documented system boundary | Trust-sensitive routing cannot be silently disabled |
| Extensibility | Public resolver DTOs, stable contract constants, and subscriber-extensible purpose metadata | Subscribers extend data and orchestration without dynamic Apex injection |

The package does not implement arbitrary subscriber action discovery or dynamic class names. That is an intentional boundary: trigger order, verification resets, primary uniqueness, and Email-to-Case fail-closed behavior are security-sensitive and must remain deterministic across managed upgrades.

## Well-Architected review

| Pillar | Evidence in this package | Remaining subscriber gate |
|---|---|---|
| Trust | `WITH USER_MODE`, `AccessLevel.USER_MODE`, explicit custom permissions, read-only verification fields, sender-address-free audit records, sanitized errors, no secrets in source | Validate the subscriber FLS/sharing matrix and configure a private vulnerability-reporting destination before publication |
| Reliability | Contact row locks plus unique primary scope, deterministic resolver ordering, idempotent EmailMessage source IDs, grouped same-Case decisions, failed `SaveResult` auditing, retention bounds | Run a clean namespaced install and 200-record routing test in a disposable subscriber org |
| Operational excellence | Setup preflight, explicit retention scheduling, migration counts/IDs only, CI JSON/XML/Jest/Code Analyzer gates, package runbook, stable global resolver contract | Activate the setup page/tab in the subscriber app and collect operational telemetry appropriate to the org |
| Resource and cost optimization | Bulk queries and DML, no raw sender persistence, terminal-row retention, sidecar identity model, no broad standard-object permissions | Confirm production Email-to-Case volume and schedule retention during a low-impact window |
| Fairness and accessibility | Standard Lightning base components, SLDS utility classes and design tokens, responsive layouts, keyboard-capable buttons, labelled dialogs, readable status pills, human confirmation for routing | Run axe/WCAG checks in the subscriber's theme and verify component placement on Case and Contact layouts |

## Reusable contracts

`CEI_ContactEmailService.ResolveRequest` and `ResolveResult` are immutable-by-convention global Flow/Apex DTOs. `resolve` preserves request order; `resolveOne` is a convenience for Apex integrations; `isPurposeActive` lets an integration validate a packaged or subscriber-created purpose. `CEI_ContactEmailContract` exposes stable source, outcome, verification, and match-status vocabulary without requiring subscribers to copy string literals.

The supported extension surface is intentionally data- and contract-oriented:

1. Add purpose metadata for subscriber-specific routing categories.
2. Call the global resolver from Flow or Apex.
3. Consume the match audit object and Case-page component for human confirmation.
4. Use the permission sets and setup preflight to fit the package into an org's existing Case/Contact access model.

Arbitrary outbound composer replacement, Contact merging, Person Account UI, relationship-specific routing, EAC, and Account Engagement remain outside v1.

## Release conclusion

The source package is architecturally ready for a managed beta once the namespace is available. Promotion still depends on the clean subscriber install, namespaced Flow discovery, FLS/sharing matrix, UI activation/smoke test, uninstall/reinstall check, and a separate released-baseline upgrade test.
