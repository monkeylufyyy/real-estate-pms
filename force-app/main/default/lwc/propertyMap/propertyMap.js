import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

const FIELDS = [
    'Property__c.Name',
    'Property__c.Address__c',
    'Property__c.City__c',
    'Property__c.State__c',
    'Property__c.Postal_Code__c',
    'Property__c.Country__c',
    'Property__c.Location__Latitude__s',
    'Property__c.Location__Longitude__s',
    'Property__c.Geocode_Status__c'
];

const value = (record, field) => (record && record.fields[field] ? record.fields[field].value : null);

export default class PropertyMap extends LightningElement {
    @api recordId;

    record;
    error;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ data, error }) {
        if (data) {
            this.record = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.record = undefined;
        }
    }

    get latitude() {
        return value(this.record, 'Location__Latitude__s');
    }
    get longitude() {
        return value(this.record, 'Location__Longitude__s');
    }
    get hasCoordinates() {
        return this.latitude !== null && this.longitude !== null;
    }
    get geocodeStatus() {
        return value(this.record, 'Geocode_Status__c');
    }
    get hasAddress() {
        return !!value(this.record, 'Address__c');
    }

    get mapMarkers() {
        if (!this.record) {
            return [];
        }
        const name = value(this.record, 'Name');
        const addressLine = [
            value(this.record, 'Address__c'),
            value(this.record, 'City__c'),
            value(this.record, 'State__c'),
            value(this.record, 'Postal_Code__c'),
            value(this.record, 'Country__c')
        ]
            .filter(Boolean)
            .join(', ');

        if (this.hasCoordinates) {
            return [
                {
                    location: { Latitude: this.latitude, Longitude: this.longitude },
                    title: name,
                    description: addressLine
                }
            ];
        }
        // Coordinates are still being looked up: let the map component resolve the address itself.
        if (this.hasAddress) {
            return [
                {
                    location: {
                        Street: value(this.record, 'Address__c'),
                        City: value(this.record, 'City__c'),
                        State: value(this.record, 'State__c'),
                        PostalCode: value(this.record, 'Postal_Code__c'),
                        Country: value(this.record, 'Country__c')
                    },
                    title: name,
                    description: addressLine
                }
            ];
        }
        return [];
    }

    get hasMarkers() {
        return this.mapMarkers.length > 0;
    }

    get statusText() {
        if (this.hasCoordinates) {
            return `Geocoded: ${Number(this.latitude).toFixed(5)}, ${Number(this.longitude).toFixed(5)}`;
        }
        return this.geocodeStatus ? `Geocoding status: ${this.geocodeStatus}` : 'Location not geocoded yet';
    }
}
