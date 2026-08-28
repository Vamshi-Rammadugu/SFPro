import { LightningElement, api, wire } from 'lwc';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import OPPORTUNITY_SELECTED_CHANNEL from '@salesforce/messageChannel/OpportunitySelected__c';
import getRevenueForecast from '@salesforce/apex/OpportunityDashboardController.getRevenueForecast';

export default class RevenueForecast extends LightningElement {
    @api recordId;

    forecast;
    errorMessage;
    subscription;

    @wire(MessageContext)
    messageContext;

    @wire(getRevenueForecast, { opportunityId: '$recordId' })
    wiredForecast({ data, error }) {
        if (data !== undefined) {
            this.forecast = data;
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

    get hasForecast() {
        return !!this.forecast;
    }

    get placeholderText() {
        return this.recordId
            ? 'No revenue forecast available for this opportunity.'
            : 'Select an opportunity to see its revenue forecast.';
    }

    get categoryBadgeClass() {
        const category = this.forecast && this.forecast.forecastCategory;
        if (category === 'Commit') {
            return 'slds-badge slds-theme_success';
        }
        if (category === 'Best Case') {
            return 'slds-badge slds-theme_warning';
        }
        return 'slds-badge';
    }

    reduceError(error) {
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        return (error.body && error.body.message) || 'Unable to load the revenue forecast.';
    }
}
