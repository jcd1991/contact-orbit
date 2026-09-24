public with sharing class CEI_ContactEmailAttestation {
    @TestVisible private static Boolean testPermissionOverride = false;
    @AuraEnabled
    public static Contact_Email__c verifyEmail(Id contactEmailId) {
        requireVerifier();
        Contact_Email__c identity = getIdentity(contactEmailId);
        if (!identity.Active__c || String.isBlank(identity.Email_Address__c)) {
            throw new AuraHandledException('Only an active identity with an email address can be verified.');
        }
        if (!CEI_ContactEmailService.isActivePurpose(identity.Purpose_Key__c)) {
            throw new AuraHandledException('The identity purpose is inactive or invalid.');
        }
        identity.Verification_Status__c = 'Verified';
        identity.Verified_At__c = System.now();
        identity.Verified_By__c = UserInfo.getUserId();
        identity.Verification_Method__c = 'AdminAttestation';
        return saveVerification(identity);
    }

    @AuraEnabled
    public static Contact_Email__c revokeEmail(Id contactEmailId) {
        requireVerifier();
        Contact_Email__c identity = getIdentity(contactEmailId);
        identity.Verification_Status__c = 'Revoked';
        identity.Verified_At__c = null;
        identity.Verified_By__c = null;
        identity.Verification_Method__c = 'AdminAttestation';
        return saveVerification(identity);
    }

    private static Contact_Email__c getIdentity(Id contactEmailId) {
        if (contactEmailId == null) throw new AuraHandledException('A Contact email identity is required.');
        List<Contact_Email__c> rows = [
            SELECT Id, Email_Address__c, Active__c, Purpose_Key__c, Verification_Status__c,
                Verified_At__c, Verified_By__c, Verification_Method__c
            FROM Contact_Email__c
            WHERE Id = :contactEmailId
            WITH USER_MODE
            LIMIT 1
        ];
        if (rows.isEmpty()) throw new AuraHandledException('The Contact email identity is not available to you.');
        return rows[0];
    }

    private static Contact_Email__c saveVerification(Contact_Email__c identity) {
        CEI_ContactEmailService.allowVerificationMutation = true;
        try {
            Database.SaveResult result = Database.update(identity, AccessLevel.SYSTEM_MODE);
            if (!result.isSuccess()) throw new AuraHandledException('The verification change could not be saved.');
        } finally {
            CEI_ContactEmailService.allowVerificationMutation = false;
        }
        return getIdentity(identity.Id);
    }

    private static void requireVerifier() {
        if (Test.isRunningTest() && testPermissionOverride) return;
        if (!FeatureManagement.checkPermission('Verify_Contact_Email_Identity')) {
            throw new AuraHandledException('The Verify Contact Email Identity permission is required.');
        }
    }
}
