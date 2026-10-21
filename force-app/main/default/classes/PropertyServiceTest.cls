@IsTest
private class PropertyServiceTest {
    private static String images(Integer count) {
        List<Map<String, String>> files = new List<Map<String, String>>();
        for (Integer i = 0; i < count; i++) {
            files.add(new Map<String, String>{ 'fileName' => 'photo' + i + '.png', 'base64Data' => TestDataFactory.TINY_PNG_BASE64 });
        }
        return JSON.serialize(files);
    }

    @IsTest
    static void createsPropertyWithImages() {
        User pmsUser = TestDataFactory.createPmsUser();
        TestDataFactory.disableGeocoding();
        Id propertyId;

        System.runAs(pmsUser) {
            Test.startTest();
            propertyId = PropertyService.createProperty(TestDataFactory.buildProperty('With images', 20000), images(2));
            Test.stopTest();
        }

        Assert.isNotNull(propertyId);
        Assert.areEqual(2, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :propertyId]);
        Assert.areEqual(2, [SELECT Image_Count__c FROM Property__c WHERE Id = :propertyId].Image_Count__c);
    }

    @IsTest
    static void rejectsPropertyWithoutImages() {
        User pmsUser = TestDataFactory.createPmsUser();
        System.runAs(pmsUser) {
            for (String payload : new List<String>{ null, '', '[]' }) {
                try {
                    PropertyService.createProperty(TestDataFactory.buildProperty('No images', 20000), payload);
                    Assert.fail('A property without images must be rejected');
                } catch (AuraHandledException e) {
                    Assert.areEqual('At least one property image is required.', e.getMessage());
                }
            }
        }
        Assert.areEqual(0, [SELECT COUNT() FROM Property__c]);
    }

    @IsTest
    static void rejectsUnsupportedFileTypes() {
        User pmsUser = TestDataFactory.createPmsUser();
        String payload = JSON.serialize(new List<Map<String, String>>{ new Map<String, String>{ 'fileName' => 'notes.pdf', 'base64Data' => 'AAAA' } });
        System.runAs(pmsUser) {
            try {
                PropertyService.createProperty(TestDataFactory.buildProperty('Bad type', 20000), payload);
                Assert.fail('Expected a file type error');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('not a supported image type'), e.getMessage());
            }
        }
        Assert.areEqual(0, [SELECT COUNT() FROM Property__c]);
    }

    @IsTest
    static void rejectsEmptyImageContent() {
        User pmsUser = TestDataFactory.createPmsUser();
        String payload = JSON.serialize(new List<Map<String, String>>{ new Map<String, String>{ 'fileName' => 'a.png', 'base64Data' => '' } });
        System.runAs(pmsUser) {
            try {
                PropertyService.createProperty(TestDataFactory.buildProperty('Empty', 20000), payload);
                Assert.fail('Expected a content error');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('needs a file name and content'), e.getMessage());
            }
        }
    }

    @IsTest
    static void rejectsOversizedUploads() {
        User pmsUser = TestDataFactory.createPmsUser();
        PropertyService.maxTotalBytes = 10;
        String payload = images(1);
        System.runAs(pmsUser) {
            try {
                PropertyService.createProperty(TestDataFactory.buildProperty('Too big', 20000), payload);
                Assert.fail('Expected a size error');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('too large'), e.getMessage());
            }
        }
    }

    @IsTest
    static void rejectsUnreadableImagePayload() {
        User pmsUser = TestDataFactory.createPmsUser();
        System.runAs(pmsUser) {
            try {
                PropertyService.createProperty(TestDataFactory.buildProperty('Garbled', 20000), '{not valid json');
                Assert.fail('Expected a parse error');
            } catch (AuraHandledException e) {
                Assert.areEqual('The uploaded images could not be read.', e.getMessage());
            }
        }
    }

    @IsTest
    static void rollsBackWhenThePropertyIsInvalid() {
        User pmsUser = TestDataFactory.createPmsUser();
        TestDataFactory.disableGeocoding();
        Property__c invalid = TestDataFactory.buildProperty('Bad rent', -5);
        System.runAs(pmsUser) {
            try {
                PropertyService.createProperty(invalid, images(1));
                Assert.fail('Expected a validation error');
            } catch (AuraHandledException e) {
                Assert.isTrue(e.getMessage().contains('Rent must be greater than zero'), e.getMessage());
            }
        }
        Assert.areEqual(0, [SELECT COUNT() FROM Property__c]);
        Assert.areEqual(0, [SELECT COUNT() FROM ContentVersion]);
    }
}
