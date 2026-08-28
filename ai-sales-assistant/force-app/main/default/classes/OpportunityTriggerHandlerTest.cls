@isTest
private class OpportunityTriggerHandlerTest {

    @isTest
    static void testInsertComputesRiskScore() {
        Account acct = TestDataFactory.createAccount('Trigger Co');

        Test.startTest();
        Opportunity opp = TestDataFactory.createHighRiskOpportunity(acct.Id, 'Trigger Insert Deal');
        Test.stopTest();

        Opportunity refreshed = [SELECT Risk_Score__c, Risk_Level__c, AI_Last_Analyzed__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('High', refreshed.Risk_Level__c);
        System.assertNotEquals(null, refreshed.Risk_Score__c);
        System.assertNotEquals(null, refreshed.AI_Last_Analyzed__c);
    }

    @isTest
    static void testUpdateRecomputesOnRiskRelevantChange() {
        Account acct = TestDataFactory.createAccount('Recompute Co');
        Opportunity opp = TestDataFactory.createHealthyOpportunity(acct.Id, 'Recompute Deal');
        Opportunity before = [SELECT Risk_Level__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Low', before.Risk_Level__c);

        Test.startTest();
        opp.Amount = 250000;
        opp.CloseDate = Date.today().addDays(-1);
        opp.Probability = 5;
        update opp;
        Test.stopTest();

        Opportunity after = [SELECT Risk_Level__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('High', after.Risk_Level__c);
    }

    @isTest
    static void testUpdateSkipsRecomputeForIrrelevantFieldChange() {
        Account acct = TestDataFactory.createAccount('Irrelevant Co');
        Opportunity opp = TestDataFactory.createHealthyOpportunity(acct.Id, 'Irrelevant Deal');
        Opportunity before = [SELECT Risk_Score__c, AI_Last_Analyzed__c FROM Opportunity WHERE Id = :opp.Id];

        Test.startTest();
        opp.Description = 'Just adding some notes, nothing risk-related.';
        update opp;
        Test.stopTest();

        Opportunity after = [SELECT Risk_Score__c, AI_Last_Analyzed__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(before.Risk_Score__c, after.Risk_Score__c);
        System.assertEquals(before.AI_Last_Analyzed__c, after.AI_Last_Analyzed__c);
    }

    @isTest
    static void testClosedOpportunityIsNotScored() {
        Account acct = TestDataFactory.createAccount('Closed Co');

        Test.startTest();
        Opportunity opp = TestDataFactory.createOpportunity(acct.Id, 'Closed Deal', 'Closed Won', 50000, Date.today().addDays(-10), 100);
        Test.stopTest();

        Opportunity refreshed = [SELECT Risk_Score__c, Risk_Level__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(null, refreshed.Risk_Score__c);
        System.assertEquals(null, refreshed.Risk_Level__c);
    }
}
