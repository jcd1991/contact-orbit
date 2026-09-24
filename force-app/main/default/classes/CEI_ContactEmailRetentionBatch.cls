global with sharing class CEI_ContactEmailRetentionBatch implements Database.Batchable<SObject>, Schedulable {
    global Database.QueryLocator start(Database.BatchableContext context) {
        Integer days = 90;
        Contact_Email_Settings__c settings = Contact_Email_Settings__c.getOrgDefaults();
        if (settings != null && settings.Match_Log_Retention_Days__c != null) {
            days = settings.Match_Log_Retention_Days__c < 30 ? 30 : (settings.Match_Log_Retention_Days__c > 730 ? 730 : Integer.valueOf(settings.Match_Log_Retention_Days__c));
        }
        DateTime cutoff = System.now().addDays(-days);
        return Database.getQueryLocator([
            SELECT Id
            FROM Contact_Email_Match__c
            WHERE Status__c IN ('Confirmed', 'Rejected', 'AutoLinked', 'Failed', 'Superseded')
              AND Occurred_At__c < :cutoff
            WITH SYSTEM_MODE
        ]);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        if (scope == null || scope.isEmpty()) return;
        Database.delete(scope, false, AccessLevel.SYSTEM_MODE);
    }

    global void finish(Database.BatchableContext context) { }

    global void execute(SchedulableContext context) {
        Database.executeBatch(new CEI_ContactEmailRetentionBatch(), 200);
    }
}
