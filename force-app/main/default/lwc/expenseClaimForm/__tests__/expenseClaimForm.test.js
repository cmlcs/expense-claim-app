import { createElement } from '@lwc/engine-dom';
import ExpenseClaimForm from 'c/expenseClaimForm';

import getConfiguration from '@salesforce/apex/ExpenseClaimController.getConfiguration';
import applyPolicy from '@salesforce/apex/ExpenseClaimController.applyPolicy';
import submitClaim from '@salesforce/apex/ExpenseClaimController.submitClaim';
import createReceiptUploadKey from '@salesforce/apex/ExpenseClaimController.createReceiptUploadKey';

jest.mock(
    '@salesforce/apex/ExpenseClaimController.getConfiguration',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/ExpenseClaimController.applyPolicy',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/ExpenseClaimController.submitClaim',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/ExpenseClaimController.createReceiptUploadKey',
    () => ({
        default: jest.fn()
    }),
    { virtual: true }
);

jest.mock(
    '@salesforce/schema/ContentVersion.Expense_Receipt_Key_fileupload__c',
    () => ({
        default: {
            fieldApiName:
                'Expense_Receipt_Key_fileupload__c'
        }
    }),
    { virtual: true }
);

const RECEIPT_UPLOAD_KEY =
    '0123456789abcdef'.repeat(4);

const SECOND_RECEIPT_UPLOAD_KEY =
    'fedcba9876543210'.repeat(4);

const CONFIGURATION = {
    claimantName: 'Test Claimant',
    claimantEmail: 'claimant@example.com',
    defaultDistanceUnit: 'Kilometres',
    allowFutureExpenseDates: false,
    maximumExpenseAgeDays: 90,
    requireDescription: false,
    allowClaimantAdjustmentAfterSubmission: false,
    expenseTypes: [
        {
            developerName: 'Meals',
            label: 'Meals',
            calculationMethod: 'Amount',
            rate: null,
            distanceUnit: null,
            receiptRequired: false,
            maximumAmount: 100,
            descriptionRequired: false,
            sortOrder: 20
        },
        {
            developerName: 'Mileage',
            label: 'Mileage',
            calculationMethod: 'Distance',
            rate: 0.28,
            distanceUnit: 'Kilometres',
            receiptRequired: false,
            maximumAmount: null,
            descriptionRequired: true,
            sortOrder: 10
        }
    ]
};

const SUBMISSION_RESULT = {
    claimId: 'a00000000000001AAA',
    claimNumber: 'EC-000001',
    status: 'Submitted',
    submittedAt: '2026-11-18T12:00:00.000Z',
    totalAmount: 37.5
};

function cloneConfiguration() {
    return JSON.parse(
        JSON.stringify(CONFIGURATION)
    );
}

function configurationWithRequiredMealReceipt() {
    const configuration =
        cloneConfiguration();

    configuration.expenseTypes[0]
        .receiptRequired = true;

    return configuration;
}

async function flushPromises() {
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
}

function createComponent() {
    const element = createElement(
        'c-expense-claim-form',
        {
            is: ExpenseClaimForm
        }
    );

    document.body.appendChild(element);

    return element;
}

function findButton(
    element,
    label
) {
    return [
        ...element.shadowRoot.querySelectorAll(
            'lightning-button'
        )
    ].find(
        (button) =>
            button.label === label
    );
}

function findInput(
    element,
    fieldName
) {
    return element.shadowRoot.querySelector(
        `lightning-input[data-field="${fieldName}"]`
    );
}

function changeInput(
    input,
    value
) {
    input.value = value;

    input.dispatchEvent(
        new CustomEvent('change')
    );
}

function selectExpenseType(
    element,
    expenseTypeCode
) {
    const combobox =
        element.shadowRoot.querySelector(
            'lightning-combobox'
        );

    combobox.dispatchEvent(
        new CustomEvent(
            'change',
            {
                detail: {
                    value:
                        expenseTypeCode
                }
            }
        )
    );
}

function uploadReceipt(
    uploader,
    fileNames
) {
    uploader.dispatchEvent(
        new CustomEvent(
            'uploadfinished',
            {
                detail: {
                    files:
                        fileNames.map(
                            (name) => ({
                                name
                            })
                        )
                }
            }
        )
    );
}

function makeFormValid(
    element
) {
    const controls =
        element.shadowRoot.querySelectorAll(
            'lightning-input, lightning-combobox, lightning-textarea'
        );

    controls.forEach(
        (control) => {
            Object.defineProperty(
                control,
                'reportValidity',
                {
                    configurable: true,
                    value: jest.fn()
                }
            );

            Object.defineProperty(
                control,
                'checkValidity',
                {
                    configurable: true,
                    value: jest.fn(
                        () => true
                    )
                }
            );
        }
    );
}

function amountPolicyResponse(
    overrides = {}
) {
    return {
        expenseDate: null,
        description: null,
        expenseTypeCode: 'Meals',
        expenseTypeLabel: 'Meals',
        calculationMethod: 'Amount',
        claimedAmount: null,
        distance: null,
        distanceUnit: null,
        unitRate: null,
        receiptRequired: false,
        businessPurpose: null,
        ...overrides
    };
}

function distancePolicyResponse(
    overrides = {}
) {
    return {
        expenseDate: null,
        description: null,
        expenseTypeCode: 'Mileage',
        expenseTypeLabel: 'Mileage',
        calculationMethod: 'Distance',
        claimedAmount: null,
        distance: null,
        distanceUnit: 'Kilometres',
        unitRate: 0.28,
        receiptRequired: false,
        businessPurpose: null,
        ...overrides
    };
}

describe(
    'c-expense-claim-form',
    () => {
        beforeEach(() => {
            getConfiguration.mockResolvedValue(
                cloneConfiguration()
            );

            createReceiptUploadKey.mockResolvedValue(
                RECEIPT_UPLOAD_KEY
            );
        });

        afterEach(() => {
            while (
                document.body.firstChild
            ) {
                document.body.removeChild(
                    document.body
                        .firstChild
                );
            }

            jest.clearAllMocks();
        });

        it(
            'loads configuration and displays claimant information',
            async () => {
                const element =
                    createComponent();

                await flushPromises();

                expect(
                    getConfiguration
                ).toHaveBeenCalledTimes(
                    1
                );

                expect(
                    createReceiptUploadKey
                ).toHaveBeenCalledTimes(
                    1
                );

                expect(
                    element.shadowRoot
                        .textContent
                ).toContain(
                    'Test Claimant'
                );

                expect(
                    element.shadowRoot
                        .textContent
                ).toContain(
                    'claimant@example.com'
                );

                expect(
                    element.shadowRoot
                        .textContent
                ).toContain(
                    'Future expense dates are not allowed.'
                );

                expect(
                    element.shadowRoot
                        .textContent
                ).toContain(
                    'Expenses can be up to 90 days old.'
                );

                const combobox =
                    element.shadowRoot
                        .querySelector(
                            'lightning-combobox'
                        );

                expect(
                    combobox.options
                ).toEqual([
                    {
                        label: 'Meals',
                        value: 'Meals'
                    },
                    {
                        label:
                            'Mileage',
                        value:
                            'Mileage'
                    }
                ]);

                expect(
                    element.shadowRoot
                        .querySelectorAll(
                            '.expense-item'
                        )
                ).toHaveLength(1);
            }
        );

        it(
            'displays configuration errors and allows retry',
            async () => {
                getConfiguration
                    .mockRejectedValueOnce({
                        body: {
                            message:
                                'Configuration unavailable'
                        }
                    });

                const element =
                    createComponent();

                await flushPromises();

                expect(
                    element.shadowRoot
                        .textContent
                ).toContain(
                    'Configuration unavailable'
                );

                const retryButton =
                    findButton(
                        element,
                        'Retry'
                    );

                expect(
                    retryButton
                ).not.toBeUndefined();

                retryButton.click();

                await flushPromises();

                expect(
                    getConfiguration
                ).toHaveBeenCalledTimes(
                    2
                );

                expect(
                    createReceiptUploadKey
                ).toHaveBeenCalledTimes(
                    1
                );

                expect(
                    element.shadowRoot
                        .textContent
                ).toContain(
                    'Test Claimant'
                );
            }
        );

        it(
            'adds and removes expense items',
            async () => {
                createReceiptUploadKey
                    .mockResolvedValueOnce(
                        RECEIPT_UPLOAD_KEY
                    )
                    .mockResolvedValueOnce(
                        SECOND_RECEIPT_UPLOAD_KEY
                    );

                const element =
                    createComponent();

                await flushPromises();

                const addButton =
                    findButton(
                        element,
                        'Add expense'
                    );

                addButton.click();

                await flushPromises();

                expect(
                    createReceiptUploadKey
                ).toHaveBeenCalledTimes(
                    2
                );

                expect(
                    element.shadowRoot
                        .querySelectorAll(
                            '.expense-item'
                        )
                ).toHaveLength(2);

                const deleteButtons =
                    element.shadowRoot
                        .querySelectorAll(
                            'lightning-button-icon'
                        );

                expect(
                    deleteButtons
                ).toHaveLength(2);

                deleteButtons[0].click();

                await flushPromises();

                expect(
                    element.shadowRoot
                        .querySelectorAll(
                            '.expense-item'
                        )
                ).toHaveLength(1);
            }
        );

        it(
            'applies server policy when an amount expense type is selected',
            async () => {
                applyPolicy.mockResolvedValueOnce(
                    amountPolicyResponse()
                );

                const element =
                    createComponent();

                await flushPromises();

                selectExpenseType(
                    element,
                    'Meals'
                );

                await flushPromises();

                expect(
                    applyPolicy
                ).toHaveBeenCalledTimes(
                    1
                );

                expect(
                    applyPolicy
                ).toHaveBeenCalledWith({
                    itemDto: {
                        expenseDate: null,
                        description: null,
                        expenseTypeCode:
                            'Meals',
                        claimedAmount: null,
                        distance: null,
                        businessPurpose:
                            null,
                        receiptUploadKey:
                            RECEIPT_UPLOAD_KEY
                    }
                });

                const amountInput =
                    findInput(
                        element,
                        'claimedAmount'
                    );

                expect(
                    amountInput
                ).not.toBeNull();

                expect(
                    amountInput.max
                ).toBe(100);

                expect(
                    findInput(
                        element,
                        'distance'
                    )
                ).toBeNull();
            }
        );

        it(
            'recalculates a distance expense through Apex',
            async () => {
                applyPolicy
                    .mockResolvedValueOnce(
                        distancePolicyResponse()
                    )
                    .mockResolvedValueOnce(
                        distancePolicyResponse(
                            {
                                distance: 10,
                                claimedAmount:
                                    2.8
                            }
                        )
                    );

                const element =
                    createComponent();

                await flushPromises();

                selectExpenseType(
                    element,
                    'Mileage'
                );

                await flushPromises();

                const distanceInput =
                    findInput(
                        element,
                        'distance'
                    );

                expect(
                    distanceInput
                ).not.toBeNull();

                changeInput(
                    distanceInput,
                    '10'
                );

                await flushPromises();

                expect(
                    applyPolicy
                ).toHaveBeenCalledTimes(
                    2
                );

                expect(
                    applyPolicy
                ).toHaveBeenLastCalledWith({
                    itemDto: {
                        expenseDate: null,
                        description: null,
                        expenseTypeCode:
                            'Mileage',
                        claimedAmount: null,
                        distance: 10,
                        businessPurpose:
                            null,
                        receiptUploadKey:
                            RECEIPT_UPLOAD_KEY
                    }
                });

                const calculatedAmount =
                    [
                        ...element
                            .shadowRoot
                            .querySelectorAll(
                                'lightning-input'
                            )
                    ].find(
                        (input) =>
                            input.label ===
                            'Calculated amount'
                    );

                expect(
                    calculatedAmount
                ).not.toBeUndefined();

                expect(
                    calculatedAmount.value
                ).toBe(2.8);

                expect(
                    calculatedAmount.disabled
                ).toBe(true);
            }
        );

        it(
            'updates the live claim total when an amount changes',
            async () => {
                applyPolicy.mockResolvedValueOnce(
                    amountPolicyResponse()
                );

                const element =
                    createComponent();

                await flushPromises();

                selectExpenseType(
                    element,
                    'Meals'
                );

                await flushPromises();

                const amountInput =
                    findInput(
                        element,
                        'claimedAmount'
                    );

                changeInput(
                    amountInput,
                    '37.50'
                );

                await flushPromises();

                const claimTotal =
                    element.shadowRoot
                        .querySelector(
                            'lightning-formatted-number[data-role="claim-total"]'
                        );

                expect(
                    claimTotal
                ).not.toBeNull();

                expect(
                    claimTotal.value
                ).toBe(37.5);
            }
        );

        it(
            'marks description as required when the expense type requires it',
            async () => {
                applyPolicy.mockResolvedValueOnce(
                    distancePolicyResponse()
                );

                const element =
                    createComponent();

                await flushPromises();

                selectExpenseType(
                    element,
                    'Mileage'
                );

                await flushPromises();

                const descriptionInput =
                    findInput(
                        element,
                        'description'
                    );

                expect(
                    descriptionInput.required
                ).toBe(true);

                const badges =
                    [
                        ...element.shadowRoot
                            .querySelectorAll(
                                'lightning-badge'
                            )
                    ];

                const descriptionBadge =
                    badges.find(
                        (badge) =>
                            badge.label ===
                            'Description required'
                    );

                expect(
                    descriptionBadge
                ).not.toBeUndefined();
            }
        );

        it(
            'disables submission when an expense has a policy error',
            async () => {
                applyPolicy.mockRejectedValueOnce({
                    body: {
                        message:
                            'Expense policy could not be applied.'
                    }
                });

                const element =
                    createComponent();

                await flushPromises();

                selectExpenseType(
                    element,
                    'Mileage'
                );

                await flushPromises();

                const submitButton =
                    findButton(
                        element,
                        'Submit claim'
                    );

                expect(
                    submitButton.disabled
                ).toBe(true);

                expect(
                    element.shadowRoot
                        .textContent
                ).toContain(
                    'Expense policy could not be applied.'
                );
            }
        );

        it(
            'prepares the receipt uploader with a generated upload key',
            async () => {
                applyPolicy.mockResolvedValueOnce(
                    amountPolicyResponse()
                );

                const element =
                    createComponent();

                await flushPromises();

                selectExpenseType(
                    element,
                    'Meals'
                );

                await flushPromises();

                const uploader =
                    element.shadowRoot
                        .querySelector(
                            'lightning-file-upload'
                        );

                expect(
                    uploader
                ).not.toBeNull();

                expect(
                    uploader.disabled
                ).toBe(false);

                expect(
                    uploader.fileFieldName
                ).toBe(
                    'Expense_Receipt_Key_fileupload__c'
                );

                expect(
                    uploader.fileFieldValue
                ).toBe(
                    RECEIPT_UPLOAD_KEY
                );

                expect(
                    uploader.accept
                ).toEqual([
                    '.pdf',
                    '.png',
                    '.jpg',
                    '.jpeg',
                    '.heic',
                    '.heif'
                ]);
            }
        );

        it(
            'creates a receipt upload key for each added expense row',
            async () => {
                createReceiptUploadKey
                    .mockResolvedValueOnce(
                        RECEIPT_UPLOAD_KEY
                    )
                    .mockResolvedValueOnce(
                        SECOND_RECEIPT_UPLOAD_KEY
                    );

                const element =
                    createComponent();

                await flushPromises();

                findButton(
                    element,
                    'Add expense'
                ).click();

                await flushPromises();

                expect(
                    createReceiptUploadKey
                ).toHaveBeenCalledTimes(
                    2
                );

                const expenseItems =
                    element.shadowRoot
                        .querySelectorAll(
                            '.expense-item'
                        );

                expect(
                    expenseItems
                ).toHaveLength(2);
            }
        );

        it(
            'requires an uploaded receipt when policy requires one',
            async () => {
                getConfiguration.mockResolvedValueOnce(
                    configurationWithRequiredMealReceipt()
                );

                applyPolicy.mockResolvedValueOnce(
                    amountPolicyResponse({
                        receiptRequired: true
                    })
                );

                const element =
                    createComponent();

                await flushPromises();

                selectExpenseType(
                    element,
                    'Meals'
                );

                await flushPromises();

                let submitButton =
                    findButton(
                        element,
                        'Submit claim'
                    );

                expect(
                    submitButton.disabled
                ).toBe(true);

                const uploader =
                    element.shadowRoot
                        .querySelector(
                            'lightning-file-upload'
                        );

                expect(
                    uploader
                ).not.toBeNull();

                uploadReceipt(
                    uploader,
                    [
                        'meal-receipt.pdf'
                    ]
                );

                await flushPromises();

                expect(
                    element.shadowRoot
                        .textContent
                ).toContain(
                    'meal-receipt.pdf'
                );

                submitButton =
                    findButton(
                        element,
                        'Submit claim'
                    );

                expect(
                    submitButton.disabled
                ).toBe(false);
            }
        );

        it(
            'submits only claimant-controlled values',
            async () => {
                applyPolicy.mockResolvedValueOnce(
                    amountPolicyResponse({
                        expenseDate:
                            '2026-11-18'
                    })
                );

                submitClaim.mockResolvedValueOnce(
                    SUBMISSION_RESULT
                );

                const element =
                    createComponent();

                await flushPromises();

                const claimDescription =
                    element.shadowRoot
                        .querySelector(
                            'lightning-textarea'
                        );

                changeInput(
                    claimDescription,
                    ' November expenses '
                );

                const expenseDate =
                    findInput(
                        element,
                        'expenseDate'
                    );

                changeInput(
                    expenseDate,
                    '2026-11-18'
                );

                await flushPromises();

                selectExpenseType(
                    element,
                    'Meals'
                );

                await flushPromises();

                const description =
                    findInput(
                        element,
                        'description'
                    );

                changeInput(
                    description,
                    ' Team lunch '
                );

                await flushPromises();

                const businessPurpose =
                    findInput(
                        element,
                        'businessPurpose'
                    );

                changeInput(
                    businessPurpose,
                    'Donor meeting'
                );

                await flushPromises();

                const claimedAmount =
                    findInput(
                        element,
                        'claimedAmount'
                    );

                changeInput(
                    claimedAmount,
                    '37.50'
                );

                await flushPromises();

                makeFormValid(
                    element
                );

                const submitButton =
                    findButton(
                        element,
                        'Submit claim'
                    );

                submitButton.click();

                await flushPromises();
                await flushPromises();

                expect(
                    submitClaim
                ).toHaveBeenCalledTimes(
                    1
                );

                expect(
                    submitClaim
                ).toHaveBeenCalledWith({
                    request: {
                        description:
                            'November expenses',
                        items: [
                            {
                                expenseDate:
                                    '2026-11-18',
                                description:
                                    'Team lunch',
                                expenseTypeCode:
                                    'Meals',
                                claimedAmount:
                                    37.5,
                                distance:
                                    null,
                                businessPurpose:
                                    'Donor meeting',
                                receiptUploadKey:
                                    RECEIPT_UPLOAD_KEY
                            }
                        ]
                    }
                });

                expect(
                    element.shadowRoot
                        .textContent
                ).toContain(
                    'EC-000001'
                );

                expect(
                    element.shadowRoot
                        .textContent
                ).toContain(
                    'Submitted'
                );
            }
        );
    }
);