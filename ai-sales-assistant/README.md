# AI Sales Assistant (Agentforce + Apex + LWC)

A self-contained Salesforce DX project that demonstrates an AI-assisted sales
workspace built entirely on the core platform (Apex + Lightning Web
Components), designed to sit alongside an Agentforce agent that can call the
same Apex services as actions.

## Why this project

Sales reps juggle a pipeline of opportunities and rarely have time to dig
into risk signals, competitor context, or "what should I do next" for every
deal. This app surfaces that as a dashboard: open and high-risk
opportunities, upcoming tasks, and AI-generated recommendations, with a
drill-down view per opportunity (summary, risk score, suggested next action,
deal timeline).

## Feature map

### Dashboard
- Open Opportunities
- High-risk Opportunities
- Upcoming Tasks
- AI Recommendations

### Opportunity Details
- AI-generated summary
- Risk score
- Suggested next action
- Deal timeline (recent activity + stage history)

## Architecture

### LWC components (`force-app/main/default/lwc`)
- `opportunityDashboard` — container component. Loads the dashboard summary
  (open/high-risk opportunities, upcoming tasks) and renders a list of
  `opportunityCard`s. Selecting a card publishes the selected opportunity id
  on the `OpportunitySelected` Lightning Message Channel.
- `opportunityCard` — presentational card for a single opportunity; can be
  reused anywhere a compact opportunity summary is needed.
- `aiSummary`, `nextBestAction`, `recentActivities`, `competitorInsights`,
  `revenueForecast` — independent detail panels. Each subscribes to the
  `OpportunitySelected` message channel and pulls its own slice of data via a
  cacheable Apex method, so they can be dropped onto any Lightning page
  (app page, record page, utility bar) without a direct parent/child
  relationship to the dashboard.

### Apex services (`force-app/main/default/classes`)
- `OpportunityService` — dynamic SOQL query building for dashboard lists
  (open / high-risk / by-arbitrary-filter opportunities), field-level-secure.
- `RiskAnalysisService` — computes a 0-100 risk score from deal signals
  (stage vs. close date, days of inactivity, amount, probability), persists
  it, and publishes a `Risk_Alert__e` platform event when a deal crosses into
  high risk.
- `AIRecommendationService` — generates the AI summary, next best action,
  competitor insights and revenue forecast for an opportunity. Falls back to
  a deterministic heuristic when the external AI callout is unavailable, so
  the app is fully demoable without a live endpoint.
- `AIServiceCallout` — HTTP callout to the `AI_Service` Named Credential,
  used by `AIRecommendationService` when richer, model-generated content is
  wanted.
- `TaskScheduler` — `Schedulable` job that schedules the nightly risk batch
  and creates follow-up tasks for deals that need attention.
- `OpportunityRiskBatch` — `Batchable`/`Stateful` job that re-scores every
  open opportunity.
- `NotificationService` / `NotificationQueueable` — turns risk alerts into
  rep-facing notifications asynchronously.
- `OpportunityTriggerHandler` / `OpportunityTrigger` — keeps risk scores
  fresh as deals change.
- `RiskAlertTrigger` — subscribes to the `Risk_Alert__e` platform event and
  hands it to `NotificationService`.
- `OpportunityDashboardController` — the single `@AuraEnabled` surface the
  LWC layer talks to.

Supporting wrapper classes live in `classes/wrappers`, custom exceptions in
`classes/exceptions`.

### Platform showcase
| Capability | Where |
| --- | --- |
| Platform Events | `Risk_Alert__e`, published from `RiskAnalysisService`, consumed by `RiskAlertTrigger` |
| Queueable Apex | `NotificationQueueable` |
| Batch Apex | `OpportunityRiskBatch` |
| Scheduled Apex | `TaskScheduler` |
| Custom Metadata | `AI_Config__mdt` (risk thresholds, feature flags) |
| Named Credentials | `AI_Service`, used by `AIServiceCallout` |
| Custom Permissions | `Manage_AI_Sales_Assistant` |
| Lightning Message Service | `OpportunitySelected` channel |
| Dynamic SOQL | `OpportunityService.buildOpportunityQuery` |
| Wrapper classes | `classes/wrappers/*` |
| Exception handling | `classes/exceptions/*`, try/catch + custom exceptions throughout the service layer |
| Test classes | One test class per Apex class, targeting 90%+ coverage with `Test.startTest/stopTest`, `HttpCalloutMock`, and bulk (200-record) assertions |

## Deploying

```bash
sf org login web -a AISalesAssistant
sf project deploy start -d force-app -o AISalesAssistant
sf org assign permset -n AI_Sales_Assistant_User -o AISalesAssistant
sf apex run --file scripts/apex/schedule-jobs.apex -o AISalesAssistant
```

Then assign the `AI Sales Assistant` app / `AI Sales Assistant` tab to your
user, or add the LWC components to a Lightning App Page / the Opportunity
record page via the Lightning App Builder.

## Running the tests

```bash
sf apex run test --test-level RunLocalTests --code-coverage -o AISalesAssistant
```
