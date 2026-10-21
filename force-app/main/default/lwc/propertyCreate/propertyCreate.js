import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createProperty from '@salesforce/apex/PropertyService.createProperty';

const MAX_DIMENSION = 1600;
const JPEG_QUALITY = 0.8;
// Keep in sync with PropertyService.MAX_TOTAL_BYTES (3 MB decoded).
const MAX_TOTAL_BYTES = 3 * 1024 * 1024;
const IMAGE_EXTENSIONS = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'];

const extensionOf = (name) => (name.includes('.') ? name.split('.').pop().toLowerCase() : '');

const readAsBase64 = (blob) =>
    new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(String(reader.result).split(',')[1]);
        reader.onerror = () => reject(new Error('The file could not be read.'));
        reader.readAsDataURL(blob);
    });

const loadImage = (file) =>
    new Promise((resolve, reject) => {
        const url = URL.createObjectURL(file);
        const img = new Image();
        img.onload = () => {
            URL.revokeObjectURL(url);
            resolve(img);
        };
        img.onerror = () => {
            URL.revokeObjectURL(url);
            reject(new Error('not an image'));
        };
        img.src = url;
    });

/**
 * Downscales large photos so several images fit in a single save request.
 * Falls back to the original file when it cannot be decoded (or is a GIF, to keep animation).
 */
async function prepareImage(file) {
    const ext = extensionOf(file.name);
    if (ext === 'gif') {
        return { fileName: file.name, base64Data: await readAsBase64(file) };
    }
    try {
        const img = await loadImage(file);
        const scale = Math.min(1, MAX_DIMENSION / Math.max(img.width, img.height));
        const canvas = document.createElement('canvas');
        canvas.width = Math.round(img.width * scale);
        canvas.height = Math.round(img.height * scale);
        canvas.getContext('2d').drawImage(img, 0, 0, canvas.width, canvas.height);
        const blob = await new Promise((resolve) => canvas.toBlob(resolve, 'image/jpeg', JPEG_QUALITY));
        if (blob && blob.size < file.size) {
            const baseName = file.name.includes('.') ? file.name.slice(0, file.name.lastIndexOf('.')) : file.name;
            return { fileName: `${baseName}.jpg`, base64Data: await readAsBase64(blob) };
        }
    } catch (e) {
        // fall through and send the original
    }
    return { fileName: file.name, base64Data: await readAsBase64(file) };
}

export default class PropertyCreate extends NavigationMixin(LightningElement) {
    typeOptions = [
        { label: 'Residential', value: 'Residential' },
        { label: 'Commercial', value: 'Commercial' }
    ];
    furnishingOptions = [
        { label: 'Furnished', value: 'Furnished' },
        { label: 'Semi-Furnished', value: 'Semi-Furnished' },
        { label: 'Unfurnished', value: 'Unfurnished' }
    ];
    statusOptions = [
        { label: 'Available', value: 'Available' },
        { label: 'Occupied', value: 'Occupied' }
    ];

    form = { Status__c: 'Available' };
    files = [];
    isSaving = false;
    errorMessage = '';
    imageError = '';

    get hasFiles() {
        return this.files.length > 0;
    }
    get saveLabel() {
        return this.isSaving ? 'Saving...' : 'Save property';
    }

    handleChange(event) {
        this.form = { ...this.form, [event.target.dataset.field]: event.detail.value };
    }

    handleFiles(event) {
        const selected = [...event.target.files];
        const rejected = selected.filter((f) => !IMAGE_EXTENSIONS.includes(extensionOf(f.name)));
        const accepted = selected.filter((f) => IMAGE_EXTENSIONS.includes(extensionOf(f.name)));

        this.imageError = rejected.length
            ? `Skipped non-image files: ${rejected.map((f) => f.name).join(', ')}`
            : '';
        this.files = [
            ...this.files,
            ...accepted.map((file, index) => ({
                key: `${Date.now()}-${index}-${file.name}`,
                file,
                name: file.name,
                sizeLabel: `${Math.max(1, Math.round(file.size / 1024))} KB`,
                preview: URL.createObjectURL(file)
            }))
        ];
        event.target.value = null;
    }

    handleRemove(event) {
        const key = event.currentTarget.dataset.key;
        const removed = this.files.find((f) => f.key === key);
        if (removed) {
            URL.revokeObjectURL(removed.preview);
        }
        this.files = this.files.filter((f) => f.key !== key);
    }

    handleCancel() {
        this.files.forEach((f) => URL.revokeObjectURL(f.preview));
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'Property_Search' }
        });
    }

    async handleSave() {
        this.errorMessage = '';
        const inputs = this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea');
        const valid = [...inputs].reduce((ok, el) => el.reportValidity() && ok, true);

        if (!this.hasFiles) {
            this.imageError = 'At least one property image is required.';
            return;
        }
        if (!valid) {
            return;
        }

        this.isSaving = true;
        try {
            const images = [];
            for (const entry of this.files) {
                images.push(await prepareImage(entry.file));
            }
            const totalBytes = images.reduce((sum, img) => sum + (img.base64Data.length * 3) / 4, 0);
            if (totalBytes > MAX_TOTAL_BYTES) {
                this.imageError =
                    'The images are still too large to save together. Remove a few, then add more from the property page after saving.';
                return;
            }

            const property = { ...this.form, Rent__c: Number(this.form.Rent__c) };
            if (!property.Furnishing_Status__c) {
                delete property.Furnishing_Status__c;
            }
            const recordId = await createProperty({ property, imagesJson: JSON.stringify(images) });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Property created',
                    message: `${this.form.Name} was saved with ${images.length} image(s). The map location is being looked up.`,
                    variant: 'success'
                })
            );
            this.files.forEach((f) => URL.revokeObjectURL(f.preview));
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId, objectApiName: 'Property__c', actionName: 'view' }
            });
        } catch (error) {
            this.errorMessage = (error && error.body && error.body.message) || (error && error.message) || 'Save failed.';
        } finally {
            this.isSaving = false;
        }
    }
}
