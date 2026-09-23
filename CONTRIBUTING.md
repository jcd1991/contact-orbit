# Contributing

Thanks for helping improve Contact Email Identity.

## Before opening a change

- Keep the package Contact-focused and preserve the safety boundaries in the README.
- Never commit credentials, org URLs containing authentication material, customer data, or generated Salesforce state.
- Add or update scoped Apex tests for behavior changes.
- Keep metadata changes deployable from a clean Salesforce DX project.

## Validation

Run the scoped deployment and tests against a disposable validation org:

```sh
sf project deploy start --source-dir force-app --target-org YOUR_ORG \
  --test-level RunSpecifiedTests \
  --tests CEI_ContactEmailServiceTest \
  --tests CEI_EmailMessageHandlerTest \
  --wait 30
```

Do not enable Email-to-Case matching in a shared org until the automation user
has the packaged permission set and the behavior has been verified with safe
test data.
