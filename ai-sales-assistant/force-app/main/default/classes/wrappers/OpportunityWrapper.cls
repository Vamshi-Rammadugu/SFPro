/**
 * Flat, UI-friendly view of an Opportunity for the dashboard and card components.
 */
public with sharing class OpportunityWrapper {
    @AuraEnabled public Id opportunityId;
    @AuraEnabled public String name;
    @AuraEnabled public String accountName;
    @AuraEnabled public Decimal amount;
    @AuraEnabled public String stageName;
    @AuraEnabled public Date closeDate;
    @AuraEnabled public Decimal probability;
    @AuraEnabled public Integer riskScore;
    @AuraEnabled public String riskLevel;
    @AuraEnabled public String ownerName;
    @AuraEnabled public Datetime aiLastAnalyzed;

    public OpportunityWrapper(Opportunity opp) {
        this.opportunityId = opp.Id;
        this.name = opp.Name;
        this.accountName = opp.Account != null ? opp.Account.Name : null;
        this.amount = opp.Amount;
        this.stageName = opp.StageName;
        this.closeDate = opp.CloseDate;
        this.probability = opp.Probability;
        this.riskScore = opp.Risk_Score__c != null ? opp.Risk_Score__c.intValue() : null;
        this.riskLevel = opp.Risk_Level__c;
        this.ownerName = opp.Owner != null ? opp.Owner.Name : null;
        this.aiLastAnalyzed = opp.AI_Last_Analyzed__c;
    }

    public static List<OpportunityWrapper> wrapAll(List<Opportunity> opportunities) {
        List<OpportunityWrapper> wrapped = new List<OpportunityWrapper>();
        for (Opportunity opp : opportunities) {
            wrapped.add(new OpportunityWrapper(opp));
        }
        return wrapped;
    }
}
