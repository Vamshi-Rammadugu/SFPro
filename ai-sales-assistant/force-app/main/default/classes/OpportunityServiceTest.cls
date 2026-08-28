@isTest
private class OpportunityServiceTest {

    @isTest
    static void testGetConfigReturnsDefaultConfig() {
        AI_Config__mdt config = OpportunityService.getConfig();
        System.assertNotEquals(null, config, 'Default_Config custom metadata record should be deployed');
        System.assertEquals(70, config.High_Risk_Threshold__c.intValue());
        System.assertEquals(40, config.Medium_Risk_Threshold__c.intValue());
    }

    @isTest
    static void testGetOpenOpportunitiesExcludesClosed() {
        Account acct = TestDataFactory.createAccount('Acme Corp');
        Opportunity openOpp = TestDataFactory.createOpportunity(acct.Id, 'Open Deal', 'Prospecting', 10000, Date.today().addDays(30), 50);
        Opportunity closedOpp = TestDataFactory.createOpportunity(acct.Id, 'Closed Deal', 'Closed Won', 20000, Date.today().addDays(-10), 100);

        Test.startTest();
        List<Opportunity> openOpps = OpportunityService.getOpenOpportunities(50);
        Test.stopTest();

        Set<Id> openIds = new Map<Id, Opportunity>(openOpps).keySet();
        System.assert(openIds.contains(openOpp.Id), 'Open opportunity should be returned');
        System.assert(!openIds.contains(closedOpp.Id), 'Closed opportunity should be excluded');
    }

    @isTest
    static void testGetHighRiskOpportunitiesOnlyReturnsAboveThreshold() {
        Account acct = TestDataFactory.createAccount('Risky Inc');
        Opportunity highRisk = TestDataFactory.createHighRiskOpportunity(acct.Id, 'At Risk Deal');
        Opportunity healthy = TestDataFactory.createHealthyOpportunity(acct.Id, 'Healthy Deal');

        Test.startTest();
        List<Opportunity> highRiskOpps = OpportunityService.getHighRiskOpportunities(50);
        Test.stopTest();

        Set<Id> highRiskIds = new Map<Id, Opportunity>(highRiskOpps).keySet();
        System.assert(highRiskIds.contains(highRisk.Id), 'Engineered high-risk deal should be flagged High');
        System.assert(!highRiskIds.contains(healthy.Id), 'Healthy deal should not be flagged High');
    }

    @isTest
    static void testQueryOpportunitiesRejectsUnsupportedSortField() {
        Boolean threw = false;
        try {
            OpportunityService.queryOpportunities(new Map<String, Object>(), 'UnsupportedField__c', true, 10);
        } catch (IllegalArgumentException ex) {
            threw = true;
        }
        System.assert(threw, 'An unsupported sort field should raise IllegalArgumentException');
    }

    @isTest
    static void testGetOpportunityByIdReturnsNullWhenMissing() {
        Opportunity result = OpportunityService.getOpportunityById(null);
        System.assertEquals(null, result);
    }

    @isTest
    static void testGetUpcomingTasksWithinWindow() {
        Account acct = TestDataFactory.createAccount('Task Co');
        Opportunity opp = TestDataFactory.createOpportunity(acct.Id, 'Task Deal', 'Prospecting', 1000, Date.today().addDays(30), 40);
        TestDataFactory.createTask(opp.Id, 'Follow up call', Date.today().addDays(2), 'Not Started');
        TestDataFactory.createTask(opp.Id, 'Too far out', Date.today().addDays(60), 'Not Started');

        Test.startTest();
        List<Task> upcoming = OpportunityService.getUpcomingTasks(14, 10);
        Test.stopTest();

        Set<String> subjects = new Set<String>();
        for (Task t : upcoming) {
            subjects.add(t.Subject);
        }
        System.assert(subjects.contains('Follow up call'), 'Task within the window should be returned');
        System.assert(!subjects.contains('Too far out'), 'Task outside the window should be excluded');
    }

    @isTest
    static void testCountOpenOpportunitiesWithRecommendations() {
        Account acct = TestDataFactory.createAccount('Reco Co');
        Opportunity opp = TestDataFactory.createOpportunity(acct.Id, 'Reco Deal', 'Prospecting', 1000, Date.today().addDays(30), 40);

        Integer before = OpportunityService.countOpenOpportunitiesWithRecommendations();

        Database.update(new Opportunity(Id = opp.Id, AI_Summary__c = 'Some AI summary'), AccessLevel.SYSTEM_MODE);

        Test.startTest();
        Integer after = OpportunityService.countOpenOpportunitiesWithRecommendations();
        Test.stopTest();

        System.assertEquals(before + 1, after);
    }

    @isTest
    static void testGetRecentActivitiesMergesTasksAndEventsSortedDescending() {
        Account acct = TestDataFactory.createAccount('Activity Co');
        Opportunity opp = TestDataFactory.createOpportunity(acct.Id, 'Activity Deal', 'Prospecting', 1000, Date.today().addDays(30), 40);
        TestDataFactory.createTask(opp.Id, 'Older task', Date.today().addDays(-5), 'Completed');
        TestDataFactory.createEvent(opp.Id, 'Newer event', Date.today().addDays(-1));

        Test.startTest();
        List<ActivityWrapper> activities = OpportunityService.getRecentActivities(opp.Id, 10);
        Test.stopTest();

        System.assertEquals(2, activities.size());
        System.assertEquals('Newer event', activities[0].subject);
        System.assertEquals('Older task', activities[1].subject);
    }

    @isTest
    static void testGetDealTimelineIncludesCloseDateAndActivities() {
        Account acct = TestDataFactory.createAccount('Timeline Co');
        Opportunity opp = TestDataFactory.createOpportunity(acct.Id, 'Timeline Deal', 'Prospecting', 1000, Date.today().addDays(30), 40);
        TestDataFactory.createTask(opp.Id, 'Kickoff call', Date.today(), 'Completed');
        Opportunity fullOpp = OpportunityService.getOpportunityById(opp.Id);

        Test.startTest();
        List<ActivityWrapper> activities = OpportunityService.getRecentActivities(opp.Id, 10);
        List<DealTimelineEntry> timeline = OpportunityService.getDealTimeline(fullOpp, activities);
        Test.stopTest();

        System.assertEquals(2, timeline.size(), 'Timeline should include the expected close entry plus one activity');
        System.assertEquals('Expected Close', timeline[0].label);
    }
}
