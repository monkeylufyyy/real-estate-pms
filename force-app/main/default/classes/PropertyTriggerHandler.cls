/**
 * Handles Property__c trigger logic. Everything is bulkified: no SOQL or DML inside loops.
 *  - Assigning a tenant marks an available property as Occupied and creates a "generate lease" task.
 *  - New or re-addressed properties are flagged for geocoding. Small transactions geocode
 *    immediately through a Queueable, large loads are left for PropertyGeocodeBatch.
 */
public with sharing class PropertyTriggerHandler {
    @TestVisible
    private static Boolean disableGeocoding = false;

    @TestVisible
    private static final Integer MAX_INLINE_GEOCODE = 100;

    public static void beforeSave(List<Property__c> newList, Map<Id, Property__c> oldMap) {
        for (Property__c prop : newList) {
            Property__c oldProp = oldMap == null ? null : oldMap.get(prop.Id);

            if (isTenantAssigned(prop, oldProp) && prop.Status__c == 'Available') {
                prop.Status__c = 'Occupied';
            }
            if (needsGeocoding(prop, oldProp)) {
                prop.Geocode_Status__c = GeocodingService.STATUS_PENDING;
            }
        }
    }

    public static void afterSave(List<Property__c> newList, Map<Id, Property__c> oldMap) {
        List<Property__c> newlyAssigned = new List<Property__c>();
        List<Id> pendingGeocode = new List<Id>();

        for (Property__c prop : newList) {
            Property__c oldProp = oldMap == null ? null : oldMap.get(prop.Id);

            if (isTenantAssigned(prop, oldProp)) {
                newlyAssigned.add(prop);
            }
            if (
                prop.Geocode_Status__c == GeocodingService.STATUS_PENDING &&
                (oldProp == null || oldProp.Geocode_Status__c != GeocodingService.STATUS_PENDING)
            ) {
                pendingGeocode.add(prop.Id);
            }
        }

        PropertyAssignmentService.createLeaseTasks(newlyAssigned);
        enqueueGeocoding(pendingGeocode);
    }

    private static Boolean isTenantAssigned(Property__c prop, Property__c oldProp) {
        return prop.Tenant__c != null && (oldProp == null || oldProp.Tenant__c != prop.Tenant__c);
    }

    @TestVisible
    private static Boolean needsGeocoding(Property__c prop, Property__c oldProp) {
        if (disableGeocoding) {
            return false;
        }
        if (oldProp == null) {
            // Coordinates supplied by the caller are trusted, otherwise geocode the address.
            return prop.Location__Latitude__s == null || prop.Location__Longitude__s == null;
        }
        return prop.Address__c != oldProp.Address__c ||
            prop.City__c != oldProp.City__c ||
            prop.State__c != oldProp.State__c ||
            prop.Postal_Code__c != oldProp.Postal_Code__c ||
            prop.Country__c != oldProp.Country__c;
    }

    private static void enqueueGeocoding(List<Id> propertyIds) {
        if (disableGeocoding || propertyIds.isEmpty() || propertyIds.size() > MAX_INLINE_GEOCODE) {
            // Large loads stay "Pending" and are picked up by PropertyGeocodeBatch.
            return;
        }
        if (System.isQueueable() || System.isBatch() || System.isFuture()) {
            return;
        }
        System.enqueueJob(new PropertyGeocodeQueueable(propertyIds));
    }
}
