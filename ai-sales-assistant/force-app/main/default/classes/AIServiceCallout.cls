/**
 * HTTP callout to the external AI recommendation service via the AI_Service
 * Named Credential. Kept separate from AIRecommendationService so the
 * transport concern (endpoint, auth, timeouts, response parsing) can be
 * mocked or swapped independently of the recommendation logic.
 */
public with sharing class AIServiceCallout {

    public class CalloutResult {
        public String summary;
        public String nextBestAction;
        public String competitorInsights;
        public Decimal confidence;
    }

    public static CalloutResult fetchRecommendation(Opportunity opp) {
        AI_Config__mdt config = OpportunityService.getConfig();
        String path = String.isNotBlank(config.AI_Endpoint_Path__c) ? config.AI_Endpoint_Path__c : '/v1/recommendations';

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:AI_Service' + path);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(10000);
        req.setBody(JSON.serialize(new Map<String, Object>{
            'opportunityId' => opp.Id,
            'name' => opp.Name,
            'stageName' => opp.StageName,
            'amount' => opp.Amount,
            'closeDate' => opp.CloseDate,
            'probability' => opp.Probability
        }));

        Http http = new Http();
        HttpResponse res;
        try {
            res = http.send(req);
        } catch (System.CalloutException ex) {
            throw new AIServiceException('AI service callout failed: ' + ex.getMessage(), ex);
        }

        if (res.getStatusCode() != 200) {
            throw new AIServiceException('AI service returned HTTP ' + res.getStatusCode() + ': ' + res.getBody());
        }

        return parseResponse(res.getBody());
    }

    @TestVisible
    private static CalloutResult parseResponse(String body) {
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
            CalloutResult result = new CalloutResult();
            result.summary = (String) parsed.get('summary');
            result.nextBestAction = (String) parsed.get('nextBestAction');
            result.competitorInsights = (String) parsed.get('competitorInsights');
            result.confidence = parsed.get('confidence') != null ? (Decimal) parsed.get('confidence') : null;
            return result;
        } catch (Exception ex) {
            throw new AIServiceException('Unable to parse AI service response: ' + ex.getMessage(), ex);
        }
    }
}
