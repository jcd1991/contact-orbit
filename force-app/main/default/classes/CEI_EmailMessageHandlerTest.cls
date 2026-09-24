@IsTest
private class CEI_EmailMessageHandlerTest {
    @TestSetup
    static void setupPackageUser() {
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User packageUser = new User(
            Alias = 'ceimsg',
            Email = 'cei.messages@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'CEI Messages',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = 'cei.messages.' + System.currentTimeMillis() + '@example.com'
        );
        insert packageUser;
        PermissionSet permissionSet = [
            SELECT Id FROM PermissionSet WHERE Name = 'Contact_Email_Identity_Admin' LIMIT 1
        ];
        insert new PermissionSetAssignment(AssigneeId = packageUser.Id, PermissionSetId = permissionSet.Id);
    }

    @IsTest
    static void linksUnambiguousAlternateAddressToCase() {
        User packageUser = [SELECT Id FROM User WHERE Alias = 'ceimsg' LIMIT 1];
        Id expectedContactId;
        Id supportCaseId;
        System.runAs(packageUser) {
            CEI_ContactEmailAttestation.testPermissionOverride = true;
            insert new Contact_Email_Settings__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                Enable_Email_To_Case_Suggestions__c = true,
                Enable_Verified_Auto_Link__c = true,
                Match_Log_Retention_Days__c = 90
            );

            Account account = new Account(Name = 'Support Account');
            insert account;
            Contact contact = new Contact(LastName = 'Support Contact', AccountId = account.Id);
            insert contact;
            expectedContactId = contact.Id;
            Contact_Email__c identity = new Contact_Email__c(
                Contact__c = contact.Id,
                Email_Address__c = 'alternate@example.com',
                Purpose_Key__c = 'Support',
                Is_Primary__c = true,
                Active__c = true
            );
            insert identity;
            CEI_ContactEmailAttestation.verifyEmail(identity.Id);
            Case supportCase = new Case(Subject = 'Alternate identity', Origin = 'Email');
            insert supportCase;
            supportCaseId = supportCase.Id;

            Test.startTest();
            insert new EmailMessage(
                ParentId = supportCase.Id,
                Incoming = true,
                Status = '0',
                Subject = 'Need help',
                FromAddress = 'ALTERNATE@example.com',
                ToAddress = 'support@example.com',
                TextBody = 'Please help.'
            );
            Test.stopTest();
        }

        Case supportCase = [SELECT ContactId FROM Case WHERE Id = :supportCaseId];
        System.assertEquals(expectedContactId, supportCase.ContactId);
        System.assertEquals(1, [SELECT COUNT() FROM Contact_Email_Match__c WHERE Case__c = :supportCaseId AND Status__c = 'AutoLinked']);
    }

    @IsTest
    static void doesNotLinkAmbiguousAddressOrOverwriteExistingContact() {
        User packageUser = [SELECT Id FROM User WHERE Alias = 'ceimsg' LIMIT 1];
        Id supportCaseId;
        System.runAs(packageUser) {
            CEI_ContactEmailAttestation.testPermissionOverride = true;
            insert new Contact_Email_Settings__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                Enable_Email_To_Case_Suggestions__c = true,
                Enable_Verified_Auto_Link__c = true
            );
            Account account = new Account(Name = 'Ambiguity Account');
            insert account;
            Contact firstContact = new Contact(LastName = 'First', AccountId = account.Id);
            Contact secondContact = new Contact(LastName = 'Second', AccountId = account.Id);
            insert new List<Contact>{ firstContact, secondContact };
            List<Contact_Email__c> identities = new List<Contact_Email__c>{
                new Contact_Email__c(
                    Contact__c = firstContact.Id,
                    Email_Address__c = 'shared@example.com',
                    Purpose_Key__c = 'General',
                    Is_Primary__c = true,
                    Active__c = true
                ),
                new Contact_Email__c(
                    Contact__c = secondContact.Id,
                    Email_Address__c = 'shared@example.com',
                    Purpose_Key__c = 'General',
                    Is_Primary__c = true,
                    Active__c = true
                )
            };
            insert identities;
            for (Contact_Email__c identity : identities) CEI_ContactEmailAttestation.verifyEmail(identity.Id);
            Case supportCase = new Case(Subject = 'Ambiguous identity', Origin = 'Email');
            insert supportCase;
            supportCaseId = supportCase.Id;

            insert new EmailMessage(
                ParentId = supportCase.Id,
                Incoming = true,
                Status = '0',
                Subject = 'Shared sender',
                FromAddress = 'shared@example.com',
                ToAddress = 'support@example.com',
                TextBody = 'Ambiguous sender.'
            );
        }

        Case supportCase = [SELECT ContactId FROM Case WHERE Id = :supportCaseId];
        System.assertEquals(null, supportCase.ContactId);
        System.assertEquals(1, [SELECT COUNT() FROM Contact_Email_Match__c WHERE Case__c = :supportCaseId AND Status__c = 'Ambiguous']);
    }

    @IsTest
    static void routesTwoHundredMessagesWithBoundedQueriesAndDml() {
        User packageUser = [SELECT Id FROM User WHERE Alias = 'ceimsg' LIMIT 1];
        Id contactId;
        List<Id> caseIds = new List<Id>();
        System.runAs(packageUser) {
            CEI_ContactEmailAttestation.testPermissionOverride = true;
            insert new Contact_Email_Settings__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                Enable_Email_To_Case_Suggestions__c = true,
                Enable_Verified_Auto_Link__c = true,
                Match_Log_Retention_Days__c = 90
            );
            Account account = new Account(Name = 'Bulk Support Account');
            insert account;
            Contact contact = new Contact(LastName = 'Bulk Support Contact', AccountId = account.Id);
            insert contact;
            contactId = contact.Id;
            Contact_Email__c identity = new Contact_Email__c(
                Contact__c = contact.Id,
                Email_Address__c = 'bulk@example.com',
                Purpose_Key__c = 'Support',
                Is_Primary__c = true,
                Active__c = true
            );
            insert identity;
            CEI_ContactEmailAttestation.verifyEmail(identity.Id);

            List<Case> cases = new List<Case>();
            for (Integer index = 0; index < 200; index++) {
                cases.add(new Case(Subject = 'Bulk routing ' + index, Origin = 'Email'));
            }
            insert cases;
            for (Case supportCase : cases) caseIds.add(supportCase.Id);

            List<EmailMessage> messages = new List<EmailMessage>();
            for (Case supportCase : cases) {
                messages.add(new EmailMessage(
                    ParentId = supportCase.Id,
                    Incoming = true,
                    Status = '0',
                    Subject = 'Bulk sender',
                    FromAddress = 'bulk@example.com',
                    ToAddress = 'support@example.com',
                    TextBody = 'Bulk routing test.'
                ));
            }

            Test.startTest();
            insert messages;
            Integer queryCount = Limits.getQueries();
            Integer dmlCount = Limits.getDmlStatements();
            Test.stopTest();
            System.assert(queryCount <= 4, 'Email routing should stay within a small fixed query budget for 200 messages.');
            System.assert(dmlCount <= 4, 'Email routing should use one insert plus grouped audit and Case writes.');
        }

        System.assertEquals(200, [SELECT COUNT() FROM Contact_Email_Match__c WHERE Source_Email_Message_Id__c != null AND Status__c = 'AutoLinked']);
        System.assertEquals(200, [SELECT COUNT() FROM Case WHERE Id IN :caseIds AND ContactId = :contactId]);
    }
}
