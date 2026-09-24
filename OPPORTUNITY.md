# IdeaExchange managed-package opportunity scan

Research date: September 22, 2026. Demand is shown as current IdeaExchange points from the points-descending ranking; exact vote counts were opened and verified for the leading finalists.

| Idea | Demand | Package fit | Market reality | Decision |
|---|---:|---:|---|---|
| Inline Editing for Related Lists | 90,170 points / 9,039 votes | High | Multiple existing AppExchange apps, including a free security-reviewed package; Salesforce says it was displaced from the roadmap | Do not enter |
| Cross Object Merge Fields in Email Template | 78,840 / 7,900 | Medium | Strong active need, but a package must replace the send/render path rather than fix native templates; Goat Email CORE already advertises cross-object merge fields | Runner-up |
| Set Accounts & Contacts as Inactive | 65,760 | Low-medium | A package cannot globally alter every native lookup; existing inactivation tools use sharing/workarounds | Avoid as a standalone product |
| Existing picklists use Global Picklists | 61,030 | Low | Requires native metadata behavior a managed package cannot retrofit safely | Reject |
| Long Text Area fields on Activities | 49,150 | Low-medium | A package can only provide a sidecar object/component, not the requested native field type | Reject |
| Frequency Reports from Multi-Select Picklists | 47,690 / 4,779 | Medium | Salesforce says performance at scale is the remaining blocker; MultiSelect Reporting is already on AppExchange | Do not enter |
| Web-to-Case attachments | 46,490 | Medium | On Salesforce roadmap; security and public-upload abuse make the MVP costly; multiple Service Cloud packages compete | Defer |
| Bulk rename/move reports | 42,840 | Medium | Report Bulk Manager now offers the exact workflow | Do not enter |
| Scheduled reports to non-users | 37,210 | Medium | Mature incumbents include CloudAnswers Report Sender and Report & Dashboard Scheduler | Do not enter |
| Multiple email addresses for a Contact | 31,630 / 3,191 | High for a bounded solution | Active 2025-2026 use cases; no direct package found that owns the full contact-email identity problem | **Build first** |

## Need-to-effort ranking

To avoid mistaking raw votes for a good package business, the shortlist was scored on three 1-5 factors: verified demand, implementation ease, and competitive whitespace. The opportunity index is their product; it is a prioritization aid, not a claim of market size.

| Finalist | Demand | Ease | Whitespace | Opportunity index | Why |
|---|---:|---:|---:|---:|---|
| Multiple email addresses for a Contact | 3 | 4 | 5 | **60** | Lower raw votes, but a clean sidecar-object solution and the clearest unoccupied product position |
| Inline Editing for Related Lists | 5 | 4 | 1 | 20 | Very easy to understand and highly requested, but already served by several packages |
| Cross Object Merge Fields in Email Template | 5 | 2 | 2 | 20 | Strong need, but requires owning a replacement rendering/sending path and has a direct incumbent |
| Frequency Reports from Multi-Select Picklists | 4 | 2 | 1 | 8 | Scaling is the hard part, Salesforce is actively working on it, and a direct package exists |

That makes **Contact Orbit** the best need-to-implementation opportunity after feasibility and incumbent risk are included. Raw points alone would have selected crowded or non-packageable ideas.

## Recommended positioning

Position Contact Orbit as a focused, native identity-routing layer—not another bulk email product. Start with Contact email storage, purpose-aware Flow resolution, and conservative Email-to-Case matching. Validate demand with Service Cloud teams and nonprofits before expanding to Person Accounts, EAC-adjacent reconciliation, billing routing, and unsubscribe/consent per address.

## Primary evidence

- IdeaExchange ranking: https://ideas.salesforce.com/s/search
- Multiple email addresses for a contact: https://ideas.salesforce.com/s/idea/a0B8W00000Gde7FUAR/multiple-email-addresses-for-a-contact
- Cross-object merge fields: https://ideas.salesforce.com/s/idea/a0B8W00000GdifOUAR/cross-object-merge-fields-in-email-template
- Inline editing for related lists: https://ideas.salesforce.com/s/idea/a0B8W00000GdlpwUAB/inline-editing-for-related-lists
- Multi-select frequency reporting: https://ideas.salesforce.com/s/idea/a0B8W00000GdjTJUAZ/frequency-reports-from-multiselect-picklists
- Salesforce Help on cross-object email-template limitations: https://help.salesforce.com/s/articleView?id=000385133&language=en_US&type=1
- Salesforce Help on packaged Apex email services: https://help.salesforce.com/s/articleView?id=sf.code_email_service_address.htm&language=en_US&type=5
