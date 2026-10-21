/**
 * Geocodes a small set of freshly saved properties right after the save transaction commits.
 * Processes up to BATCH_LIMIT records per run and chains itself for the remainder.
 */
public with sharing class PropertyGeocodeQueueable implements Queueable, Database.AllowsCallouts {
    @TestVisible
    private static final Integer BATCH_LIMIT = 50;

    private List<Id> propertyIds;

    public PropertyGeocodeQueueable(List<Id> propertyIds) {
        this.propertyIds = propertyIds;
    }

    public void execute(QueueableContext context) {
        List<Id> current = new List<Id>();
        List<Id> remaining = new List<Id>();
        for (Integer i = 0; i < propertyIds.size(); i++) {
            if (i < BATCH_LIMIT) {
                current.add(propertyIds[i]);
            } else {
                remaining.add(propertyIds[i]);
            }
        }

        List<Property__c> properties = [
            SELECT Id, Address__c, City__c, State__c, Postal_Code__c, Country__c
            FROM Property__c
            WHERE Id IN :current AND Geocode_Status__c = :GeocodingService.STATUS_PENDING
        ];
        List<Property__c> updates = GeocodingService.geocodeProperties(properties);
        if (!updates.isEmpty()) {
            update updates;
        }

        // Test.isRunningTest(): chained queueables are not allowed from a test context.
        if (!remaining.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(new PropertyGeocodeQueueable(remaining));
        }
    }
}
