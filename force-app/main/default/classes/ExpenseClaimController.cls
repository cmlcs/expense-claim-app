/**
 * Lightning-facing controller for the Expense Claim application.
 *
 * This class accepts DTO input and delegates mapping, persistence,
 * policy calculation, and lifecycle rules to dedicated services.
 */
public with sharing class ExpenseClaimController {

    /**
     * Returns claimant information, application settings, and active Expense Types.
     *
     * @return Configuration required to initialize the Expense Claim UI.
     */
    @AuraEnabled(cacheable=true)
    public static ExpenseClaimConfigurationDto getConfiguration() {
        try {
            Expense_Settings__mdt settings =
                ExpensePolicyService.getSettings();

            List<Expense_Type__mdt> expenseTypes =
                ExpensePolicyService.getActiveExpenseTypes();

            return ExpenseClaimDtoMapper.toConfiguration(
                settings,
                expenseTypes
            );
        } catch (
            ExpensePolicyService.ExpensePolicyException exceptionValue
        ) {
            throw clientException(
                exceptionValue.getMessage()
            );
        } catch (Exception exceptionValue) {
            throw clientException(
                'Unable to load Expense Claim configuration.'
            );
        }
    }

    /**
     * Applies current Expense Type policy to a client-side Expense Item.
     *
     * No DML is performed.
     *
     * @param itemDto Expense Item entered by the claimant.
     * @return Expense Item with server-derived policy fields populated.
     */
    @AuraEnabled
    public static ExpenseItemDto applyPolicy(
        ExpenseItemDto itemDto
    ) {
        try {
            if (itemDto == null) {
                throw new ExpenseClaimService.ExpenseClaimException(
                    'An Expense Item must be provided.'
                );
            }

            Expense_Item__c item =
                ExpenseClaimDtoMapper.toExpenseItem(
                    itemDto
                );

            ExpensePolicyService.applyPolicy(
                item,
                item.Expense_Type_Code__c
            );

            return ExpenseClaimDtoMapper.toExpenseItemDto(
                item
            );
        } catch (
            ExpensePolicyService.ExpensePolicyException exceptionValue
        ) {
            throw clientException(
                exceptionValue.getMessage()
            );
        } catch (
            ExpenseClaimService.ExpenseClaimException exceptionValue
        ) {
            throw clientException(
                exceptionValue.getMessage()
            );
        } catch (Exception exceptionValue) {
            throw clientException(
                'Unable to apply Expense Type policy.'
            );
        }
    }

    /**
     * Validates, prepares, and persists an Expense Claim.
     *
     * @param request Expense Claim submission request.
     * @return Submission result.
     */
    @AuraEnabled
    public static ExpenseClaimResponseDto submitClaim(
        ExpenseClaimRequestDto request
    ) {
        try {
            return submitClaimInternal(
                request
            );
        } catch (
            ExpenseClaimService.ExpenseClaimException exceptionValue
        ) {
            throw clientException(
                exceptionValue.getMessage()
            );
        } catch (
            ExpensePolicyService.ExpensePolicyException exceptionValue
        ) {
            throw clientException(
                exceptionValue.getMessage()
            );
        } catch (
            ExpenseReceiptService.ExpenseReceiptException exceptionValue
        ) {
            throw clientException(
                exceptionValue.getMessage()
            );
        } catch (Exception exceptionValue) {
            throw clientException(
                'The expense claim could not be submitted.'
            );
        }
    }

    /**
     * Creates an opaque key used to correlate receipt uploads with an
     * expense line before the expense item has been persisted.
     *
     * @return A cryptographically random receipt upload key.
     */
    @AuraEnabled
    public static String createReceiptUploadKey() {
        return ExpenseReceiptService.createUploadKey();
    }

    /**
     * Requires a submission request.
     *
     * @param request Client submission request.
     */
    private static void requireRequest(
        ExpenseClaimRequestDto request
    ) {
        if (request == null) {
            throw new ExpenseClaimService.ExpenseClaimException(
                'Expense claim request is required.'
            );
        }
    }

    /**
     * Executes Expense Claim submission after controller-level
     * exception handling has been established.
     *
     * @param request Expense Claim submission request.
     * @return Submission result.
     */
    private static ExpenseClaimResponseDto submitClaimInternal(
        ExpenseClaimRequestDto request
    ) {
        requireRequest(
            request
        );

        Expense_Claim__c claim =
            ExpenseClaimDtoMapper.toExpenseClaim(
                request
            );

        List<Expense_Item__c> items =
            ExpenseClaimDtoMapper.toExpenseItems(
                request.items
            );

        claim =
            ExpenseClaimPersistenceService.sanitizeClaimInput(
                claim
            );

        items =
            ExpenseClaimPersistenceService.sanitizeItemInput(
                items
            );

        claim.Status__c =
            'Draft';

        ExpenseClaimService.prepareForSubmission(
            claim,
            items
        );

        ExpenseReceiptService.validateReceipts(
            request.items,
            items
        );

        ExpenseClaimPersistenceService.persistSubmission(
            claim,
            items
        );

        ExpenseReceiptService.linkReceipts(
            request.items,
            items
        );

        return ExpenseClaimDtoMapper.toResponse(
            claim,
            items
        );
    }

    /**
     * Creates a Lightning-safe handled exception.
     *
     * Setting the message explicitly ensures that Apex tests receive
     * the intended domain error instead of only "Script-thrown exception."
     *
     * @param message User-safe error message.
     * @return AuraHandledException containing the supplied message.
     */
    private static AuraHandledException clientException(
        String message
    ) {
        AuraHandledException exceptionValue =
            new AuraHandledException(
                message
            );

        exceptionValue.setMessage(
            message
        );

        return exceptionValue;
    }
}