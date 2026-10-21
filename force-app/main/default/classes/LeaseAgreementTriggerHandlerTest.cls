@IsTest
private class LeaseAgreementTriggerHandlerTest {
    private static Date today = Date.today();

    @IsTest
    static void savesALeaseAndRejectsAnOverlappingOne() {
        Tenant__c tenant = TestDataFactory.insertTenants(1)[0];
        Property__c prop = TestDataFactory.insertProperties(1)[0];
        insert TestDataFactory.buildLease(prop.Id, tenant.Id, today, today.addMonths(11));

        Lease_Agreement__c overlapping = TestDataFactory.buildLease(prop.Id, tenant.Id, today.addMonths(6), today.addMonths(18));
        Database.SaveResult result = Database.insert(overlapping, false);

        Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains('overlaps'), result.getErrors()[0].getMessage());
    }

    @IsTest
    static void allowsBackToBackLeasesAndLeasesOnOtherProperties() {
        Tenant__c tenant = TestDataFactory.insertTenants(1)[0];
        List<Property__c> props = TestDataFactory.insertProperties(2);
        insert TestDataFactory.buildLease(props[0].Id, tenant.Id, today, today.addMonths(11));

        Lease_Agreement__c next = TestDataFactory.buildLease(props[0].Id, tenant.Id, today.addMonths(11).addDays(1), today.addMonths(23));
        Lease_Agreement__c elsewhere = TestDataFactory.buildLease(props[1].Id, tenant.Id, today, today.addMonths(11));
        List<Database.SaveResult> results = Database.insert(new List<Lease_Agreement__c>{ next, elsewhere }, false);

        Assert.isTrue(results[0].isSuccess());
        Assert.isTrue(results[1].isSuccess());
    }

    @IsTest
    static void rejectsOverlapsInsideTheSameBatch() {
        Tenant__c tenant = TestDataFactory.insertTenants(1)[0];
        Property__c prop = TestDataFactory.insertProperties(1)[0];
        Lease_Agreement__c first = TestDataFactory.buildLease(prop.Id, tenant.Id, today, today.addMonths(11));
        Lease_Agreement__c second = TestDataFactory.buildLease(prop.Id, tenant.Id, today.addMonths(3), today.addMonths(9));

        List<Database.SaveResult> results = Database.insert(new List<Lease_Agreement__c>{ first, second }, false);

        Assert.isTrue(results[0].isSuccess());
        Assert.isFalse(results[1].isSuccess());
    }

    @IsTest
    static void editingALeaseDoesNotConflictWithItself() {
        Tenant__c tenant = TestDataFactory.insertTenants(1)[0];
        Property__c prop = TestDataFactory.insertProperties(1)[0];
        Lease_Agreement__c lease = TestDataFactory.buildLease(prop.Id, tenant.Id, today, today.addMonths(11));
        insert lease;

        lease.Agreed_Monthly_Rent__c = 18000;
        update lease;

        Assert.areEqual(18000, [SELECT Agreed_Monthly_Rent__c FROM Lease_Agreement__c WHERE Id = :lease.Id].Agreed_Monthly_Rent__c);
    }

    @IsTest
    static void updatingIntoAnotherLeasePeriodIsRejected() {
        Tenant__c tenant = TestDataFactory.insertTenants(1)[0];
        Property__c prop = TestDataFactory.insertProperties(1)[0];
        insert TestDataFactory.buildLease(prop.Id, tenant.Id, today, today.addMonths(11));
        Lease_Agreement__c later = TestDataFactory.buildLease(prop.Id, tenant.Id, today.addMonths(12), today.addMonths(23));
        insert later;

        later.Start_Date__c = today.addMonths(5);
        Database.SaveResult result = Database.update(later, false);

        Assert.isFalse(result.isSuccess());
    }

    @IsTest
    static void creatingALeaseCompletesTheGenerationTask() {
        Tenant__c tenant = TestDataFactory.insertTenants(1)[0];
        Property__c prop = TestDataFactory.insertProperties(1)[0];
        prop.Tenant__c = tenant.Id;
        update prop;
        Assert.areEqual(1, [SELECT COUNT() FROM Task WHERE WhatId = :prop.Id AND IsClosed = FALSE]);

        Test.startTest();
        insert TestDataFactory.buildLease(prop.Id, tenant.Id, today, today.addMonths(11));
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM Task WHERE WhatId = :prop.Id AND IsClosed = FALSE]);
        Assert.areEqual('Completed', [SELECT Status FROM Task WHERE WhatId = :prop.Id].Status);
    }

    @IsTest
    static void endDateMustBeAfterStartDate() {
        Tenant__c tenant = TestDataFactory.insertTenants(1)[0];
        Property__c prop = TestDataFactory.insertProperties(1)[0];
        Database.SaveResult result = Database.insert(TestDataFactory.buildLease(prop.Id, tenant.Id, today, today.addDays(-1)), false);
        Assert.isFalse(result.isSuccess());
        Assert.isTrue(result.getErrors()[0].getMessage().contains('End Date must be after Start Date'));
    }

    @IsTest
    static void rentAndTermsAreValidated() {
        Tenant__c tenant = TestDataFactory.insertTenants(1)[0];
        Property__c prop = TestDataFactory.insertProperties(1)[0];

        Lease_Agreement__c zeroRent = TestDataFactory.buildLease(prop.Id, tenant.Id, today, today.addMonths(11));
        zeroRent.Agreed_Monthly_Rent__c = 0;
        Assert.isFalse(Database.insert(zeroRent, false).isSuccess());

        Lease_Agreement__c noTerms = TestDataFactory.buildLease(prop.Id, tenant.Id, today, today.addMonths(11));
        noTerms.Terms__c = null;
        Assert.isFalse(Database.insert(noTerms, false).isSuccess());
    }

    @IsTest
    static void leaseStatusFormulaReflectsTheDates() {
        Tenant__c tenant = TestDataFactory.insertTenants(1)[0];
        List<Property__c> props = TestDataFactory.insertProperties(3);
        Lease_Agreement__c active = TestDataFactory.buildLease(props[0].Id, tenant.Id, today.addDays(-10), today.addDays(100));
        Lease_Agreement__c upcoming = TestDataFactory.buildLease(props[1].Id, tenant.Id, today.addDays(10), today.addDays(100));
        Lease_Agreement__c expired = TestDataFactory.buildLease(props[2].Id, tenant.Id, today.addDays(-100), today.addDays(-10));
        insert new List<Lease_Agreement__c>{ active, upcoming, expired };

        Map<Id, Lease_Agreement__c> reloaded = new Map<Id, Lease_Agreement__c>([SELECT Status__c FROM Lease_Agreement__c]);
        Assert.areEqual('Active', reloaded.get(active.Id).Status__c);
        Assert.areEqual('Upcoming', reloaded.get(upcoming.Id).Status__c);
        Assert.areEqual('Expired', reloaded.get(expired.Id).Status__c);
    }
}
