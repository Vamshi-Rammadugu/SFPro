/**
 * AI-weighted revenue forecast for a single opportunity.
 */
public with sharing class RevenueForecastWrapper {
    @AuraEnabled public Decimal amount;
    @AuraEnabled public Decimal weightedAmount;
    @AuraEnabled public Decimal confidence;
    @AuraEnabled public String forecastCategory;
    @AuraEnabled public Date expectedCloseDate;

    public RevenueForecastWrapper(Decimal amount, Decimal weightedAmount, Decimal confidence,
            String forecastCategory, Date expectedCloseDate) {
        this.amount = amount;
        this.weightedAmount = weightedAmount;
        this.confidence = confidence;
        this.forecastCategory = forecastCategory;
        this.expectedCloseDate = expectedCloseDate;
    }
}
