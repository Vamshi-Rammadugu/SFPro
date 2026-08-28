/**
 * Computes a 0-100 deal risk score from close-date pressure, activity staleness,
 * win probability and deal size, persists it onto the Opportunity, and publishes
 * a Risk_Alert__e platform event whenever a deal newly crosses into High risk.
 */
public with sharing class RiskAnalysisService {

    public static List<RiskScoreResult> analyzeAndUpdate(List<Opportunity> opportunities) {
        if (opportunities == null || opportunities.isEmpty()) {
            return new List<RiskScoreResult>();
        }

        AI_Config__mdt config = OpportunityService.getConfig();
        Map<Id, List<Task>> tasksByOpp = getOpenActivityDatesByOpportunity(opportunities);

        List<RiskScoreResult> results = new List<RiskScoreResult>();
        List<Opportunity> toUpdate = new List<Opportunity>();
        List<Risk_Alert__e> alertsToPublish = new List<Risk_Alert__e>();

        for (Opportunity opp : opportunities) {
            RiskScoreResult result;
            try {
                result = scoreOpportunity(opp, config, tasksByOpp.get(opp.Id));
            } catch (Exception ex) {
                throw new RiskAnalysisException('Unable to score opportunity ' + opp.Id + ': ' + ex.getMessage(), ex);
            }
            results.add(result);

            String previousLevel = opp.Risk_Level__c;
            toUpdate.add(new Opportunity(
                Id = opp.Id,
                Risk_Score__c = result.score,
                Risk_Level__c = result.level,
                AI_Last_Analyzed__c = Datetime.now()
            ));

            if (result.level == 'High' && previousLevel != 'High') {
                alertsToPublish.add(new Risk_Alert__e(
                    Opportunity_Id__c = opp.Id,
                    Account_Name__c = opp.Name,
                    Risk_Score__c = result.score,
                    Message__c = String.join(result.reasons, '; ')
                ));
            }
        }

        if (!toUpdate.isEmpty()) {
            Database.SaveResult[] saveResults = Database.update(toUpdate, false, AccessLevel.SYSTEM_MODE);
            for (Database.SaveResult sr : saveResults) {
                if (!sr.isSuccess()) {
                    System.debug(LoggingLevel.ERROR, 'RiskAnalysisService: failed to persist risk score - ' + sr.getErrors());
                }
            }
        }

        if (!alertsToPublish.isEmpty()) {
            EventBus.publish(alertsToPublish);
        }

        return results;
    }

    public static RiskScoreResult scoreOpportunity(Opportunity opp, AI_Config__mdt config, List<Task> openTasks) {
        if (opp == null) {
            throw new RiskAnalysisException('Cannot score a null opportunity.');
        }
        if (config == null) {
            throw new RiskAnalysisException('Missing AI_Config__mdt.Default_Config.');
        }

        Integer score = 0;
        List<String> reasons = new List<String>();

        if (opp.CloseDate != null) {
            Integer daysToClose = Date.today().daysBetween(opp.CloseDate);
            if (daysToClose < 0) {
                score += 35;
                reasons.add('Close date is ' + Math.abs(daysToClose) + ' day(s) in the past');
            } else if (daysToClose <= 7 && (opp.Probability == null || opp.Probability < 60)) {
                score += 20;
                reasons.add('Closing within a week but probability is below 60%');
            }
        }

        Integer staleDays = config.Stale_Deal_Days__c != null ? config.Stale_Deal_Days__c.intValue() : 14;
        Date lastActivityDate = latestActivityDate(openTasks);
        if (lastActivityDate == null) {
            score += 20;
            reasons.add('No logged activity found');
        } else {
            Integer daysSinceActivity = lastActivityDate.daysBetween(Date.today());
            if (daysSinceActivity >= staleDays) {
                score += 20;
                reasons.add('No activity in ' + daysSinceActivity + ' day(s)');
            }
        }

        if (opp.Probability != null && opp.Probability < 30 && !opp.IsClosed) {
            score += 15;
            reasons.add('Win probability is below 30%');
        }

        if (opp.Amount != null && opp.Amount >= 100000) {
            score += 10;
            reasons.add('Large deal size (' + opp.Amount.format() + ') warrants extra attention');
        }

        score = Math.min(score, 100);

        String level;
        if (score >= config.High_Risk_Threshold__c) {
            level = 'High';
        } else if (score >= config.Medium_Risk_Threshold__c) {
            level = 'Medium';
        } else {
            level = 'Low';
        }

        if (reasons.isEmpty()) {
            reasons.add('No risk signals detected');
        }

        return new RiskScoreResult(opp.Id, score, level, reasons);
    }

    private static Date latestActivityDate(List<Task> tasks) {
        if (tasks == null || tasks.isEmpty()) {
            return null;
        }
        Date latest;
        for (Task t : tasks) {
            if (t.ActivityDate != null && (latest == null || t.ActivityDate > latest)) {
                latest = t.ActivityDate;
            }
        }
        return latest;
    }

    private static Map<Id, List<Task>> getOpenActivityDatesByOpportunity(List<Opportunity> opportunities) {
        Set<Id> oppIds = new Map<Id, Opportunity>(opportunities).keySet();
        Map<Id, List<Task>> tasksByOpp = new Map<Id, List<Task>>();
        for (Task t : [
            SELECT Id, WhatId, ActivityDate, Status
            FROM Task
            WHERE WhatId IN :oppIds AND ActivityDate != null
            WITH USER_MODE
            ORDER BY ActivityDate DESC
        ]) {
            if (!tasksByOpp.containsKey(t.WhatId)) {
                tasksByOpp.put(t.WhatId, new List<Task>());
            }
            tasksByOpp.get(t.WhatId).add(t);
        }
        return tasksByOpp;
    }
}
