trigger ContentDocumentLinkTrigger on ContentDocumentLink(after insert, after delete) {
    ImageCountService.refresh(Trigger.isDelete ? Trigger.old : Trigger.new);
}
