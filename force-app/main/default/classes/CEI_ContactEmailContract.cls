/**
 * Stable, subscriber-visible vocabulary for Contact Orbit integrations.
 *
 * Values are strings because Flow, custom metadata, and managed-package
 * boundaries must remain serializable and upgrade-safe.
 */
global class CEI_ContactEmailContract {
    global static final String SOURCE_VERIFIED_IDENTITY = 'VerifiedIdentity';
    global static final String SOURCE_CONTACT_EMAIL = 'ContactEmail';
    global static final String SOURCE_NONE = 'None';

    global static final String OUTCOME_MATCHED_PRIMARY = 'MATCHED_PRIMARY';
    global static final String OUTCOME_MATCHED_FALLBACK = 'MATCHED_FALLBACK';
    global static final String OUTCOME_CONTACT_EMAIL_FALLBACK = 'CONTACT_EMAIL_FALLBACK';
    global static final String OUTCOME_NO_MATCH = 'NO_MATCH';
    global static final String OUTCOME_INVALID_REQUEST = 'INVALID_REQUEST';
    global static final String OUTCOME_PURPOSE_DISABLED = 'PURPOSE_DISABLED';
    global static final String OUTCOME_ACCESS_DENIED = 'ACCESS_DENIED';

    global static final String VERIFICATION_UNVERIFIED = 'Unverified';
    global static final String VERIFICATION_VERIFIED = 'Verified';
    global static final String VERIFICATION_REVOKED = 'Revoked';

    global static final String MATCH_SUGGESTED = 'Suggested';
    global static final String MATCH_CONFIRMED = 'Confirmed';
    global static final String MATCH_REJECTED = 'Rejected';
    global static final String MATCH_AUTO_LINKED = 'AutoLinked';
    global static final String MATCH_AMBIGUOUS = 'Ambiguous';
    global static final String MATCH_FAILED = 'Failed';
    global static final String MATCH_SUPERSEDED = 'Superseded';
}
