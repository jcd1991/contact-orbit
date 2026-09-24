# Contact Orbit TODO

## Managed-package release plan

The intended package name is **Contact Orbit** and the intended namespace is
**ContactOrbit**, subject to Salesforce namespace availability. Do not reserve
a substitute namespace silently.

Before promotion:

1. Link the namespace org to the Dev Hub.
2. Create a code-coverage-enabled managed 2GP beta.
3. Install it in a different clean subscriber scratch org.
4. Verify namespaced Flow/Apex Actions visibility, permission sets, FLS/sharing
   behavior, UI placement, uninstall/reinstall, and security analysis.
5. Test upgrades only after a released baseline exists.

See [docs/managed-package-setup.md](docs/managed-package-setup.md) for the
detailed release gates and [docs/architecture-review.md](docs/architecture-review.md)
for the architecture review.
