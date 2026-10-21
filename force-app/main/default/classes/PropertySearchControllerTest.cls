@IsTest
private class PropertySearchControllerTest {
    private static final String[] FURNISHINGS = new List<String>{ 'Furnished', 'Semi-Furnished', 'Unfurnished' };

    @TestSetup
    static void setup() {
        TestDataFactory.disableGeocoding();
        // 60 properties: rent 10,000 .. 15,900, alternating status, cycling furnishing and type.
        List<Property__c> props = new List<Property__c>();
        for (Integer i = 0; i < 60; i++) {
            Property__c p = TestDataFactory.buildProperty('Listing ' + String.valueOf(1000 + i), 10000 + (i * 100));
            p.Status__c = Math.mod(i, 2) == 0 ? 'Available' : 'Occupied';
            p.Furnishing_Status__c = FURNISHINGS[Math.mod(i, 3)];
            p.Type__c = Math.mod(i, 5) == 0 ? 'Commercial' : 'Residential';
            props.add(p);
        }
        insert props;
    }

    private static PropertySearchController.PageResult search(Map<String, Object> filters, Integer page) {
        return PropertySearchController.searchProperties(JSON.serialize(filters), page);
    }

    @IsTest
    static void listsTwentyFiveRecordsPerPage() {
        User pmsUser = TestDataFactory.createPmsUser();
        System.runAs(pmsUser) {
            PropertySearchController.PageResult page1 = search(new Map<String, Object>(), 1);
            Assert.areEqual(60, page1.totalCount);
            Assert.areEqual(25, page1.rows.size());
            Assert.areEqual(3, page1.totalPages);
            Assert.areEqual(25, page1.pageSize);
            Assert.areEqual('Listing 1000', page1.rows[0].name);

            PropertySearchController.PageResult page2 = search(new Map<String, Object>(), 2);
            Assert.areEqual(25, page2.rows.size());
            Assert.areEqual('Listing 1025', page2.rows[0].name);

            PropertySearchController.PageResult page3 = search(new Map<String, Object>(), 3);
            Assert.areEqual(10, page3.rows.size());
            Assert.isFalse(page3.truncated);
        }
    }

    @IsTest
    static void clampsOutOfRangePageNumbers() {
        User pmsUser = TestDataFactory.createPmsUser();
        System.runAs(pmsUser) {
            Assert.areEqual(3, search(new Map<String, Object>(), 99).pageNumber);
            Assert.areEqual(1, search(new Map<String, Object>(), 0).pageNumber);
            Assert.areEqual(1, PropertySearchController.searchProperties(null, null).pageNumber);
        }
    }

    @IsTest
    static void filtersByPrice() {
        User pmsUser = TestDataFactory.createPmsUser();
        System.runAs(pmsUser) {
            PropertySearchController.PageResult result = search(new Map<String, Object>{ 'minRent' => 10000, 'maxRent' => 10900 }, 1);
            Assert.areEqual(10, result.totalCount);
            for (PropertySearchController.PropertyRow row : result.rows) {
                Assert.isTrue(row.rent >= 10000 && row.rent <= 10900);
            }
            Assert.areEqual(50, search(new Map<String, Object>{ 'minRent' => 11000 }, 1).totalCount);
            Assert.areEqual(11, search(new Map<String, Object>{ 'maxRent' => 11000 }, 1).totalCount);
        }
    }

    @IsTest
    static void filtersByAvailabilityAndFurnishing() {
        User pmsUser = TestDataFactory.createPmsUser();
        System.runAs(pmsUser) {
            Assert.areEqual(30, search(new Map<String, Object>{ 'status' => 'Available' }, 1).totalCount);
            Assert.areEqual(30, search(new Map<String, Object>{ 'status' => 'Occupied' }, 1).totalCount);
            Assert.areEqual(20, search(new Map<String, Object>{ 'furnishing' => 'Furnished' }, 1).totalCount);
            Assert.areEqual(12, search(new Map<String, Object>{ 'propertyType' => 'Commercial' }, 1).totalCount);

            PropertySearchController.PageResult combined = search(new Map<String, Object>{ 'status' => 'Available', 'furnishing' => 'Furnished', 'minRent' => 10000, 'maxRent' => 11000 }, 1);
            for (PropertySearchController.PropertyRow row : combined.rows) {
                Assert.areEqual('Available', row.status);
                Assert.areEqual('Furnished', row.furnishing);
            }
            Assert.isTrue(combined.totalCount > 0);
        }
    }

    @IsTest
    static void returnsAnEmptyPageWhenNothingMatches() {
        User pmsUser = TestDataFactory.createPmsUser();
        System.runAs(pmsUser) {
            PropertySearchController.PageResult result = search(new Map<String, Object>{ 'minRent' => 999999 }, 1);
            Assert.areEqual(0, result.totalCount);
            Assert.isTrue(result.rows.isEmpty());
            Assert.areEqual(1, result.totalPages);
        }
    }

    @IsTest
    static void filtersByDistanceAndSortsNearestFirst() {
        List<Property__c> located = new List<Property__c>();
        Property__c near = TestDataFactory.buildProperty('Near', 5000);
        near.Location__Latitude__s = 13.0900;
        near.Location__Longitude__s = 80.2800;
        Property__c nearer = TestDataFactory.buildProperty('Nearer', 5000);
        nearer.Location__Latitude__s = 13.0830;
        nearer.Location__Longitude__s = 80.2710;
        Property__c far = TestDataFactory.buildProperty('Far away', 5000);
        far.Location__Latitude__s = 19.0760;
        far.Location__Longitude__s = 72.8777;
        located.addAll(new List<Property__c>{ near, nearer, far });
        TestDataFactory.disableGeocoding();
        insert located;

        User pmsUser = TestDataFactory.createPmsUser();
        System.runAs(pmsUser) {
            PropertySearchController.PageResult result = search(
                new Map<String, Object>{ 'latitude' => 13.0827, 'longitude' => 80.2707, 'distanceKm' => 10 },
                1
            );
            Assert.areEqual(2, result.totalCount, 'Mumbai and un-geocoded properties are excluded');
            Assert.areEqual('Nearer', result.rows[0].name);
            Assert.areEqual('Near', result.rows[1].name);
            Assert.isNotNull(result.rows[0].distanceKm);
            Assert.isTrue(result.rows[0].distanceKm < result.rows[1].distanceKm);
            Assert.isTrue(result.rows[1].distanceKm < 10);

            PropertySearchController.PageResult wide = search(
                new Map<String, Object>{ 'latitude' => 13.0827, 'longitude' => 80.2707, 'distanceKm' => 2000 },
                1
            );
            Assert.areEqual(3, wide.totalCount);
        }
    }

    @IsTest
    static void includesTheFirstImageOfEachProperty() {
        Property__c prop = [SELECT Id FROM Property__c WHERE Name = 'Listing 1000'];
        ContentVersion file = TestDataFactory.insertFile(prop.Id, 'front.png');
        TestDataFactory.insertFile(prop.Id, 'back.png');
        // A non-image attachment must be ignored.
        insert new ContentVersion(Title = 'Agreement', PathOnClient = 'agreement.pdf', VersionData = Blob.valueOf('x'), FirstPublishLocationId = prop.Id);

        User pmsUser = TestDataFactory.createPmsUser();
        System.runAs(pmsUser) {
            PropertySearchController.PageResult result = search(new Map<String, Object>(), 1);
            PropertySearchController.PropertyRow first = result.rows[0];
            Assert.areEqual('Listing 1000', first.name);
            Assert.isNotNull(first.imageUrl);
            Assert.isTrue(first.imageUrl.startsWith('/sfc/servlet.shepherd/version/download/'));
            Assert.isNotNull(first.thumbUrl);
            Assert.isNull(result.rows[1].imageUrl);
        }
        Assert.isNotNull(file.Id);
    }

    @IsTest
    static void validatesFilters() {
        User pmsUser = TestDataFactory.createPmsUser();
        List<Map<String, Object>> invalid = new List<Map<String, Object>>{
            new Map<String, Object>{ 'minRent' => 500, 'maxRent' => 100 },
            new Map<String, Object>{ 'status' => 'Unknown' },
            new Map<String, Object>{ 'furnishing' => 'Unknown' },
            new Map<String, Object>{ 'propertyType' => 'Unknown' },
            new Map<String, Object>{ 'distanceKm' => 0, 'latitude' => 10, 'longitude' => 10 },
            new Map<String, Object>{ 'distanceKm' => 5 },
            new Map<String, Object>{ 'distanceKm' => 5, 'latitude' => 95, 'longitude' => 10 }
        };
        System.runAs(pmsUser) {
            for (Map<String, Object> filters : invalid) {
                try {
                    search(filters, 1);
                    Assert.fail('Expected a validation error for ' + JSON.serialize(filters));
                } catch (AuraHandledException e) {
                    Assert.isNotNull(e.getMessage());
                }
            }
            try {
                PropertySearchController.searchProperties('{broken', 1);
                Assert.fail('Expected a parse error');
            } catch (AuraHandledException e) {
                Assert.areEqual('The filters could not be read.', e.getMessage());
            }
        }
    }
}
