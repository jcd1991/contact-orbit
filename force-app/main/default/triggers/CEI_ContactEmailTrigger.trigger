trigger CEI_ContactEmailTrigger on Contact_Email__c (before insert, before update) {
    CEI_ContactEmailService.prepareForSave(Trigger.new);
}
