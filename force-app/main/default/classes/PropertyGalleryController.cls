/**
 * Image gallery support for the property record page.
 */
public with sharing class PropertyGalleryController {
    public class ImageInfo {
        @AuraEnabled
        public Id documentId;
        @AuraEnabled
        public String title;
        @AuraEnabled
        public String url;
        @AuraEnabled
        public String thumbUrl;
    }

    @AuraEnabled
    public static List<ImageInfo> getImages(Id propertyId) {
        List<ImageInfo> images = new List<ImageInfo>();
        for (ContentDocumentLink link : imageLinks(propertyId)) {
            ImageInfo info = new ImageInfo();
            info.documentId = link.ContentDocumentId;
            info.title = link.ContentDocument.Title;
            Id versionId = link.ContentDocument.LatestPublishedVersionId;
            info.url = '/sfc/servlet.shepherd/version/download/' + versionId;
            info.thumbUrl = '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + versionId;
            images.add(info);
        }
        return images;
    }

    /**
     * Removes one image but never the last one, so the "property needs an image" rule keeps holding.
     */
    @AuraEnabled
    public static void deleteImage(Id propertyId, Id documentId) {
        List<ContentDocumentLink> links = imageLinks(propertyId);
        Boolean found = false;
        for (ContentDocumentLink link : links) {
            if (link.ContentDocumentId == documentId) {
                found = true;
            }
        }
        if (!found) {
            throw AuraErrors.build('That image does not belong to this property.');
        }
        if (links.size() <= 1) {
            throw AuraErrors.build('A property must keep at least one image.');
        }
        try {
            delete [SELECT Id FROM ContentDocument WHERE Id = :documentId];
            ImageCountService.refreshProperties(new Set<Id>{ propertyId });
        } catch (Exception e) {
            throw AuraErrors.build(AuraErrors.messageOf(e));
        }
    }

    private static List<ContentDocumentLink> imageLinks(Id propertyId) {
        return [
            SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :propertyId AND ContentDocument.FileExtension IN :PropertyService.IMAGE_EXTENSIONS
            ORDER BY SystemModstamp ASC
            LIMIT 200
        ];
    }
}
