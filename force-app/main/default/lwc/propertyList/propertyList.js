import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import CURRENCY from '@salesforce/i18n/currency';
import searchProperties from '@salesforce/apex/PropertySearchController.searchProperties';

const STATUS_OPTIONS = [
    { label: 'All', value: '' },
    { label: 'Available', value: 'Available' },
    { label: 'Occupied', value: 'Occupied' }
];
const FURNISHING_OPTIONS = [
    { label: 'All', value: '' },
    { label: 'Furnished', value: 'Furnished' },
    { label: 'Semi-Furnished', value: 'Semi-Furnished' },
    { label: 'Unfurnished', value: 'Unfurnished' }
];
const TYPE_OPTIONS = [
    { label: 'All', value: '' },
    { label: 'Residential', value: 'Residential' },
    { label: 'Commercial', value: 'Commercial' }
];

const toNumber = (value) => (value === '' || value === null || value === undefined ? null : Number(value));

export default class PropertyList extends NavigationMixin(LightningElement) {
    statusOptions = STATUS_OPTIONS;
    furnishingOptions = FURNISHING_OPTIONS;
    typeOptions = TYPE_OPTIONS;
    currencyCode = CURRENCY;

    // filter inputs
    minRent = '';
    maxRent = '';
    status = '';
    furnishing = '';
    propertyType = '';
    distanceKm = '';
    latitude = '';
    longitude = '';

    // result state
    rows = [];
    totalCount = 0;
    pageNumber = 1;
    totalPages = 1;
    pageSize = 25;
    truncated = false;
    isLoading = false;
    locating = false;

    // Incremented per request so a slow, outdated response never overwrites a newer one.
    requestId = 0;
    appliedFilters = {};

    connectedCallback() {
        this.loadPage(1);
    }

    // ---------- derived ----------
    get hasRows() {
        return this.rows.length > 0;
    }
    get isFirstPage() {
        return this.pageNumber <= 1;
    }
    get isLastPage() {
        return this.pageNumber >= this.totalPages;
    }
    get rangeLabel() {
        if (this.totalCount === 0) {
            return 'No properties found';
        }
        const from = (this.pageNumber - 1) * this.pageSize + 1;
        const to = from + this.rows.length - 1;
        return `${from}-${to} of ${this.totalCount}`;
    }
    get pageLabel() {
        return `Page ${this.pageNumber} of ${this.totalPages}`;
    }
    get nearbyActive() {
        return this.appliedFilters.distanceKm !== null && this.appliedFilters.distanceKm !== undefined;
    }

    // ---------- filter handlers ----------
    handleInput(event) {
        const field = event.target.dataset.field;
        this[field] = event.detail.value;
    }

    handleApply() {
        const inputs = this.template.querySelectorAll('lightning-input, lightning-combobox');
        const valid = [...inputs].reduce((ok, el) => el.reportValidity() && ok, true);
        if (!valid) {
            return;
        }
        const minRent = toNumber(this.minRent);
        const maxRent = toNumber(this.maxRent);
        if (minRent !== null && maxRent !== null && minRent > maxRent) {
            this.showToast('Check the price filter', 'Minimum price cannot be greater than maximum price.', 'error');
            return;
        }

        const needsLocation = toNumber(this.distanceKm) !== null && (this.latitude === '' || this.longitude === '');
        if (needsLocation) {
            this.useMyLocation().then((located) => {
                if (located) {
                    this.loadPage(1);
                }
            });
            return;
        }
        this.loadPage(1);
    }

    handleClear() {
        this.minRent = '';
        this.maxRent = '';
        this.status = '';
        this.furnishing = '';
        this.propertyType = '';
        this.distanceKm = '';
        this.latitude = '';
        this.longitude = '';
        this.loadPage(1);
    }

    handleUseMyLocation() {
        this.useMyLocation();
    }

    useMyLocation() {
        return new Promise((resolve) => {
            if (!navigator.geolocation) {
                this.showToast('Location unavailable', 'Your browser does not support geolocation. Enter latitude and longitude manually.', 'warning');
                resolve(false);
                return;
            }
            this.locating = true;
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    this.latitude = String(Number(position.coords.latitude.toFixed(6)));
                    this.longitude = String(Number(position.coords.longitude.toFixed(6)));
                    this.locating = false;
                    resolve(true);
                },
                () => {
                    this.locating = false;
                    this.showToast(
                        'Could not get your location',
                        'Allow location access in the browser, or enter latitude and longitude manually.',
                        'warning'
                    );
                    resolve(false);
                },
                { enableHighAccuracy: false, timeout: 10000 }
            );
        });
    }

    // ---------- paging ----------
    handleFirst() {
        this.loadPage(1);
    }
    handlePrevious() {
        this.loadPage(this.pageNumber - 1);
    }
    handleNext() {
        this.loadPage(this.pageNumber + 1);
    }
    handleLast() {
        this.loadPage(this.totalPages);
    }

    // ---------- data ----------
    buildFilters() {
        const distanceKm = toNumber(this.distanceKm);
        return {
            minRent: toNumber(this.minRent),
            maxRent: toNumber(this.maxRent),
            status: this.status || null,
            furnishing: this.furnishing || null,
            propertyType: this.propertyType || null,
            distanceKm,
            latitude: distanceKm === null ? null : toNumber(this.latitude),
            longitude: distanceKm === null ? null : toNumber(this.longitude)
        };
    }

    loadPage(pageNumber, keepFilters = false) {
        if (!keepFilters) {
            this.appliedFilters = this.buildFilters();
        }
        const current = ++this.requestId;
        this.isLoading = true;
        searchProperties({ filtersJson: JSON.stringify(this.appliedFilters), pageNumber })
            .then((result) => {
                if (current !== this.requestId) {
                    return;
                }
                this.rows = result.rows.map((row) => ({
                    ...row,
                    badgeClass: row.status === 'Available' ? 'slds-badge slds-theme_success' : 'slds-badge slds-theme_warning',
                    subtitle: [row.propertyType, row.furnishing].filter(Boolean).join(' • '),
                    location: [row.city, row.state, row.country].filter(Boolean).join(', '),
                    hasDistance: row.distanceKm !== null && row.distanceKm !== undefined,
                    imageSrc: row.thumbUrl || row.imageUrl
                }));
                this.totalCount = result.totalCount;
                this.pageNumber = result.pageNumber;
                this.totalPages = result.totalPages;
                this.pageSize = result.pageSize;
                this.truncated = result.truncated;
            })
            .catch((error) => {
                if (current === this.requestId) {
                    this.showToast('Could not load properties', this.errorMessage(error), 'error');
                }
            })
            .finally(() => {
                if (current === this.requestId) {
                    this.isLoading = false;
                }
            });
    }

    // ---------- navigation ----------
    handleNew() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Property__c', actionName: 'new' }
        });
    }

    handleOpen(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: event.currentTarget.dataset.id, objectApiName: 'Property__c', actionName: 'view' }
        });
    }

    // Thumbnails are generated asynchronously by Salesforce, so fall back to the original file.
    handleImageError(event) {
        const img = event.target;
        const fallback = img.dataset.fallback;
        if (fallback && !img.src.endsWith(fallback)) {
            img.src = fallback;
        } else {
            img.style.display = 'none';
        }
    }

    // ---------- helpers ----------
    errorMessage(error) {
        return (error && error.body && error.body.message) || (error && error.message) || 'Unknown error';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
