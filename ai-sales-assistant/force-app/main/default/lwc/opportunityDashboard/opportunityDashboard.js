import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getDashboardSummary from '@salesforce/apex/OpportunityDashboardController.getDashboardSummary';

/**
 * Container tile for the AI Sales Assistant: open/high-risk opportunity
 * lists, upcoming tasks, and the AI recommendation count. Selecting a card
 * broadcasts the opportunity id over the OpportunitySelected message
 * channel; the detail panels (aiSummary, nextBestAction, recentActivities,
 * competitorInsights, revenueForecast) are independent siblings that react
 * to that broadcast.
 */
export default class OpportunityDashboard extends LightningElement {
    summary;
    errorMessage;
    wiredResult;

    @wire(getDashboardSummary)
    wiredDashboard(result) {
        this.wiredResult = result;
        if (result.data) {
            this.summary = result.data;
            this.errorMessage = undefined;
        } else if (result.error) {
            this.errorMessage = this.reduceError(result.error);
            this.summary = undefined;
        }
    }

    get isLoading() {
        return !this.summary && !this.errorMessage;
    }

    get openOpportunities() {
        return this.summary ? this.summary.openOpportunities : [];
    }

    get highRiskOpportunities() {
        return this.summary ? this.summary.highRiskOpportunities : [];
    }

    get upcomingTasks() {
        return this.summary ? this.summary.upcomingTasks : [];
    }

    get aiRecommendationCount() {
        return this.summary ? this.summary.aiRecommendationCount : 0;
    }

    get hasHighRiskOpportunities() {
        return this.highRiskOpportunities.length > 0;
    }

    get hasUpcomingTasks() {
        return this.upcomingTasks.length > 0;
    }

    handleRefresh() {
        return refreshApex(this.wiredResult);
    }

    reduceError(error) {
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        return error.statusText || 'Unable to load the dashboard.';
    }
}
