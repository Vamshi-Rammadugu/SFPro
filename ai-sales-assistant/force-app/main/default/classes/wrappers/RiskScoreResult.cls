/**
 * Result of RiskAnalysisService's scoring algorithm for a single opportunity.
 */
public with sharing class RiskScoreResult {
    @AuraEnabled public Id opportunityId;
    @AuraEnabled public Integer score;
    @AuraEnabled public String level;
    @AuraEnabled public List<String> reasons;

    public RiskScoreResult(Id opportunityId, Integer score, String level, List<String> reasons) {
        this.opportunityId = opportunityId;
        this.score = score;
        this.level = level;
        this.reasons = reasons;
    }
}
