/**
 * Geocodes property addresses with the OpenStreetMap Nominatim search API
 * (free, no API key). Callouts are made first, DML is returned to the caller so the
 * same logic can run from a Queueable or a Batch.
 */
public with sharing class GeocodingService {
    public static final String STATUS_PENDING = 'Pending';
    public static final String STATUS_SUCCESS = 'Success';
    public static final String STATUS_FAILED = 'Failed';

    @TestVisible
    private static final String ENDPOINT = 'https://nominatim.openstreetmap.org/search';

    public class GeoResult {
        public Boolean found = false;
        public Decimal latitude;
        public Decimal longitude;
        public String message;
    }

    public static GeoResult geocode(String address) {
        GeoResult result = new GeoResult();
        if (String.isBlank(address)) {
            result.message = 'Address is blank';
            return result;
        }
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(ENDPOINT + '?format=json&limit=1&q=' + EncodingUtil.urlEncode(address, 'UTF-8'));
            req.setMethod('GET');
            req.setHeader('User-Agent', 'RealEstatePMS-Salesforce/1.0');
            req.setTimeout(20000);

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) {
                result.message = 'HTTP ' + res.getStatusCode();
                return result;
            }
            List<Object> matches = (List<Object>) JSON.deserializeUntyped(res.getBody());
            if (matches.isEmpty()) {
                result.message = 'No match found';
                return result;
            }
            Map<String, Object> first = (Map<String, Object>) matches[0];
            result.latitude = Decimal.valueOf(String.valueOf(first.get('lat'))).setScale(6);
            result.longitude = Decimal.valueOf(String.valueOf(first.get('lon'))).setScale(6);
            result.found = true;
        } catch (Exception e) {
            result.message = e.getMessage();
        }
        return result;
    }

    public static String buildAddress(Property__c prop) {
        List<String> parts = new List<String>();
        for (String part : new List<String>{ prop.Address__c, prop.City__c, prop.State__c, prop.Postal_Code__c, prop.Country__c }) {
            if (String.isNotBlank(part)) {
                parts.add(part.trim());
            }
        }
        return String.join(parts, ', ');
    }

    /**
     * Makes one callout per property and returns the records to update (no DML here).
     */
    public static List<Property__c> geocodeProperties(List<Property__c> properties) {
        List<Property__c> updates = new List<Property__c>();
        for (Property__c prop : properties) {
            GeoResult result = geocode(buildAddress(prop));
            Property__c upd = new Property__c(Id = prop.Id);
            if (result.found) {
                upd.Location__Latitude__s = result.latitude;
                upd.Location__Longitude__s = result.longitude;
                upd.Geocode_Status__c = STATUS_SUCCESS;
            } else {
                upd.Geocode_Status__c = (STATUS_FAILED + ': ' + result.message).left(100);
            }
            updates.add(upd);
        }
        return updates;
    }
}
