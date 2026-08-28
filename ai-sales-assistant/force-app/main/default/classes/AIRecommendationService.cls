/**
 * Produces the AI summary, next best action, competitor insights and revenue
 * forecast for an opportunity. Prefers a live call to the external AI
 * service (via AIServiceCallout) and falls back to a deterministic
 * heuristic whenever the callout is unavailable or disabled, so the app is
 * fully demoable without a configured external endpoint.
 */
public with sharing class AIRecommendationService {

    public static AIRecommendationResult generateAndSave(Id opportunityId) {
        AI_Config__mdt config = OpportunityService.getConfig();
        if (config.Enable_AI_Recommendations__c != true) {
            throw new AIServiceException('AI recommendations are disabled via AI_Config__mdt.Default_Config.');
        }

        Opportunity opp = OpportunityService.getOpportunityById(opportunityId);
        if (opp == null) {
            throw new AIServiceException('Opportunity not found or not accessible: ' + opportunityId);
        }

        AIRecommendationResult result = generate(opp);

        Opportunity toUpdate = new Opportunity(
            Id = opp.Id,
            AI_Summary__c = result.summary,
            Next_Best_Action__c = result.nextBestAction,
            Competitor_Insights__c = result.competitorInsights,
            Revenue_Forecast__c = result.revenueForecast.weightedAmount,
            AI_Last_Analyzed__c = result.generatedAt
        );
        Database.update(toUpdate, true, AccessLevel.SYSTEM_MODE);

        return result;
    }

    public static AIRecommendationResult generate(Opportunity opp) {
        if (opp == null) {
            throw new AIServiceException('Cannot generate a recommendation for a null opportunity.');
        }

        AIServiceCallout.CalloutResult calloutResult;
        try {
            calloutResult = AIServiceCallout.fetchRecommendation(opp);
        } catch (AIServiceException ex) {
            System.debug(LoggingLevel.WARN, 'AIRecommendationService: falling back to heuristic generation - ' + ex.getMessage());
            calloutResult = null;
        }

        String summary = calloutResult != null && String.isNotBlank(calloutResult.summary)
            ? calloutResult.summary
            : buildHeuristicSummary(opp);
        String nextBestAction = calloutResult != null && String.isNotBlank(calloutResult.nextBestAction)
            ? calloutResult.nextBestAction
            : buildHeuristicNextBestAction(opp);
        String competitorInsights = calloutResult != null && String.isNotBlank(calloutResult.competitorInsights)
            ? calloutResult.competitorInsights
            : buildHeuristicCompetitorInsights(opp);
        Decimal confidence = calloutResult != null && calloutResult.confidence != null
            ? calloutResult.confidence
            : defaultConfidence(opp);

        RevenueForecastWrapper forecast = buildForecast(opp, confidence);

        return new AIRecommendationResult(summary, nextBestAction, competitorInsights, forecast, Datetime.now());
    }

    private static String buildHeuristicSummary(Opportunity opp) {
        String amountText = opp.Amount != null ? opp.Amount.format() : 'an unspecified amount';
        String probabilityText = opp.Probability != null ? opp.Probability.intValue() + '%' : 'an unknown';
        String closeText = opp.CloseDate != null ? opp.CloseDate.format() : 'TBD';
        return opp.Name + ' is in ' + opp.StageName + ' for ' + amountText + ', with ' + probabilityText +
            ' win probability and an expected close of ' + closeText + '.';
    }

    private static String buildHeuristicNextBestAction(Opportunity opp) {
        if (opp.Risk_Level__c == 'High') {
            String closeText = opp.CloseDate != null ? opp.CloseDate.format() : 'the close date';
            return 'Schedule an executive check-in this week to address open risks before ' + closeText + '.';
        }
        if (opp.Probability != null && opp.Probability < 50) {
            return 'Confirm the economic buyer and share a tailored ROI summary to move probability past 50%.';
        }
        return 'Send a closing checklist and confirm procurement/legal timelines with the champion.';
    }

    private static String buildHeuristicCompetitorInsights(Opportunity opp) {
        return 'No competitor mentions detected in recent activity for ' + opp.Name + '. Confirm the competitive landscape on the next call.';
    }

    private static Decimal defaultConfidence(Opportunity opp) {
        return opp.Probability != null ? opp.Probability / 100 : 0.5;
    }

    private static RevenueForecastWrapper buildForecast(Opportunity opp, Decimal confidence) {
        Decimal amount = opp.Amount != null ? opp.Amount : 0;
        Decimal weighted = (amount * confidence).setScale(2);
        String category;
        if (confidence >= 0.7) {
            category = 'Commit';
        } else if (confidence >= 0.4) {
            category = 'Best Case';
        } else {
            category = 'Pipeline';
        }
        return new RevenueForecastWrapper(amount, weighted, confidence, category, opp.CloseDate);
    }
}
