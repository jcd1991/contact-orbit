public with sharing class CEI_ContactEmailRoutingController {
    @TestVisible private static Boolean testPermissionOverride = false;
    @TestVisible private static Boolean testPermissionDenied = false;
    public class SetupState {
        @AuraEnabled public Boolean suggestionsEnabled;
        @AuraEnabled public Boolean autoLinkEnabled;
        @AuraEnabled public Integer retentionDays;
        @AuraEnabled public Boolean caseUpdateable;
        @AuraEnabled public Boolean contactUpdateable;
        @AuraEnabled public String packageVersion;
    }

    @AuraEnabled(cacheable=true)
    public static List<Contact_Email_Match__c> getMatches(Id caseId) {
        if (caseId == null) return new List<Contact_Email_Match__c>();
        return [
            SELECT Id, Case__c, Candidate_Contact__c, Candidate_Contact__r.Name,
                Contact_Email__c, Status__c, Reason_Code__c, Occurred_At__c,
                Confirmed_At__c, Confirmed_By__c, Error_Code__c, Error_Message__c
            FROM Contact_Email_Match__c
            WHERE Case__c = :caseId
              AND Status__c IN ('Suggested', 'Ambiguous', 'Failed')
            WITH USER_MODE
            ORDER BY Occurred_At__c DESC
        ];
    }

    @AuraEnabled
    public static Contact_Email_Match__c confirmMatch(Id matchId) {
        requireConfirmationPermission();
        Contact_Email_Match__c match = getMatch(matchId);
        if (match.Status__c != 'Suggested' || match.Candidate_Contact__c == null) {
            throw new AuraHandledException('Only an unambiguous suggested match can be confirmed.');
        }
        Contact_Email__c identity = getVerifiedIdentity(match.Contact_Email__c);

        if (!Schema.sObjectType.Case.isUpdateable() || !Schema.sObjectType.Case.fields.ContactId.isUpdateable()) {
            throw new AuraHandledException('You do not have Case Contact edit access.');
        }
        Case lockedCase = [SELECT Id, ContactId FROM Case WHERE Id = :match.Case__c FOR UPDATE];
        if (lockedCase.ContactId != null) {
            match.Status__c = 'Superseded';
            match.Reason_Code__c = 'EXISTING_CONTACT';
            saveMatch(match);
            throw new AuraHandledException('The Case already has a Contact; the suggestion was superseded.');
        }

        lockedCase.ContactId = identity.Contact__c;
        Database.SaveResult caseResult = Database.update(lockedCase, AccessLevel.USER_MODE);
        if (!caseResult.isSuccess()) {
            match.Status__c = 'Failed';
            match.Reason_Code__c = 'UPDATE_FAILED';
            match.Error_Code__c = 'CASE_UPDATE_FAILED';
            match.Error_Message__c = 'The Case Contact could not be updated in the current access context.';
            saveMatch(match);
            throw new AuraHandledException('The Case could not be updated.');
        }

        match.Status__c = 'Confirmed';
        match.Reason_Code__c = 'USER_CONFIRMED';
        match.Confirmed_At__c = System.now();
        match.Confirmed_By__c = UserInfo.getUserId();
        saveMatch(match);

        List<Contact_Email_Match__c> stale = [
            SELECT Id, Status__c, Reason_Code__c
            FROM Contact_Email_Match__c
            WHERE Case__c = :match.Case__c AND Id != :match.Id AND Status__c IN ('Suggested', 'Ambiguous')
            WITH USER_MODE
        ];
        for (Contact_Email_Match__c staleMatch : stale) {
            staleMatch.Status__c = 'Superseded';
            staleMatch.Reason_Code__c = 'EXISTING_CONTACT';
        }
        if (!stale.isEmpty()) Database.update(stale, false, AccessLevel.USER_MODE);
        return getMatch(match.Id);
    }

    @AuraEnabled
    public static Contact_Email_Match__c rejectMatch(Id matchId) {
        requireConfirmationPermission();
        Contact_Email_Match__c match = getMatch(matchId);
        if (match.Status__c != 'Suggested' && match.Status__c != 'Ambiguous') {
            throw new AuraHandledException('This match is no longer actionable.');
        }
        match.Status__c = 'Rejected';
        match.Reason_Code__c = 'USER_REJECTED';
        match.Confirmed_At__c = System.now();
        match.Confirmed_By__c = UserInfo.getUserId();
        saveMatch(match);
        return getMatch(match.Id);
    }

    @AuraEnabled(cacheable=true)
    public static SetupState getSetupState() {
        Contact_Email_Settings__c settings = Contact_Email_Settings__c.getOrgDefaults();
        SetupState state = new SetupState();
        state.suggestionsEnabled = settings != null && settings.Enable_Email_To_Case_Suggestions__c == true;
        state.autoLinkEnabled = settings != null && settings.Enable_Verified_Auto_Link__c == true && state.suggestionsEnabled;
        Decimal retention = settings == null ? 90 : settings.Match_Log_Retention_Days__c;
        state.retentionDays = clampRetention(retention);
        state.caseUpdateable = Schema.sObjectType.Case.isUpdateable() && Schema.sObjectType.Case.fields.ContactId.isUpdateable();
        state.contactUpdateable = Schema.sObjectType.Contact.isUpdateable();
        state.packageVersion = 'Source build (managed namespace pending)';
        return state;
    }

    @AuraEnabled
    public static SetupState saveSettings(Boolean suggestionsEnabled, Boolean autoLinkEnabled, Integer retentionDays) {
        requireAdminPermission();
        Contact_Email_Settings__c settings = Contact_Email_Settings__c.getOrgDefaults();
        if (settings == null) settings = new Contact_Email_Settings__c(SetupOwnerId = UserInfo.getOrganizationId());
        settings.Enable_Email_To_Case_Suggestions__c = suggestionsEnabled == true;
        settings.Enable_Verified_Auto_Link__c = suggestionsEnabled == true && autoLinkEnabled == true;
        settings.Match_Log_Retention_Days__c = clampRetention(retentionDays);
        Database.SaveResult result = settings.Id == null
            ? Database.insert(settings, AccessLevel.USER_MODE)
            : Database.update(settings, AccessLevel.USER_MODE);
        if (!result.isSuccess()) throw new AuraHandledException('Routing settings could not be saved.');
        return getSetupState();
    }

    @AuraEnabled
    public static String scheduleRetention() {
        requireAdminPermission();
        String jobName = 'Contact Orbit Retention ' + String.valueOf(DateTime.now().getTime());
        System.schedule(jobName, '0 0 2 * * ?', new CEI_ContactEmailRetentionBatch());
        return jobName;
    }

    private static Contact_Email_Match__c getMatch(Id matchId) {
        if (matchId == null) throw new AuraHandledException('A match suggestion is required.');
        List<Contact_Email_Match__c> rows = [
            SELECT Id, Case__c, Candidate_Contact__c, Contact_Email__c, Status__c, Reason_Code__c,
                Confirmed_At__c, Confirmed_By__c, Error_Code__c, Error_Message__c
            FROM Contact_Email_Match__c
            WHERE Id = :matchId
            WITH USER_MODE
            LIMIT 1
        ];
        if (rows.isEmpty()) throw new AuraHandledException('The match suggestion is not available to you.');
        return rows[0];
    }

    private static Contact_Email__c getVerifiedIdentity(Id identityId) {
        List<Contact_Email__c> rows = [
            SELECT Id, Contact__c, Active__c, Verification_Status__c
            FROM Contact_Email__c
            WHERE Id = :identityId
            WITH USER_MODE
            LIMIT 1
        ];
        if (rows.isEmpty() || rows[0].Active__c != true || rows[0].Verification_Status__c != 'Verified') {
            throw new AuraHandledException('The identity is no longer active and verified.');
        }
        return rows[0];
    }

    private static void saveMatch(Contact_Email_Match__c match) {
        // Match audit rows are controlled by the parent Case and contain no raw sender address.
        // Case and identity changes remain USER_MODE; this bounded system-mode write preserves
        // the audit failure state even when the confirming user has read-only audit access.
        Database.SaveResult result = Database.update(match, AccessLevel.SYSTEM_MODE);
        if (!result.isSuccess()) throw new AuraHandledException('The match audit could not be saved.');
    }

    private static Integer clampRetention(Decimal value) {
        Integer days = value == null ? 90 : Integer.valueOf(value);
        if (days < 30) return 30;
        if (days > 730) return 730;
        return days;
    }

    private static void requireConfirmationPermission() {
        if (Test.isRunningTest() && testPermissionDenied) {
            throw new AuraHandledException('The Confirm Contact Email Match permission is required.');
        }
        if (Test.isRunningTest() && testPermissionOverride) return;
        if (!FeatureManagement.checkPermission('Confirm_Contact_Email_Match')) {
            throw new AuraHandledException('The Confirm Contact Email Match permission is required.');
        }
    }

    private static void requireAdminPermission() {
        if (Test.isRunningTest() && testPermissionDenied) {
            throw new AuraHandledException('The Manage Contact Email Routing permission is required.');
        }
        if (Test.isRunningTest() && testPermissionOverride) return;
        if (!FeatureManagement.checkPermission('Manage_Contact_Email_Routing')) {
            throw new AuraHandledException('The Manage Contact Email Routing permission is required.');
        }
    }
}
