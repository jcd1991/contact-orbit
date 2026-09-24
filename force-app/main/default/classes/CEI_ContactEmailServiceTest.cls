@IsTest
private class CEI_ContactEmailServiceTest {
    @TestSetup
    static void setupData() {
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User packageUser = new User(
            Alias = 'ceiuser',
            Email = 'cei.user@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'CEI User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = 'cei.user.' + System.currentTimeMillis() + '@example.com'
        );
        insert packageUser;
        PermissionSet permissionSet = [
            SELECT Id FROM PermissionSet WHERE Name = 'Contact_Email_Identity_Admin' LIMIT 1
        ];
        insert new PermissionSetAssignment(AssigneeId = packageUser.Id, PermissionSetId = permissionSet.Id);

        System.runAs(packageUser) {
            Account account = new Account(Name = 'Identity Test Account');
            insert account;
            insert new Contact(
                FirstName = 'Avery',
                LastName = 'Jordan',
                AccountId = account.Id,
                Email = 'avery.primary@example.com'
            );
        }
    }

    @IsTest
    static void normalizesAndResolvesPurposeAddress() {
        Contact contact = [SELECT Id FROM Contact LIMIT 1];
        User packageUser = [SELECT Id FROM User WHERE Alias = 'ceiuser' LIMIT 1];
        Contact_Email__c workEmail;
        Contact_Email__c stored;
        List<CEI_ContactEmailService.ResolveResult> results;
        System.runAs(packageUser) {
            CEI_ContactEmailAttestation.testPermissionOverride = true;
            workEmail = new Contact_Email__c(
                Contact__c = contact.Id,
                Email_Address__c = '  AVERY.WORK@EXAMPLE.COM ',
                Purpose_Key__c = 'Work',
                Is_Primary__c = true,
                Active__c = true
            );
            insert workEmail;
            CEI_ContactEmailAttestation.verifyEmail(workEmail.Id);
            stored = [
                SELECT Normalized_Email_Key__c, Contact_Email_Key__c
                FROM Contact_Email__c
                WHERE Id = :workEmail.Id
            ];

            CEI_ContactEmailService.ResolveRequest request = new CEI_ContactEmailService.ResolveRequest();
            request.contactId = contact.Id;
            request.purposeKey = 'Work';
            Test.startTest();
            results = CEI_ContactEmailService.resolve(
                new List<CEI_ContactEmailService.ResolveRequest>{ request }
            );
            Test.stopTest();
        }

        System.assertEquals('avery.work@example.com', stored.Normalized_Email_Key__c);
        System.assertEquals(String.valueOf(contact.Id) + '|avery.work@example.com', stored.Contact_Email_Key__c);
        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].matched);
        System.assertEquals('avery.work@example.com', results[0].emailAddress);
        System.assertEquals(workEmail.Id, results[0].contactEmailId);
    }

    @IsTest
    static void fallsBackToContactEmail() {
        Contact contact = [SELECT Id, Email FROM Contact LIMIT 1];
        CEI_ContactEmailService.ResolveRequest request = new CEI_ContactEmailService.ResolveRequest();
        request.contactId = contact.Id;
        request.purposeKey = 'Billing';
        request.allowContactEmailFallback = true;

        User packageUser = [SELECT Id FROM User WHERE Alias = 'ceiuser' LIMIT 1];
        List<CEI_ContactEmailService.ResolveResult> results;
        System.runAs(packageUser) {
            results = CEI_ContactEmailService.resolve(
                new List<CEI_ContactEmailService.ResolveRequest>{ request }
            );
        }

        System.assertEquals(false, results[0].matched);
        System.assertEquals(contact.Email, results[0].emailAddress);
    }

    @IsTest
    static void rejectsTwoActivePrimariesForSamePurpose() {
        Contact contact = [SELECT Id FROM Contact LIMIT 1];
        User packageUser = [SELECT Id FROM User WHERE Alias = 'ceiuser' LIMIT 1];
        Database.SaveResult result;
        System.runAs(packageUser) {
            insert new Contact_Email__c(
                Contact__c = contact.Id,
                Email_Address__c = 'first@example.com',
                Purpose_Key__c = 'Support',
                Is_Primary__c = true,
                Active__c = true
            );

            Contact_Email__c duplicatePrimary = new Contact_Email__c(
                Contact__c = contact.Id,
                Email_Address__c = 'second@example.com',
                Purpose_Key__c = 'Support',
                Is_Primary__c = true,
                Active__c = true
            );
            result = Database.insert(duplicatePrimary, false);
        }
        System.assertEquals(false, result.isSuccess());
        System.assert(result.getErrors()[0].getMessage().contains('Only one active primary email'));
    }

    @IsTest
    static void controllerReturnsVisibleContactEmails() {
        Contact contact = [SELECT Id FROM Contact LIMIT 1];
        User packageUser = [SELECT Id FROM User WHERE Alias = 'ceiuser' LIMIT 1];
        List<Contact_Email__c> results;
        System.runAs(packageUser) {
            CEI_ContactEmailController.createEmail(
                contact.Id,
                'personal@example.com',
                'Personal',
                true
            );
            Test.startTest();
            results = CEI_ContactEmailController.getEmails(contact.Id);
            Test.stopTest();
        }
        System.assertEquals(1, results.size());
        System.assertEquals('personal@example.com', results[0].Email_Address__c);
    }

    @IsTest
    static void controllerRejectsMissingContact() {
        Boolean rejected = false;
        try {
            CEI_ContactEmailController.createEmail(null, 'missing@example.com', 'General', false);
            System.assert(false, 'Expected a missing Contact to be rejected.');
        } catch (AuraHandledException error) {
            rejected = true;
        }
        System.assert(rejected, 'Expected a missing Contact to be rejected.');
    }

    @IsTest
    static void resolverHandlesTwoHundredRequestsWithinGovernorBudget() {
        Contact contact = [SELECT Id FROM Contact LIMIT 1];
        User packageUser = [SELECT Id FROM User WHERE Alias = 'ceiuser' LIMIT 1];
        List<CEI_ContactEmailService.ResolveRequest> requests = new List<CEI_ContactEmailService.ResolveRequest>();
        for (Integer index = 0; index < 200; index++) {
            CEI_ContactEmailService.ResolveRequest request = new CEI_ContactEmailService.ResolveRequest();
            request.contactId = contact.Id;
            request.purposeKey = 'Billing';
            request.allowContactEmailFallback = true;
            requests.add(request);
        }

        List<CEI_ContactEmailService.ResolveResult> results;
        System.runAs(packageUser) {
            Test.startTest();
            results = CEI_ContactEmailService.resolve(requests);
            Integer queryCount = Limits.getQueries();
            Integer dmlCount = Limits.getDmlStatements();
            Test.stopTest();
            System.assert(queryCount <= 2, 'Resolver should use one Contact query and one identity query for a bulk request.');
            System.assertEquals(0, dmlCount, 'Resolver must not perform DML.');
        }
        System.assertEquals(200, results.size());
        System.assertEquals('avery.primary@example.com', results[0].emailAddress);
        System.assertEquals('avery.primary@example.com', results[199].emailAddress);
    }
}
