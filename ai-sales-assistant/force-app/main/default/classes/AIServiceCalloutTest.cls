@isTest
private class AIServiceCalloutTest {

    @isTest
    static void testFetchRecommendationParsesSuccessfulResponse() {
        Account acct = TestDataFactory.createAccount('Callout Co');
        Opportunity opp = TestDataFactory.createOpportunity(acct.Id, 'Callout Deal', 'Prospecting', 5000, Date.today().addDays(30), 60);

        Test.setMock(HttpCalloutMock.class, new AIServiceCalloutMock());

        Test.startTest();
        AIServiceCallout.CalloutResult result = AIServiceCallout.fetchRecommendation(opp);
        Test.stopTest();

        System.assertEquals('Mock AI summary generated for testing.', result.summary);
        System.assertEquals('Mock next best action.', result.nextBestAction);
        System.assertEquals(0.72, result.confidence);
    }

    @isTest
    static void testFetchRecommendationThrowsOnHttpError() {
        Account acct = TestDataFactory.createAccount('Callout Fail Co');
        Opportunity opp = TestDataFactory.createOpportunity(acct.Id, 'Callout Fail Deal', 'Prospecting', 5000, Date.today().addDays(30), 60);

        Test.setMock(HttpCalloutMock.class, new AIServiceCalloutMock(500, 'Internal Server Error'));

        Boolean threw = false;
        Test.startTest();
        try {
            AIServiceCallout.fetchRecommendation(opp);
        } catch (AIServiceException ex) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'A non-200 response should raise AIServiceException');
    }

    @isTest
    static void testParseResponseThrowsOnInvalidJson() {
        Boolean threw = false;
        try {
            AIServiceCallout.parseResponse('not-json');
        } catch (AIServiceException ex) {
            threw = true;
        }
        System.assert(threw, 'Malformed JSON should raise AIServiceException');
    }
}
