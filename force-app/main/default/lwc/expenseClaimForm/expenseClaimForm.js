import { LightningElement } from 'lwc';

import getConfiguration from '@salesforce/apex/ExpenseClaimController.getConfiguration';
import applyPolicy from '@salesforce/apex/ExpenseClaimController.applyPolicy';
import submitClaim from '@salesforce/apex/ExpenseClaimController.submitClaim';
import createReceiptUploadKey from '@salesforce/apex/ExpenseClaimController.createReceiptUploadKey';

import RECEIPT_KEY_FIELD from '@salesforce/schema/ContentVersion.Expense_Receipt_Key_fileupload__c';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const METHOD_AMOUNT = 'Amount';
const METHOD_DISTANCE = 'Distance';

export default class ExpenseClaimForm extends LightningElement {
    configuration;
    claimDescription = '';
    items = [];

    isLoading = true;
    isSubmitting = false;

    loadError;
    submissionResult;

    nextItemNumber = 1;
    policyRequestSequence = 0;

    connectedCallback() {
        this.loadConfiguration();
    }

    async loadConfiguration() {
        this.isLoading = true;
        this.loadError = undefined;

        try {
            this.configuration =
                await getConfiguration();

            const item =
                this.createEmptyItem();

            this.items =
                this.normalizeItems([
                    item
                ]);

            await this.prepareReceiptUploadKey(
                item.clientId
            );
        } catch (error) {
            this.loadError =
                this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    get claimantName() {
        return (
            this.configuration
                ?.claimantName || ''
        );
    }

    get claimantEmail() {
        return (
            this.configuration
                ?.claimantEmail || ''
        );
    }

    get expenseTypeOptions() {
        return (
            this.configuration
                ?.expenseTypes || []
        ).map((expenseType) => ({
            label: expenseType.label,
            value:
                expenseType.developerName
        }));
    }

    get receiptKeyFieldApiName() {
        return RECEIPT_KEY_FIELD.fieldApiName;
    }

    get acceptedReceiptFormats() {
        return [
            '.pdf',
            '.png',
            '.jpg',
            '.jpeg',
            '.heic',
            '.heif'
        ];
    }

    get claimTotal() {
        return this.items.reduce(
            (total, item) =>
                total +
                this.toFiniteNumber(
                    item.claimedAmount
                ),
            0
        );
    }

    get datePolicyMessage() {
        const messages = [];

        if (
            this.configuration &&
            !this.configuration
                .allowFutureExpenseDates
        ) {
            messages.push(
                'Future expense dates are not allowed.'
            );
        }

        const maximumAge =
            this.configuration
                ?.maximumExpenseAgeDays;

        if (
            maximumAge !== null &&
            maximumAge !== undefined
        ) {
            messages.push(
                `Expenses can be up to ${maximumAge} days old.`
            );
        }

        return messages.join(' ');
    }

    get hasDatePolicyMessage() {
        return Boolean(
            this.datePolicyMessage
        );
    }

    get hasPolicyCalculation() {
        return this.items.some(
            (item) =>
                item.isCalculating
        );
    }

    get hasPolicyErrors() {
        return this.items.some(
            (item) =>
                Boolean(
                    item.policyError
                )
        );
    }

    get hasMissingRequiredReceipts() {
        return this.items.some(
            (item) =>
                item.receiptRequired &&
                !item.hasReceipts
        );
    }

    get isSubmitDisabled() {
        return (
            this.isLoading ||
            this.isSubmitting ||
            this.hasPolicyCalculation ||
            this.hasPolicyErrors ||
            this.hasMissingRequiredReceipts ||
            this.items.length === 0
        );
    }

    get successReference() {
        return (
            this.submissionResult
                ?.claimNumber ||
            this.submissionResult
                ?.claimId ||
            ''
        );
    }

    createEmptyItem() {
        return this.decorateItem({
            clientId:
                `item-${this.nextItemNumber++}`,

            expenseDate: null,
            description: '',
            businessPurpose: '',

            expenseTypeCode: '',
            expenseTypeLabel: null,

            calculationMethod: null,

            claimedAmount: null,

            distance: null,
            distanceUnit: null,
            unitRate: null,

            receiptRequired: false,

            receiptUploadKey: null,
            receiptNames: [],
            isPreparingReceiptUpload: true,
            receiptUploadError: null,

            isCalculating: false,
            policyError: null,
            policyRequestId: null
        });
    }

    decorateItem(item) {
        const expenseType =
            this.findExpenseType(
                item.expenseTypeCode
            );

        const calculationMethod =
            expenseType
                ?.calculationMethod ||
            item.calculationMethod ||
            null;

        const maximumAmount =
            expenseType
                ?.maximumAmount ??
            null;

        const unitRate =
            item.unitRate ??
            expenseType?.rate ??
            null;

        const distanceUnit =
            item.distanceUnit ||
            expenseType
                ?.distanceUnit ||
            this.configuration
                ?.defaultDistanceUnit ||
            null;

        const receiptNames =
            item.receiptNames || [];

        return {
            ...item,

            calculationMethod,

            isAmount:
                calculationMethod ===
                METHOD_AMOUNT,

            isDistance:
                calculationMethod ===
                METHOD_DISTANCE,

            hasExpenseType:
                Boolean(
                    expenseType
                ),

            descriptionRequired:
                Boolean(
                    this.configuration
                        ?.requireDescription ||
                    expenseType
                        ?.descriptionRequired
                ),

            receiptRequired:
                item.receiptRequired ??
                expenseType
                    ?.receiptRequired ??
                false,

            receiptNames,

            hasReceipts:
                receiptNames.length > 0,

            receiptSummary:
                receiptNames.join(', '),

            isReceiptUploadDisabled:
                item.isPreparingReceiptUpload ||
                !item.receiptUploadKey ||
                Boolean(
                    item.receiptUploadError
                ),

            maximumAmount,

            hasMaximumAmount:
                maximumAmount !==
                null,

            unitRate,

            hasUnitRate:
                unitRate !== null,

            distanceUnit,

            lineTotal:
                this.toFiniteNumber(
                    item.claimedAmount
                )
        };
    }

    normalizeItems(items) {
        const canDelete =
            items.length > 1;

        return items.map(
            (item, index) => ({
                ...this.decorateItem(
                    item
                ),
                sequence:
                    index + 1,
                canDelete
            })
        );
    }

    findExpenseType(
        developerName
    ) {
        if (!developerName) {
            return undefined;
        }

        return (
            this.configuration
                ?.expenseTypes || []
        ).find(
            (expenseType) =>
                expenseType
                    .developerName ===
                developerName
        );
    }

    findItem(clientId) {
        return this.items.find(
            (item) =>
                item.clientId ===
                clientId
        );
    }

    updateItem(
        clientId,
        changes
    ) {
        this.items =
            this.normalizeItems(
                this.items.map(
                    (item) => {
                        if (
                            item.clientId ===
                            clientId
                        ) {
                            return {
                                ...item,
                                ...changes
                            };
                        }

                        return item;
                    }
                )
            );
    }

    handleClaimDescriptionChange(
        event
    ) {
        this.claimDescription =
            event.target.value;
    }

    async handleExpenseTypeChange(
        event
    ) {
        const clientId =
            event.target.dataset.id;

        const expenseTypeCode =
            event.detail.value;

        const expenseType =
            this.findExpenseType(
                expenseTypeCode
            );

        const currentItem =
            this.findItem(
                clientId
            );

        const isDistance =
            expenseType
                ?.calculationMethod ===
            METHOD_DISTANCE;

        this.updateItem(
            clientId,
            {
                expenseTypeCode,

                calculationMethod:
                    expenseType
                        ?.calculationMethod ||
                    null,

                claimedAmount: null,

                distance:
                    isDistance
                        ? currentItem
                              ?.distance
                        : null,

                distanceUnit:
                    isDistance
                        ? expenseType
                              ?.distanceUnit ||
                          this.configuration
                              ?.defaultDistanceUnit ||
                          null
                        : null,

                unitRate:
                    isDistance
                        ? expenseType
                              ?.rate ??
                          null
                        : null,

                receiptRequired:
                    expenseType
                        ?.receiptRequired ||
                    false,

                policyError: null
            }
        );

        await this.refreshPolicy(
            clientId
        );
    }

    async handleItemInputChange(
        event
    ) {
        const clientId =
            event.target.dataset.id;

        const field =
            event.target.dataset.field;

        let value =
            event.target.value;

        if (
            field ===
                'claimedAmount' ||
            field === 'distance'
        ) {
            value =
                this.toNumberOrNull(
                    value
                );
        }

        this.updateItem(
            clientId,
            {
                [field]: value,
                policyError: null
            }
        );

        const item =
            this.findItem(
                clientId
            );

        if (
            field ===
                'distance' &&
            item?.isDistance &&
            item.expenseTypeCode
        ) {
            await this.refreshPolicy(
                clientId
            );
        }
    }

    async handleAddItem() {
        const item =
            this.createEmptyItem();

        this.items =
            this.normalizeItems([
                ...this.items,
                item
            ]);

        await this.prepareReceiptUploadKey(
            item.clientId
        );
    }

    handleDeleteItem(event) {
        const clientId =
            event.target.dataset.id;

        this.items =
            this.normalizeItems(
                this.items.filter(
                    (item) =>
                        item.clientId !==
                        clientId
                )
            );
    }

    async prepareReceiptUploadKey(
        clientId
    ) {
        this.updateItem(
            clientId,
            {
                isPreparingReceiptUpload:
                    true,
                receiptUploadError: null
            }
        );

        try {
            const receiptUploadKey =
                await createReceiptUploadKey();

            this.updateItem(
                clientId,
                {
                    receiptUploadKey,
                    isPreparingReceiptUpload:
                        false,
                    receiptUploadError:
                        null
                }
            );
        } catch (error) {
            this.updateItem(
                clientId,
                {
                    receiptUploadKey:
                        null,
                    isPreparingReceiptUpload:
                        false,
                    receiptUploadError:
                        this.reduceError(
                            error
                        )
                }
            );
        }
    }

    handleReceiptUploadFinished(
        event
    ) {
        const clientId =
            event.target.dataset.id;

        const item =
            this.findItem(
                clientId
            );

        if (!item) {
            return;
        }

        const uploadedNames =
            event.detail.files.map(
                (file) =>
                    file.name
            );

        this.updateItem(
            clientId,
            {
                receiptNames: [
                    ...(item.receiptNames ||
                        []),
                    ...uploadedNames
                ],
                receiptUploadError:
                    null
            }
        );
    }

    async handleRetryReceiptUpload(
        event
    ) {
        await this.prepareReceiptUploadKey(
            event.target.dataset.id
        );
    }

    async refreshPolicy(
        clientId
    ) {
        const item =
            this.findItem(
                clientId
            );

        if (
            !item ||
            !item.expenseTypeCode
        ) {
            return;
        }

        const policyRequestId =
            ++this.policyRequestSequence;

        this.updateItem(
            clientId,
            {
                isCalculating: true,
                policyRequestId,
                policyError: null
            }
        );

        try {
            const result =
                await applyPolicy({
                    itemDto:
                        this.toServerItem(
                            this.findItem(
                                clientId
                            )
                        )
                });

            const latestItem =
                this.findItem(
                    clientId
                );

            if (
                !latestItem ||
                latestItem
                    .policyRequestId !==
                    policyRequestId
            ) {
                return;
            }

            this.updateItem(
                clientId,
                {
                    ...result,

                    clientId,
                    policyRequestId,

                    receiptUploadKey:
                        latestItem
                            .receiptUploadKey,

                    receiptNames:
                        latestItem
                            .receiptNames,

                    receiptUploadError:
                        latestItem
                            .receiptUploadError,

                    isPreparingReceiptUpload:
                        latestItem
                            .isPreparingReceiptUpload,

                    isCalculating:
                        false,

                    policyError: null
                }
            );
        } catch (error) {
            const latestItem =
                this.findItem(
                    clientId
                );

            if (
                !latestItem ||
                latestItem
                    .policyRequestId !==
                    policyRequestId
            ) {
                return;
            }

            this.updateItem(
                clientId,
                {
                    isCalculating:
                        false,
                    policyError:
                        this.reduceError(
                            error
                        )
                }
            );
        }
    }

    async handleSubmit() {
        if (
            this.hasPolicyCalculation
        ) {
            this.showToast(
                'Please wait',
                'An expense amount is still being calculated.',
                'warning'
            );
            return;
        }

        if (
            !this.validateInputs()
        ) {
            this.showToast(
                'Check the form',
                'Complete the required fields before submitting.',
                'error'
            );
            return;
        }

        if (
            this.hasPolicyErrors
        ) {
            this.showToast(
                'Check the expenses',
                'Resolve the expense policy errors before submitting.',
                'error'
            );
            return;
        }

        if (
            this.hasMissingRequiredReceipts
        ) {
            this.showToast(
                'Receipt required',
                'Upload the required receipts before submitting.',
                'error'
            );
            return;
        }

        this.isSubmitting = true;

        try {
            const request = {
                description:
                    this.claimDescription
                        ?.trim() ||
                    null,

                items:
                    this.items.map(
                        (item) =>
                            this.toServerItem(
                                item
                            )
                    )
            };

            this.submissionResult =
                await submitClaim({
                    request
                });

            this.showToast(
                'Expense claim submitted',
                `Claim ${this.successReference} was submitted successfully.`,
                'success'
            );
        } catch (error) {
            this.showToast(
                'Unable to submit claim',
                this.reduceError(
                    error
                ),
                'error'
            );
        } finally {
            this.isSubmitting =
                false;
        }
    }

    async handleNewClaim() {
        this.submissionResult =
            undefined;

        this.claimDescription =
            '';

        const item =
            this.createEmptyItem();

        this.items =
            this.normalizeItems([
                item
            ]);

        await this.prepareReceiptUploadKey(
            item.clientId
        );
    }

    handleRetry() {
        this.loadConfiguration();
    }

    validateInputs() {
        const inputs =
            this.template
                .querySelectorAll(
                    'lightning-input, lightning-combobox, lightning-textarea'
                );

        let valid = true;

        inputs.forEach(
            (input) => {
                input.reportValidity();

                valid =
                    input.checkValidity() &&
                    valid;
            }
        );

        return valid;
    }

    toServerItem(item) {
        return {
            expenseDate:
                item.expenseDate ||
                null,

            description:
                item.description
                    ?.trim() ||
                null,

            expenseTypeCode:
                item.expenseTypeCode ||
                null,

            claimedAmount:
                item.claimedAmount ??
                null,

            distance:
                item.distance ??
                null,

            businessPurpose:
                item.businessPurpose
                    ?.trim() ||
                null,

            receiptUploadKey:
                item.receiptUploadKey ||
                null
        };
    }

    toNumberOrNull(value) {
        if (
            value === null ||
            value === undefined ||
            value === ''
        ) {
            return null;
        }

        const parsed =
            Number(value);

        return Number.isNaN(
            parsed
        )
            ? null
            : parsed;
    }

    toFiniteNumber(value) {
        const numberValue =
            Number(value);

        return Number.isFinite(
            numberValue
        )
            ? numberValue
            : 0;
    }

    reduceError(error) {
        if (
            Array.isArray(
                error?.body
            )
        ) {
            return error.body
                .map(
                    (entry) =>
                        entry.message
                )
                .join(', ');
        }

        if (
            error?.body?.message
        ) {
            return error.body.message;
        }

        if (error?.message) {
            return error.message;
        }

        return 'An unexpected error occurred.';
    }

    showToast(
        title,
        message,
        variant
    ) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}