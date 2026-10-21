@IsTest
private class LeaseExpiryNotificationJobTest {
    private static Date today = Date.today();

    /** One lease per property so the overlap rule never interferes. */
    private static List<Lease_Agreement__c> insertLeases(List<Date> endDates) {
        Tenant__c tenant = TestDataFactory.insertTenants(1)[0];
        List<Property__c> props = TestDataFactory.insertProperties(endDates.size());
        List<Lease_Agreement__c> leases = new List<Lease_Agreement__c>();
        for (Integer i = 0; i < endDates.size(); i++) {
            leases.add(TestDataFactory.buildLease(props[i].Id, tenant.Id, today.addYears(-1), endDates[i]));
        }
        insert leases;
        return leases;
    }

    private static Lease_Agreement__c reload(Id leaseId) {
        return [SELECT One_Month_Notice_Sent__c, One_Day_Notice_Sent__c FROM Lease_Agreement__c WHERE Id = :leaseId];
    }

    private static void runJob() {
        Test.startTest();
        Database.executeBatch(new LeaseExpiryNotificationJob(), 100);
        Test.stopTest();
    }

    @IsTest
    static void sendsTheOneMonthReminder() {
        List<Lease_Agreement__c> leases = insertLeases(new List<Date>{ today.addMonths(1), today.addDays(20) });
        runJob();

        for (Lease_Agreement__c lease : leases) {
            Lease_Agreement__c reloaded = reload(lease.Id);
            Assert.isTrue(reloaded.One_Month_Notice_Sent__c);
            Assert.isFalse(reloaded.One_Day_Notice_Sent__c);
        }
    }

    @IsTest
    static void sendsTheFinalReminderOneDayBefore() {
        List<Lease_Agreement__c> leases = insertLeases(new List<Date>{ today.addDays(1), today });
        runJob();

        for (Lease_Agreement__c lease : leases) {
            Lease_Agreement__c reloaded = reload(lease.Id);
            Assert.isTrue(reloaded.One_Day_Notice_Sent__c);
            Assert.isTrue(reloaded.One_Month_Notice_Sent__c, 'The month reminder is skipped, not sent as well');
        }
    }

    @IsTest
    static void ignoresLeasesOutsideTheWindow() {
        List<Lease_Agreement__c> leases = insertLeases(new List<Date>{ today.addMonths(1).addDays(1), today.addMonths(6), today.addDays(-3) });
        runJob();

        for (Lease_Agreement__c lease : leases) {
            Lease_Agreement__c reloaded = reload(lease.Id);
            Assert.isFalse(reloaded.One_Month_Notice_Sent__c);
            Assert.isFalse(reloaded.One_Day_Notice_Sent__c);
        }
    }

    @IsTest
    static void neverSendsTheSameReminderTwice() {
        Lease_Agreement__c lease = insertLeases(new List<Date>{ today.addDays(20) })[0];
        lease.One_Month_Notice_Sent__c = true;
        update lease;

        List<Lease_Agreement__c> scope = [
            SELECT Id, Name, End_Date__c, Tenant_Email__c, One_Month_Notice_Sent__c, One_Day_Notice_Sent__c, Tenant__r.Name, Property__r.Name
            FROM Lease_Agreement__c
        ];
        Test.startTest();
        LeaseExpiryNotificationJob.sendReminders(scope, today);
        Integer emails = Limits.getEmailInvocations();
        Test.stopTest();

        Assert.areEqual(0, emails, 'Already notified leases must not be mailed again');
    }

    @IsTest
    static void sendsOneBulkEmailCallForManyLeases() {
        List<Date> ends = new List<Date>();
        // Developer Edition orgs cap single emails at 15 a day, so stay below that here.
        for (Integer i = 0; i < 10; i++) {
            ends.add(today.addDays(10 + i));
        }
        insertLeases(ends);
        List<Lease_Agreement__c> scope = [
            SELECT Id, Name, End_Date__c, Tenant_Email__c, One_Month_Notice_Sent__c, One_Day_Notice_Sent__c, Tenant__r.Name, Property__r.Name
            FROM Lease_Agreement__c
        ];

        Test.startTest();
        LeaseExpiryNotificationJob.sendReminders(scope, today);
        Integer emailCalls = Limits.getEmailInvocations();
        Test.stopTest();

        Assert.areEqual(1, emailCalls, 'All reminders go out in a single sendEmail call');
        Assert.areEqual(10, [SELECT COUNT() FROM Lease_Agreement__c WHERE One_Month_Notice_Sent__c = TRUE]);
    }

    @IsTest
    static void canBeScheduledDaily() {
        Test.startTest();
        Id jobId = LeaseExpiryNotificationJob.scheduleDaily();
        Test.stopTest();

        CronTrigger cron = [SELECT CronExpression, CronJobDetail.Name FROM CronTrigger WHERE Id = :jobId];
        Assert.areEqual('0 0 6 * * ?', cron.CronExpression);
        Assert.areEqual(LeaseExpiryNotificationJob.JOB_NAME, cron.CronJobDetail.Name);
    }

    @IsTest
    static void scheduledRunStartsTheBatch() {
        List<Lease_Agreement__c> leases = insertLeases(new List<Date>{ today.addDays(15) });
        Test.startTest();
        new LeaseExpiryNotificationJob().execute((SchedulableContext) null);
        Test.stopTest();
        Assert.isTrue(reload(leases[0].Id).One_Month_Notice_Sent__c);
    }
}
