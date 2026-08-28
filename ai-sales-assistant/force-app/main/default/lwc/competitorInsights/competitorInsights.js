import { LightningElement, api, wire } from 'lwc';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import OPPORTUNITY_SELECTED_CHANNEL from '@salesforce/messageChannel/OpportunitySelected__c';
import getCompetitorInsights from '@salesforce/apex/OpportunityDashboardController.getCompetitorInsights';

export default class CompetitorInsights extends LightningElement {
    @api recordId;

    insights;
    errorMessage;
    subscription;

    @wire(MessageContext)
    messageContext;

    @wire(getCompetitorInsights, { opportunityId: '$recordId' })
    wiredInsights({ data, error }) {
        if (data !== undefined) {
            this.insights = data;
            this.errorMessage = undefined;
        } else if (error) {
            this.errorMessage = this.reduceError(error);
        }
    }

    connectedCallback() {
        this.subscription = subscribe(this.messageContext, OPPORTUNITY_SELECTED_CHANNEL, (message) => {
            this.recordId = message.recordId;
        });
    }

    disconnectedCallback() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    get hasInsights() {
        return !!this.insights;
    }

    get placeholderText() {
        return this.recordId
            ? 'No competitor insights generated yet for this opportunity.'
            : 'Select an opportunity to see competitor insights.';
    }

    reduceError(error) {
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        return (error.body && error.body.message) || 'Unable to load competitor insights.';
    }
}
