@IsTest
private class LeaseAgreementControllerTest {
    @TestSetup
    static void setup() {
        Tenant__c tenant = TestDataFactory.insertTenants(1)[0];
        Property__c prop = TestDataFactory.insertProperties(1)[0];
        insert TestDataFactory.buildLease(prop.Id, tenant.Id, Date.today(), Date.today().addMonths(11));
    }

    private static Lease_Agreement__c lease() {
        return [SELECT Id, Name FROM Lease_Agreement__c LIMIT 1];
    }

    @IsTest
    static void returnsEverythingTheOverviewNeeds() {
        LeaseAgreementController.LeaseDetails details = LeaseAgreementController.getLeaseDetails(lease().Id);

        Assert.areEqual('Property 0', details.propertyName);
        Assert.areEqual('12 Anna Salai, Chennai, Tamil Nadu, 600002, India', details.propertyAddress);
        Assert.areEqual('Tenant 0', details.tenantName);
        Assert.areEqual('tenant0@example.com', details.tenantEmail);
        Assert.areEqual(15000, details.monthlyRent);
        Assert.areEqual(Date.today(), details.startDate);
        Assert.isNotNull(details.terms);
        Assert.isTrue(details.leaseNumber.startsWith('LA-'));
    }

    @IsTest
    static void reportsAMissingLease() {
        Lease_Agreement__c lease = lease();
        delete lease;
        try {
            LeaseAgreementController.getLeaseDetails(lease.Id);
            Assert.fail('Expected a not-found error');
        } catch (AuraHandledException e) {
            Assert.areEqual('Lease agreement not found.', e.getMessage());
        }
    }

    @IsTest
    static void emailsThePdfAndKeepsACopy() {
        Lease_Agreement__c lease = lease();

        Test.startTest();
        LeaseAgreementController.sendLeasePdf(lease.Id, TestDataFactory.TINY_PNG_BASE64, lease.Name + '.pdf');
        Integer emailsSent = Limits.getEmailInvocations();
        Test.stopTest();

        Assert.areEqual(1, emailsSent);
        Assert.isNotNull([SELECT PDF_Sent_On__c FROM Lease_Agreement__c WHERE Id = :lease.Id].PDF_Sent_On__c);
        Assert.areEqual(1, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :lease.Id]);
    }

    @IsTest
    static void usesADefaultFileNameWhenNoneIsGiven() {
        Lease_Agreement__c lease = lease();
        LeaseAgreementController.sendLeasePdf(lease.Id, TestDataFactory.TINY_PNG_BASE64, null);
        ContentVersion saved = [SELECT PathOnClient FROM ContentVersion WHERE FirstPublishLocationId = :lease.Id];
        Assert.areEqual(lease.Name + '.pdf', saved.PathOnClient);
    }

    @IsTest
    static void refusesToSendAnEmptyPdf() {
        try {
            LeaseAgreementController.sendLeasePdf(lease().Id, '', 'x.pdf');
            Assert.fail('Expected an error');
        } catch (AuraHandledException e) {
            Assert.areEqual('The PDF could not be generated.', e.getMessage());
        }
    }
}
