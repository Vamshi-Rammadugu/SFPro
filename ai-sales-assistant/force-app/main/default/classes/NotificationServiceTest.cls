@isTest
private class NotificationServiceTest {

    @isTest
    static void testNotifyOwnersSendsEmailForValidAlert() {
        Account acct = TestDataFactory.createAccount('Notify Co');
        Opportunity opp = TestDataFactory.createOpportunity(acct.Id, 'Notify Deal', 'Prospecting', 10000, Date.today().addDays(10), 40);

        Risk_Alert__e alert = new Risk_Alert__e(
            Opportunity_Id__c = opp.Id,
            Account_Name__c = 'Notify Deal',
            Risk_Score__c = 85,
            Message__c = 'Test alert message'
        );

        Integer emailsBefore = Limits.getEmailInvocations();

        Test.startTest();
        NotificationService.notifyOwners(new List<Risk_Alert__e>{ alert });
        Test.stopTest();

        Integer emailsAfter = Limits.getEmailInvocations();
        System.assert(emailsAfter > emailsBefore, 'A valid alert with an owner email should trigger an email invocation');
    }

    @isTest
    static void testNotifyOwnersNoopOnEmptyList() {
        Test.startTest();
        NotificationService.notifyOwners(new List<Risk_Alert__e>());
        NotificationService.notifyOwners(null);
        Test.stopTest();
        System.assert(true, 'Empty or null alert lists should be handled without error');
    }

    @isTest
    static void testHandleRiskAlertsEnqueuesJob() {
        Account acct = TestDataFactory.createAccount('Enqueue Co');
        Opportunity opp = TestDataFactory.createOpportunity(acct.Id, 'Enqueue Deal', 'Prospecting', 10000, Date.today().addDays(10), 40);
        Risk_Alert__e alert = new Risk_Alert__e(
            Opportunity_Id__c = opp.Id,
            Account_Name__c = 'Enqueue Deal',
            Risk_Score__c = 90,
            Message__c = 'Enqueued alert'
        );

        Integer emailsBefore = Limits.getEmailInvocations();

        Test.startTest();
        NotificationService.handleRiskAlerts(new List<Risk_Alert__e>{ alert });
        NotificationService.handleRiskAlerts(new List<Risk_Alert__e>());
        Test.stopTest();

        Integer emailsAfter = Limits.getEmailInvocations();
        System.assert(emailsAfter > emailsBefore, 'Handling a risk alert should asynchronously send an email');
    }
}
