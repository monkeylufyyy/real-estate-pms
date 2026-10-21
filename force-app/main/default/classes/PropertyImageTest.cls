@IsTest
private class PropertyImageTest {
    @IsTest
    static void imageCountTracksUploadedImagesOnly() {
        Property__c prop = TestDataFactory.insertProperties(1)[0];

        TestDataFactory.insertFile(prop.Id, 'one.png');
        Assert.areEqual(1, [SELECT Image_Count__c FROM Property__c WHERE Id = :prop.Id].Image_Count__c);

        TestDataFactory.insertFile(prop.Id, 'two.jpg');
        Assert.areEqual(2, [SELECT Image_Count__c FROM Property__c WHERE Id = :prop.Id].Image_Count__c);

        insert new ContentVersion(Title = 'Contract', PathOnClient = 'contract.pdf', VersionData = Blob.valueOf('x'), FirstPublishLocationId = prop.Id);
        Assert.areEqual(2, [SELECT Image_Count__c FROM Property__c WHERE Id = :prop.Id].Image_Count__c, 'PDFs are not images');
    }

    @IsTest
    static void filesLinkedToOtherRecordsAreIgnored() {
        Tenant__c tenant = TestDataFactory.insertTenants(1)[0];
        Test.startTest();
        TestDataFactory.insertFile(tenant.Id, 'tenant.png');
        Test.stopTest();
        Assert.areEqual(0, [SELECT COUNT() FROM Property__c]);
    }

    @IsTest
    static void refreshHandlesEmptyInput() {
        ImageCountService.refreshProperties(null);
        ImageCountService.refreshProperties(new Set<Id>());
        Assert.areEqual(0, Limits.getDmlStatements());
    }

    @IsTest
    static void galleryListsImages() {
        Property__c prop = TestDataFactory.insertProperties(1)[0];
        TestDataFactory.insertFile(prop.Id, 'front.png');
        TestDataFactory.insertFile(prop.Id, 'back.png');

        List<PropertyGalleryController.ImageInfo> images = PropertyGalleryController.getImages(prop.Id);
        Assert.areEqual(2, images.size());
        Assert.isTrue(images[0].url.startsWith('/sfc/servlet.shepherd/version/download/'));
        Assert.isTrue(images[0].thumbUrl.contains('renditionDownload'));
        Assert.isNotNull(images[0].title);
    }

    @IsTest
    static void deletingAnImageUpdatesTheCount() {
        Property__c prop = TestDataFactory.insertProperties(1)[0];
        TestDataFactory.insertFile(prop.Id, 'front.png');
        TestDataFactory.insertFile(prop.Id, 'back.png');
        Id documentId = PropertyGalleryController.getImages(prop.Id)[0].documentId;

        Test.startTest();
        PropertyGalleryController.deleteImage(prop.Id, documentId);
        Test.stopTest();

        Assert.areEqual(1, PropertyGalleryController.getImages(prop.Id).size());
        Assert.areEqual(1, [SELECT Image_Count__c FROM Property__c WHERE Id = :prop.Id].Image_Count__c);
    }

    @IsTest
    static void lastImageCannotBeDeleted() {
        Property__c prop = TestDataFactory.insertProperties(1)[0];
        TestDataFactory.insertFile(prop.Id, 'only.png');
        Id documentId = PropertyGalleryController.getImages(prop.Id)[0].documentId;

        try {
            PropertyGalleryController.deleteImage(prop.Id, documentId);
            Assert.fail('The last image must be protected');
        } catch (AuraHandledException e) {
            Assert.areEqual('A property must keep at least one image.', e.getMessage());
        }
        Assert.areEqual(1, PropertyGalleryController.getImages(prop.Id).size());
    }

    @IsTest
    static void foreignDocumentsCannotBeDeleted() {
        List<Property__c> props = TestDataFactory.insertProperties(2);
        TestDataFactory.insertFile(props[0].Id, 'a.png');
        TestDataFactory.insertFile(props[0].Id, 'b.png');
        TestDataFactory.insertFile(props[1].Id, 'c.png');
        Id foreignDocument = PropertyGalleryController.getImages(props[1].Id)[0].documentId;

        try {
            PropertyGalleryController.deleteImage(props[0].Id, foreignDocument);
            Assert.fail('Expected a not-found error');
        } catch (AuraHandledException e) {
            Assert.areEqual('That image does not belong to this property.', e.getMessage());
        }
    }
}
