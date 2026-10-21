@IsTest
private class VendorAssignmentServiceTest {
    private static Property__c prop() {
        return [SELECT Id FROM Property__c LIMIT 1];
    }

    @TestSetup
    static void setup() {
        TestDataFactory.insertProperties(1);
    }

    private static Map<Id, Integer> countByVendor() {
        Map<Id, Integer> counts = new Map<Id, Integer>();
        for (AggregateResult row : [SELECT Vendor__c v, COUNT(Id) c FROM Maintenance_Request__c GROUP BY Vendor__c]) {
            counts.put((Id) row.get('v'), (Integer) row.get('c'));
        }
        return counts;
    }

    @IsTest
    static void leavesRequestsUnassignedWhenThereAreNoVendors() {
        Maintenance_Request__c request = TestDataFactory.buildRequest(prop().Id, 'Open');
        insert request;
        Assert.isNull([SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :request.Id].Vendor__c);
    }

    @IsTest
    static void assignsTheVendorWithTheLeastOpenWorkload() {
        List<Vendor__c> vendors = TestDataFactory.insertVendors(new List<String>{ 'Alpha Repairs', 'Bravo Fixers' });
        // Alpha already has two active requests, Bravo has none.
        insert new List<Maintenance_Request__c>{
            new Maintenance_Request__c(Property__c = prop().Id, Vendor__c = vendors[0].Id, Status__c = 'Open', Description__c = 'x'),
            new Maintenance_Request__c(Property__c = prop().Id, Vendor__c = vendors[0].Id, Status__c = 'In progress', Description__c = 'x')
        };

        Maintenance_Request__c request = TestDataFactory.buildRequest(prop().Id, 'Open');
        insert request;

        Assert.areEqual(vendors[1].Id, [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :request.Id].Vendor__c);
    }

    @IsTest
    static void completedAndCancelledRequestsDoNotCountAsWorkload() {
        List<Vendor__c> vendors = TestDataFactory.insertVendors(new List<String>{ 'Alpha Repairs', 'Bravo Fixers' });
        insert new List<Maintenance_Request__c>{
            new Maintenance_Request__c(Property__c = prop().Id, Vendor__c = vendors[0].Id, Status__c = 'Completed', Description__c = 'x'),
            new Maintenance_Request__c(Property__c = prop().Id, Vendor__c = vendors[0].Id, Status__c = 'Cancelled', Description__c = 'x'),
            new Maintenance_Request__c(Property__c = prop().Id, Vendor__c = vendors[1].Id, Status__c = 'Open', Description__c = 'x')
        };

        Maintenance_Request__c request = TestDataFactory.buildRequest(prop().Id, 'Open');
        insert request;

        Assert.areEqual(vendors[0].Id, [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :request.Id].Vendor__c);
    }

    @IsTest
    static void breaksTiesByVendorName() {
        List<Vendor__c> vendors = TestDataFactory.insertVendors(new List<String>{ 'Zulu Services', 'Alpha Repairs' });
        Maintenance_Request__c request = TestDataFactory.buildRequest(prop().Id, 'Open');
        insert request;
        Assert.areEqual(vendors[1].Id, [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :request.Id].Vendor__c);
    }

    @IsTest
    static void skipsInactiveVendors() {
        List<Vendor__c> vendors = TestDataFactory.insertVendors(new List<String>{ 'Alpha Repairs', 'Bravo Fixers' });
        vendors[0].Is_Active__c = false;
        update vendors[0];

        Maintenance_Request__c request = TestDataFactory.buildRequest(prop().Id, 'Open');
        insert request;

        Assert.areEqual(vendors[1].Id, [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :request.Id].Vendor__c);
    }

    @IsTest
    static void spreadsABulkInsertEvenlyAcrossVendors() {
        List<Vendor__c> vendors = TestDataFactory.insertVendors(new List<String>{ 'Alpha Repairs', 'Bravo Fixers', 'Charlie Works' });
        List<Maintenance_Request__c> requests = new List<Maintenance_Request__c>();
        for (Integer i = 0; i < 10; i++) {
            requests.add(TestDataFactory.buildRequest(prop().Id, 'Open'));
        }

        Test.startTest();
        insert requests;
        Test.stopTest();

        Map<Id, Integer> counts = countByVendor();
        Assert.areEqual(4, counts.get(vendors[0].Id));
        Assert.areEqual(3, counts.get(vendors[1].Id));
        Assert.areEqual(3, counts.get(vendors[2].Id));
    }

    @IsTest
    static void keepsAnExplicitVendorAndCountsItTowardsWorkload() {
        List<Vendor__c> vendors = TestDataFactory.insertVendors(new List<String>{ 'Alpha Repairs', 'Bravo Fixers' });
        Maintenance_Request__c chosen = new Maintenance_Request__c(Property__c = prop().Id, Vendor__c = vendors[0].Id, Status__c = 'Open', Description__c = 'x');
        Maintenance_Request__c automatic = TestDataFactory.buildRequest(prop().Id, 'Open');

        insert new List<Maintenance_Request__c>{ chosen, automatic };

        Assert.areEqual(vendors[0].Id, [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :chosen.Id].Vendor__c);
        Assert.areEqual(vendors[1].Id, [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :automatic.Id].Vendor__c);
    }

    @IsTest
    static void aClosedRequestGetsAVendorButAddsNoWorkload() {
        List<Vendor__c> vendors = TestDataFactory.insertVendors(new List<String>{ 'Alpha Repairs', 'Bravo Fixers' });
        Maintenance_Request__c closed = TestDataFactory.buildRequest(prop().Id, 'Completed');
        Maintenance_Request__c open = TestDataFactory.buildRequest(prop().Id, 'Open');

        insert new List<Maintenance_Request__c>{ closed, open };

        Assert.areEqual(vendors[0].Id, [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :closed.Id].Vendor__c);
        Assert.areEqual(vendors[0].Id, [SELECT Vendor__c FROM Maintenance_Request__c WHERE Id = :open.Id].Vendor__c, 'Closed work does not count, so Alpha is still the least loaded');
    }

    @IsTest
    static void requestDefaultsToOpenAndRequiresADescription() {
        Maintenance_Request__c request = new Maintenance_Request__c(Property__c = prop().Id, Description__c = 'Broken window');
        insert request;
        Assert.areEqual('Open', [SELECT Status__c FROM Maintenance_Request__c WHERE Id = :request.Id].Status__c);

        Maintenance_Request__c blank = new Maintenance_Request__c(Property__c = prop().Id);
        Assert.isFalse(Database.insert(blank, false).isSuccess());
    }
}
