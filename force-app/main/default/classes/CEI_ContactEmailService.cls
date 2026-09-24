global with sharing class CEI_ContactEmailService {
    public static Boolean allowVerificationMutation = false;

    global class ResolveRequest {
        @InvocableVariable(required=true label='Contact ID')
        global Id contactId;

        @InvocableVariable(required=true label='Purpose Key')
        global String purposeKey;

        @InvocableVariable(label='Allow Contact.Email Fallback')
        global Boolean allowContactEmailFallback;
    }

    global class ResolveResult {
        @InvocableVariable(label='Email Address')
        global String emailAddress;

        @InvocableVariable(label='Contact Email ID')
        global Id contactEmailId;

        @InvocableVariable(label='Matched')
        global Boolean matched;

        @InvocableVariable(label='Source')
        global String source;

        @InvocableVariable(label='Outcome Code')
        global String outcomeCode;

        @InvocableVariable(label='Message')
        global String message;
    }

    public static String normalize(String rawEmail) {
        return String.isBlank(rawEmail) ? null : rawEmail.trim().toLowerCase();
    }

    public static Map<String, Contact_Email_Purpose__mdt> allPurposes() {
        return Contact_Email_Purpose__mdt.getAll();
    }

    public static Boolean isActivePurpose(String purposeKey) {
        if (String.isBlank(purposeKey)) return false;
        Contact_Email_Purpose__mdt purpose = allPurposes().get(purposeKey.trim());
        return purpose != null && purpose.Active__c == true;
    }

    public static void prepareForSave(List<Contact_Email__c> records) {
        prepareForSave(records, null, false);
    }

    public static void prepareForSave(
        List<Contact_Email__c> records,
        Map<Id, Contact_Email__c> oldById,
        Boolean isInsert
    ) {
        Set<Id> contactIds = new Set<Id>();
        Set<Id> incomingIds = new Set<Id>();
        for (Contact_Email__c item : records) {
            if (item.Contact__c == null) item.Contact__c.addError('A Contact is required.');
            if (String.isBlank(item.Email_Address__c)) item.Email_Address__c.addError('An email address is required.');
            if (String.isBlank(item.Purpose_Key__c)) {
                item.Purpose_Key__c.addError('A purpose key is required.');
            } else {
                Contact_Email_Purpose__mdt purpose = allPurposes().get(item.Purpose_Key__c.trim());
                Boolean changedPurpose = isInsert == true || oldById == null || !oldById.containsKey(item.Id) ||
                    oldById.get(item.Id).Purpose_Key__c != item.Purpose_Key__c;
                if (purpose == null) {
                    item.Purpose_Key__c.addError('The purpose key is not recognized.');
                } else if (purpose.Active__c != true && changedPurpose) {
                    item.Purpose_Key__c.addError('That purpose is inactive and cannot be newly assigned.');
                }
            }

            Contact_Email__c oldItem = oldById == null ? null : oldById.get(item.Id);
            if (isInsert == true && !allowVerificationMutation) {
                // New identities always start unverified. Any caller-supplied trust fields
                // are discarded rather than allowing a direct insert to establish trust.
                item.Verification_Status__c = 'Unverified';
                item.Verified_At__c = null;
                item.Verified_By__c = null;
                item.Verification_Method__c = null;
            } else if (oldItem != null && !allowVerificationMutation) {
                if (item.Verification_Status__c != oldItem.Verification_Status__c ||
                    item.Verified_At__c != oldItem.Verified_At__c ||
                    item.Verified_By__c != oldItem.Verified_By__c ||
                    item.Verification_Method__c != oldItem.Verification_Method__c) {
                    item.addError('Verification state can only be changed through Contact Orbit attestation.');
                }
            }
            if (oldItem != null && (item.Email_Address__c != oldItem.Email_Address__c || item.Contact__c != oldItem.Contact__c)) {
                item.Verification_Status__c = 'Unverified';
                item.Verified_At__c = null;
                item.Verified_By__c = null;
                item.Verification_Method__c = null;
            }
            if (String.isBlank(item.Verification_Status__c)) item.Verification_Status__c = 'Unverified';
            if (item.Contact__c != null) contactIds.add(item.Contact__c);
            if (item.Id != null) incomingIds.add(item.Id);

            item.Normalized_Email_Key__c = normalize(item.Email_Address__c);
            if (item.Contact__c != null && item.Normalized_Email_Key__c != null) {
                item.Contact_Email_Key__c = String.valueOf(item.Contact__c) + '|' + item.Normalized_Email_Key__c;
            }
            if (item.Contact__c != null && item.Active__c == true && item.Is_Primary__c == true &&
                !String.isBlank(item.Purpose_Key__c) && isActivePurpose(item.Purpose_Key__c)) {
                item.Primary_Scope_Key__c = primaryScope(item.Contact__c, item.Purpose_Key__c);
            } else {
                item.Primary_Scope_Key__c = null;
            }
        }

        if (!contactIds.isEmpty()) {
            Map<Id, Contact> lockedContacts = new Map<Id, Contact>([
                SELECT Id FROM Contact WHERE Id IN :contactIds WITH SYSTEM_MODE FOR UPDATE
            ]);
        }

        Map<String, Id> existingPrimaryByScope = new Map<String, Id>();
        if (!contactIds.isEmpty()) {
            for (Contact_Email__c existing : [
                SELECT Id, Contact__c, Purpose_Key__c
                FROM Contact_Email__c
                WHERE Contact__c IN :contactIds
                  AND Is_Primary__c = true
                  AND Active__c = true
                  AND Id NOT IN :incomingIds
                WITH SYSTEM_MODE
            ]) {
                existingPrimaryByScope.put(primaryScope(existing.Contact__c, existing.Purpose_Key__c), existing.Id);
            }
        }

        Set<String> batchPrimaryScopes = new Set<String>();
        for (Contact_Email__c item : records) {
            if (item.Active__c == true && item.Is_Primary__c == true && item.Contact__c != null &&
                !String.isBlank(item.Purpose_Key__c)) {
                String scope = primaryScope(item.Contact__c, item.Purpose_Key__c);
                if (existingPrimaryByScope.containsKey(scope) || batchPrimaryScopes.contains(scope)) {
                    item.Is_Primary__c.addError('Only one active primary email is allowed per Contact and purpose.');
                }
                batchPrimaryScopes.add(scope);
            }
        }
    }

    @InvocableMethod(
        label='Resolve Contact Email'
        description='Resolves one verified Contact email identity for a required active purpose. Contact.Email fallback is explicit per request.'
    )
    global static List<ResolveResult> resolve(List<ResolveRequest> requests) {
        List<ResolveResult> results = new List<ResolveResult>();
        if (requests == null) return results;

        Set<Id> contactIds = new Set<Id>();
        Set<String> requestedPurposes = new Set<String>();
        for (ResolveRequest request : requests) {
            if (request != null && request.contactId != null) contactIds.add(request.contactId);
            if (request != null && !String.isBlank(request.purposeKey)) requestedPurposes.add(request.purposeKey.trim());
        }

        Map<String, Contact_Email_Purpose__mdt> purposes = allPurposes();
        Map<Id, Contact> contactsById = new Map<Id, Contact>();
        if (!contactIds.isEmpty()) {
            contactsById = new Map<Id, Contact>([
                SELECT Id, Email FROM Contact WHERE Id IN :contactIds WITH USER_MODE
            ]);
        }

        Map<String, List<Contact_Email__c>> candidatesByScope = new Map<String, List<Contact_Email__c>>();
        if (!contactsById.isEmpty() && !requestedPurposes.isEmpty()) {
            for (Contact_Email__c item : [
                SELECT Id, Contact__c, Email_Address__c, Purpose_Key__c, Is_Primary__c, Verified_At__c
                FROM Contact_Email__c
                WHERE Contact__c IN :contactIds
                  AND Active__c = true
                  AND Verification_Status__c = 'Verified'
                  AND Purpose_Key__c IN :requestedPurposes
                WITH USER_MODE
                ORDER BY Is_Primary__c DESC, Verified_At__c DESC NULLS LAST, Id ASC
            ]) {
                String scope = primaryScope(item.Contact__c, item.Purpose_Key__c);
                if (!candidatesByScope.containsKey(scope)) candidatesByScope.put(scope, new List<Contact_Email__c>());
                candidatesByScope.get(scope).add(item);
            }
        }

        for (ResolveRequest request : requests) {
            ResolveResult result = new ResolveResult();
            result.matched = false;
            result.source = 'None';
            result.outcomeCode = 'NO_MATCH';
            result.message = 'No verified identity matched the requested purpose.';

            if (request == null || request.contactId == null || String.isBlank(request.purposeKey)) {
                result.outcomeCode = 'INVALID_REQUEST';
                result.message = 'Contact ID and purpose key are required.';
                results.add(result);
                continue;
            }
            String purposeKey = request.purposeKey.trim();
            Contact_Email_Purpose__mdt purpose = purposes.get(purposeKey);
            if (purpose == null) {
                result.outcomeCode = 'INVALID_REQUEST';
                result.message = 'The requested purpose is not recognized.';
                results.add(result);
                continue;
            }
            if (purpose.Active__c != true) {
                result.outcomeCode = 'PURPOSE_DISABLED';
                result.message = 'The requested purpose is inactive.';
                results.add(result);
                continue;
            }
            if (!contactsById.containsKey(request.contactId)) {
                result.outcomeCode = 'ACCESS_DENIED';
                result.message = 'The Contact is not available to the running user.';
                results.add(result);
                continue;
            }

            List<Contact_Email__c> candidates = candidatesByScope.get(primaryScope(request.contactId, purposeKey));
            if (candidates != null && !candidates.isEmpty()) {
                Contact_Email__c selected = candidates[0];
                result.emailAddress = selected.Email_Address__c;
                result.contactEmailId = selected.Id;
                result.matched = true;
                result.source = 'VerifiedIdentity';
                result.outcomeCode = selected.Is_Primary__c == true ? 'MATCHED_PRIMARY' : 'MATCHED_FALLBACK';
                result.message = selected.Is_Primary__c == true ? 'Verified primary identity resolved.' : 'Verified fallback identity resolved.';
            } else if (request.allowContactEmailFallback == true && !String.isBlank(contactsById.get(request.contactId).Email)) {
                result.emailAddress = contactsById.get(request.contactId).Email;
                result.source = 'ContactEmail';
                result.outcomeCode = 'CONTACT_EMAIL_FALLBACK';
                result.message = 'No verified identity matched; explicit Contact.Email fallback was used.';
            }
            results.add(result);
        }
        return results;
    }

    public static String primaryScope(Id contactId, String purposeKey) {
        return String.valueOf(contactId) + '|' + purposeKey.trim();
    }
}
