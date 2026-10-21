/**
 * Keeps Property__c.Image_Count__c in sync with the image files attached to the property.
 */
public with sharing class ImageCountService {
    public static void refresh(List<ContentDocumentLink> links) {
        String propertyPrefix = Property__c.SObjectType.getDescribe().getKeyPrefix();
        Set<Id> propertyIds = new Set<Id>();
        for (ContentDocumentLink link : links) {
            if (link.LinkedEntityId != null && String.valueOf(link.LinkedEntityId).startsWith(propertyPrefix)) {
                propertyIds.add(link.LinkedEntityId);
            }
        }
        refreshProperties(propertyIds);
    }

    public static void refreshProperties(Set<Id> propertyIds) {
        if (propertyIds == null || propertyIds.isEmpty()) {
            return;
        }

        Map<Id, Integer> counts = new Map<Id, Integer>();
        for (ContentDocumentLink link : [
            SELECT LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :propertyIds AND ContentDocument.FileExtension IN :PropertyService.IMAGE_EXTENSIONS
        ]) {
            Integer current = counts.containsKey(link.LinkedEntityId) ? counts.get(link.LinkedEntityId) : 0;
            counts.put(link.LinkedEntityId, current + 1);
        }

        // Query first so deleted properties are skipped and unchanged counts cause no DML.
        List<Property__c> toUpdate = new List<Property__c>();
        for (Property__c prop : [SELECT Id, Image_Count__c FROM Property__c WHERE Id IN :propertyIds]) {
            Integer newCount = counts.containsKey(prop.Id) ? counts.get(prop.Id) : 0;
            if (prop.Image_Count__c != newCount) {
                toUpdate.add(new Property__c(Id = prop.Id, Image_Count__c = newCount));
            }
        }
        if (!toUpdate.isEmpty()) {
            // Image_Count__c is maintained by the system. Run in system mode so this also works
            // when the upload itself runs in user mode (users only get read access to the field).
            update as system toUpdate;
        }
    }
}
