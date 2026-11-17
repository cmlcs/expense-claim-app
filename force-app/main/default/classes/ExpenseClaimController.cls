/**
 * Lightning-facing controller for the Expense Claim application.
 *
 * This class accepts DTO input and delegates mapping, persistence,
 * policy calculation, and lifecycle rules to dedicated services.
 */
public with sharing class ExpenseClaimController {

    private static final String STATUS_DRAFT = 'Draft';

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
            requireRequest(request);

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
                STATUS_DRAFT;

            ExpenseClaimService.prepareForSubmission(
                claim,
                items
            );

            ExpenseClaimPersistenceService.persistSubmission(
                claim,
                items
            );

            return ExpenseClaimDtoMapper.toResponse(
                claim,
                items
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
        } catch (DmlException exceptionValue) {
            throw clientException(
                'Unable to save the Expense Claim.'
            );
        } catch (Exception exceptionValue) {
            throw clientException(
                'Unable to submit the Expense Claim.'
            );
        }
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
                'An Expense Claim request must be provided.'
            );
        }
    }

    /**
     * Creates a Lightning-safe handled exception.
     *
     * @param message User-safe error message.
     * @return AuraHandledException.
     */
    private static AuraHandledException clientException(
        String message
    ) {
        return new AuraHandledException(
            message
        );
    }
}