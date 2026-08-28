import { LightningElement, api, wire } from 'lwc';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import OPPORTUNITY_SELECTED_CHANNEL from '@salesforce/messageChannel/OpportunitySelected__c';
import getAiSummary from '@salesforce/apex/OpportunityDashboardController.getAiSummary';

/**
 * Standalone detail panel: works auto-bound on an Opportunity record page
 * (recordId is populated by the page context) or on any app page next to
 * opportunityDashboard, picking up selections over the OpportunitySelected
 * message channel.
 */
export default class AiSummary extends LightningElement {
    @api recordId;

    summary;
    errorMessage;
    subscription;

    @wire(MessageContext)
    messageContext;

    @wire(getAiSummary, { opportunityId: '$recordId' })
    wiredSummary({ data, error }) {
        if (data !== undefined) {
            this.summary = data;
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

    get hasSummary() {
        return !!this.summary;
    }

    get placeholderText() {
        return this.recordId
            ? 'No AI summary generated yet for this opportunity.'
            : 'Select an opportunity to see its AI summary.';
    }

    reduceError(error) {
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        return (error.body && error.body.message) || 'Unable to load the AI summary.';
    }
}
