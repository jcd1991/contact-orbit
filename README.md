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
sf apex run test --tests CEI_ContactEmailServiceTest,CEI_EmailMessageHandlerTest --target-org YOUR_ORG --code-coverage --wait 30
```

Assign `Contact Email Identity Admin`, add `Contact Email Manager` to the Contact Lightning record page, then enable the hierarchy setting only after the Email-to-Case automation user has access.

## Verified MVP status

- Deployed to a connected Salesforce Developer Edition org on September 23, 2026.
- Deployment `0Afbm00000gr4RtCAI` succeeded with all 20 metadata components.
- All 7 scoped Apex tests passed.
- The service, handler, and both triggers reported full coverage; the controller's defensive permission guard and thin Aura wrapper are the only uncovered controller lines in the scoped deployment result.
- The Contact record page was verified in Chrome: the card renders cleanly, the add form is aligned, the success toast appears, and a newly-created row is readable in the table.
- `Contact_Email__c` and `Contact_Email_Settings__c` were read back from the target org, and the packaged permission set was assigned to the validating user.

This proves the source deploys and behaves correctly in the connected validation org. It does not by itself prove clean-org installation, upgrade compatibility, managed-package creation, or AppExchange security review.

## Managed 2GP gate

The source is structured for a managed second-generation package, but package creation requires:

1. A Partner Business Org or Dev Hub authorized in the Salesforce CLI.
2. A reserved namespace selected after product validation.
3. A package alias and package ID added to `sfdx-project.json`.
4. Package-version creation, installation in a clean test org, upgrade testing, and Salesforce security review.

Do not reserve a namespace or publish before the Contact-only MVP is validated with design partners.
