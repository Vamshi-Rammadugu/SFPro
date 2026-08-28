/**
 * Turns Risk_Alert__e platform events into rep-facing notifications.
 * Hands the work to NotificationQueueable so RiskAlertTrigger (which runs
 * on the event bus's own async context) stays fast and side-effect free.
 */
public with sharing class NotificationService {

    public static void handleRiskAlerts(List<Risk_Alert__e> alerts) {
        if (alerts == null || alerts.isEmpty()) {
            return;
        }
        System.enqueueJob(new NotificationQueueable(alerts));
    }

    public static void notifyOwners(List<Risk_Alert__e> alerts) {
        if (alerts == null || alerts.isEmpty()) {
            return;
        }

        Set<Id> oppIds = new Set<Id>();
        for (Risk_Alert__e alert : alerts) {
            if (alert.Opportunity_Id__c != null) {
                oppIds.add((Id) alert.Opportunity_Id__c);
            }
        }
        if (oppIds.isEmpty()) {
            return;
        }

        Map<Id, Opportunity> opportunitiesById = new Map<Id, Opportunity>([
            SELECT Id, Name, OwnerId, Owner.Email, Owner.Name
            FROM Opportunity
            WHERE Id IN :oppIds
            WITH USER_MODE
        ]);

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Risk_Alert__e alert : alerts) {
            Opportunity opp = opportunitiesById.get((Id) alert.Opportunity_Id__c);
            if (opp == null || opp.Owner == null || String.isBlank(opp.Owner.Email)) {
                continue;
            }
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ opp.Owner.Email });
            email.setSubject('High risk alert: ' + opp.Name);
            email.setPlainTextBody(
                'Hi ' + opp.Owner.Name + ',\n\n' +
                opp.Name + ' just crossed into High risk (score ' + alert.Risk_Score__c + ').\n' +
                alert.Message__c + '\n\n— AI Sales Assistant'
            );
            email.setSaveAsActivity(false);
            emails.add(email);
        }

        if (emails.isEmpty()) {
            return;
        }

        try {
            Messaging.sendEmail(emails, false);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'NotificationService: failed to send risk alert email(s) - ' + ex.getMessage());
        }
    }
}
