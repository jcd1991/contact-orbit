public with sharing class CEI_EmailMessageHandler {
    public static void afterInsert(List<EmailMessage> newMessages) {
        Contact_Email_Settings__c settings = Contact_Email_Settings__c.getOrgDefaults();
        if (settings == null || settings.Enable_Email_To_Case_Suggestions__c != true || newMessages == null || newMessages.isEmpty()) return;

        Map<Id, EmailMessage> inboundById = new Map<Id, EmailMessage>();
        Map<Id, List<Id>> messageIdsByCase = new Map<Id, List<Id>>();
        Set<String> normalizedAddresses = new Set<String>();
        Set<Id> caseIds = new Set<Id>();
        for (EmailMessage message : newMessages) {
            if (message.Incoming != true || message.ParentId == null || message.ParentId.getSObjectType() != Case.SObjectType) continue;
            String normalized = CEI_ContactEmailService.normalize(message.FromAddress);
            if (normalized == null) continue;
            inboundById.put(message.Id, message);
            caseIds.add(message.ParentId);
            normalizedAddresses.add(normalized);
            if (!messageIdsByCase.containsKey(message.ParentId)) messageIdsByCase.put(message.ParentId, new List<Id>());
            messageIdsByCase.get(message.ParentId).add(message.Id);
        }
        if (inboundById.isEmpty()) return;

        Map<Id, Case> visibleCases = new Map<Id, Case>();
        for (Case supportCase : [
            SELECT Id, ContactId
            FROM Case
            WHERE Id IN :caseIds
            WITH USER_MODE
        ]) visibleCases.put(supportCase.Id, supportCase);

        Set<Id> existingMatchSourceIds = new Set<Id>();
        Set<String> inboundSourceIds = toTextIds(inboundById.keySet());
        for (Contact_Email_Match__c existing : [
            SELECT Source_Email_Message_Id__c
            FROM Contact_Email_Match__c
            WHERE Source_Email_Message_Id__c IN :inboundSourceIds
            WITH SYSTEM_MODE
        ]) {
            if (existing.Source_Email_Message_Id__c != null) existingMatchSourceIds.add((Id)existing.Source_Email_Message_Id__c);
        }

        // Intentional privilege boundary: this is the automation's narrow identity lookup.
        // It reads only matching fields and never exposes the sender address or bypasses
        // Case sharing for the user-facing confirmation path.
        Map<String, Set<Id>> contactsByAddress = new Map<String, Set<Id>>();
        Map<String, Id> identityByAddress = new Map<String, Id>();
        for (Contact_Email__c identity : [
            SELECT Id, Contact__c, Normalized_Email_Key__c
            FROM Contact_Email__c
            WHERE Normalized_Email_Key__c IN :normalizedAddresses
              AND Active__c = true
              AND Verification_Status__c = 'Verified'
            WITH SYSTEM_MODE
            ORDER BY Id ASC
        ]) {
            if (!contactsByAddress.containsKey(identity.Normalized_Email_Key__c)) {
                contactsByAddress.put(identity.Normalized_Email_Key__c, new Set<Id>());
                identityByAddress.put(identity.Normalized_Email_Key__c, identity.Id);
            }
            contactsByAddress.get(identity.Normalized_Email_Key__c).add(identity.Contact__c);
        }

        List<Contact_Email_Match__c> newMatches = new List<Contact_Email_Match__c>();
        Map<Id, Contact_Email_Match__c> matchByMessage = new Map<Id, Contact_Email_Match__c>();
        Map<Id, Set<Id>> uniqueContactsByCase = new Map<Id, Set<Id>>();
        Map<Id, Integer> uniqueMessagesByCase = new Map<Id, Integer>();
        Map<Id, Boolean> allMessagesUniqueByCase = new Map<Id, Boolean>();
        Set<Id> auditFailedCases = new Set<Id>();

        for (Id caseId : messageIdsByCase.keySet()) {
            allMessagesUniqueByCase.put(caseId, true);
            uniqueContactsByCase.put(caseId, new Set<Id>());
            uniqueMessagesByCase.put(caseId, 0);
            if (!visibleCases.containsKey(caseId)) auditFailedCases.add(caseId);
            if (visibleCases.containsKey(caseId) && visibleCases.get(caseId).ContactId != null) allMessagesUniqueByCase.put(caseId, false);
        }

        for (Id messageId : inboundById.keySet()) {
            EmailMessage message = inboundById.get(messageId);
            if (existingMatchSourceIds.contains(messageId)) continue;
            String normalized = CEI_ContactEmailService.normalize(message.FromAddress);
            Set<Id> candidateContacts = contactsByAddress.get(normalized);
            Contact_Email_Match__c audit = new Contact_Email_Match__c(
                Case__c = message.ParentId,
                Source_Email_Message_Id__c = String.valueOf(message.Id),
                Occurred_At__c = System.now()
            );
            if (candidateContacts == null || candidateContacts.isEmpty()) {
                // Routine no-match is intentionally not persisted.
                allMessagesUniqueByCase.put(message.ParentId, false);
                continue;
            }
            if (candidateContacts.size() == 1) {
                Id candidateContactId = new List<Id>(candidateContacts)[0];
                audit.Candidate_Contact__c = candidateContactId;
                audit.Contact_Email__c = identityByAddress.get(normalized);
                audit.Status__c = visibleCases.containsKey(message.ParentId) && visibleCases.get(message.ParentId).ContactId != null
                    ? 'Superseded' : 'Suggested';
                audit.Reason_Code__c = visibleCases.containsKey(message.ParentId) && visibleCases.get(message.ParentId).ContactId != null
                    ? 'EXISTING_CONTACT' : 'UNIQUE_MATCH';
                newMatches.add(audit);
                matchByMessage.put(messageId, audit);
                uniqueContactsByCase.get(message.ParentId).add(candidateContactId);
                uniqueMessagesByCase.put(message.ParentId, uniqueMessagesByCase.get(message.ParentId) + 1);
            } else {
                audit.Status__c = 'Ambiguous';
                audit.Reason_Code__c = 'AMBIGUOUS_MATCH';
                newMatches.add(audit);
                matchByMessage.put(messageId, audit);
                allMessagesUniqueByCase.put(message.ParentId, false);
            }
        }

        Map<Id, Contact_Email_Match__c> persistedMatchesByMessage = new Map<Id, Contact_Email_Match__c>();
        if (!newMatches.isEmpty()) {
            Database.SaveResult[] auditResults = Database.insert(newMatches, false, AccessLevel.SYSTEM_MODE);
            for (Integer index = 0; index < auditResults.size(); index++) {
                Contact_Email_Match__c audit = newMatches[index];
                Id messageId = (Id)audit.Source_Email_Message_Id__c;
                if (auditResults[index].isSuccess()) {
                    persistedMatchesByMessage.put(messageId, audit);
                } else {
                    auditFailedCases.add(audit.Case__c);
                }
            }
        }

        if (settings.Enable_Verified_Auto_Link__c != true) return;
        List<Case> caseUpdates = new List<Case>();
        Map<Id, Id> caseContactById = new Map<Id, Id>();
        for (Id caseId : messageIdsByCase.keySet()) {
            if (auditFailedCases.contains(caseId) || !visibleCases.containsKey(caseId) ||
                visibleCases.get(caseId).ContactId != null || allMessagesUniqueByCase.get(caseId) != true) continue;
            if (uniqueMessagesByCase.get(caseId) != messageIdsByCase.get(caseId).size()) continue;
            Set<Id> candidates = uniqueContactsByCase.get(caseId);
            if (candidates == null || candidates.size() != 1) continue;
            caseContactById.put(caseId, new List<Id>(candidates)[0]);
            caseUpdates.add(new Case(Id = caseId, ContactId = new List<Id>(candidates)[0]));
        }
        if (caseUpdates.isEmpty()) return;

        Database.SaveResult[] caseResults = Database.update(caseUpdates, false, AccessLevel.USER_MODE);
        List<Contact_Email_Match__c> matchUpdates = new List<Contact_Email_Match__c>();
        for (Integer index = 0; index < caseResults.size(); index++) {
            Case updatedCase = caseUpdates[index];
            Boolean success = caseResults[index].isSuccess();
            for (Id messageId : messageIdsByCase.get(updatedCase.Id)) {
                Contact_Email_Match__c audit = persistedMatchesByMessage.get(messageId);
                if (audit == null || audit.Status__c != 'Suggested') continue;
                audit.Status__c = success ? 'AutoLinked' : 'Failed';
                audit.Reason_Code__c = success ? 'UNIQUE_MATCH' : 'UPDATE_FAILED';
                if (!success) {
                    audit.Error_Code__c = 'CASE_UPDATE_FAILED';
                    audit.Error_Message__c = 'The Case Contact could not be updated in the current access context.';
                }
                matchUpdates.add(audit);
            }
        }
        if (!matchUpdates.isEmpty()) Database.update(matchUpdates, false, AccessLevel.SYSTEM_MODE);
    }

    private static Set<String> toTextIds(Set<Id> ids) {
        Set<String> values = new Set<String>();
        for (Id value : ids) values.add(String.valueOf(value));
        return values;
    }
}
