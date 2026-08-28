@isTest
private class TaskSchedulerTest {

    @isTest
    static void testScheduleDailyRegistersCronJob() {
        Test.startTest();
        Id jobId = TaskScheduler.scheduleDaily('0 0 3 * * ?');
        Test.stopTest();

        CronTrigger job = [SELECT Id, CronExpression, State FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals('0 0 3 * * ?', job.CronExpression);
    }

    @isTest
    static void testExecuteScoresDealsAndCreatesFollowUpTasks() {
        Account acct = TestDataFactory.createAccount('Scheduler Co');
        Opportunity highRisk = TestDataFactory.createHighRiskOpportunity(acct.Id, 'Scheduler Risk Deal');

        Test.startTest();
        new TaskScheduler().execute(null);
        Test.stopTest();

        List<Task> followUps = [
            SELECT Id, Subject, WhatId
            FROM Task
            WHERE WhatId = :highRisk.Id AND Subject = 'AI Sales Assistant: Review high-risk deal'
        ];
        System.assertEquals(1, followUps.size());
    }

    @isTest
    static void testCreateFollowUpTasksDoesNotDuplicateOpenTask() {
        Account acct = TestDataFactory.createAccount('No Dup Co');
        Opportunity highRisk = TestDataFactory.createHighRiskOpportunity(acct.Id, 'No Dup Risk Deal');

        Test.startTest();
        TaskScheduler.createFollowUpTasksForStaleDeals();
        TaskScheduler.createFollowUpTasksForStaleDeals();
        Test.stopTest();

        List<Task> followUps = [
            SELECT Id
            FROM Task
            WHERE WhatId = :highRisk.Id AND Subject = 'AI Sales Assistant: Review high-risk deal'
        ];
        System.assertEquals(1, followUps.size(), 'A second run should not create a duplicate follow-up task');
    }
}
