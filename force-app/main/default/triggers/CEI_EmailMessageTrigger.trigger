trigger CEI_EmailMessageTrigger on EmailMessage (after insert) {
    CEI_EmailMessageHandler.afterInsert(Trigger.new);
}
