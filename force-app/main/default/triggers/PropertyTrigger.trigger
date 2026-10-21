trigger PropertyTrigger on Property__c(before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        PropertyTriggerHandler.beforeSave(Trigger.new, Trigger.oldMap);
    } else {
        PropertyTriggerHandler.afterSave(Trigger.new, Trigger.oldMap);
    }
}
