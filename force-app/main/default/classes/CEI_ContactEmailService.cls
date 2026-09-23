public with sharing class CEI_ContactEmailService {
    public class ResolveRequest {
        @InvocableVariable(required=true label='Contact ID')
        public Id contactId;

        @InvocableVariable(label='Purpose')
        public String purpose;
    }

    public class ResolveResult {
        @InvocableVariable(label='Email Address')
        public String emailAddress;

        @InvocableVariable(label='Matched')
        public Boolean matched;

        @InvocableVariable(label='Contact Email ID')
        public Id contactEmailId;
    }

    public static String normalize(String rawEmail) {
        return String.isBlank(rawEmail) ? null : rawEmail.trim().toLowerCase();
    }

    public static void prepareForSave(List<Contact_Email__c> records) {
        Set<Id> contactIds = new Set<Id>();
        Set<Id> incomingIds = new Set<Id>();
        for (Contact_Email__c item : records) {
            if (item.Contact__c == null) item.Contact__c.addError('A Contact is required.');
            if (String.isBlank(item.Email_Address__c)) item.Email_Address__c.addError('An email address is required.');
            if (String.isBlank(item.Purpose__c)) item.Purpose__c.addError('A purpose is required.');
            if (item.Contact__c != null) contactIds.add(item.Contact__c);
            if (item.Id != null) incomingIds.add(item.Id);
            item.Normalized_Email__c = normalize(item.Email_Address__c);
            if (item.Contact__c != null && item.Normalized_Email__c != null) {
                item.Match_Key__c = String.valueOf(item.Contact__c) + '|' + item.Normalized_Email__c;
            }
        }

        Map<String, Id> existingPrimaryByScope = new Map<String, Id>();
        if (!contactIds.isEmpty()) {
            for (Contact_Email__c existing : [
                SELECT Id, Contact__c, Purpose__c
                FROM Contact_Email__c
                WHERE Contact__c IN :contactIds
                  AND Is_Primary__c = true
                  AND Active__c = true
                  AND Id NOT IN :incomingIds
                WITH SYSTEM_MODE
            ]) {
                existingPrimaryByScope.put(primaryScope(existing.Contact__c, existing.Purpose__c), existing.Id);
            }
        }

        Set<String> batchPrimaryScopes = new Set<String>();
        for (Contact_Email__c item : records) {
            if (item.Active__c == true && item.Is_Primary__c == true && item.Contact__c != null) {
                String scope = primaryScope(item.Contact__c, item.Purpose__c);
                if (existingPrimaryByScope.containsKey(scope) || batchPrimaryScopes.contains(scope)) {
                    item.Is_Primary__c.addError('Only one active primary email is allowed per Contact and purpose.');
                }
                batchPrimaryScopes.add(scope);
            }
        }
    }

    @InvocableMethod(
        label='Resolve Contact Email'
        description='Returns the active primary address for the requested purpose, then falls back to any active address for that purpose and finally the Contact Email field.'
    )
    public static List<ResolveResult> resolve(List<ResolveRequest> requests) {
        Set<Id> contactIds = new Set<Id>();
        for (ResolveRequest request : requests) {
            if (request != null && request.contactId != null) contactIds.add(request.contactId);
        }

        Map<Id, List<Contact_Email__c>> emailsByContact = new Map<Id, List<Contact_Email__c>>();
        if (!contactIds.isEmpty()) {
            for (Contact_Email__c item : [
                SELECT Id, Contact__c, Email_Address__c, Purpose__c, Is_Primary__c
                FROM Contact_Email__c
                WHERE Contact__c IN :contactIds AND Active__c = true
                WITH USER_MODE
                ORDER BY Is_Primary__c DESC, LastModifiedDate DESC
            ]) {
                if (!emailsByContact.containsKey(item.Contact__c)) {
                    emailsByContact.put(item.Contact__c, new List<Contact_Email__c>());
                }
                emailsByContact.get(item.Contact__c).add(item);
            }
        }

        Map<Id, Contact> contactsById = new Map<Id, Contact>();
        if (!contactIds.isEmpty()) {
            contactsById = new Map<Id, Contact>([
                SELECT Id, Email FROM Contact WHERE Id IN :contactIds WITH USER_MODE
            ]);
        }

        List<ResolveResult> results = new List<ResolveResult>();
        for (ResolveRequest request : requests) {
            ResolveResult result = new ResolveResult();
            List<Contact_Email__c> candidates = emailsByContact.get(request.contactId);
            Contact_Email__c selected;
            if (candidates != null) {
                for (Contact_Email__c candidate : candidates) {
                    if (String.isBlank(request.purpose) || candidate.Purpose__c == request.purpose) {
                        selected = candidate;
                        break;
                    }
                }
            }
            if (selected != null) {
                result.emailAddress = selected.Email_Address__c;
                result.contactEmailId = selected.Id;
                result.matched = true;
            } else {
                Contact fallback = contactsById.get(request.contactId);
                result.emailAddress = fallback == null ? null : fallback.Email;
                result.matched = false;
            }
            results.add(result);
        }
        return results;
    }

    private static String primaryScope(Id contactId, String purpose) {
        return String.valueOf(contactId) + '|' + (String.isBlank(purpose) ? 'General' : purpose);
    }
}
