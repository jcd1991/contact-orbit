# Managed package setup

This project is ready for a second-generation managed package, pending a Salesforce namespace org.

## Current Salesforce state

- Dev Hub: enabled
- Second-generation managed packaging: enabled
- CLI default Dev Hub: `sflens-browser-6988f780d7e5`
- Dev Hub org ID: `00Dbm00000zvwwzEAA`
- Organization namespace prefix: none
- Package list in the Dev Hub: empty

## Product identity

- Display name: **Contact Orbit**
- Namespace candidate: `ContactOrbit`

The name is intentionally broader than the initial Contact email implementation so future Contact identity features can share one namespace.

## Required namespace handoff

Salesforce requires the namespace to be created in a separate Developer Edition org. In that namespace org:

1. Open Setup -> Package Manager -> Namespace Settings.
2. Choose **Edit**, enter `ContactOrbit`, check availability, and save it.
3. In the Dev Hub, link the namespace org from Namespace Registry.
4. Confirm the namespace is linked before changing `sfdx-project.json`.

The current Dev Hub cannot perform step 2 because Salesforce hides Namespace Settings editing after Dev Hub activation.

## Package commands after the namespace is linked

From this project directory:

```sh
sf config set target-dev-hub=sflens-browser-6988f780d7e5 --global
sf package create --name "Contact Orbit" --package-type Managed --path force-app --target-dev-hub sflens-browser-6988f780d7e5
```

Create the first beta version with a secret installation key held only in the shell environment:

```sh
sf package version create --package "Contact Orbit" --target-dev-hub sflens-browser-6988f780d7e5 --installation-key "$CEI_PACKAGE_INSTALL_KEY" --code-coverage --wait 60
```

Then install the resulting `04t...` version in a fresh scratch org and repeat the UI and Apex verification. Package versions remain beta until an authorized release decision promotes one; promotion is irreversible.
