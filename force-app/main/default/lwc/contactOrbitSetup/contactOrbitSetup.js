import { LightningElement, wire } from 'lwc';
import getSetupState from '@salesforce/apex/CEI_ContactEmailRoutingController.getSetupState';
import saveSettings from '@salesforce/apex/CEI_ContactEmailRoutingController.saveSettings';
import scheduleRetention from '@salesforce/apex/CEI_ContactEmailRoutingController.scheduleRetention';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class ContactOrbitSetup extends LightningElement {
    state;
    draft;
    isLoading = false;
    wiredResult;

    get routingMode() {
        if (!this.state?.suggestionsEnabled) return 'Off';
        return this.state.autoLinkEnabled ? 'Verified auto-link' : 'Suggestion only';
    }

    get caseAccessLabel() { return this.state?.caseUpdateable ? 'Ready' : 'Review access'; }
    get contactAccessLabel() { return this.state?.contactUpdateable ? 'Ready' : 'Review access'; }
    get caseAccessClass() { return this.state?.caseUpdateable ? 'status-pill status-pill_success' : 'status-pill status-pill_warning'; }
    get contactAccessClass() { return this.state?.contactUpdateable ? 'status-pill status-pill_success' : 'status-pill status-pill_warning'; }
    get preflightLabel() { return this.state?.caseUpdateable && this.state?.contactUpdateable ? 'Ready to test' : 'Action needed'; }
    get preflightClass() { return this.state?.caseUpdateable && this.state?.contactUpdateable ? 'status-pill status-pill_success' : 'status-pill status-pill_warning'; }

    @wire(getSetupState)
    wiredSetup(result) {
        this.wiredResult = result;
        if (result.data) {
            this.state = result.data;
            this.draft = { suggestions: result.data.suggestionsEnabled, autoLink: result.data.autoLinkEnabled, retention: result.data.retentionDays };
        }
        if (result.error) this.toast('Unable to load setup', this.errorMessage(result.error), 'error');
    }

    handleInput(event) {
        const key = event.target.name;
        this.draft = { ...this.draft, [key]: event.target.type === 'checkbox' ? event.target.checked : event.target.value };
    }

    async save() {
        this.isLoading = true;
        try {
            await saveSettings({ suggestionsEnabled: this.draft.suggestions, autoLinkEnabled: this.draft.autoLink, retentionDays: Number(this.draft.retention) });
            this.toast('Setup saved', 'Suggestion mode is explicit and auto-link remains opt-in.', 'success');
            await refreshApex(this.wiredResult);
        } catch (error) { this.toast('Unable to save setup', this.errorMessage(error), 'error'); }
        finally { this.isLoading = false; }
    }

    async schedule() {
        this.isLoading = true;
        try { const name = await scheduleRetention(); this.toast('Retention scheduled', name, 'success'); }
        catch (error) { this.toast('Unable to schedule retention', this.errorMessage(error), 'error'); }
        finally { this.isLoading = false; }
    }

    toast(title, message, variant) { this.dispatchEvent(new ShowToastEvent({ title, message, variant })); }
    errorMessage(error) { return error?.body?.message || error?.message || 'Unexpected error'; }
}
