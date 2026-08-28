@isTest
private class OpportunityRiskBatchTest {

    @isTest
    static void testBatchScoresOpenOpportunitiesOnly() {
        Account acct = TestDataFactory.createAccount('Batch Co');
        Opportunity openOpp = TestDataFactory.createOpportunity(acct.Id, 'Open Batch Deal', 'Negotiation/Review', 150000, Date.today().addDays(-2), 10);
        Opportunity closedOpp = TestDataFactory.createOpportunity(acct.Id, 'Closed Batch Deal', 'Closed Won', 50000, Date.today().addDays(-10), 100);
        Datetime beforeRun = Datetime.now();

        Test.startTest();
        Database.executeBatch(new OpportunityRiskBatch(), 50);
        Test.stopTest();

        Opportunity refreshedOpen = [SELECT Risk_Level__c, AI_Last_Analyzed__c FROM Opportunity WHERE Id = :openOpp.Id];
        Opportunity refreshedClosed = [SELECT AI_Last_Analyzed__c FROM Opportunity WHERE Id = :closedOpp.Id];

        System.assertEquals('High', refreshedOpen.Risk_Level__c);
        System.assertNotEquals(null, refreshedOpen.AI_Last_Analyzed__c);
        System.assertEquals(null, refreshedClosed.AI_Last_Analyzed__c, 'Closed opportunities are excluded from the batch scope');
    }

    @isTest
    static void testBatchHandlesEmptyScope() {
        Test.startTest();
        Database.executeBatch(new OpportunityRiskBatch(), 50);
        Test.stopTest();
        System.assert(true, 'Batch should complete without error when there is nothing to score');
    }
}
