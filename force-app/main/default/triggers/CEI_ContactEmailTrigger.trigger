trigger CEI_ContactEmailTrigger on Contact_Email__c (before insert, before update) {
    CEI_TriggerDispatcher.beforeContactEmail(
        Trigger.new,
        Trigger.isUpdate ? Trigger.oldMap : null,
        Trigger.isInsert
    );
}
