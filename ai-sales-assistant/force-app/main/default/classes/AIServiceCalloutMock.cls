/**
 * Simulated AI service response used by test classes to exercise
 * AIServiceCallout without a live external endpoint.
 */
@isTest
public class AIServiceCalloutMock implements HttpCalloutMock {

    private final Integer statusCode;
    private final String body;

    public AIServiceCalloutMock() {
        this(200, JSON.serialize(new Map<String, Object>{
            'summary' => 'Mock AI summary generated for testing.',
            'nextBestAction' => 'Mock next best action.',
            'competitorInsights' => 'Mock competitor insights.',
            'confidence' => 0.72
        }));
    }

    public AIServiceCalloutMock(Integer statusCode, String body) {
        this.statusCode = statusCode;
        this.body = body;
    }

    public HttpResponse respond(HttpRequest request) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(statusCode);
        res.setBody(body);
        res.setHeader('Content-Type', 'application/json');
        return res;
    }
}
