/**
 * Shared test data builders. Geocoding is switched off by default so unrelated tests
 * never queue callouts; call enableGeocoding() in the tests that exercise it.
 */
@IsTest
public class TestDataFactory {
    // 1x1 pixel PNG
    public static final String TINY_PNG_BASE64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

    public static void enableGeocoding() {
        PropertyTriggerHandler.disableGeocoding = false;
    }

    public static void disableGeocoding() {
        PropertyTriggerHandler.disableGeocoding = true;
    }

    public static List<Tenant__c> insertTenants(Integer count) {
        List<Tenant__c> tenants = new List<Tenant__c>();
        for (Integer i = 0; i < count; i++) {
            tenants.add(new Tenant__c(Name = 'Tenant ' + i, Phone__c = '98765432' + String.valueOf(10 + i), Email__c = 'tenant' + i + '@example.com'));
        }
        insert tenants;
        return tenants;
    }

    public static Property__c buildProperty(String name, Decimal rent) {
        return new Property__c(
            Name = name,
            Address__c = '12 Anna Salai',
            City__c = 'Chennai',
            State__c = 'Tamil Nadu',
            Postal_Code__c = '600002',
            Country__c = 'India',
            Type__c = 'Residential',
            Status__c = 'Available',
            Rent__c = rent,
            Description__c = 'A test property'
        );
    }

    public static List<Property__c> insertProperties(Integer count) {
        disableGeocoding();
        List<Property__c> properties = new List<Property__c>();
        for (Integer i = 0; i < count; i++) {
            properties.add(buildProperty('Property ' + i, 10000 + (i * 100)));
        }
        insert properties;
        return properties;
    }

    public static Lease_Agreement__c buildLease(Id propertyId, Id tenantId, Date startDate, Date endDate) {
        return new Lease_Agreement__c(
            Property__c = propertyId,
            Tenant__c = tenantId,
            Terms__c = 'Rent is due on the first of every month.',
            Agreed_Monthly_Rent__c = 15000,
            Start_Date__c = startDate,
            End_Date__c = endDate
        );
    }

    public static List<Vendor__c> insertVendors(List<String> names) {
        List<Vendor__c> vendors = new List<Vendor__c>();
        for (String name : names) {
            vendors.add(new Vendor__c(Name = name, Phone__c = '9000000000', Email__c = name.deleteWhitespace().toLowerCase() + '@example.com'));
        }
        insert vendors;
        return vendors;
    }

    public static Maintenance_Request__c buildRequest(Id propertyId, String status) {
        return new Maintenance_Request__c(Property__c = propertyId, Status__c = status, Description__c = 'Leaking tap');
    }

    public static ContentVersion insertFile(Id linkedEntityId, String fileName) {
        ContentVersion version = new ContentVersion(
            Title = fileName.substringBeforeLast('.'),
            PathOnClient = fileName,
            VersionData = EncodingUtil.base64Decode(TINY_PNG_BASE64),
            FirstPublishLocationId = linkedEntityId
        );
        insert version;
        return version;
    }

    /**
     * A non-admin user holding only the Real Estate PMS permission set, so tests that run
     * with user-mode security prove the permission set grants everything the app needs.
     */
    public static User createPmsUser() {
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User user = new User(
            Alias = 'pmsuser',
            Email = 'pmsuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Tester',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            Username = 'pms' + System.currentTimeMillis() + '@example.com'
        );
        // runAs keeps this setup-object DML apart from the test's regular DML (mixed DML rule).
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert user;
            PermissionSet permissionSet = [SELECT Id FROM PermissionSet WHERE Name = 'Real_Estate_PMS_Admin' LIMIT 1];
            insert new PermissionSetAssignment(AssigneeId = user.Id, PermissionSetId = permissionSet.Id);
        }
        return user;
    }
}
