/**
 * Converts exceptions raised by guest Expense Claim operations into
 * user-safe Lightning exceptions.
 *
 * This class contains no data access. It centralizes exception classification
 * so ExpenseClaimGuestController can remain a small transport boundary.
 */
public inherited sharing class ExpenseClaimGuestExceptionMapper {

    /**
     * Converts verification exceptions into user-safe Lightning errors.
     *
     * @param exceptionValue Exception raised during code verification.
     * @return Lightning-safe handled exception.
     */
    public static AuraHandledException forVerification(
        Exception exceptionValue
    ) {
        if (
            exceptionValue instanceof
                ExpenseClaimGuestAccessService.GuestAccessException
        ) {
            return clientException(
                exceptionValue.getMessage()
            );
        }

        return clientException(
            'The verification code could not be validated.'
        );
    }

    /**
     * Converts configuration exceptions into user-safe Lightning errors.
     *
     * @param exceptionValue Exception raised while loading configuration.
     * @return Lightning-safe handled exception.
     */
    public static AuraHandledException forConfiguration(
        Exception exceptionValue
    ) {
        if (
            exceptionValue instanceof
                ExpenseClaimGuestAccessService.GuestAccessException
        ) {
            return clientException(
                exceptionValue.getMessage()
            );
        }

        if (
            exceptionValue instanceof
                ExpensePolicyService.ExpensePolicyException
        ) {
            return clientException(
                exceptionValue.getMessage()
            );
        }

        return clientException(
            'Unable to load Expense Claim configuration.'
        );
    }

    /**
     * Converts receipt-upload preparation exceptions into user-safe
     * Lightning errors.
     *
     * @param exceptionValue Exception raised while preparing an upload.
     * @return Lightning-safe handled exception.
     */
    public static AuraHandledException forReceiptUpload(
        Exception exceptionValue
    ) {
        if (
            exceptionValue instanceof
                ExpenseClaimGuestAccessService.GuestAccessException
        ) {
            return clientException(
                exceptionValue.getMessage()
            );
        }

        return clientException(
            'Unable to prepare the receipt upload.'
        );
    }

    /**
     * Converts policy-processing exceptions into user-safe Lightning errors.
     *
     * @param exceptionValue Exception raised while applying policy.
     * @return Lightning-safe handled exception.
     */
    public static AuraHandledException forPolicy(
        Exception exceptionValue
    ) {
        if (
            exceptionValue instanceof
                ExpenseClaimGuestAccessService.GuestAccessException
        ) {
            return clientException(
                exceptionValue.getMessage()
            );
        }

        if (
            exceptionValue instanceof
                ExpensePolicyService.ExpensePolicyException
        ) {
            return clientException(
                exceptionValue.getMessage()
            );
        }

        if (
            exceptionValue instanceof
                ExpenseClaimService.ExpenseClaimException
        ) {
            return clientException(
                exceptionValue.getMessage()
            );
        }

        return clientException(
            'Unable to apply Expense Type policy.'
        );
    }

    /**
     * Converts guest-submission exceptions into user-safe Lightning errors.
     *
     * @param exceptionValue Exception raised during guest submission.
     * @return Lightning-safe handled exception.
     */
    public static AuraHandledException forSubmission(
        Exception exceptionValue
    ) {
        if (
            exceptionValue instanceof
                ExpenseClaimGuestAccessService.GuestAccessException
        ) {
            return clientException(
                exceptionValue.getMessage()
            );
        }

        if (
            exceptionValue instanceof
                ExpenseReceiptService.ExpenseReceiptException
        ) {
            return clientException(
                exceptionValue.getMessage()
            );
        }

        if (
            exceptionValue instanceof
                ExpensePolicyService.ExpensePolicyException
        ) {
            return clientException(
                exceptionValue.getMessage()
            );
        }

        if (
            exceptionValue instanceof
                ExpenseClaimService.ExpenseClaimException
        ) {
            return clientException(
                exceptionValue.getMessage()
            );
        }

        return clientException(
            'Unable to submit the Expense Claim.'
        );
    }

    /**
     * Creates a Lightning-safe handled exception.
     *
     * Explicitly setting the message ensures Apex tests observe the same
     * message returned to Lightning clients.
     *
     * @param message User-safe message.
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