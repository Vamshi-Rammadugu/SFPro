import { LightningElement, api, wire } from 'lwc';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import OPPORTUNITY_SELECTED_CHANNEL from '@salesforce/messageChannel/OpportunitySelected__c';
import getNextBestAction from '@salesforce/apex/OpportunityDashboardController.getNextBestAction';
import refreshAiRecommendation from '@salesforce/apex/OpportunityDashboardController.refreshAiRecommendation';

/**
 * Suggested next action for the selected opportunity, with a manual
 * "Refresh with AI" action gated by the Manage_AI_Sales_Assistant custom
 * permission (enforced server-side in OpportunityDashboardController).
 */
export default class NextBestAction extends LightningElement {
    @api recordId;

    action;
    errorMessage;
    isRefreshing = false;
    subscription;
    wiredResult;

    @wire(MessageContext)
    messageContext;

    @wire(getNextBestAction, { opportunityId: '$recordId' })
    wiredAction(result) {
        this.wiredResult = result;
        if (result.data !== undefined) {
            this.action = result.data;
            this.errorMessage = undefined;
        } else if (result.error) {
            this.errorMessage = this.reduceError(result.error);
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

    get hasAction() {
        return !!this.action;
    }

    get placeholderText() {
        return this.recordId
            ? 'No suggested action yet. Try refreshing with AI.'
            : 'Select an opportunity to see the suggested next action.';
    }

    get isRefreshDisabled() {
        return !this.recordId || this.isRefreshing;
    }

    async handleRefresh() {
        this.isRefreshing = true;
        try {
            const result = await refreshAiRecommendation({ opportunityId: this.recordId });
            this.action = result.nextBestAction;
            await refreshApex(this.wiredResult);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'AI recommendation refreshed',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Unable to refresh AI recommendation',
                    message: this.reduceError(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isRefreshing = false;
        }
    }

    reduceError(error) {
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        return (error.body && error.body.message) || 'Unable to load the next best action.';
    }
}
