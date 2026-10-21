/**
 * Creates a property together with its images in ONE transaction, so a property can never be
 * saved without at least one image. If anything fails, everything is rolled back.
 */
public with sharing class PropertyService {
    public static final Set<String> IMAGE_EXTENSIONS = new Set<String>{ 'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp' };

    // Decoded size cap for one create request (the UI compresses photos before sending).
    @TestVisible
    private static Integer maxTotalBytes = 3 * 1024 * 1024;

    public class ImageFile {
        public String fileName;
        public String base64Data;
    }

    @AuraEnabled
    public static Id createProperty(Property__c property, String imagesJson) {
        List<ImageFile> images = parseImages(imagesJson);
        validateImages(images);

        Savepoint sp = Database.setSavepoint();
        try {
            property.Id = null;
            insert as user property;

            List<ContentVersion> versions = new List<ContentVersion>();
            for (ImageFile img : images) {
                versions.add(
                    new ContentVersion(
                        Title = titleOf(img.fileName),
                        PathOnClient = img.fileName,
                        VersionData = EncodingUtil.base64Decode(img.base64Data),
                        FirstPublishLocationId = property.Id
                    )
                );
            }
            insert as user versions;
            return property.Id;
        } catch (Exception e) {
            Database.rollback(sp);
            throw AuraErrors.build(AuraErrors.messageOf(e));
        }
    }

    @TestVisible
    private static List<ImageFile> parseImages(String imagesJson) {
        if (String.isBlank(imagesJson)) {
            throw AuraErrors.build('At least one property image is required.');
        }
        try {
            return (List<ImageFile>) JSON.deserialize(imagesJson, List<ImageFile>.class);
        } catch (Exception e) {
            throw AuraErrors.build('The uploaded images could not be read.');
        }
    }

    @TestVisible
    private static void validateImages(List<ImageFile> images) {
        if (images == null || images.isEmpty()) {
            throw AuraErrors.build('At least one property image is required.');
        }
        Integer totalBytes = 0;
        for (ImageFile img : images) {
            if (img == null || String.isBlank(img.fileName) || String.isBlank(img.base64Data)) {
                throw AuraErrors.build('Every uploaded image needs a file name and content.');
            }
            if (!IMAGE_EXTENSIONS.contains(extensionOf(img.fileName))) {
                throw AuraErrors.build('"' + img.fileName + '" is not a supported image type (png, jpg, jpeg, gif, webp, bmp).');
            }
            totalBytes += (img.base64Data.length() * 3) / 4;
        }
        if (totalBytes > maxTotalBytes) {
            throw AuraErrors.build('The images are too large to upload together. Use fewer or smaller images, then add more from the property page.');
        }
    }

    private static String extensionOf(String fileName) {
        Integer dot = fileName.lastIndexOf('.');
        return dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    }

    private static String titleOf(String fileName) {
        Integer dot = fileName.lastIndexOf('.');
        return (dot > 0 ? fileName.substring(0, dot) : fileName).left(255);
    }
}
