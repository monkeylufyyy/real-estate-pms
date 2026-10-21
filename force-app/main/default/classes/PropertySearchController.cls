/**
 * Server-side search and pagination for the property list view (25 records per page).
 * Filters: rent range, availability status, furnishing status, property type and
 * "nearby" (distance in km from the user's location).
 */
public with sharing class PropertySearchController {
    public static final Integer PAGE_SIZE = 25;
    // SOQL OFFSET is capped at 2,000 rows. Narrow the filters to reach records beyond that.
    @TestVisible
    private static final Integer MAX_OFFSET = 2000;

    private static final Set<String> STATUSES = new Set<String>{ 'Available', 'Occupied' };
    private static final Set<String> FURNISHINGS = new Set<String>{ 'Furnished', 'Semi-Furnished', 'Unfurnished' };
    private static final Set<String> TYPES = new Set<String>{ 'Residential', 'Commercial' };

    private static final String FIELDS =
        'Id, Name, Address__c, City__c, State__c, Postal_Code__c, Country__c, Type__c, ' +
        'Furnishing_Status__c, Status__c, Rent__c, Image_Count__c, Location__Latitude__s, Location__Longitude__s';

    public class Filters {
        public Decimal minRent;
        public Decimal maxRent;
        public String status;
        public String furnishing;
        public String propertyType;
        public Decimal latitude;
        public Decimal longitude;
        public Decimal distanceKm;
    }

    public class PropertyRow {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String address;
        @AuraEnabled
        public String city;
        @AuraEnabled
        public String state;
        @AuraEnabled
        public String country;
        @AuraEnabled
        public String propertyType;
        @AuraEnabled
        public String furnishing;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public Decimal rent;
        @AuraEnabled
        public String imageUrl;
        @AuraEnabled
        public String thumbUrl;
        @AuraEnabled
        public Decimal distanceKm;
    }

    public class PageResult {
        @AuraEnabled
        public List<PropertyRow> rows = new List<PropertyRow>();
        @AuraEnabled
        public Integer totalCount = 0;
        @AuraEnabled
        public Integer pageNumber = 1;
        @AuraEnabled
        public Integer pageSize = PAGE_SIZE;
        @AuraEnabled
        public Integer totalPages = 1;
        @AuraEnabled
        public Boolean truncated = false;
    }

    @AuraEnabled
    public static PageResult searchProperties(String filtersJson, Integer pageNumber) {
        try {
            Filters filters = parseFilters(filtersJson);
            validate(filters);

            Map<String, Object> binds = new Map<String, Object>();
            String whereSql = buildWhere(filters, binds);

            PageResult result = new PageResult();
            result.totalCount = Database.countQueryWithBinds('SELECT COUNT() FROM Property__c' + whereSql, binds, AccessLevel.USER_MODE);

            Integer pagesNeeded = Math.max(1, (Integer) Math.ceil((Decimal) result.totalCount / PAGE_SIZE));
            Integer maxPages = (MAX_OFFSET / PAGE_SIZE) + 1;
            result.truncated = pagesNeeded > maxPages;
            result.totalPages = Math.min(pagesNeeded, maxPages);
            result.pageNumber = Math.min(Math.max(pageNumber == null ? 1 : pageNumber, 1), result.totalPages);

            if (result.totalCount == 0) {
                return result;
            }

            Integer offset = (result.pageNumber - 1) * PAGE_SIZE;
            String soql =
                'SELECT ' + FIELDS + ' FROM Property__c' + whereSql +
                ' ORDER BY ' + buildOrderBy(filters) +
                ' LIMIT ' + PAGE_SIZE + ' OFFSET ' + offset;
            List<Property__c> records = Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);
            result.rows = toRows(records, filters);
            return result;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw AuraErrors.build(AuraErrors.messageOf(e));
        }
    }

    private static Filters parseFilters(String filtersJson) {
        if (String.isBlank(filtersJson)) {
            return new Filters();
        }
        try {
            return (Filters) JSON.deserialize(filtersJson, Filters.class);
        } catch (Exception e) {
            throw AuraErrors.build('The filters could not be read.');
        }
    }

    private static void validate(Filters f) {
        if (f.minRent != null && f.maxRent != null && f.minRent > f.maxRent) {
            throw AuraErrors.build('Minimum rent cannot be greater than maximum rent.');
        }
        if (String.isNotBlank(f.status) && !STATUSES.contains(f.status)) {
            throw AuraErrors.build('Unknown availability status: ' + f.status);
        }
        if (String.isNotBlank(f.furnishing) && !FURNISHINGS.contains(f.furnishing)) {
            throw AuraErrors.build('Unknown furnishing status: ' + f.furnishing);
        }
        if (String.isNotBlank(f.propertyType) && !TYPES.contains(f.propertyType)) {
            throw AuraErrors.build('Unknown property type: ' + f.propertyType);
        }
        if (f.distanceKm != null) {
            if (f.distanceKm <= 0) {
                throw AuraErrors.build('Distance must be greater than zero.');
            }
            if (f.latitude == null || f.longitude == null || Math.abs(f.latitude) > 90 || Math.abs(f.longitude) > 180) {
                throw AuraErrors.build('A valid location (latitude and longitude) is required for the nearby filter.');
            }
        }
    }

    private static String buildWhere(Filters f, Map<String, Object> binds) {
        List<String> clauses = new List<String>();
        if (f.minRent != null) {
            clauses.add('Rent__c >= :minRent');
            binds.put('minRent', f.minRent);
        }
        if (f.maxRent != null) {
            clauses.add('Rent__c <= :maxRent');
            binds.put('maxRent', f.maxRent);
        }
        if (String.isNotBlank(f.status)) {
            clauses.add('Status__c = :status');
            binds.put('status', f.status);
        }
        if (String.isNotBlank(f.furnishing)) {
            clauses.add('Furnishing_Status__c = :furnishing');
            binds.put('furnishing', f.furnishing);
        }
        if (String.isNotBlank(f.propertyType)) {
            clauses.add('Type__c = :propertyType');
            binds.put('propertyType', f.propertyType);
        }
        if (f.distanceKm != null) {
            // Numbers are typed Decimals (validated above), so inlining them is injection-safe.
            clauses.add('DISTANCE(Location__c, ' + geolocation(f) + ', \'km\') < ' + f.distanceKm);
        }
        return clauses.isEmpty() ? '' : ' WHERE ' + String.join(clauses, ' AND ');
    }

    private static String buildOrderBy(Filters f) {
        if (f.distanceKm != null) {
            return 'DISTANCE(Location__c, ' + geolocation(f) + ', \'km\') ASC, Id ASC';
        }
        return 'Name ASC, Id ASC';
    }

    private static String geolocation(Filters f) {
        return 'GEOLOCATION(' + f.latitude + ', ' + f.longitude + ')';
    }

    private static List<PropertyRow> toRows(List<Property__c> records, Filters f) {
        Map<Id, Id> versionByProperty = firstImageVersions(records);
        List<PropertyRow> rows = new List<PropertyRow>();
        for (Property__c p : records) {
            PropertyRow row = new PropertyRow();
            row.id = p.Id;
            row.name = p.Name;
            row.address = p.Address__c;
            row.city = p.City__c;
            row.state = p.State__c;
            row.country = p.Country__c;
            row.propertyType = p.Type__c;
            row.furnishing = p.Furnishing_Status__c;
            row.status = p.Status__c;
            row.rent = p.Rent__c;

            Id versionId = versionByProperty.get(p.Id);
            if (versionId != null) {
                row.imageUrl = '/sfc/servlet.shepherd/version/download/' + versionId;
                row.thumbUrl = '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + versionId;
            }
            if (f.distanceKm != null && p.Location__Latitude__s != null && p.Location__Longitude__s != null) {
                Decimal km = Location.getDistance(
                    Location.newInstance(f.latitude, f.longitude),
                    Location.newInstance(p.Location__Latitude__s, p.Location__Longitude__s),
                    'km'
                );
                row.distanceKm = km.setScale(1);
            }
            rows.add(row);
        }
        return rows;
    }

    /**
     * One query for the whole page: the latest published version of the first image of each property.
     */
    private static Map<Id, Id> firstImageVersions(List<Property__c> records) {
        Map<Id, Id> result = new Map<Id, Id>();
        if (records.isEmpty()) {
            return result;
        }
        Set<Id> propertyIds = new Map<Id, Property__c>(records).keySet();
        Set<String> imageExtensions = PropertyService.IMAGE_EXTENSIONS;
        for (ContentDocumentLink link : [
            SELECT LinkedEntityId, ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :propertyIds AND ContentDocument.FileExtension IN :imageExtensions
            ORDER BY SystemModstamp ASC
            LIMIT 2000
        ]) {
            if (!result.containsKey(link.LinkedEntityId)) {
                result.put(link.LinkedEntityId, link.ContentDocument.LatestPublishedVersionId);
            }
        }
        return result;
    }
}
