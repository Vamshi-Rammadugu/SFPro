/**
 * Nightly (or on-demand) re-scoring of every open opportunity. Stateful so the
 * run can report how many deals it touched and how many are now High risk.
 */
public with sharing class OpportunityRiskBatch implements Database.Batchable<SObject>, Database.Stateful {

    @TestVisible
    private Integer processedCount = 0;
    @TestVisible
    private Integer highRiskCount = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocatorWithBinds(
            'SELECT Id, Name, Amount, StageName, CloseDate, Probability, IsClosed, IsWon, OwnerId, AccountId, ' +
            'Risk_Score__c, Risk_Level__c FROM Opportunity WHERE IsClosed = false',
            new Map<String, Object>(),
            AccessLevel.SYSTEM_MODE
        );
    }

    public void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        List<RiskScoreResult> results = RiskAnalysisService.analyzeAndUpdate(scope);
        processedCount += results.size();
        for (RiskScoreResult result : results) {
            if (result.level == 'High') {
                highRiskCount++;
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(
            LoggingLevel.INFO,
            'OpportunityRiskBatch complete: ' + processedCount + ' opportunities scored, ' + highRiskCount + ' now High risk.'
        );
    }
}
