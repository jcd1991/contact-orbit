import { LightningElement, api, wire } from 'lwc';
import getEmails from '@salesforce/apex/CEI_ContactEmailController.getEmails';
import createEmailRecord from '@salesforce/apex/CEI_ContactEmailController.createEmailRecord';
import { deleteRecord, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

const ROW_ACTIONS = [{ label: 'Delete', name: 'delete' }];
const COLUMNS = [
    { label: 'Email', fieldName: 'Email_Address__c', type: 'email', editable: true },
    { label: 'Purpose', fieldName: 'Purpose__c', type: 'text' },
    { label: 'Primary', fieldName: 'Is_Primary__c', type: 'boolean', editable: true },
    { label: 'Active', fieldName: 'Active__c', type: 'boolean', editable: true },
    { label: 'Last verified', fieldName: 'Last_Verified__c', type: 'date', editable: true },
    { type: 'action', typeAttributes: { rowActions: ROW_ACTIONS } }
];

export default class ContactEmailManager extends LightningElement {
    @api recordId;
    columns = COLUMNS;
    rows = [];
    draftValues = [];
    showForm = false;
    wiredResult;
    draft = this.newDraft();

    purposeOptions = [
        { label: 'General', value: 'General' },
        { label: 'Work', value: 'Work' },
        { label: 'Personal', value: 'Personal' },
        { label: 'Billing', value: 'Billing' },
        { label: 'Support', value: 'Support' },
        { label: 'Other', value: 'Other' }
    ];

    @wire(getEmails, { contactId: '$recordId' })
    wiredEmails(result) {
        this.wiredResult = result;
        if (result.data) {
            this.rows = result.data;
        } else if (result.error) {
            this.toast('Unable to load contact emails', this.errorMessage(result.error), 'error');
        }
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    newDraft() {
        return { emailAddress: '', purpose: 'General', isPrimary: false };
    }

    showCreateForm() {
        this.draft = this.newDraft();
        this.showForm = true;
    }

    hideCreateForm() {
        this.showForm = false;
    }

    handleInput(event) {
        const value = event.target.type === 'checkbox'
            ? event.target.checked
            : (event.detail?.value ?? event.target.value);
        this.draft = { ...this.draft, [event.target.name]: value };
    }

    async createEmail() {
        try {
            const emailAddress = this.draft.emailAddress;
            const fields = {
                Contact__c: this.recordId,
                Email_Address__c: emailAddress,
                Purpose__c: this.draft.purpose,
                Is_Primary__c: this.draft.isPrimary,
                Active__c: true
            };
            await createEmailRecord({
                contactId: this.recordId,
                emailAddress,
                purpose: fields.Purpose__c,
                isPrimary: fields.Is_Primary__c
            });
            this.showForm = false;
            this.toast('Email added', 'The contact email identity is ready to use.', 'success');
            await refreshApex(this.wiredResult);
        } catch (error) {
            this.toast('Unable to add email', this.errorMessage(error), 'error');
        }
    }

    async handleSave(event) {
        const updates = event.detail.draftValues.map((fields) => updateRecord({ fields }));
        try {
            await Promise.all(updates);
            this.draftValues = [];
            this.toast('Changes saved', 'Contact email identities were updated.', 'success');
            await refreshApex(this.wiredResult);
        } catch (error) {
            this.toast('Unable to save changes', this.errorMessage(error), 'error');
        }
    }

    async handleRowAction(event) {
        if (event.detail.action.name !== 'delete') return;
        try {
            await deleteRecord(event.detail.row.Id);
            this.toast('Email removed', 'The contact email identity was deleted.', 'success');
            await refreshApex(this.wiredResult);
        } catch (error) {
            this.toast('Unable to remove email', this.errorMessage(error), 'error');
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    errorMessage(error) {
        return error?.body?.message || error?.message || 'Unexpected error';
    }
}
