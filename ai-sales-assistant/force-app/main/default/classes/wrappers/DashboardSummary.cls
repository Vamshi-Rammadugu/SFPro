/**
 * Aggregate payload for the opportunityDashboard LWC's single load call.
 */
public with sharing class DashboardSummary {
    @AuraEnabled public List<OpportunityWrapper> openOpportunities;
    @AuraEnabled public List<OpportunityWrapper> highRiskOpportunities;
    @AuraEnabled public List<TaskWrapper> upcomingTasks;
    @AuraEnabled public Integer aiRecommendationCount;

    public DashboardSummary(List<OpportunityWrapper> openOpportunities, List<OpportunityWrapper> highRiskOpportunities,
            List<TaskWrapper> upcomingTasks, Integer aiRecommendationCount) {
        this.openOpportunities = openOpportunities;
        this.highRiskOpportunities = highRiskOpportunities;
        this.upcomingTasks = upcomingTasks;
        this.aiRecommendationCount = aiRecommendationCount;
    }
}
