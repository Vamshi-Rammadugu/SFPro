@isTest
private class RiskAnalysisServiceTest {

    @isTest
    static void testScoreOpportunityFlagsPastCloseDate() {
        AI_Config__mdt config = OpportunityService.getConfig();
        Opportunity opp = new Opportunity(CloseDate = Date.today().addDays(-3), Probability = 90, Amount = 1000);

        RiskScoreResult result = RiskAnalysisService.scoreOpportunity(opp, config, new List<Task>());

        System.assert(result.score >= 35, 'Past close date should contribute at least 35 points');
        System.assert(result.reasons[0].contains('past'));
    }

    @isTest
    static void testScoreOpportunityRecentActivityAvoidsStalePenalty() {
        AI_Config__mdt config = OpportunityService.getConfig();
        Opportunity opp = new Opportunity(CloseDate = Date.today().addDays(30), Probability = 80, Amount = 1000);
        Task recentTask = new Task(ActivityDate = Date.today());

        RiskScoreResult result = RiskAnalysisService.scoreOpportunity(opp, config, new List<Task>{ recentTask });

        for (String reason : result.reasons) {
            System.assert(!reason.contains('No activity') && !reason.contains('No logged activity'), 'Recent activity should avoid the staleness penalty: ' + reason);
        }
    }

    @isTest
    static void testScoreOpportunityNoActivityAddsPenalty() {
        AI_Config__mdt config = OpportunityService.getConfig();
        Opportunity opp = new Opportunity(CloseDate = Date.today().addDays(30), Probability = 80, Amount = 1000);

        RiskScoreResult result = RiskAnalysisService.scoreOpportunity(opp, config, null);

        System.assert(result.reasons.contains('No logged activity found'));
    }

    @isTest
    static void testScoreOpportunityLowProbabilityAndLargeDeal() {
        AI_Config__mdt config = OpportunityService.getConfig();
        Opportunity opp = new Opportunity(CloseDate = Date.today().addDays(30), Probability = 10, Amount = 200000);
        Task recentTask = new Task(ActivityDate = Date.today());

        RiskScoreResult result = RiskAnalysisService.scoreOpportunity(opp, config, new List<Task>{ recentTask });

        Boolean sawProbabilityReason = false;
        Boolean sawAmountReason = false;
        for (String reason : result.reasons) {
            if (reason.contains('probability')) {
                sawProbabilityReason = true;
            }
            if (reason.contains('Large deal')) {
                sawAmountReason = true;
            }
        }
        System.assert(sawProbabilityReason, 'Low probability should be flagged');
        System.assert(sawAmountReason, 'Large deal size should be flagged');
    }

    @isTest
    static void testScoreOpportunityNullOpportunityThrows() {
        Boolean threw = false;
        try {
            RiskAnalysisService.scoreOpportunity(null, OpportunityService.getConfig(), null);
        } catch (RiskAnalysisException ex) {
            threw = true;
        }
        System.assert(threw, 'Scoring a null opportunity should throw RiskAnalysisException');
    }

    @isTest
    static void testAnalyzeAndUpdateEmptyListReturnsEmpty() {
        List<RiskScoreResult> results = RiskAnalysisService.analyzeAndUpdate(new List<Opportunity>());
        System.assertEquals(0, results.size());
    }

    @isTest
    static void testAnalyzeAndUpdatePersistsScoreAndPublishesAlert() {
        Account acct = TestDataFactory.createAccount('Alert Co');
        Opportunity opp = TestDataFactory.createOpportunity(acct.Id, 'Alert Deal', 'Negotiation/Review', 150000, Date.today().addDays(-2), 5);

        Integer emailsBefore = Limits.getEmailInvocations();

        Test.startTest();
        List<RiskScoreResult> results = RiskAnalysisService.analyzeAndUpdate(new List<Opportunity>{ opp });
        Test.getEventBus().deliver();
        Test.stopTest();

        Integer emailsAfter = Limits.getEmailInvocations();

        System.assertEquals(1, results.size());
        System.assertEquals('High', results[0].level);

        Opportunity updated = [SELECT Risk_Score__c, Risk_Level__c, AI_Last_Analyzed__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('High', updated.Risk_Level__c);
        System.assertNotEquals(null, updated.AI_Last_Analyzed__c);
        System.assert(emailsAfter > emailsBefore, 'Publishing a new High risk alert should notify the opportunity owner');
    }

    @isTest
    static void testAnalyzeAndUpdateBulk200Opportunities() {
        Account acct = TestDataFactory.createAccount('Bulk Co');
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 200; i++) {
            opps.add(TestDataFactory.buildOpportunity(acct.Id, 'Bulk Deal ' + i, 'Prospecting', 1000 + i, Date.today().addDays(30), 50));
        }
        insert opps;

        Test.startTest();
        List<RiskScoreResult> results = RiskAnalysisService.analyzeAndUpdate(opps);
        Test.stopTest();

        System.assertEquals(200, results.size());
    }
}
