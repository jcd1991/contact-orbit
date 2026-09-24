# Contact Orbit managed-package setup

Contact Orbit is source-ready for a managed second-generation package. Namespace registration and package creation are intentionally separate, irreversible release gates and cannot be completed from the current Dev Hub alone.

## Required Salesforce state

- A Dev Hub with second-generation managed packaging enabled.
- A separate Developer Edition namespace org that owns the `ContactOrbit` namespace, subject to Salesforce availability.
- A linked namespace entry in the Dev Hub Namespace Registry.
- A CI-only authentication secret for the Dev Hub and a separate secret installation key.

Use placeholders in local and public documentation: `<DEV_HUB_USERNAME>`, `<NAMESPACE_ORG_ALIAS>`, `<SCRATCH_ALIAS>`, and `<PACKAGE_INSTALL_KEY>`. Never commit a real alias, org ID, frontdoor URL, session, or installation key.

## Namespace handoff

1. In the namespace Developer Edition, open Setup → Package Manager → Namespace Settings.
2. Register `ContactOrbit` only after Salesforce confirms it is available. Stop if it is unavailable; do not silently reserve another permanent namespace.
3. In the Dev Hub, link the namespace org from Namespace Registry and verify the link.
4. Change `sfdx-project.json` from an empty namespace to `ContactOrbit` only after the link is visible.
5. Run a source deployment and the complete local test suite before creating any package version.

Before that deployment, run `scripts/apex/migrate_contact_email_identities.apex`
against a backup or disposable copy. It aborts on duplicate active primaries,
populates `Purpose_Key__c` and `Primary_Scope_Key__c`, and marks every existing
identity `Unverified`; it emits counts and IDs only. Apply
`manifest/destructiveChangesPre.xml` only after the migration readback is
clean. The old fixed purpose, editable last-verified field, and Boolean-only
Email-to-Case matching setting are not part of the first managed package.

## Create the package and beta

```sh
sf config set target-dev-hub=<DEV_HUB_USERNAME> --global
sf package create --name "Contact Orbit" --package-type Managed \
  --path force-app --target-dev-hub <DEV_HUB_USERNAME>

export CONTACT_ORBIT_PACKAGE_INSTALL_KEY="<PACKAGE_INSTALL_KEY>"
sf package version create --package "Contact Orbit" \
  --target-dev-hub <DEV_HUB_USERNAME> \
  --installation-key "$CONTACT_ORBIT_PACKAGE_INSTALL_KEY" \
  --code-coverage --wait 60
```

Keep the installation key in a CI secret. Do not put it in shell history, a package descriptor, a README, or a test fixture.

## Clean subscriber verification

1. Create a fresh subscriber scratch org from `config/project-scratch-def.json`.
2. Install the `04t...` beta version with the installation key.
3. Assign Contact Orbit User, Verifier, and Administrator to dedicated test users.
4. Query the Apex Actions REST resource and confirm the namespaced `CEI_ContactEmailService` resolver is visible outside the package; `public` is insufficient for subscriber Flow discovery, so this is a hard gate for the `global` contract.
5. Run all package Apex tests, the FLS/sharing matrix, same-Case bulk routing tests, idempotent retry tests, retention boundaries, and browser UI smoke tests.
6. Verify install, uninstall, and reinstall cleanup. Confirm that no installation-time retention job was created.
7. Record package coverage (minimum 75%, every trigger covered), Code Analyzer SARIF (no High/Critical), and zero unresolved routing failures.

## Upgrade and promotion

Salesforce beta versions cannot be upgraded. Promotion is a separate irreversible approval. After the first released baseline exists, create the next beta, install it over that released version in a clean subscriber org, and verify metadata upgrades, retained identities, historical match records, and subscriber-created purpose metadata before promotion.
