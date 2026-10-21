/**
 * Daily job that emails tenants before their lease ends:
 *  - one reminder when the lease ends within a month
 *  - a final reminder when it ends tomorrow (or today)
 * Flags on the lease make each reminder go out only once, and a lease created late
 * (for example with 10 days left) never gets both mails at once.
 *
 * Schedule: LeaseExpiryNotificationJob.scheduleDaily();
 */
public with sharing class LeaseExpiryNotificationJob implements Database.Batchable<SObject>, Schedulable {
    public static final String JOB_NAME = 'Lease Expiry Notifications';

    public static Id scheduleDaily() {
        return System.schedule(JOB_NAME, '0 0 6 * * ?', new LeaseExpiryNotificationJob());
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        Date horizon = Date.today().addMonths(1);
        return Database.getQueryLocator(
            [
                SELECT
                    Id, Name, End_Date__c, Tenant_Email__c, One_Month_Notice_Sent__c, One_Day_Notice_Sent__c,
                    Tenant__r.Name, Property__r.Name
                FROM Lease_Agreement__c
                WHERE
                    End_Date__c >= TODAY
                    AND End_Date__c <= :horizon
                    AND (One_Month_Notice_Sent__c = FALSE OR One_Day_Notice_Sent__c = FALSE)
            ]
        );
    }

    public void execute(Database.BatchableContext context, List<Lease_Agreement__c> scope) {
        sendReminders(scope, Date.today());
    }

    public void finish(Database.BatchableContext context) {
    }

    public void execute(SchedulableContext context) {
        Database.executeBatch(new LeaseExpiryNotificationJob(), 100);
    }

    @TestVisible
    private static void sendReminders(List<Lease_Agreement__c> leases, Date today) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Lease_Agreement__c> flagUpdates = new List<Lease_Agreement__c>();

        for (Lease_Agreement__c lease : leases) {
            if (String.isBlank(lease.Tenant_Email__c)) {
                continue;
            }
            Integer daysLeft = today.daysBetween(lease.End_Date__c);
            if (daysLeft <= 1) {
                if (!lease.One_Day_Notice_Sent__c) {
                    emails.add(LeaseNotificationService.buildReminder(lease, true));
                    flagUpdates.add(
                        new Lease_Agreement__c(Id = lease.Id, One_Day_Notice_Sent__c = true, One_Month_Notice_Sent__c = true)
                    );
                }
            } else if (!lease.One_Month_Notice_Sent__c && lease.End_Date__c <= today.addMonths(1)) {
                emails.add(LeaseNotificationService.buildReminder(lease, false));
                flagUpdates.add(new Lease_Agreement__c(Id = lease.Id, One_Month_Notice_Sent__c = true));
            }
        }
        if (emails.isEmpty()) {
            return;
        }

        // Partial success: only leases whose email was accepted get their flag set.
        Messaging.SendEmailResult[] results = Messaging.sendEmail(emails, false);
        List<Lease_Agreement__c> confirmed = new List<Lease_Agreement__c>();
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                confirmed.add(flagUpdates[i]);
            }
        }
        if (!confirmed.isEmpty()) {
            update confirmed;
        }
    }
}
