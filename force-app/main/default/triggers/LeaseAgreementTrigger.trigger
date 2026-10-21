trigger LeaseAgreementTrigger on Lease_Agreement__c(before insert, before update, after insert) {
    if (Trigger.isBefore) {
        LeaseAgreementTriggerHandler.beforeSave(Trigger.new, Trigger.oldMap);
    } else {
        LeaseAgreementTriggerHandler.afterInsert(Trigger.new);
    }
}
