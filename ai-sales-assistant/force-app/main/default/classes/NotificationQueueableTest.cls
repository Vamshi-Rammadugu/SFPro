@isTest
private class NotificationQueueableTest {

    @isTest
    static void testExecuteDelegatesToNotificationService() {
        Account acct = TestDataFactory.createAccount('Queueable Co');
        Opportunity opp = TestDataFactory.createOpportunity(acct.Id, 'Queueable Deal', 'Prospecting', 10000, Date.today().addDays(10), 40);
        Risk_Alert__e alert = new Risk_Alert__e(
            Opportunity_Id__c = opp.Id,
            Account_Name__c = 'Queueable Deal',
            Risk_Score__c = 90,
            Message__c = 'Queueable alert'
        );

        Integer emailsBefore = Limits.getEmailInvocations();

        Test.startTest();
        System.enqueueJob(new NotificationQueueable(new List<Risk_Alert__e>{ alert }));
        Test.stopTest();

        Integer emailsAfter = Limits.getEmailInvocations();
        System.assert(emailsAfter > emailsBefore, 'The queueable job should send the risk alert email');
    }
}
