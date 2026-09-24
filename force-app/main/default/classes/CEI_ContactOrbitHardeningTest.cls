@IsTest
private class CEI_ContactOrbitHardeningTest {
    @TestSetup
    static void setupData() {
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User testUser = new User(
            Alias = 'cohard',
            Email = 'contact.orbit.hardening@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Contact Orbit',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = 'contact.orbit.hardening.' + System.currentTimeMillis() + '@example.com'
        );
        insert testUser;
        User ordinaryUser = new User(
            Alias = 'coordny',
            Email = 'contact.orbit.ordinary@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Contact Orbit Ordinary',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = 'contact.orbit.ordinary.' + System.currentTimeMillis() + '@example.com'
        );
        insert ordinaryUser;
        PermissionSet admin = [SELECT Id FROM PermissionSet WHERE Name = 'Contact_Email_Identity_Admin' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = testUser.Id, PermissionSetId = admin.Id);
        System.runAs(testUser) {
            Account account = new Account(Name = 'Contact Orbit Hardening');
            insert account;
            insert new Contact(LastName = 'Resolver', AccountId = account.Id, Email = 'contact.fallback@example.com');
        }
    }

    @IsTest
    static void resolverPreservesOrderAndUsesExplicitFallback() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'cohard' LIMIT 1];
        Contact contact = [SELECT Id, Email FROM Contact WHERE LastName = 'Resolver' LIMIT 1];
        System.runAs(testUser) {
            CEI_ContactEmailService.ResolveRequest noFallback = new CEI_ContactEmailService.ResolveRequest();
            noFallback.contactId = contact.Id;
            noFallback.purposeKey = 'General';
            noFallback.allowContactEmailFallback = false;
            CEI_ContactEmailService.ResolveRequest explicitFallback = new CEI_ContactEmailService.ResolveRequest();
            explicitFallback.contactId = contact.Id;
            explicitFallback.purposeKey = 'General';
            explicitFallback.allowContactEmailFallback = true;
            CEI_ContactEmailService.ResolveRequest invalid = new CEI_ContactEmailService.ResolveRequest();
            invalid.contactId = contact.Id;
            invalid.purposeKey = 'NotARealPurpose';
            List<CEI_ContactEmailService.ResolveResult> results = CEI_ContactEmailService.resolve(
                new List<CEI_ContactEmailService.ResolveRequest>{ noFallback, explicitFallback, invalid }
            );
            System.assertEquals(3, results.size());
            System.assertEquals('NO_MATCH', results[0].outcomeCode);
            System.assertEquals('CONTACT_EMAIL_FALLBACK', results[1].outcomeCode);
            System.assertEquals(contact.Email, results[1].emailAddress);
            System.assertEquals('INVALID_REQUEST', results[2].outcomeCode);
        }
    }

    @IsTest
    static void unauthorizedUserCannotAttestOrConfigure() {
        User ordinaryUser = [SELECT Id FROM User WHERE Alias = 'coordny' LIMIT 1];
        System.runAs(ordinaryUser) {
            CEI_ContactEmailAttestation.testPermissionOverride = false;
            CEI_ContactEmailRoutingController.testPermissionOverride = false;
            CEI_ContactEmailRoutingController.testPermissionDenied = false;
            try {
                CEI_ContactEmailAttestation.verifyEmail(null);
                System.assert(false, 'Verification permission should be required.');
            } catch (AuraHandledException expected) {
                System.assert(true);
            }
            try {
                CEI_ContactEmailRoutingController.saveSettings(true, false, 90);
                System.assert(false, 'Routing administration permission should be required.');
            } catch (AuraHandledException expected) {
                System.assert(true);
            }
        }
    }

    @IsTest
    static void emailChangeResetsVerification() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'cohard' LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE LastName = 'Resolver' LIMIT 1];
        System.runAs(testUser) {
            CEI_ContactEmailAttestation.testPermissionOverride = true;
            Contact_Email__c untrustedInsert = new Contact_Email__c(
                    Contact__c = contact.Id,
                    Email_Address__c = 'untrusted-insert@example.com',
                    Purpose_Key__c = 'Work',
                    Active__c = true,
                    Verification_Status__c = 'Verified'
                );
            insert untrustedInsert;
            System.assertEquals('Unverified', [SELECT Verification_Status__c FROM Contact_Email__c WHERE Id = :untrustedInsert.Id].Verification_Status__c);
            Contact_Email__c identity = new Contact_Email__c(Contact__c = contact.Id, Email_Address__c = 'reset@example.com', Purpose_Key__c = 'Work', Active__c = true);
            insert identity;
            CEI_ContactEmailAttestation.verifyEmail(identity.Id);
            identity = [SELECT Id, Email_Address__c, Verification_Status__c FROM Contact_Email__c WHERE Id = :identity.Id];
            identity.Email_Address__c = 'changed@example.com';
            update identity;
            identity = [SELECT Verification_Status__c, Verified_At__c, Verified_By__c FROM Contact_Email__c WHERE Id = :identity.Id];
            System.assertEquals('Unverified', identity.Verification_Status__c);
            System.assertEquals(null, identity.Verified_At__c);
            System.assertEquals(null, identity.Verified_By__c);
        }
    }

    @IsTest
    static void suggestionModeIsSafeAndRetryIdempotent() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'cohard' LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE LastName = 'Resolver' LIMIT 1];
        Id caseId;
        Id emailMessageId;
        System.runAs(testUser) {
            CEI_ContactEmailAttestation.testPermissionOverride = true;
            insert new Contact_Email_Settings__c(SetupOwnerId = UserInfo.getOrganizationId(), Enable_Email_To_Case_Suggestions__c = true, Enable_Verified_Auto_Link__c = false, Match_Log_Retention_Days__c = 90);
            Contact_Email__c identity = new Contact_Email__c(Contact__c = contact.Id, Email_Address__c = 'suggest@example.com', Purpose_Key__c = 'Support', Active__c = true);
            insert identity;
            CEI_ContactEmailAttestation.verifyEmail(identity.Id);
            Case supportCase = new Case(Subject = 'Suggestion only', Origin = 'Email');
            insert supportCase;
            caseId = supportCase.Id;
            EmailMessage message = new EmailMessage(ParentId = caseId, Incoming = true, Status = '0', Subject = 'Suggestion', FromAddress = 'suggest@example.com', ToAddress = 'support@example.com', TextBody = 'Hello');
            insert message;
            emailMessageId = message.Id;
            CEI_EmailMessageHandler.afterInsert(new List<EmailMessage>{ message });
        }
        System.assertEquals(null, [SELECT ContactId FROM Case WHERE Id = :caseId].ContactId);
        System.assertEquals(1, [SELECT COUNT() FROM Contact_Email_Match__c WHERE Source_Email_Message_Id__c = :String.valueOf(emailMessageId) AND Status__c = 'Suggested']);
    }

    @IsTest
    static void retentionDeletesOnlyTerminalRows() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'cohard' LIMIT 1];
        Id matchId;
        System.runAs(testUser) {
            CEI_ContactEmailAttestation.testPermissionOverride = true;
            insert new Contact_Email_Settings__c(SetupOwnerId = UserInfo.getOrganizationId(), Match_Log_Retention_Days__c = 800);
            Account account = new Account(Name = 'Retention Account');
            insert account;
            Case supportCase = new Case(Subject = 'Retention', Origin = 'Phone');
            insert supportCase;
            matchId = supportCase.Id;
        }
        Contact_Email_Match__c match = new Contact_Email_Match__c(Case__c = matchId, Source_Email_Message_Id__c = '000000000000001AAA', Status__c = 'Rejected', Reason_Code__c = 'USER_REJECTED', Occurred_At__c = System.now().addDays(-120));
        insert match;
        Id auditId = match.Id;
        Database.QueryLocator locator = new CEI_ContactEmailRetentionBatch().start(null);
        System.assertNotEquals(null, locator);
        Test.startTest();
        new CEI_ContactEmailRetentionBatch().execute(null, new List<SObject>{ match });
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM Contact_Email_Match__c WHERE Id = :auditId]);
    }

    @IsTest
    static void routingControllerExposesSetupAndRejectsSuggestion() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'cohard' LIMIT 1];
        System.runAs(testUser) {
            CEI_ContactEmailRoutingController.testPermissionOverride = true;
            CEI_ContactEmailAttestation.testPermissionOverride = true;
            CEI_ContactEmailRoutingController.SetupState state = CEI_ContactEmailRoutingController.getSetupState();
            System.assertNotEquals(null, state);
            System.assert(state.retentionDays >= 30 && state.retentionDays <= 730);
            System.assertEquals(0, CEI_ContactEmailRoutingController.getMatches(null).size());
            CEI_ContactEmailRoutingController.SetupState saved = CEI_ContactEmailRoutingController.saveSettings(true, false, 45);
            System.assertEquals(true, saved.suggestionsEnabled);
            CEI_ContactEmailRoutingController.saveSettings(true, true, 10);
            CEI_ContactEmailRoutingController.saveSettings(true, true, 800);
            CEI_ContactEmailRoutingController.scheduleRetention();

            Contact contact = [SELECT Id FROM Contact WHERE LastName = 'Resolver' LIMIT 1];
            Contact_Email__c identity = new Contact_Email__c(Contact__c = contact.Id, Email_Address__c = 'reject@example.com', Purpose_Key__c = 'Billing', Active__c = true);
            insert identity;
            CEI_ContactEmailAttestation.verifyEmail(identity.Id);
            Contact_Email__c inactive = new Contact_Email__c(Contact__c = contact.Id, Email_Address__c = 'inactive@example.com', Purpose_Key__c = 'Other', Active__c = false);
            insert inactive;
            try {
                CEI_ContactEmailAttestation.verifyEmail(inactive.Id);
                System.assert(false, 'Expected inactive verification to fail.');
            } catch (AuraHandledException expected) {
                System.assert(true);
            }
            Case supportCase = new Case(Subject = 'Reject suggestion', Origin = 'Email');
            insert supportCase;
            Contact_Email_Match__c suggestion = new Contact_Email_Match__c(Case__c = supportCase.Id, Candidate_Contact__c = contact.Id, Contact_Email__c = identity.Id, Source_Email_Message_Id__c = '000000000000003AAA', Status__c = 'Suggested', Reason_Code__c = 'UNIQUE_MATCH', Occurred_At__c = System.now());
            insert suggestion;
            System.assertEquals(1, CEI_ContactEmailRoutingController.getMatches(supportCase.Id).size());
            Contact_Email_Match__c rejected = CEI_ContactEmailRoutingController.rejectMatch(suggestion.Id);
            System.assertEquals('Rejected', rejected.Status__c);
            Contact_Email__c revoked = CEI_ContactEmailAttestation.revokeEmail(identity.Id);
            System.assertEquals('Revoked', revoked.Verification_Status__c);
        }
    }

    @IsTest
    static void controllerSupportsPurposeOptionsAndDeactivate() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'cohard' LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE LastName = 'Resolver' LIMIT 1];
        System.runAs(testUser) {
            CEI_ContactEmailAttestation.testPermissionOverride = true;
            List<CEI_ContactEmailController.PurposeOption> purposes = CEI_ContactEmailController.getPurposeOptions();
            System.assert(purposes.size() >= 6);
            CEI_ContactEmailController.createEmail(contact.Id, 'duplicate-controller@example.com', 'General', true);
            try {
                CEI_ContactEmailController.createEmail(contact.Id, 'duplicate-controller-2@example.com', 'General', true);
                System.assert(false, 'Expected the primary conflict to be rejected.');
            } catch (AuraHandledException expected) {
                System.assert(true);
            }
            try {
                CEI_ContactEmailController.createEmail(contact.Id, 'duplicate-controller@example.com', 'Other', false);
                System.assert(false, 'Expected the duplicate identity key to be rejected.');
            } catch (AuraHandledException expected) {
                System.assert(true);
            }
            Contact_Email__c identity = CEI_ContactEmailController.createEmail(contact.Id, 'deactivate@example.com', 'Other', false);
            Contact_Email__c deactivated = CEI_ContactEmailController.deactivateEmail(identity.Id);
            System.assertEquals(false, deactivated.Active__c);
            System.assertEquals(0, CEI_ContactEmailController.getEmails(null).size());
            try {
                CEI_ContactEmailController.deactivateEmail(null);
                System.assert(false, 'Expected a missing identity to be rejected.');
            } catch (AuraHandledException expected) {
                System.assert(true);
            }
        }
    }

    @IsTest
    static void routingControllerConfirmsVerifiedSuggestion() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'cohard' LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE LastName = 'Resolver' LIMIT 1];
        System.runAs(testUser) {
            CEI_ContactEmailRoutingController.testPermissionOverride = true;
            CEI_ContactEmailAttestation.testPermissionOverride = true;
            Contact_Email__c identity = new Contact_Email__c(Contact__c = contact.Id, Email_Address__c = 'confirm@example.com', Purpose_Key__c = 'Work', Active__c = true);
            insert identity;
            CEI_ContactEmailAttestation.verifyEmail(identity.Id);
            Case supportCase = new Case(Subject = 'Confirm suggestion', Origin = 'Email');
            insert supportCase;
            Contact_Email_Match__c suggestion = new Contact_Email_Match__c(Case__c = supportCase.Id, Candidate_Contact__c = contact.Id, Contact_Email__c = identity.Id, Source_Email_Message_Id__c = '000000000000004AAA', Status__c = 'Suggested', Reason_Code__c = 'UNIQUE_MATCH', Occurred_At__c = System.now());
            insert suggestion;
            Contact_Email_Match__c stale = new Contact_Email_Match__c(Case__c = supportCase.Id, Candidate_Contact__c = contact.Id, Contact_Email__c = identity.Id, Source_Email_Message_Id__c = '000000000000005AAA', Status__c = 'Suggested', Reason_Code__c = 'UNIQUE_MATCH', Occurred_At__c = System.now());
            insert stale;
            Contact_Email_Match__c confirmed = CEI_ContactEmailRoutingController.confirmMatch(suggestion.Id);
            System.assertEquals('Confirmed', confirmed.Status__c);
            System.assertEquals(contact.Id, [SELECT ContactId FROM Case WHERE Id = :supportCase.Id].ContactId);
        }
    }

    @IsTest
    static void routingControllerCoversConflictAndPermissionFailures() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'cohard' LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE LastName = 'Resolver' LIMIT 1];
        System.runAs(testUser) {
            CEI_ContactEmailRoutingController.testPermissionOverride = true;
            CEI_ContactEmailAttestation.testPermissionOverride = true;
            Contact_Email__c identity = new Contact_Email__c(Contact__c = contact.Id, Email_Address__c = 'failure-path@example.com', Purpose_Key__c = 'Work', Active__c = true);
            insert identity;
            CEI_ContactEmailAttestation.verifyEmail(identity.Id);
            Case existingContactCase = new Case(Subject = 'Existing Contact', Origin = 'Email', ContactId = contact.Id);
            insert existingContactCase;
            Contact_Email_Match__c existingContactSuggestion = new Contact_Email_Match__c(Case__c = existingContactCase.Id, Candidate_Contact__c = contact.Id, Contact_Email__c = identity.Id, Source_Email_Message_Id__c = '000000000000006AAA', Status__c = 'Suggested', Reason_Code__c = 'UNIQUE_MATCH', Occurred_At__c = System.now());
            insert existingContactSuggestion;
            try {
                CEI_ContactEmailRoutingController.confirmMatch(existingContactSuggestion.Id);
                System.assert(false, 'Expected an existing Case Contact to supersede the suggestion.');
            } catch (AuraHandledException expected) {
                System.assert(true);
            }

            Contact_Email_Match__c rejected = new Contact_Email_Match__c(Case__c = existingContactCase.Id, Candidate_Contact__c = contact.Id, Contact_Email__c = identity.Id, Source_Email_Message_Id__c = '000000000000007AAA', Status__c = 'Rejected', Reason_Code__c = 'USER_REJECTED', Occurred_At__c = System.now());
            insert rejected;
            try {
                CEI_ContactEmailRoutingController.rejectMatch(rejected.Id);
                System.assert(false, 'Expected a terminal suggestion to be rejected.');
            } catch (AuraHandledException expected) {
                System.assert(true);
            }

            CEI_ContactEmailAttestation.revokeEmail(identity.Id);
            Case revokedCase = new Case(Subject = 'Revoked identity', Origin = 'Email');
            insert revokedCase;
            Contact_Email_Match__c revokedSuggestion = new Contact_Email_Match__c(Case__c = revokedCase.Id, Candidate_Contact__c = contact.Id, Contact_Email__c = identity.Id, Source_Email_Message_Id__c = '000000000000008AAA', Status__c = 'Suggested', Reason_Code__c = 'UNIQUE_MATCH', Occurred_At__c = System.now());
            insert revokedSuggestion;
            try {
                CEI_ContactEmailRoutingController.confirmMatch(revokedSuggestion.Id);
                System.assert(false, 'Expected revoked identity confirmation to fail.');
            } catch (AuraHandledException expected) {
                System.assert(true);
            }

            CEI_ContactEmailRoutingController.testPermissionOverride = false;
            CEI_ContactEmailRoutingController.testPermissionDenied = true;
            try {
                CEI_ContactEmailRoutingController.rejectMatch(revokedSuggestion.Id);
                System.assert(false, 'Expected confirmation permission to be required.');
            } catch (AuraHandledException expected) {
                System.assert(true);
            }
            try {
                CEI_ContactEmailRoutingController.saveSettings(true, false, 90);
                System.assert(false, 'Expected administrator permission to be required.');
            } catch (AuraHandledException expected) {
                System.assert(true);
            }
            CEI_ContactEmailRoutingController.testPermissionDenied = false;
        }
    }
}
