/**
 * Backs the Download / Send PDF buttons on the lease agreement record page.
 * The PDF itself is generated in the browser with jsPDF; this class supplies the data
 * and emails/stores the generated file.
 */
public with sharing class LeaseAgreementController {
    public class LeaseDetails {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String leaseNumber;
        @AuraEnabled
        public String propertyName;
        @AuraEnabled
        public String propertyAddress;
        @AuraEnabled
        public String tenantName;
        @AuraEnabled
        public String tenantEmail;
        @AuraEnabled
        public String tenantPhone;
        @AuraEnabled
        public String terms;
        @AuraEnabled
        public Decimal monthlyRent;
        @AuraEnabled
        public Date startDate;
        @AuraEnabled
        public Date endDate;
    }

    @AuraEnabled
    public static LeaseDetails getLeaseDetails(Id leaseId) {
        Lease_Agreement__c lease = queryLease(leaseId);
        LeaseDetails details = new LeaseDetails();
        details.id = lease.Id;
        details.leaseNumber = lease.Name;
        details.propertyName = lease.Property__r.Name;
        details.propertyAddress = GeocodingService.buildAddress(lease.Property__r);
        details.tenantName = lease.Tenant__r.Name;
        details.tenantEmail = lease.Tenant__r.Email__c;
        details.tenantPhone = lease.Tenant__r.Phone__c;
        details.terms = lease.Terms__c;
        details.monthlyRent = lease.Agreed_Monthly_Rent__c;
        details.startDate = lease.Start_Date__c;
        details.endDate = lease.End_Date__c;
        return details;
    }

    @AuraEnabled
    public static void sendLeasePdf(Id leaseId, String base64Pdf, String fileName) {
        if (String.isBlank(base64Pdf)) {
            throw AuraErrors.build('The PDF could not be generated.');
        }
        Lease_Agreement__c lease = queryLease(leaseId);
        if (String.isBlank(lease.Tenant_Email__c)) {
            throw AuraErrors.build('The tenant has no email address.');
        }
        String safeName = String.isBlank(fileName) ? lease.Name + '.pdf' : fileName;
        Blob pdf = EncodingUtil.base64Decode(base64Pdf);

        try {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(
                new List<Messaging.SingleEmailMessage>{ LeaseNotificationService.buildPdfEmail(lease, safeName, pdf) }
            );
            if (!results[0].isSuccess()) {
                throw AuraErrors.build('Email failed: ' + results[0].getErrors()[0].getMessage());
            }

            // Keep a copy of what was sent on the record.
            insert new ContentVersion(
                Title = safeName.removeEnd('.pdf'),
                PathOnClient = safeName,
                VersionData = pdf,
                FirstPublishLocationId = lease.Id
            );
            update new Lease_Agreement__c(Id = lease.Id, PDF_Sent_On__c = System.now());
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw AuraErrors.build(AuraErrors.messageOf(e));
        }
    }

    private static Lease_Agreement__c queryLease(Id leaseId) {
        List<Lease_Agreement__c> leases = [
            SELECT
                Id, Name, Terms__c, Agreed_Monthly_Rent__c, Start_Date__c, End_Date__c, Tenant_Email__c,
                Tenant__r.Name, Tenant__r.Email__c, Tenant__r.Phone__c,
                Property__r.Name, Property__r.Address__c, Property__r.City__c, Property__r.State__c,
                Property__r.Postal_Code__c, Property__r.Country__c
            FROM Lease_Agreement__c
            WHERE Id = :leaseId
            LIMIT 1
        ];
        if (leases.isEmpty()) {
            throw AuraErrors.build('Lease agreement not found.');
        }
        return leases[0];
    }
}
