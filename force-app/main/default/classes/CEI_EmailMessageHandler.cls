public with sharing class CEI_EmailMessageHandler {
    public static void afterInsert(List<EmailMessage> newMessages) {
        Contact_Email_Settings__c settings = Contact_Email_Settings__c.getOrgDefaults();
        if (settings == null || settings.Enable_Email_To_Case_Matching__c != true) return;

        Map<Id, String> addressByCaseId = new Map<Id, String>();
        Set<String> normalizedAddresses = new Set<String>();
        for (EmailMessage message : newMessages) {
            if (message.Incoming == true && message.ParentId != null &&
                message.ParentId.getSObjectType() == Case.SObjectType) {
                String normalized = CEI_ContactEmailService.normalize(message.FromAddress);
                if (normalized != null) {
                    addressByCaseId.put(message.ParentId, normalized);
                    normalizedAddresses.add(normalized);
                }
            }
        }
        if (normalizedAddresses.isEmpty()) return;

        Map<String, Set<Id>> contactIdsByAddress = new Map<String, Set<Id>>();
        for (Contact_Email__c contactEmail : [
            SELECT Contact__c, Normalized_Email__c
            FROM Contact_Email__c
            WHERE Normalized_Email__c IN :normalizedAddresses AND Active__c = true
            WITH SYSTEM_MODE
        ]) {
            if (!contactIdsByAddress.containsKey(contactEmail.Normalized_Email__c)) {
                contactIdsByAddress.put(contactEmail.Normalized_Email__c, new Set<Id>());
            }
            contactIdsByAddress.get(contactEmail.Normalized_Email__c).add(contactEmail.Contact__c);
        }

        List<Case> updates = new List<Case>();
        for (Case supportCase : [
            SELECT Id, ContactId
            FROM Case
            WHERE Id IN :addressByCaseId.keySet()
            WITH USER_MODE
        ]) {
            if (supportCase.ContactId != null) continue;
            Set<Id> matches = contactIdsByAddress.get(addressByCaseId.get(supportCase.Id));
            if (matches != null && matches.size() == 1) {
                supportCase.ContactId = new List<Id>(matches)[0];
                updates.add(supportCase);
            }
        }
        if (!updates.isEmpty()) Database.update(updates, false, AccessLevel.USER_MODE);
    }
}
