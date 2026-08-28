/**
 * Schedulable entry point that kicks off the nightly risk re-scoring batch
 * and opens a follow-up task for every High risk deal that doesn't already
 * have one outstanding.
 */
public with sharing class TaskScheduler implements Schedulable {

    public static final String DEFAULT_CRON = '0 0 2 * * ?';

    @TestVisible
    private static final String FOLLOW_UP_SUBJECT = 'AI Sales Assistant: Review high-risk deal';

    public void execute(SchedulableContext context) {
        Database.executeBatch(new OpportunityRiskBatch(), 50);
        createFollowUpTasksForStaleDeals();
    }

    public static Id scheduleDaily() {
        return scheduleDaily(DEFAULT_CRON);
    }

    public static Id scheduleDaily(String cronExpression) {
        return System.schedule('AI Sales Assistant - Nightly Risk Refresh', cronExpression, new TaskScheduler());
    }

    @TestVisible
    private static void createFollowUpTasksForStaleDeals() {
        List<Opportunity> highRisk = OpportunityService.getHighRiskOpportunities(200);
        if (highRisk.isEmpty()) {
            return;
        }

        Set<Id> oppIds = new Map<Id, Opportunity>(highRisk).keySet();
        Set<Id> oppIdsWithOpenFollowUp = new Set<Id>();
        for (Task t : [
            SELECT WhatId
            FROM Task
            WHERE WhatId IN :oppIds AND Subject = :FOLLOW_UP_SUBJECT AND Status != 'Completed'
            WITH USER_MODE
        ]) {
            oppIdsWithOpenFollowUp.add(t.WhatId);
        }

        List<Task> followUps = new List<Task>();
        for (Opportunity opp : highRisk) {
            if (oppIdsWithOpenFollowUp.contains(opp.Id)) {
                continue;
            }
            followUps.add(new Task(
                Subject = FOLLOW_UP_SUBJECT,
                WhatId = opp.Id,
                OwnerId = opp.OwnerId,
                ActivityDate = Date.today().addDays(1),
                Priority = 'High',
                Status = 'Not Started',
                Description = 'Automatically created because this opportunity is flagged High risk (score ' + opp.Risk_Score__c + ').'
            ));
        }

        if (!followUps.isEmpty()) {
            Database.insert(followUps, false, AccessLevel.SYSTEM_MODE);
        }
    }
}
