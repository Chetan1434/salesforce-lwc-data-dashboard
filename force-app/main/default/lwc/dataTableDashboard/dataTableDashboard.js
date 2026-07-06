import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAccounts from '@salesforce/apex/DataTableController.getAccounts';
import updateAccounts from '@salesforce/apex/DataTableController.updateAccounts';

const COLUMNS = [
    { label: 'Account Name', fieldName: 'Name', editable: true },
    { label: 'Industry', fieldName: 'Industry', editable: true },
    { label: 'Phone', fieldName: 'Phone', type: 'phone', editable: true },
    { label: 'Annual Revenue', fieldName: 'AnnualRevenue', type: 'currency', editable: true },
    { label: 'Rating', fieldName: 'Rating', editable: true }
];

const PAGE_SIZE = 10;
const SEARCH_DEBOUNCE_MS = 300;

export default class DataTableDashboard extends LightningElement {
    columns = COLUMNS;
    searchKey = '';
    pageNumber = 1;
    pageSize = PAGE_SIZE;
    draftValues = [];
    isLoading = false;

    wiredResult;      // keeps a handle on the full @wire response for refreshApex
    searchTimeout;

    @wire(getAccounts, {
        searchKey: '$searchKey',
        pageSize: '$pageSize',
        pageNumber: '$pageNumber'
    })
    wiredAccounts(result) {
        this.wiredResult = result;
        this.isLoading = false;
        if (result.error) {
            this.showToast('Error loading accounts', this.reduceError(result.error), 'error');
        }
    }

    get accounts() {
        return this.wiredResult?.data ? this.wiredResult.data.records : [];
    }

    get totalRecords() {
        return this.wiredResult?.data ? this.wiredResult.data.totalRecords : 0;
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.totalRecords / this.pageSize));
    }

    get hasRecords() {
        return this.accounts.length > 0;
    }

    get hasNoRecords() {
        return !!this.wiredResult?.data && this.accounts.length === 0;
    }

    get isFirstPage() {
        return this.pageNumber <= 1;
    }

    get isLastPage() {
        return this.pageNumber >= this.totalPages;
    }

    // ---- Real-time search (debounced so we don't fire a query per keystroke) ----
    handleSearch(event) {
        const value = event.target.value;
        window.clearTimeout(this.searchTimeout);
        this.isLoading = true;
        this.searchTimeout = window.setTimeout(() => {
            this.searchKey = value;
            this.pageNumber = 1; // reset to page 1 whenever the search term changes
        }, SEARCH_DEBOUNCE_MS);
    }

    // ---- Pagination ----
    handlePrevious() {
        if (!this.isFirstPage) {
            this.pageNumber -= 1;
        }
    }

    handleNext() {
        if (!this.isLastPage) {
            this.pageNumber += 1;
        }
    }

    // ---- Inline edit ----
    async handleSave(event) {
        const recordsToUpdate = event.detail.draftValues.map((draft) => ({ ...draft }));

        this.isLoading = true;
        try {
            await updateAccounts({ accounts: recordsToUpdate });
            this.showToast('Success', 'Record(s) updated successfully.', 'success');
            this.draftValues = [];
            await refreshApex(this.wiredResult); // re-pulls data without a full page reload
        } catch (error) {
            this.showToast('Error saving records', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.draftValues = [];
    }

    // ---- Helpers ----
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        return error?.body?.message || error?.message || 'Unknown error occurred';
    }
}
