@IsTest
private class PropertyTriggerHandlerTest {
    @IsTest
    static void assigningTenantMarksOccupiedAndCreatesLeaseTask() {
        Tenant__c tenant = TestDataFactory.insertTenants(1)[0];
        Property__c prop = TestDataFactory.insertProperties(1)[0];

        Test.startTest();
        prop.Tenant__c = tenant.Id;
        update prop;
        Test.stopTest();

        Property__c reloaded = [SELECT Status__c FROM Property__c WHERE Id = :prop.Id];
        Assert.areEqual('Occupied', reloaded.Status__c, 'An assigned property becomes occupied');

        List<Task> tasks = [SELECT Subject, Status, Priority, ActivityDate FROM Task WHERE WhatId = :prop.Id];
        Assert.areEqual(1, tasks.size(), 'One task should be created');
        Assert.isTrue(tasks[0].Subject.startsWith(PropertyAssignmentService.TASK_SUBJECT_PREFIX));
        Assert.isTrue(tasks[0].Subject.contains('Tenant 0'));
        Assert.areEqual('Not Started', tasks[0].Status);
        Assert.areEqual('High', tasks[0].Priority);
        Assert.areEqual(Date.today().addDays(7), tasks[0].ActivityDate);
    }

    @IsTest
    static void creatingPropertyWithTenantCreatesTask() {
        Tenant__c tenant = TestDataFactory.insertTenants(1)[0];
        TestDataFactory.disableGeocoding();
        Property__c prop = TestDataFactory.buildProperty('Assigned on create', 12000);
        prop.Tenant__c = tenant.Id;

        Test.startTest();
        insert prop;
        Test.stopTest();

        Assert.areEqual(1, [SELECT COUNT() FROM Task WHERE WhatId = :prop.Id]);
        Assert.areEqual('Occupied', [SELECT Status__c FROM Property__c WHERE Id = :prop.Id].Status__c);
    }

    @IsTest
    static void unrelatedUpdateDoesNotCreateAnotherTask() {
        Tenant__c tenant = TestDataFactory.insertTenants(1)[0];
        Property__c prop = TestDataFactory.insertProperties(1)[0];
        prop.Tenant__c = tenant.Id;
        update prop;

        Test.startTest();
        prop.Description__c = 'Changed description';
        update prop;
        Test.stopTest();

        Assert.areEqual(1, [SELECT COUNT() FROM Task WHERE WhatId = :prop.Id], 'No extra task for an unchanged tenant');
    }

    @IsTest
    static void reassigningToAnotherTenantCreatesNewTask() {
        List<Tenant__c> tenants = TestDataFactory.insertTenants(2);
        Property__c prop = TestDataFactory.insertProperties(1)[0];
        prop.Tenant__c = tenants[0].Id;
        update prop;

        Test.startTest();
        prop.Tenant__c = tenants[1].Id;
        update prop;
        Test.stopTest();

        Assert.areEqual(2, [SELECT COUNT() FROM Task WHERE WhatId = :prop.Id]);
    }

    @IsTest
    static void bulkAssignmentIsBulkified() {
        Tenant__c tenant = TestDataFactory.insertTenants(1)[0];
        List<Property__c> props = TestDataFactory.insertProperties(200);
        for (Property__c p : props) {
            p.Tenant__c = tenant.Id;
        }

        Test.startTest();
        update props;
        Test.stopTest();

        Assert.areEqual(200, [SELECT COUNT() FROM Task WHERE WhatId IN :props]);
        Assert.areEqual(200, [SELECT COUNT() FROM Property__c WHERE Status__c = 'Occupied']);
    }

    @IsTest
    static void newPropertyIsGeocodedAfterSave() {
        TestDataFactory.enableGeocoding();
        Test.setMock(HttpCalloutMock.class, GeocodeMock.chennai());
        Property__c prop = TestDataFactory.buildProperty('Geocoded', 12000);

        Test.startTest();
        insert prop;
        Assert.areEqual(GeocodingService.STATUS_PENDING, [SELECT Geocode_Status__c FROM Property__c WHERE Id = :prop.Id].Geocode_Status__c);
        Test.stopTest();

        Property__c reloaded = [SELECT Geocode_Status__c, Location__Latitude__s, Location__Longitude__s FROM Property__c WHERE Id = :prop.Id];
        Assert.areEqual(GeocodingService.STATUS_SUCCESS, reloaded.Geocode_Status__c);
        Assert.areEqual(13.0827, reloaded.Location__Latitude__s);
        Assert.areEqual(80.2707, reloaded.Location__Longitude__s);
    }

    @IsTest
    static void changingTheAddressGeocodesAgain() {
        Property__c prop = TestDataFactory.insertProperties(1)[0];
        TestDataFactory.enableGeocoding();
        Test.setMock(HttpCalloutMock.class, GeocodeMock.chennai());

        Test.startTest();
        prop.City__c = 'Madurai';
        update prop;
        Test.stopTest();

        Assert.areEqual(GeocodingService.STATUS_SUCCESS, [SELECT Geocode_Status__c FROM Property__c WHERE Id = :prop.Id].Geocode_Status__c);
    }

    @IsTest
    static void changingANonAddressFieldDoesNotGeocode() {
        Property__c prop = TestDataFactory.insertProperties(1)[0];
        TestDataFactory.enableGeocoding();

        Test.startTest();
        prop.Description__c = 'Only the description changed';
        update prop;
        Test.stopTest();

        Assert.isNull([SELECT Geocode_Status__c FROM Property__c WHERE Id = :prop.Id].Geocode_Status__c);
    }

    @IsTest
    static void suppliedCoordinatesAreNotGeocoded() {
        TestDataFactory.enableGeocoding();
        Property__c prop = TestDataFactory.buildProperty('Has coordinates', 12000);
        prop.Location__Latitude__s = 12.9716;
        prop.Location__Longitude__s = 77.5946;

        Test.startTest();
        insert prop;
        Test.stopTest();

        Assert.isNull([SELECT Geocode_Status__c FROM Property__c WHERE Id = :prop.Id].Geocode_Status__c);
    }

    @IsTest
    static void largeLoadsStayPendingForTheBatch() {
        TestDataFactory.enableGeocoding();
        List<Property__c> props = new List<Property__c>();
        for (Integer i = 0; i < PropertyTriggerHandler.MAX_INLINE_GEOCODE + 1; i++) {
            props.add(TestDataFactory.buildProperty('Bulk ' + i, 9000));
        }

        Test.startTest();
        insert props;
        Test.stopTest();

        Assert.areEqual(props.size(), [SELECT COUNT() FROM Property__c WHERE Geocode_Status__c = :GeocodingService.STATUS_PENDING]);
    }

    @IsTest
    static void needsGeocodingHonoursTheSwitch() {
        Property__c prop = TestDataFactory.buildProperty('Switch', 1000);
        TestDataFactory.disableGeocoding();
        Assert.isFalse(PropertyTriggerHandler.needsGeocoding(prop, null));
        TestDataFactory.enableGeocoding();
        Assert.isTrue(PropertyTriggerHandler.needsGeocoding(prop, null));
    }
}
