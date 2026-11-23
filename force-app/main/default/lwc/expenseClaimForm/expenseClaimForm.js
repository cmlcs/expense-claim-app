import {
    LightningElement,
    api
} from 'lwc';

import { ShowToastEvent } from
    'lightning/platformShowToastEvent';

import RECEIPT_UPLOAD_KEY_FIELD from
    '@salesforce/schema/ContentVersion.Expense_Receipt_Key_fileupload__c';

/*
 * Authenticated endpoints.
 */
import authenticatedGetConfiguration from
    '@salesforce/apex/ExpenseClaimController.getConfiguration';

import authenticatedApplyPolicy from
    '@salesforce/apex/ExpenseClaimController.applyPolicy';

import authenticatedCreateReceiptUploadKey from
    '@salesforce/apex/ExpenseClaimController.createReceiptUploadKey';

import authenticatedSubmitClaim from
    '@salesforce/apex/ExpenseClaimController.submitClaim';

/*
 * Guest endpoints.
 */
import guestGetConfiguration from
    '@salesforce/apex/ExpenseClaimGuestController.getConfiguration';

import guestApplyPolicy from
    '@salesforce/apex/ExpenseClaimGuestController.applyPolicy';

import guestCreateReceiptUploadKey from
    '@salesforce/apex/ExpenseClaimGuestController.createReceiptUploadKey';

import guestSubmitClaim from
    '@salesforce/apex/ExpenseClaimGuestController.submitClaim';

const CALCULATION_METHOD_AMOUNT =
    'Amount';

const CALCULATION_METHOD_DISTANCE =
    'Distance';

const ACCEPTED_RECEIPT_FORMATS = [
    '.pdf',
    '.png',
    '.jpg',
    '.jpeg',
    '.heic',
    '.heif'
];

export default class ExpenseClaimForm extends LightningElement {

    /*
     * When guestMode is false, the existing authenticated controller is used.
     * When guestMode is true, every server operation goes through the
     * dedicated guest controller and includes the verified access token.
     */
    @api guestMode = false;
    @api accessToken;

    configuration;

    expenseItems = [];

    claimDescription = '';

    isLoading = true;
    isSubmitting = false;

    loadError;
    submissionError;

    submittedClaim;

    nextItemKey = 1;

    acceptedReceiptFormats =
        ACCEPTED_RECEIPT_FORMATS;

    receiptUploadFieldName =
        RECEIPT_UPLOAD_KEY_FIELD.fieldApiName;

    connectedCallback() {
        this.loadConfiguration();
    }

    /*
     * ---------------------------------------------------------------------
     * Configuration
     * ---------------------------------------------------------------------
     */

    async loadConfiguration() {
        this.isLoading = true;
        this.loadError = undefined;

        try {
            this.configuration =
                await this.getConfigurationFromServer();

            const item =
                this.createExpenseItem();

            this.expenseItems = [
                item
            ];

            /*
            * Receipt-key preparation must not block the initial form render.
            *
            * The row can render immediately. The upload control becomes
            * available as soon as the server-generated key arrives.
            */
            this.prepareReceiptUploadKey(
                item.key
            );
        } catch (error) {
            this.configuration =
                undefined;

            this.expenseItems =
                [];

            this.loadError =
                this.reduceError(
                    error
                );
        } finally {
            this.isLoading = false;
        }
    }


    handleRetry() {
        this.loadConfiguration();
    }

    /*
     * ---------------------------------------------------------------------
     * Server adapters
     * ---------------------------------------------------------------------
     */

    async getConfigurationFromServer() {
        if (this.guestMode) {
            return guestGetConfiguration({
                accessToken:
                    this.accessToken
            });
        }

        return authenticatedGetConfiguration();
    }

    async applyPolicyOnServer(
        itemDto
    ) {
        if (this.guestMode) {
            return guestApplyPolicy({
                accessToken:
                    this.accessToken,
                itemDto
            });
        }

        return authenticatedApplyPolicy({
            itemDto
        });
    }

    async createReceiptUploadKeyOnServer() {
        if (this.guestMode) {
            return guestCreateReceiptUploadKey({
                accessToken:
                    this.accessToken
            });
        }

        return authenticatedCreateReceiptUploadKey();
    }

    async submitClaimToServer(
        request
    ) {
        if (this.guestMode) {
            return guestSubmitClaim({
                accessToken:
                    this.accessToken,
                request
            });
        }

        return authenticatedSubmitClaim({
            request
        });
    }

    /*
     * ---------------------------------------------------------------------
     * Configuration getters
     * ---------------------------------------------------------------------
     */

    get claimantName() {
        return (
            this.configuration
                ?.claimantName ||
            ''
        );
    }

    get claimantEmail() {
        return (
            this.configuration
                ?.claimantEmail ||
            ''
        );
    }

    get expenseTypeOptions() {
        return (
            this.configuration
                ?.expenseTypes ||
            []
        ).map(
            (expenseType) => ({
                label:
                    expenseType.label,

                value:
                    expenseType
                        .developerName
            })
        );
    }

    get hasConfiguration() {
        return Boolean(
            this.configuration
        );
    }

    get hasLoadError() {
        return Boolean(
            this.loadError
        );
    }

    get hasSubmittedClaim() {
        return Boolean(
            this.submittedClaim
        );
    }

    get futureDatesNotAllowed() {
        return (
            this.configuration &&
            this.configuration
                .allowFutureExpenseDates ===
                false
        );
    }

    get maximumExpenseAgeMessage() {
        const maximumAge =
            this.configuration
                ?.maximumExpenseAgeDays;

        if (
            maximumAge === null ||
            maximumAge === undefined
        ) {
            return '';
        }

        return (
            `Expenses can be up to ${maximumAge} days old.`
        );
    }

    /*
     * ---------------------------------------------------------------------
     * Claim totals and state
     * ---------------------------------------------------------------------
     */

    get claimTotal() {
        return this.expenseItems.reduce(
            (
                total,
                item
            ) =>
                total +
                this.itemAmount(
                    item
                ),
            0
        );
    }

    get hasPolicyErrors() {
        return this.expenseItems.some(
            (item) =>
                Boolean(
                    item.policyError
                )
        );
    }

    get hasPendingPolicyRequests() {
        return this.expenseItems.some(
            (item) =>
                Boolean(
                    item.isPolicyLoading
                )
        );
    }

    get hasMissingRequiredReceipts() {
        return this.expenseItems.some(
            (item) =>
                item.receiptRequired &&
                !item.receiptUploaded
        );
    }

    get submitDisabled() {
        return (
            this.isSubmitting ||
            this.isLoading ||
            this.hasPendingPolicyRequests ||
            this.hasPolicyErrors ||
            this.hasMissingRequiredReceipts ||
            this.expenseItems.length ===
                0
        );
    }

    /*
     * ---------------------------------------------------------------------
     * Expense Item lifecycle
     * ---------------------------------------------------------------------
     */

    createExpenseItem() {
        const item = {
            key:
                this.nextItemKey,

            expenseDate:
                null,

            description:
                '',

            expenseTypeCode:
                null,

            expenseTypeLabel:
                '',

            calculationMethod:
                null,

            claimedAmount:
                null,

            distance:
                null,

            calculatedAmount:
                null,

            businessPurpose:
                '',

            unitRate:
                null,

            distanceUnit:
                this.configuration
                    ?.defaultDistanceUnit ||
                '',

            maximumAmount:
                null,

            typeDescriptionRequired:
                false,

            receiptRequired:
                false,

            receiptUploadKey:
                null,

            receiptUploaded:
                false,

            receiptNames:
                [],

            policyError:
                null,

            isPolicyLoading:
                false,

            policyRequestSequence:
                0
        };

        this.nextItemKey += 1;

        return this.decorateItem(
            item
        );
    }

    async handleAddItem() {
        const item =
            this.createExpenseItem();

        this.expenseItems = [
            ...this.expenseItems,
            item
        ];

        this.prepareReceiptUploadKey(
            item.key
        );
    }

    handleDeleteItem(event) {
        const key =
            Number(
                event.currentTarget
                    .dataset.key
            );

        if (
            this.expenseItems.length <=
            1
        ) {
            return;
        }

        this.expenseItems =
            this.expenseItems.filter(
                (item) =>
                    item.key !== key
            );
    }

    /*
     * ---------------------------------------------------------------------
     * Item input
     * ---------------------------------------------------------------------
     */

    handleItemInputChange(event) {
        const key =
            Number(
                event.target.dataset.key
            );

        const field =
            event.target.dataset.field;

        let value =
            event.detail?.value ??
            event.target.value;

        if (
            field ===
                'claimedAmount' ||
            field ===
                'distance'
        ) {
            value =
                this.toNumberOrNull(
                    value
                );
        }

        this.updateItem(
            key,
            (item) => ({
                ...item,
                [field]:
                    value
            })
        );

        /*
         * Distance reimbursement is calculated by Apex.
         *
         * Other ordinary input changes do not need a new policy request.
         */
        if (
            field === 'distance'
        ) {
            const item =
                this.findItem(
                    key
                );

            if (
                item
                    ?.calculationMethod ===
                CALCULATION_METHOD_DISTANCE
            ) {
                this.refreshPolicy(
                    key
                );
            }
        }
    }

    handleExpenseTypeChange(event) {
        const key =
            Number(
                event.target.dataset.key
            );

        const expenseTypeCode =
            event.detail.value;

        const expenseType =
            this.findExpenseType(
                expenseTypeCode
            );

        this.updateItem(
            key,
            (item) => ({
                ...item,

                expenseTypeCode,

                expenseTypeLabel:
                    expenseType?.label ||
                    '',

                calculationMethod:
                    expenseType
                        ?.calculationMethod ||
                    null,

                unitRate:
                    expenseType?.rate ??
                    null,

                distanceUnit:
                    expenseType
                        ?.distanceUnit ||
                    this.configuration
                        ?.defaultDistanceUnit ||
                    '',

                maximumAmount:
                    expenseType
                        ?.maximumAmount ??
                    null,

                receiptRequired:
                    Boolean(
                        expenseType
                            ?.receiptRequired
                    ),

                typeDescriptionRequired:
                    Boolean(
                        expenseType
                            ?.descriptionRequired
                    ),

                claimedAmount:
                    expenseType
                        ?.calculationMethod ===
                    CALCULATION_METHOD_DISTANCE
                        ? null
                        : item
                            .claimedAmount,

                distance:
                    expenseType
                        ?.calculationMethod ===
                    CALCULATION_METHOD_AMOUNT
                        ? null
                        : item.distance,

                calculatedAmount:
                    null,

                policyError:
                    null
            })
        );

        this.refreshPolicy(
            key
        );
    }

    /*
     * ---------------------------------------------------------------------
     * Policy
     * ---------------------------------------------------------------------
     */

    async refreshPolicy(
        key
    ) {
        const item =
            this.findItem(
                key
            );

        if (
            !item ||
            !item.expenseTypeCode
        ) {
            return;
        }

        const requestSequence =
            item.policyRequestSequence +
            1;

        this.updateItem(
            key,
            (currentItem) => ({
                ...currentItem,

                policyRequestSequence:
                    requestSequence,

                isPolicyLoading:
                    true,

                policyError:
                    null
            })
        );

        try {
            const serverItem =
                await this.applyPolicyOnServer(
                    this.toServerItem(
                        this.findItem(
                            key
                        )
                    )
                );

            const currentItem =
                this.findItem(
                    key
                );

            /*
             * A slower earlier request must not overwrite a newer value.
             */
            if (
                !currentItem ||
                currentItem
                    .policyRequestSequence !==
                    requestSequence
            ) {
                return;
            }

            this.updateItem(
                key,
                (existingItem) =>
                    this.applyPolicyResponse(
                        existingItem,
                        serverItem
                    )
            );
        } catch (error) {
            const currentItem =
                this.findItem(
                    key
                );

            if (
                !currentItem ||
                currentItem
                    .policyRequestSequence !==
                    requestSequence
            ) {
                return;
            }

            this.updateItem(
                key,
                (existingItem) => ({
                    ...existingItem,

                    isPolicyLoading:
                        false,

                    policyError:
                        this.reduceError(
                            error
                        )
                })
            );
        }
    }

    applyPolicyResponse(
        existingItem,
        serverItem
    ) {
        const response =
            serverItem || {};

        const calculationMethod =
            response
                .calculationMethod ||
            existingItem
                .calculationMethod;

        let calculatedAmount =
            existingItem
                .calculatedAmount;

        if (
            calculationMethod ===
            CALCULATION_METHOD_DISTANCE
        ) {
            calculatedAmount =
                this.toNumberOrNull(
                    response
                        .calculatedAmount ??
                    response
                        .claimedAmount
                );
        } else {
            calculatedAmount =
                null;
        }

        return {
            ...existingItem,

            expenseTypeLabel:
                response
                    .expenseTypeLabel ||
                existingItem
                    .expenseTypeLabel,

            calculationMethod,

            unitRate:
                response.unitRate ??
                existingItem.unitRate,

            distanceUnit:
                response.distanceUnit ??
                existingItem
                    .distanceUnit,

            maximumAmount:
                response
                    .maximumAmount ??
                existingItem
                    .maximumAmount,

            receiptRequired:
                response
                    .receiptRequired ===
                    undefined
                    ? existingItem
                        .receiptRequired
                    : Boolean(
                        response
                            .receiptRequired
                    ),

            typeDescriptionRequired:
                response
                    .descriptionRequired ===
                    undefined
                    ? existingItem
                        .typeDescriptionRequired
                    : Boolean(
                        response
                            .descriptionRequired
                    ),

            calculatedAmount,

            policyError:
                null,

            isPolicyLoading:
                false
        };
    }

    /*
     * ---------------------------------------------------------------------
     * Receipt upload
     * ---------------------------------------------------------------------
     */

    async prepareReceiptUploadKey(
        key
    ) {
        const item =
            this.findItem(
                key
            );

        if (
            !item ||
            item.receiptUploadKey
        ) {
            return;
        }

        try {
            const receiptUploadKey =
                await this
                    .createReceiptUploadKeyOnServer();

            this.updateItem(
                key,
                (currentItem) => ({
                    ...currentItem,
                    receiptUploadKey
                })
            );
        } catch (error) {
            this.updateItem(
                key,
                (currentItem) => ({
                    ...currentItem,

                    policyError:
                        this.reduceError(
                            error
                        )
                })
            );
        }
    }

    handleReceiptUploadFinished(
        event
    ) {
        const key =
            Number(
                event.target.dataset.key
            );

        const uploadedFiles =
            event.detail?.files ||
            [];

        const receiptNames =
            uploadedFiles
                .map(
                    (file) =>
                        file.name
                )
                .filter(
                    Boolean
                );

        this.updateItem(
            key,
            (item) => ({
                ...item,

                receiptUploaded:
                    receiptNames.length >
                    0,

                receiptNames
            })
        );
    }

    /*
     * ---------------------------------------------------------------------
     * Item decoration
     * ---------------------------------------------------------------------
     */

    decorateItem(item) {
        const calculationMethod =
            item.calculationMethod;

        const receiptNames =
            Array.isArray(
                item.receiptNames
            )
                ? item.receiptNames
                : [];

        const descriptionRequired =
            Boolean(
                this.configuration
                    ?.requireDescription
            ) ||
            Boolean(
                item
                    .typeDescriptionRequired
            );

        return {
            ...item,

            receiptNames,

            receiptSummary:
                receiptNames.join(
                    ', '
                ),

            hasReceipts:
                receiptNames.length >
                0,

            descriptionRequired,

            isAmount:
                calculationMethod ===
                CALCULATION_METHOD_AMOUNT,

            isDistance:
                calculationMethod ===
                CALCULATION_METHOD_DISTANCE,

            /*
             * The row always receives an upload key. The uploader itself is
             * shown once an Expense Type has been selected.
             */
            showReceiptUpload:
                Boolean(
                    item.expenseTypeCode &&
                    item.receiptUploadKey
                ),
            
            receiptUploadDisabled:
                false,
        };
    }

    itemAmount(item) {
        if (
            item.calculationMethod ===
            CALCULATION_METHOD_DISTANCE
        ) {
            return (
                Number(
                    item
                        .calculatedAmount
                ) ||
                0
            );
        }

        return (
            Number(
                item.claimedAmount
            ) ||
            0
        );
    }

    /*
     * ---------------------------------------------------------------------
     * Submission
     * ---------------------------------------------------------------------
     */

    async handleSubmit() {
        this.submissionError =
            undefined;

        if (
            !this.validateForm()
        ) {
            return;
        }

        if (
            this.hasPendingPolicyRequests
        ) {
            this.submissionError =
                'Please wait for expense calculations to finish.';

            return;
        }

        if (
            this.hasPolicyErrors
        ) {
            this.submissionError =
                'Resolve the expense item errors before submitting the claim.';

            return;
        }

        if (
            this.hasMissingRequiredReceipts
        ) {
            this.submissionError =
                'Upload all required receipts before submitting the claim.';

            return;
        }

        this.isSubmitting =
            true;

        try {
            /*
             * Only claimant-controlled values are included in the request.
             *
             * Claimant identity and all policy-derived values are rebuilt
             * server-side.
             */
            const request = {
                description:
                    this.normalizeText(
                        this.claimDescription
                    ),

                items:
                    this.expenseItems.map(
                        (item) =>
                            this.toServerItem(
                                item
                            )
                    )
            };

            this.submittedClaim =
                await this.submitClaimToServer(
                    request
                );

            this.dispatchEvent(
                new ShowToastEvent({
                    title:
                        'Expense claim submitted',

                    message:
                        'Your expense claim has been submitted successfully.',

                    variant:
                        'success'
                })
            );
        } catch (error) {
            this.submissionError =
                this.reduceError(
                    error
                );
        } finally {
            this.isSubmitting =
                false;
        }
    }

    /*
     * A guest access token is single-use.
     *
     * Starting a second guest claim therefore returns to the verification
     * wrapper instead of attempting to reuse the token.
     */
    handleNewClaim() {
        if (this.guestMode) {
            this.dispatchEvent(
                new CustomEvent(
                    'reauthenticate'
                )
            );

            return;
        }

        this.resetForm();
    }

    async resetForm() {
        this.claimDescription =
            '';

        this.submissionError =
            undefined;

        this.submittedClaim =
            undefined;

        const item =
            this.createExpenseItem();

        this.expenseItems = [
            item
        ];

        this.prepareReceiptUploadKey(
            item.key
        );
    }

    /*
     * ---------------------------------------------------------------------
     * Claim input
     * ---------------------------------------------------------------------
     */

    handleClaimDescriptionChange(
        event
    ) {
        this.claimDescription =
            event.target.value;
    }

    /*
     * ---------------------------------------------------------------------
     * Validation
     * ---------------------------------------------------------------------
     */

    validateForm() {
        const inputs = [
            ...this.template
                .querySelectorAll(
                    'lightning-input, lightning-combobox, lightning-textarea'
                )
        ];

        return inputs.reduce(
            (
                isValid,
                input
            ) => {
                if (
                    typeof input
                        .reportValidity ===
                    'function'
                ) {
                    input.reportValidity();
                }

                const inputValid =
                    typeof input
                        .checkValidity ===
                    'function'
                        ? input
                            .checkValidity()
                        : true;

                return (
                    isValid &&
                    inputValid
                );
            },
            true
        );
    }

    /*
     * ---------------------------------------------------------------------
     * Request mapping
     * ---------------------------------------------------------------------
     */

    toServerItem(item) {
        const isDistance =
            item.calculationMethod ===
            CALCULATION_METHOD_DISTANCE;

        return {
            expenseDate:
                item.expenseDate ||
                null,

            description:
                this.normalizeText(
                    item.description
                ),

            expenseTypeCode:
                item.expenseTypeCode ||
                null,

            /*
             * A distance reimbursement amount is always calculated by Apex.
             */
            claimedAmount:
                isDistance
                    ? null
                    : this.toNumberOrNull(
                        item
                            .claimedAmount
                    ),

            distance:
                isDistance
                    ? this.toNumberOrNull(
                        item.distance
                    )
                    : null,

            businessPurpose:
                this.normalizeText(
                    item
                        .businessPurpose
                ),

            receiptUploadKey:
                item
                    .receiptUploadKey ||
                null
        };
    }

    /*
     * ---------------------------------------------------------------------
     * Collection helpers
     * ---------------------------------------------------------------------
     */

    findItem(key) {
        return this.expenseItems.find(
            (item) =>
                item.key === key
        );
    }

    findExpenseType(
        developerName
    ) {
        return (
            this.configuration
                ?.expenseTypes ||
            []
        ).find(
            (expenseType) =>
                expenseType
                    .developerName ===
                developerName
        );
    }

    updateItem(
        key,
        updater
    ) {
        this.expenseItems =
            this.expenseItems.map(
                (item) => {
                    if (
                        item.key !== key
                    ) {
                        return item;
                    }

                    return this.decorateItem(
                        updater(
                            item
                        )
                    );
                }
            );
    }

    /*
     * ---------------------------------------------------------------------
     * Value helpers
     * ---------------------------------------------------------------------
     */

    normalizeText(value) {
        if (
            value === null ||
            value === undefined
        ) {
            return null;
        }

        const normalized =
            String(
                value
            ).trim();

        return normalized ||
            null;
    }

    toNumberOrNull(value) {
        if (
            value === null ||
            value === undefined ||
            value === ''
        ) {
            return null;
        }

        const numericValue =
            Number(
                value
            );

        return Number.isNaN(
            numericValue
        )
            ? null
            : numericValue;
    }

    /*
     * ---------------------------------------------------------------------
     * Error handling
     * ---------------------------------------------------------------------
     */

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
                .filter(
                    Boolean
                )
                .join(
                    ', '
                );
        }

        if (
            error?.body?.message
        ) {
            return error.body.message;
        }

        if (
            error?.message
        ) {
            return error.message;
        }

        return 'An unexpected error occurred.';
    }
}