/**
 * Builds and sends the lease related emails: the PDF copy and the two expiry reminders.
 */
public with sharing class LeaseNotificationService {
    public static Messaging.SingleEmailMessage buildPdfEmail(Lease_Agreement__c lease, String fileName, Blob pdf) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ lease.Tenant_Email__c });
        mail.setSubject('Your lease agreement ' + lease.Name + ' for ' + lease.Property__r.Name);
        mail.setPlainTextBody(
            'Hello ' + lease.Tenant__r.Name + ',\n\n' +
            'Please find your lease agreement for ' + lease.Property__r.Name + ' attached as a PDF.\n' +
            'Lease period: ' + formatDate(lease.Start_Date__c) + ' to ' + formatDate(lease.End_Date__c) + '.\n\n' +
            'Regards,\nProperty Management Team'
        );
        mail.setHtmlBody(
            '<p>Hello ' + esc(lease.Tenant__r.Name) + ',</p>' +
            '<p>Please find your lease agreement for <b>' + esc(lease.Property__r.Name) + '</b> attached as a PDF.</p>' +
            '<p>Lease period: ' + formatDate(lease.Start_Date__c) + ' to ' + formatDate(lease.End_Date__c) + '.</p>' +
            '<p>Regards,<br/>Property Management Team</p>'
        );
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName(fileName);
        attachment.setBody(pdf);
        attachment.setContentType('application/pdf');
        mail.setFileAttachments(new List<Messaging.EmailFileAttachment>{ attachment });
        mail.setSaveAsActivity(false);
        return mail;
    }

    /**
     * @param finalNotice true for the "1 day before" mail, false for the "1 month before" mail
     */
    public static Messaging.SingleEmailMessage buildReminder(Lease_Agreement__c lease, Boolean finalNotice) {
        String expiry = formatDate(lease.End_Date__c);
        String property = lease.Property__r.Name;
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ lease.Tenant_Email__c });
        mail.setSaveAsActivity(false);

        if (finalNotice) {
            mail.setSubject('Final reminder: your lease for ' + property + ' ends on ' + expiry);
            mail.setPlainTextBody(
                'Hello ' + lease.Tenant__r.Name + ',\n\n' +
                'This is a final reminder that lease ' + lease.Name + ' for ' + property + ' expires on ' + expiry + '.\n' +
                'Please contact us immediately if you wish to renew or to arrange your move-out.\n\n' +
                'Regards,\nProperty Management Team'
            );
        } else {
            mail.setSubject('Reminder: your lease for ' + property + ' ends on ' + expiry);
            mail.setPlainTextBody(
                'Hello ' + lease.Tenant__r.Name + ',\n\n' +
                'Your lease ' + lease.Name + ' for ' + property + ' expires on ' + expiry + ', about one month from now.\n' +
                'Please get in touch with us if you would like to renew the agreement.\n\n' +
                'Regards,\nProperty Management Team'
            );
        }
        return mail;
    }

    private static String formatDate(Date d) {
        return d == null ? '' : DateTime.newInstance(d, Time.newInstance(0, 0, 0, 0)).format('dd MMM yyyy');
    }

    private static String esc(String value) {
        return value == null ? '' : value.escapeHtml4();
    }
}
