@isTest
private class AIRecommendationServiceTest {

    @isTest
    static void testGenerateUsesCalloutResultWhenAvailable() {
        Account acct = TestDataFactory.createAccount('Reco Co');
        Opportunity opp = TestDataFactory.createOpportunity(acct.Id, 'Reco Deal', 'Prospecting', 40000, Date.today().addDays(20), 55);

        Test.setMock(HttpCalloutMock.class, new AIServiceCalloutMock());

        Test.startTest();
        AIRecommendationResult result = AIRecommendationService.generate(opp);
        Test.stopTest();

        System.assertEquals('Mock AI summary generated for testing.', result.summary);
        System.assertEquals('Commit', result.revenueForecast.forecastCategory);
        System.assertEquals(28800.00, result.revenueForecast.weightedAmount);
    }

    @isTest
    static void testGenerateFallsBackToHeuristicWhenCalloutFails() {
        Account acct = TestDataFactory.createAccount('Heuristic Co');
        Opportunity opp = TestDataFactory.createOpportunity(acct.Id, 'Heuristic Deal', 'Prospecting', 10000, Date.today().addDays(20), 20);

        Test.setMock(HttpCalloutMock.class, new AIServiceCalloutMock(503, 'Service Unavailable'));

        Test.startTest();
        AIRecommendationResult result = AIRecommendationService.generate(opp);
        Test.stopTest();

        System.assert(result.summary.contains('Heuristic Deal'), 'Fallback summary should reference the opportunity name');
        System.assert(result.nextBestAction.length() > 0);
    }

    @isTest
    static void testGenerateNullOpportunityThrows() {
        Boolean threw = false;
        try {
            AIRecommendationService.generate(null);
        } catch (AIServiceException ex) {
            threw = true;
        }
        System.assert(threw);
    }

    @isTest
    static void testGenerateAndSavePersistsFieldsOntoOpportunity() {
        Account acct = TestDataFactory.createAccount('Persist Co');
        Opportunity opp = TestDataFactory.createOpportunity(acct.Id, 'Persist Deal', 'Prospecting', 20000, Date.today().addDays(15), 65);

        Test.setMock(HttpCalloutMock.class, new AIServiceCalloutMock());

        Test.startTest();
        AIRecommendationResult result = AIRecommendationService.generateAndSave(opp.Id);
        Test.stopTest();

        Opportunity refreshed = [SELECT AI_Summary__c, Next_Best_Action__c, Competitor_Insights__c, Revenue_Forecast__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(result.summary, refreshed.AI_Summary__c);
        System.assertEquals(result.nextBestAction, refreshed.Next_Best_Action__c);
        System.assertEquals(result.revenueForecast.weightedAmount, refreshed.Revenue_Forecast__c);
    }

    @isTest
    static void testGenerateAndSaveThrowsForMissingOpportunity() {
        Boolean threw = false;
        try {
            AIRecommendationService.generateAndSave(null);
        } catch (AIServiceException ex) {
            threw = true;
        }
        System.assert(threw, 'A missing opportunity id should raise AIServiceException');
    }
}
