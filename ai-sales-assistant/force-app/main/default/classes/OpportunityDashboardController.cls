/**
 * Single @AuraEnabled surface for the AI Sales Assistant LWC components.
 * Every read is cacheable so the wire service can dedupe calls across the
 * independent detail components; the one write path (refreshAiRecommendation)
 * is gated by the Manage_AI_Sales_Assistant custom permission.
 */
public with sharing class OpportunityDashboardController {

    @AuraEnabled(cacheable=true)
    public static DashboardSummary getDashboardSummary() {
        try {
            List<Opportunity> openOpps = OpportunityService.getOpenOpportunities(50);
            List<Opportunity> highRiskOpps = OpportunityService.getHighRiskOpportunities(50);
            List<Task> upcomingTasks = OpportunityService.getUpcomingTasks(14, 25);
            Integer aiRecommendationCount = OpportunityService.countOpenOpportunitiesWithRecommendations();

            return new DashboardSummary(
                OpportunityWrapper.wrapAll(openOpps),
                OpportunityWrapper.wrapAll(highRiskOpps),
                TaskWrapper.wrapAll(upcomingTasks),
                aiRecommendationCount
            );
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to load dashboard: ' + ex.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static OpportunityWrapper getOpportunityCard(Id opportunityId) {
        Opportunity opp = OpportunityService.getOpportunityById(opportunityId);
        return opp != null ? new OpportunityWrapper(opp) : null;
    }

    @AuraEnabled(cacheable=true)
    public static String getAiSummary(Id opportunityId) {
        return requireOpportunity(opportunityId).AI_Summary__c;
    }

    @AuraEnabled(cacheable=true)
    public static String getNextBestAction(Id opportunityId) {
        return requireOpportunity(opportunityId).Next_Best_Action__c;
    }

    @AuraEnabled(cacheable=true)
    public static String getCompetitorInsights(Id opportunityId) {
        return requireOpportunity(opportunityId).Competitor_Insights__c;
    }

    @AuraEnabled(cacheable=true)
    public static RevenueForecastWrapper getRevenueForecast(Id opportunityId) {
        Opportunity opp = requireOpportunity(opportunityId);
        Decimal confidence = opp.Amount != null && opp.Amount > 0 && opp.Revenue_Forecast__c != null
            ? (opp.Revenue_Forecast__c / opp.Amount)
            : (opp.Probability != null ? opp.Probability / 100 : null);
        String category;
        if (confidence == null) {
            category = 'Pipeline';
        } else if (confidence >= 0.7) {
            category = 'Commit';
        } else if (confidence >= 0.4) {
            category = 'Best Case';
        } else {
            category = 'Pipeline';
        }
        return new RevenueForecastWrapper(opp.Amount, opp.Revenue_Forecast__c, confidence, category, opp.CloseDate);
    }

    @AuraEnabled(cacheable=true)
    public static List<DealTimelineEntry> getDealTimeline(Id opportunityId) {
        Opportunity opp = requireOpportunity(opportunityId);
        try {
            List<ActivityWrapper> activities = OpportunityService.getRecentActivities(opportunityId, 10);
            return OpportunityService.getDealTimeline(opp, activities);
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to load deal timeline: ' + ex.getMessage());
        }
    }

    @AuraEnabled
    public static AIRecommendationResult refreshAiRecommendation(Id opportunityId) {
        if (!FeatureManagement.checkPermission('Manage_AI_Sales_Assistant')) {
            throw new AuraHandledException('You do not have permission to refresh AI recommendations.');
        }
        try {
            AIRecommendationResult result = AIRecommendationService.generateAndSave(opportunityId);
            Opportunity refreshed = OpportunityService.getOpportunityById(opportunityId);
            RiskAnalysisService.analyzeAndUpdate(new List<Opportunity>{ refreshed });
            return result;
        } catch (AIServiceException ex) {
            throw new AuraHandledException(ex.getMessage());
        } catch (Exception ex) {
            throw new AuraHandledException('Unable to refresh AI recommendation: ' + ex.getMessage());
        }
    }

    private static Opportunity requireOpportunity(Id opportunityId) {
        Opportunity opp = OpportunityService.getOpportunityById(opportunityId);
        if (opp == null) {
            throw new AuraHandledException('Opportunity not found or not accessible.');
        }
        return opp;
    }
}
