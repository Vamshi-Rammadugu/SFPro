/**
 * Keeps Risk_Score__c / Risk_Level__c fresh whenever a risk-relevant field
 * changes, by scoring in place inside the before-trigger context (no extra
 * DML). The authoritative, alert-publishing pass is RiskAnalysisService.
 * analyzeAndUpdate, run nightly by OpportunityRiskBatch.
 */
public with sharing class OpportunityTriggerHandler {

    public void run(List<Opportunity> newRecords, Map<Id, Opportunity> oldMap) {
        List<Opportunity> toScore = new List<Opportunity>();
        for (Opportunity opp : newRecords) {
            if (opp.IsClosed) {
                continue;
            }
            Opportunity oldOpp = oldMap != null ? oldMap.get(opp.Id) : null;
            if (oldOpp == null || hasRiskRelevantChange(opp, oldOpp)) {
                toScore.add(opp);
            }
        }
        if (!toScore.isEmpty()) {
            scoreInPlace(toScore);
        }
    }

    @TestVisible
    private void scoreInPlace(List<Opportunity> opportunities) {
        AI_Config__mdt config = OpportunityService.getConfig();
        Map<Id, List<Task>> tasksByOpp = getActivityDatesForExistingRecords(opportunities);

        for (Opportunity opp : opportunities) {
            try {
                RiskScoreResult result = RiskAnalysisService.scoreOpportunity(opp, config, tasksByOpp.get(opp.Id));
                opp.Risk_Score__c = result.score;
                opp.Risk_Level__c = result.level;
                opp.AI_Last_Analyzed__c = Datetime.now();
            } catch (RiskAnalysisException ex) {
                opp.addError('Unable to compute AI risk score: ' + ex.getMessage());
            }
        }
    }

    private Map<Id, List<Task>> getActivityDatesForExistingRecords(List<Opportunity> opportunities) {
        Set<Id> existingIds = new Set<Id>();
        for (Opportunity opp : opportunities) {
            if (opp.Id != null) {
                existingIds.add(opp.Id);
            }
        }

        Map<Id, List<Task>> tasksByOpp = new Map<Id, List<Task>>();
        if (existingIds.isEmpty()) {
            return tasksByOpp;
        }

        for (Task t : [
            SELECT Id, WhatId, ActivityDate
            FROM Task
            WHERE WhatId IN :existingIds AND ActivityDate != null
            WITH USER_MODE
        ]) {
            if (!tasksByOpp.containsKey(t.WhatId)) {
                tasksByOpp.put(t.WhatId, new List<Task>());
            }
            tasksByOpp.get(t.WhatId).add(t);
        }
        return tasksByOpp;
    }

    private Boolean hasRiskRelevantChange(Opportunity newOpp, Opportunity oldOpp) {
        return newOpp.StageName != oldOpp.StageName
            || newOpp.Amount != oldOpp.Amount
            || newOpp.CloseDate != oldOpp.CloseDate
            || newOpp.Probability != oldOpp.Probability;
    }
}
