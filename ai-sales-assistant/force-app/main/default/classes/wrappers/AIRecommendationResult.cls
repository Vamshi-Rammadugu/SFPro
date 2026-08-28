/**
 * Bundled output of AIRecommendationService.generate() for one opportunity.
 */
public with sharing class AIRecommendationResult {
    @AuraEnabled public String summary;
    @AuraEnabled public String nextBestAction;
    @AuraEnabled public String competitorInsights;
    @AuraEnabled public RevenueForecastWrapper revenueForecast;
    @AuraEnabled public Datetime generatedAt;

    public AIRecommendationResult(String summary, String nextBestAction, String competitorInsights,
            RevenueForecastWrapper revenueForecast, Datetime generatedAt) {
        this.summary = summary;
        this.nextBestAction = nextBestAction;
        this.competitorInsights = competitorInsights;
        this.revenueForecast = revenueForecast;
        this.generatedAt = generatedAt;
    }
}
