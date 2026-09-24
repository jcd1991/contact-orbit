/**
 * Deterministic trigger action boundary for Contact Orbit.
 *
 * This follows the useful parts of a trigger-actions architecture—one thin
 * trigger, explicit action partitioning, and recursion protection—without
 * introducing dynamic subscriber Apex or a runtime dependency on an external
 * framework. That keeps the managed package upgrade-safe and auditable.
 */
public without sharing class CEI_TriggerDispatcher {
    public static void beforeContactEmail(
        List<Contact_Email__c> records,
        Map<Id, Contact_Email__c> oldById,
        Boolean isInsert
    ) {
        if (!CEI_TriggerRuntime.enter('Contact_Email__c.beforeSave')) return;
        try {
            CEI_ContactEmailService.prepareForSave(records, oldById, isInsert);
        } finally {
            CEI_TriggerRuntime.exit('Contact_Email__c.beforeSave');
        }
    }

    public static void afterEmailMessage(List<EmailMessage> records) {
        if (!CEI_TriggerRuntime.enter('EmailMessage.afterInsert')) return;
        try {
            CEI_EmailMessageHandler.afterInsert(records);
        } finally {
            CEI_TriggerRuntime.exit('EmailMessage.afterInsert');
        }
    }
}
