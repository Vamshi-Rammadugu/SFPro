@isTest
private class OpportunityDashboardControllerTest {

    @isTest
    static void testGetDashboardSummaryAggregatesData() {
        Account acct = TestDataFactory.createAccount('Dashboard Co');
        TestDataFactory.createHighRiskOpportunity(acct.Id, 'Dashboard High Risk Deal');
        TestDataFactory.createHealthyOpportunity(acct.Id, 'Dashboard Healthy Deal');

        Test.startTest();
        DashboardSummary summary = OpportunityDashboardController.getDashboardSummary();
        Test.stopTest();

        System.assert(summary.openOpportunities.size() >= 2);
        System.assert(summary.highRiskOpportunities.size() >= 1);
        System.assertNotEquals(null, summary.aiRecommendationCount);
    }

    @isTest
    static void testGetOpportunityCardReturnsWrapperOrNull() {
        Account acct = TestDataFactory.createAccount('Card Co');
        Opportunity opp = TestDataFactory.createOpportunity(acct.Id, 'Card Deal', 'Prospecting', 5000, Date.today().addDays(20), 60);

        OpportunityWrapper found = OpportunityDashboardController.getOpportunityCard(opp.Id);
        System.assertEquals('Card Deal', found.name);

        OpportunityWrapper missing = OpportunityDashboardController.getOpportunityCard(null);
        System.assertEquals(null, missing);
    }

    @isTest
    static void testDetailGettersReturnPersistedAiFields() {
        Account acct = TestDataFactory.createAccount('Detail Co');
        Opportunity opp = TestDataFactory.createOpportunity(acct.Id, 'Detail Deal', 'Prospecting', 20000, Date.today().addDays(20), 60);
        Database.update(new Opportunity(
            Id = opp.Id,
            AI_Summary__c = 'Persisted summary',
            Next_Best_Action__c = 'Persisted next action',
            Competitor_Insights__c = 'Persisted competitor insights',
            Revenue_Forecast__c = 12000
        ), AccessLevel.SYSTEM_MODE);

        Test.startTest();
        String summary = OpportunityDashboardController.getAiSummary(opp.Id);
        String nextBestAction = OpportunityDashboardController.getNextBestAction(opp.Id);
        String competitorInsights = OpportunityDashboardController.getCompetitorInsights(opp.Id);
        RevenueForecastWrapper forecast = OpportunityDashboardController.getRevenueForecast(opp.Id);
        List<DealTimelineEntry> timeline = OpportunityDashboardController.getDealTimeline(opp.Id);
        Test.stopTest();

        System.assertEquals('Persisted summary', summary);
        System.assertEquals('Persisted next action', nextBestAction);
        System.assertEquals('Persisted competitor insights', competitorInsights);
        System.assertEquals('Commit', forecast.forecastCategory);
        System.assert(!timeline.isEmpty());
    }

    @isTest
    static void testDetailGettersThrowForUnknownOpportunity() {
        Boolean threw = false;
        try {
            OpportunityDashboardController.getAiSummary(null);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        System.assert(threw, 'Requesting details for an unknown opportunity should raise AuraHandledException');
    }

    @isTest
    static void testRefreshAiRecommendationWithoutPermissionThrows() {
        Account acct = TestDataFactory.createAccount('No Perm Co');
        Opportunity opp = TestDataFactory.createOpportunity(acct.Id, 'No Perm Deal', 'Prospecting', 5000, Date.today().addDays(20), 60);

        Test.setMock(HttpCalloutMock.class, new AIServiceCalloutMock());

        Boolean threw = false;
        Test.startTest();
        try {
            OpportunityDashboardController.refreshAiRecommendation(opp.Id);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Without the Manage_AI_Sales_Assistant custom permission the refresh action should be blocked');
    }

    @isTest
    static void testRefreshAiRecommendationWithPermissionSucceeds() {
        Account acct = TestDataFactory.createAccount('With Perm Co');
        Opportunity opp = TestDataFactory.createOpportunity(acct.Id, 'With Perm Deal', 'Prospecting', 5000, Date.today().addDays(20), 60);

        User testUser = new User(
            FirstName = 'AI',
            LastName = 'Tester',
            Alias = 'aitest',
            Email = 'ai.sales.assistant.tester@example.com.invalid',
            Username = 'ai.sales.assistant.tester@example.com.' + Crypto.getRandomInteger() + '.invalid',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id
        );
        insert testUser;

        List<PermissionSet> permSets = [SELECT Id FROM PermissionSet WHERE Name = 'AI_Sales_Assistant_User' LIMIT 1];
        if (permSets.isEmpty()) {
            return;
        }
        insert new PermissionSetAssignment(AssigneeId = testUser.Id, PermissionSetId = permSets[0].Id);

        Test.setMock(HttpCalloutMock.class, new AIServiceCalloutMock());

        Test.startTest();
        System.runAs(testUser) {
            AIRecommendationResult result = OpportunityDashboardController.refreshAiRecommendation(opp.Id);
            System.assertEquals('Mock AI summary generated for testing.', result.summary);
        }
        Test.stopTest();
    }
}
