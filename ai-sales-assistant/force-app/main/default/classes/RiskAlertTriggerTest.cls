@isTest
private class RiskAlertTriggerTest {

    @isTest
    static void testPublishedAlertTriggersNotification() {
        Account acct = TestDataFactory.createAccount('Trigger Alert Co');
        Opportunity opp = TestDataFactory.createOpportunity(acct.Id, 'Trigger Alert Deal', 'Prospecting', 10000, Date.today().addDays(10), 40);

        Integer emailsBefore = Limits.getEmailInvocations();

        Test.startTest();
        EventBus.publish(new Risk_Alert__e(
            Opportunity_Id__c = opp.Id,
            Account_Name__c = 'Trigger Alert Deal',
            Risk_Score__c = 92,
            Message__c = 'Published directly for RiskAlertTrigger coverage'
        ));
        Test.getEventBus().deliver();
        Test.stopTest();

        Integer emailsAfter = Limits.getEmailInvocations();
        System.assert(emailsAfter > emailsBefore, 'The platform event trigger should hand off to NotificationService');
    }
}
