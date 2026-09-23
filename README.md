# Contact Email Identity

Package-ready Salesforce source for managing multiple purpose-specific email addresses on a Contact without creating duplicate Contact records.

## Why this product

The IdeaExchange request **Multiple email addresses for a contact** has 31,630 points and 3,191 votes. Recent comments describe active Service Cloud, Email-to-Case, Person Account, nonprofit, billing, and relationship-specific routing needs. The idea remains open and Salesforce's latest visible update asks for more use cases rather than committing to a roadmap.

This MVP focuses on the portion a managed package can solve safely:

- Store many active or inactive addresses per Contact.
- Classify addresses by purpose: General, Work, Personal, Billing, Support, or Other.
- Enforce one active primary address per Contact and purpose.
- Resolve the appropriate address from Flow, with a fallback to `Contact.Email`.
- Optionally match an inbound Email-to-Case `EmailMessage.FromAddress` to one unambiguous alternate address and populate an empty `Case.ContactId`.
- Give users a Contact record-page component for adding, editing, and removing email identities.

The package does **not** claim to change closed Salesforce features such as Einstein Activity Capture association, Sales Engagement cadences, Account Engagement prospect identity, or the native Contact email data model.

## Safety boundaries

- Email-to-Case matching is off by default and requires the org-level `Contact Email Settings` hierarchy setting.
- Existing `Case.ContactId` values are never overwritten.
- Shared addresses that match more than one Contact are treated as ambiguous and ignored.
- Queries and updates use user-mode enforcement; automation users need the packaged permission set and Case access.
- The two user-facing email fields are optional at the metadata layer for UI API compatibility; the trigger service still enforces that Contact, email address, and purpose are present.
- Email normalization is intentionally conservative: trim and lowercase only. It does not alter dots or plus tags.

## Validate in a connected org

```sh
sf project deploy start --source-dir force-app --target-org YOUR_ORG \
  --test-level RunSpecifiedTests \
  --tests CEI_ContactEmailServiceTest \
  --tests CEI_EmailMessageHandlerTest \
  --wait 30
sf apex run test --tests CEI_ContactEmailServiceTest --tests CEI_EmailMessageHandlerTest \
  --target-org YOUR_ORG --code-coverage --wait 30
```

Assign `Contact Email Identity Admin`, add `Contact Email Manager` to the Contact Lightning record page, then enable the hierarchy setting only after the Email-to-Case automation user has access.

## Verified MVP status

- Validated in a Salesforce Developer Edition org on September 23, 2026.
- Source deployment completed with all 20 metadata components.
- All 7 scoped Apex tests passed.
- The service, handler, and both triggers reported full coverage; the controller's defensive permission guard and thin Aura wrapper are the only uncovered controller lines in the scoped deployment result.
- The Contact record page was verified in Chrome: the card renders cleanly, the add form is aligned, the success toast appears, and a newly-created row is readable in the table.
- `Contact_Email__c` and `Contact_Email_Settings__c` were read back from the validation org, and the packaged permission set was assigned to the validating user.

This proves the source deploys and behaves correctly in the connected validation org. It does not by itself prove clean-org installation, upgrade compatibility, managed-package creation, or AppExchange security review.

## Managed 2GP setup status

The source is structured for a managed second-generation package. The working product identity is:

- Display name: **Contact Orbit**
- Namespace candidate: `ContactOrbit`
- Dev Hub alias: `sflens-browser-6988f780d7e5`
- Dev Hub org ID: `00Dbm00000zvwwzEAA`

The Dev Hub and **Unlocked Packages and Second-Generation Managed Packages** settings are enabled, and the Dev Hub is configured as the Salesforce CLI default. The package has not been created yet because Salesforce requires a namespace to be created in a separate Developer Edition namespace org and linked to the Dev Hub first. The current Dev Hub Package Manager confirms that namespace editing is unavailable in a Dev Hub org.

After the namespace org is created and linked, finish the release setup in this order:

1. Set `"namespace": "ContactOrbit"` in `sfdx-project.json` after Salesforce confirms availability.
2. Create the managed package with Salesforce CLI.
3. Create a beta package version with an installation key and code coverage enabled.
4. Install that version in a fresh scratch org, run the package tests, and verify the Contact UI and Email-to-Case guardrails.
5. Promote only after upgrade testing and a deliberate release decision; promotion is irreversible.

Do not commit an installation key or reserve a different namespace after package creation. A managed 2GP namespace cannot be changed once the package exists.

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE).
