/**
 * Geocodes every property still marked "Pending". Use it after large data loads.
 *   Database.executeBatch(new PropertyGeocodeBatch(), 20);
 * It can also be scheduled (see scripts/apex/schedule-jobs.apex).
 */
public with sharing class PropertyGeocodeBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable {
    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator(
            [
                SELECT Id, Address__c, City__c, State__c, Postal_Code__c, Country__c
                FROM Property__c
                WHERE Geocode_Status__c = :GeocodingService.STATUS_PENDING
            ]
        );
    }

    public void execute(Database.BatchableContext context, List<Property__c> scope) {
        List<Property__c> updates = GeocodingService.geocodeProperties(scope);
        if (!updates.isEmpty()) {
            update updates;
        }
    }

    public void finish(Database.BatchableContext context) {
    }

    public void execute(SchedulableContext context) {
        Database.executeBatch(new PropertyGeocodeBatch(), 20);
    }
}
