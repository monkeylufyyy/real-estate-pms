@IsTest
private class GeocodingServiceTest {
    @IsTest
    static void geocodeParsesTheFirstMatch() {
        Test.setMock(HttpCalloutMock.class, GeocodeMock.chennai());
        GeocodingService.GeoResult result = GeocodingService.geocode('12 Anna Salai, Chennai');
        Assert.isTrue(result.found);
        Assert.areEqual(13.0827, result.latitude);
        Assert.areEqual(80.2707, result.longitude);
    }

    @IsTest
    static void geocodeHandlesNoMatch() {
        Test.setMock(HttpCalloutMock.class, new GeocodeMock(200, '[]'));
        GeocodingService.GeoResult result = GeocodingService.geocode('Nowhere');
        Assert.isFalse(result.found);
        Assert.areEqual('No match found', result.message);
    }

    @IsTest
    static void geocodeHandlesHttpErrors() {
        Test.setMock(HttpCalloutMock.class, new GeocodeMock(503, 'unavailable'));
        GeocodingService.GeoResult result = GeocodingService.geocode('Chennai');
        Assert.isFalse(result.found);
        Assert.areEqual('HTTP 503', result.message);
    }

    @IsTest
    static void geocodeHandlesInvalidResponses() {
        Test.setMock(HttpCalloutMock.class, new GeocodeMock(200, 'not json'));
        GeocodingService.GeoResult result = GeocodingService.geocode('Chennai');
        Assert.isFalse(result.found);
        Assert.isNotNull(result.message);
    }

    @IsTest
    static void geocodeRejectsBlankAddress() {
        GeocodingService.GeoResult result = GeocodingService.geocode('  ');
        Assert.isFalse(result.found);
        Assert.areEqual('Address is blank', result.message);
    }

    @IsTest
    static void buildAddressSkipsBlankParts() {
        Property__c prop = new Property__c(Address__c = '12 Anna Salai', City__c = 'Chennai', State__c = null, Postal_Code__c = '600002', Country__c = 'India');
        Assert.areEqual('12 Anna Salai, Chennai, 600002, India', GeocodingService.buildAddress(prop));
    }

    @IsTest
    static void geocodePropertiesMarksFailures() {
        Test.setMock(HttpCalloutMock.class, new GeocodeMock(200, '[]'));
        Property__c prop = TestDataFactory.insertProperties(1)[0];
        List<Property__c> updates = GeocodingService.geocodeProperties(new List<Property__c>{ prop });
        Assert.areEqual(1, updates.size());
        Assert.isTrue(updates[0].Geocode_Status__c.startsWith(GeocodingService.STATUS_FAILED));
    }

    @IsTest
    static void batchGeocodesPendingProperties() {
        TestDataFactory.disableGeocoding();
        List<Property__c> props = new List<Property__c>();
        for (Integer i = 0; i < 20; i++) {
            Property__c p = TestDataFactory.buildProperty('Backlog ' + i, 9000);
            p.Geocode_Status__c = GeocodingService.STATUS_PENDING;
            props.add(p);
        }
        Property__c alreadyDone = TestDataFactory.buildProperty('Already done', 9000);
        alreadyDone.Geocode_Status__c = GeocodingService.STATUS_SUCCESS;
        props.add(alreadyDone);
        insert props;
        Test.setMock(HttpCalloutMock.class, GeocodeMock.chennai());
        GeocodeMock.calls = 0;

        Test.startTest();
        // One chunk of 20, because a test context allows a single executeBatch run.
        Database.executeBatch(new PropertyGeocodeBatch(), 20);
        Test.stopTest();

        Assert.areEqual(21, [SELECT COUNT() FROM Property__c WHERE Geocode_Status__c = :GeocodingService.STATUS_SUCCESS]);
        Assert.areEqual(0, [SELECT COUNT() FROM Property__c WHERE Geocode_Status__c = :GeocodingService.STATUS_PENDING]);
        Assert.areEqual(20, GeocodeMock.calls, 'Only pending properties are geocoded');
    }

    @IsTest
    static void scheduledRunStartsTheBatch() {
        Test.startTest();
        new PropertyGeocodeBatch().execute((SchedulableContext) null);
        Test.stopTest();
        Assert.areEqual(0, [SELECT COUNT() FROM Property__c]);
    }

    @IsTest
    static void batchCanBeScheduled() {
        Test.startTest();
        Id jobId = System.schedule('Geocode test', '0 0 3 * * ?', new PropertyGeocodeBatch());
        Test.stopTest();
        Assert.areEqual(1, [SELECT COUNT() FROM CronTrigger WHERE Id = :jobId]);
    }

    @IsTest
    static void queueableProcessesOnlyPendingRecords() {
        Property__c done = TestDataFactory.insertProperties(1)[0];
        Test.setMock(HttpCalloutMock.class, GeocodeMock.chennai());
        GeocodeMock.calls = 0;

        Test.startTest();
        System.enqueueJob(new PropertyGeocodeQueueable(new List<Id>{ done.Id }));
        Test.stopTest();

        Assert.areEqual(0, GeocodeMock.calls, 'A property that is not pending must not be geocoded');
    }
}
