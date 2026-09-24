trigger CEI_EmailMessageTrigger on EmailMessage (after insert) {
    CEI_TriggerDispatcher.afterEmailMessage(Trigger.new);
}
