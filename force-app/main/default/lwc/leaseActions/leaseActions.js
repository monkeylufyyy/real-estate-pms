import { LightningElement, api, wire } from 'lwc';
import { getRecord, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import CURRENCY from '@salesforce/i18n/currency';
import JSPDF from '@salesforce/resourceUrl/jspdf';
import getLeaseDetails from '@salesforce/apex/LeaseAgreementController.getLeaseDetails';
import sendLeasePdf from '@salesforce/apex/LeaseAgreementController.sendLeasePdf';
import { buildLeasePdf, pdfFileName } from 'c/leasePdfBuilder';

const FIELDS = ['Lease_Agreement__c.Tenant_Email__c', 'Lease_Agreement__c.PDF_Sent_On__c'];

export default class LeaseActions extends LightningElement {
    @api recordId;

    tenantEmail;
    pdfSentOn;
    isBusy = false;
    libraryLoaded = false;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredLease({ data }) {
        if (data) {
            this.tenantEmail = data.fields.Tenant_Email__c.value;
            this.pdfSentOn = data.fields.PDF_Sent_On__c.value;
        }
    }

    get cannotSend() {
        return this.isBusy || !this.tenantEmail;
    }
    get sendHint() {
        return this.tenantEmail ? `Sends the PDF to ${this.tenantEmail}.` : 'The tenant has no email address.';
    }

    async ensureLibrary() {
        if (!this.libraryLoaded) {
            await loadScript(this, JSPDF);
            this.libraryLoaded = true;
        }
    }

    async createPdf() {
        await this.ensureLibrary();
        const details = await getLeaseDetails({ leaseId: this.recordId });
        // window.jspdf is exposed by the UMD build of jsPDF.
        const doc = buildLeasePdf(window.jspdf.jsPDF, details, CURRENCY);
        return { doc, fileName: pdfFileName(details), details };
    }

    async handleDownload() {
        this.isBusy = true;
        try {
            const { doc, fileName } = await this.createPdf();
            doc.save(fileName);
        } catch (error) {
            this.toast('Could not create the PDF', this.messageOf(error), 'error');
        } finally {
            this.isBusy = false;
        }
    }

    async handleSend() {
        const confirmed = await LightningConfirm.open({
            message: `Email the lease agreement PDF to ${this.tenantEmail}?`,
            label: 'Send to tenant',
            theme: 'info'
        });
        if (!confirmed) {
            return;
        }
        this.isBusy = true;
        try {
            const { doc, fileName, details } = await this.createPdf();
            const dataUri = doc.output('datauristring');
            const base64Pdf = dataUri.substring(dataUri.indexOf('base64,') + 'base64,'.length);
            await sendLeasePdf({ leaseId: this.recordId, base64Pdf, fileName });
            this.toast('PDF sent', `${fileName} was emailed to ${details.tenantEmail}.`, 'success');
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        } catch (error) {
            this.toast('Could not send the PDF', this.messageOf(error), 'error');
        } finally {
            this.isBusy = false;
        }
    }

    messageOf(error) {
        return (error && error.body && error.body.message) || (error && error.message) || 'Unknown error';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
