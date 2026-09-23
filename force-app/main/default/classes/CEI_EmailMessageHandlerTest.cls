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
            insert new Contact_Email_Settings__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                Enable_Email_To_Case_Matching__c = true
            );

            Account account = new Account(Name = 'Support Account');
            insert account;
            Contact contact = new Contact(LastName = 'Support Contact', AccountId = account.Id);
            insert contact;
            expectedContactId = contact.Id;
            insert new Contact_Email__c(
                Contact__c = contact.Id,
                Email_Address__c = 'alternate@example.com',
                Purpose__c = 'Support',
                Is_Primary__c = true,
                Active__c = true
            );
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
    }

    @IsTest
    static void doesNotLinkAmbiguousAddressOrOverwriteExistingContact() {
        User packageUser = [SELECT Id FROM User WHERE Alias = 'ceimsg' LIMIT 1];
        Id supportCaseId;
        System.runAs(packageUser) {
            insert new Contact_Email_Settings__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                Enable_Email_To_Case_Matching__c = true
            );
            Account account = new Account(Name = 'Ambiguity Account');
            insert account;
            Contact firstContact = new Contact(LastName = 'First', AccountId = account.Id);
            Contact secondContact = new Contact(LastName = 'Second', AccountId = account.Id);
            insert new List<Contact>{ firstContact, secondContact };
            insert new List<Contact_Email__c>{
                new Contact_Email__c(
                    Contact__c = firstContact.Id,
                    Email_Address__c = 'shared@example.com',
                    Purpose__c = 'General',
                    Is_Primary__c = true,
                    Active__c = true
                ),
                new Contact_Email__c(
                    Contact__c = secondContact.Id,
                    Email_Address__c = 'shared@example.com',
                    Purpose__c = 'General',
                    Is_Primary__c = true,
                    Active__c = true
                )
            };
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
    }
}
