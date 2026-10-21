import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import LightningConfirm from 'lightning/confirm';
import getImages from '@salesforce/apex/PropertyGalleryController.getImages';
import deleteImage from '@salesforce/apex/PropertyGalleryController.deleteImage';

const ACCEPTED = ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp'];

export default class PropertyGallery extends LightningElement {
    @api recordId;

    images = [];
    isLoading = false;
    loaded = false;
    acceptedFormats = ACCEPTED;

    connectedCallback() {
        this.refresh();
    }

    get hasImages() {
        return this.images.length > 0;
    }
    get showEmptyWarning() {
        return this.loaded && !this.hasImages;
    }
    get canDelete() {
        return this.images.length > 1;
    }
    get heading() {
        return `Images (${this.images.length})`;
    }

    async refresh() {
        this.isLoading = true;
        try {
            const result = await getImages({ propertyId: this.recordId });
            this.images = result.map((img) => ({ ...img, src: img.thumbUrl, fallback: img.url }));
            this.loaded = true;
        } catch (error) {
            this.toast('Could not load images', this.messageOf(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleUploadFinished(event) {
        const count = event.detail.files.length;
        this.toast('Images uploaded', `${count} image(s) added to the property.`, 'success');
        // Give the image-count trigger a moment, then refresh this gallery and the record page.
        await this.refresh();
        notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
    }

    async handleDelete(event) {
        const documentId = event.currentTarget.dataset.id;
        const confirmed = await LightningConfirm.open({
            message: 'Remove this image from the property?',
            variant: 'headerless',
            label: 'Remove image'
        });
        if (!confirmed) {
            return;
        }
        try {
            await deleteImage({ propertyId: this.recordId, documentId });
            await this.refresh();
            notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        } catch (error) {
            this.toast('Could not remove image', this.messageOf(error), 'error');
        }
    }

    handleImageError(event) {
        const img = event.target;
        if (img.dataset.fallback && !img.src.endsWith(img.dataset.fallback)) {
            img.src = img.dataset.fallback;
        }
    }

    messageOf(error) {
        return (error && error.body && error.body.message) || (error && error.message) || 'Unknown error';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
