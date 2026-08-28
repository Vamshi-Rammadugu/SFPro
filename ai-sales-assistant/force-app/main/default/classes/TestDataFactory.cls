/**
 * Shared record-building helpers for the AI Sales Assistant test suite.
 */
@isTest
public class TestDataFactory {

    public static Account createAccount(String name) {
        Account acct = new Account(Name = name);
        insert acct;
        return acct;
    }

    public static Opportunity buildOpportunity(Id accountId, String name, String stageName, Decimal amount, Date closeDate, Decimal probability) {
        return new Opportunity(
            AccountId = accountId,
            Name = name,
            StageName = stageName,
            Amount = amount,
            CloseDate = closeDate,
            Probability = probability
        );
    }

    public static Opportunity createOpportunity(Id accountId, String name, String stageName, Decimal amount, Date closeDate, Decimal probability) {
        Opportunity opp = buildOpportunity(accountId, name, stageName, amount, closeDate, probability);
        insert opp;
        return opp;
    }

    /** An opportunity engineered to score High risk: past close date, no activity, low probability, large amount. */
    public static Opportunity createHighRiskOpportunity(Id accountId, String name) {
        return createOpportunity(accountId, name, 'Negotiation/Review', 150000, Date.today().addDays(-5), 10);
    }

    /** An opportunity engineered to score Low risk: future close date, healthy probability, modest amount. */
    public static Opportunity createHealthyOpportunity(Id accountId, String name) {
        Opportunity opp = createOpportunity(accountId, name, 'Prospecting', 5000, Date.today().addDays(60), 80);
        insert new Task(
            Subject = 'Discovery call',
            WhatId = opp.Id,
            ActivityDate = Date.today(),
            Status = 'Completed'
        );
        return opp;
    }

    public static Task createTask(Id whatId, String subject, Date activityDate, String status) {
        Task t = new Task(Subject = subject, WhatId = whatId, ActivityDate = activityDate, Status = status);
        insert t;
        return t;
    }

    public static Event createEvent(Id whatId, String subject, Date activityDate) {
        Event e = new Event(
            Subject = subject,
            WhatId = whatId,
            ActivityDate = activityDate,
            ActivityDateTime = Datetime.newInstance(activityDate, Time.newInstance(9, 0, 0, 0)),
            DurationInMinutes = 30
        );
        insert e;
        return e;
    }
}
