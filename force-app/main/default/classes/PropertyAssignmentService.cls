/**
 * Creates the "generate lease agreement" task whenever a property is assigned to a tenant.
 */
public with sharing class PropertyAssignmentService {
    public static final String TASK_SUBJECT_PREFIX = 'Generate lease agreement: ';

    public static void createLeaseTasks(List<Property__c> assignedProperties) {
        if (assignedProperties == null || assignedProperties.isEmpty()) {
            return;
        }

        Set<Id> tenantIds = new Set<Id>();
        for (Property__c prop : assignedProperties) {
            tenantIds.add(prop.Tenant__c);
        }
        Map<Id, Tenant__c> tenants = new Map<Id, Tenant__c>([SELECT Id, Name FROM Tenant__c WHERE Id IN :tenantIds]);

        List<Task> tasks = new List<Task>();
        for (Property__c prop : assignedProperties) {
            Tenant__c tenant = tenants.get(prop.Tenant__c);
            String tenantName = tenant == null ? 'tenant' : tenant.Name;
            tasks.add(
                new Task(
                    Subject = (TASK_SUBJECT_PREFIX + tenantName + ' - ' + prop.Name).left(255),
                    Description = 'Property "' +
                        prop.Name +
                        '" was assigned to ' +
                        tenantName +
                        '. Create the lease agreement (terms, agreed monthly rent, start and end dates).',
                    WhatId = prop.Id,
                    OwnerId = prop.OwnerId,
                    Status = 'Not Started',
                    Priority = 'High',
                    ActivityDate = Date.today().addDays(7)
                )
            );
        }
        insert tasks;
    }
}
