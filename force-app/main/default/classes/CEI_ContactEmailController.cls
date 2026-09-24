public with sharing class CEI_ContactEmailController {
    public class PurposeOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public Boolean active;
        @AuraEnabled public Decimal sortOrder;
    }

    @AuraEnabled
    public static Contact_Email__c createEmail(
        Id contactId,
        String emailAddress,
        String purposeKey,
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
            Purpose_Key__c = purposeKey,
            Is_Primary__c = isPrimary == true,
            Active__c = true
        );
        try {
            Database.SaveResult saveResult = Database.insert(contactEmail, AccessLevel.USER_MODE);
            if (!saveResult.isSuccess()) throw new AuraHandledException(sanitizeErrors(saveResult.getErrors()));
        } catch (DmlException error) {
            throw new AuraHandledException('The Contact email identity could not be saved. Check for a primary-purpose conflict.');
        }
        return getEmail(contactEmail.Id);
    }

    @AuraEnabled
    public static Contact_Email__c deactivateEmail(Id contactEmailId) {
        if (contactEmailId == null) throw new AuraHandledException('A Contact email identity is required.');
        Contact_Email__c identity = getEditableEmail(contactEmailId);
        identity.Active__c = false;
        identity.Is_Primary__c = false;
        identity.Primary_Scope_Key__c = null;
        Database.SaveResult result = Database.update(identity, AccessLevel.USER_MODE);
        if (!result.isSuccess()) throw new AuraHandledException('The Contact email identity could not be deactivated.');
        return getEmail(contactEmailId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Contact_Email__c> getEmails(Id contactId) {
        if (contactId == null) return new List<Contact_Email__c>();
        return [
            SELECT Id, Email_Address__c, Purpose_Key__c, Is_Primary__c, Active__c,
                Verification_Status__c, Verified_At__c, Verified_By__c, Verification_Method__c
            FROM Contact_Email__c
            WHERE Contact__c = :contactId
            WITH USER_MODE
            ORDER BY Active__c DESC, Is_Primary__c DESC, Purpose_Key__c, Email_Address__c
            LIMIT 200
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<PurposeOption> getPurposeOptions() {
        List<PurposeOption> options = new List<PurposeOption>();
        for (Contact_Email_Purpose__mdt metadata : Contact_Email_Purpose__mdt.getAll().values()) {
            if (metadata.Active__c != true) continue;
            PurposeOption option = new PurposeOption();
            option.label = metadata.Label;
            option.value = metadata.DeveloperName;
            option.active = metadata.Active__c;
            option.sortOrder = metadata.Sort_Order__c;
            options.add(option);
        }
        for (Integer i = 0; i < options.size(); i++) {
            for (Integer j = i + 1; j < options.size(); j++) {
                Decimal leftOrder = options[i].sortOrder == null ? 999 : options[i].sortOrder;
                Decimal rightOrder = options[j].sortOrder == null ? 999 : options[j].sortOrder;
                if (rightOrder < leftOrder || (rightOrder == leftOrder && options[j].value < options[i].value)) {
                    PurposeOption swap = options[i];
                    options[i] = options[j];
                    options[j] = swap;
                }
            }
        }
        return options;
    }

    private static Contact_Email__c getEditableEmail(Id contactEmailId) {
        List<Contact_Email__c> identities = [
            SELECT Id, Active__c, Is_Primary__c, Primary_Scope_Key__c
            FROM Contact_Email__c
            WHERE Id = :contactEmailId
            WITH USER_MODE
            LIMIT 1
        ];
        if (identities.isEmpty()) throw new AuraHandledException('The Contact email identity is not available to you.');
        return identities[0];
    }

    private static Contact_Email__c getEmail(Id contactEmailId) {
        List<Contact_Email__c> identities = [
            SELECT Id, Email_Address__c, Purpose_Key__c, Is_Primary__c, Active__c,
                Verification_Status__c, Verified_At__c, Verified_By__c, Verification_Method__c
            FROM Contact_Email__c
            WHERE Id = :contactEmailId
            WITH USER_MODE
            LIMIT 1
        ];
        return identities.isEmpty() ? null : identities[0];
    }

    private static String sanitizeErrors(Database.Error[] errors) {
        if (errors == null || errors.isEmpty()) return 'The identity could not be saved.';
        for (Database.Error error : errors) {
            if (error.getStatusCode() == StatusCode.DUPLICATE_VALUE) {
                return 'An active primary already exists for this Contact and purpose.';
            }
        }
        return 'The identity could not be saved. Check the Contact Orbit fields and permissions.';
    }
}
