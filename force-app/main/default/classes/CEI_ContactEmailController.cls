public with sharing class CEI_ContactEmailController {
    @AuraEnabled
    public static Contact_Email__c createEmail(
        Id contactId,
        String emailAddress,
        String purpose,
        Boolean isPrimary
    ) {
        if (!Schema.sObjectType.Contact_Email__c.isCreateable()) {
            throw new AuraHandledException('You do not have permission to create Contact email identities.');
        }
        if (contactId == null) throw new AuraHandledException('A Contact is required.');

        List<Contact> visibleContacts = [
            SELECT Id
            FROM Contact
            WHERE Id = :contactId
            WITH USER_MODE
            LIMIT 1
        ];
        if (visibleContacts.isEmpty()) throw new AuraHandledException('The Contact is not available to you.');

        Contact_Email__c contactEmail = new Contact_Email__c(
            Contact__c = contactId,
            Email_Address__c = emailAddress,
            Purpose__c = purpose,
            Is_Primary__c = isPrimary == true,
            Active__c = true
        );
        insert contactEmail;
        return [
            SELECT Id, Email_Address__c, Purpose__c, Is_Primary__c, Active__c, Last_Verified__c
            FROM Contact_Email__c
            WHERE Id = :contactEmail.Id
            WITH USER_MODE
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static Contact_Email__c createEmailRecord(
        Id contactId,
        String emailAddress,
        String purpose,
        Boolean isPrimary
    ) {
        return createEmail(contactId, emailAddress, purpose, isPrimary);
    }

    @AuraEnabled(cacheable=true)
    public static List<Contact_Email__c> getEmails(Id contactId) {
        if (contactId == null) return new List<Contact_Email__c>();
        return [
            SELECT Id, Email_Address__c, Purpose__c, Is_Primary__c, Active__c, Last_Verified__c
            FROM Contact_Email__c
            WHERE Contact__c = :contactId
            WITH USER_MODE
            ORDER BY Active__c DESC, Is_Primary__c DESC, Purpose__c, Email_Address__c
        ];
    }
}
