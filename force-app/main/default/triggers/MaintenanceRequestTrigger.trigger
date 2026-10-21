trigger MaintenanceRequestTrigger on Maintenance_Request__c(before insert) {
    VendorAssignmentService.assignVendors(Trigger.new);
}
