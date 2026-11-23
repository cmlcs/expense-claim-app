/**
 * Lightning-facing controller for unauthenticated Expense Claim access.
 *
 * This controller is the only Apex boundary intended to be exposed to the
 * Experience Cloud Guest User. Privileged verification and access-state
 * operations are delegated to internal guest services.
 *
 * Guest users receive no direct CRUD/FLS access to Contact,
 * Expense_Claim_Access__c, Expense_Claim__c, or Expense_Item__c.
 */
public without sharing class ExpenseClaimGuestController {

    private static final String VERIFICATION_REQUEST_MESSAGE =
        'If this email belongs to an eligible volunteer, a verification code has been sent.';

    /**
     * Requests an email verification code.
     *
     * The same response is returned regardless of whether the email address
     * matched an eligible Contact. This prevents callers from using the
     * endpoint to discover which email addresses exist in Salesforce.
     *
     * @param email Email address supplied by the claimant.
     * @return Generic verification-request response.
     */
    @AuraEnabled
    public static String requestVerification(
        String email
    ) {
        try {
            ExpenseClaimGuestAccessService.requestVerification(
                email
            );
        } catch (Exception exceptionValue) {
            /*
             * Deliberately return the same generic response.
             *
             * The guest must not be able to distinguish an unknown email,
             * duplicate Contact, throttled request, or internal failure.
             */
            return VERIFICATION_REQUEST_MESSAGE;
        }

        return VERIFICATION_REQUEST_MESSAGE;
    }

    /**
     * Verifies an emailed code and returns a short-lived guest access token.
     *
     * @param email Email address used when requesting verification.
     * @param code Six-digit verification code.
     * @return High-entropy guest access token.
     */
    @AuraEnabled
    public static String verifyCode(
        String email,
        String code
    ) {
        try {
            return ExpenseClaimGuestAccessService.verifyCode(
                email,
                code
            );
        } catch (Exception exceptionValue) {
            throw ExpenseClaimGuestExceptionMapper.forVerification(
                exceptionValue
            );
        }
    }

    /**
     * Returns application configuration for a verified guest claimant.
     *
     * Claimant identity is derived from the Contact associated with the
     * validated guest access token. Browser-supplied claimant identity is
     * never trusted.
     *
     * @param accessToken Verified guest access token.
     * @return Configuration required to initialize the Expense Claim UI.
     */
    @AuraEnabled
    public static ExpenseClaimConfigurationDto getConfiguration(
        String accessToken
    ) {
        try {
            return getConfigurationInternal(
                accessToken
            );
        } catch (Exception exceptionValue) {
            throw ExpenseClaimGuestExceptionMapper.forConfiguration(
                exceptionValue
            );
        }
    }

    /**
     * Creates an opaque receipt-upload correlation key for a verified
     * guest claimant.
     *
     * @param accessToken Verified guest access token.
     * @return Cryptographically random receipt upload key.
     */
    @AuraEnabled
    public static String createReceiptUploadKey(
        String accessToken
    ) {
        try {
            validateAccess(
                accessToken
            );

            return ExpenseReceiptService.createUploadKey();
        } catch (Exception exceptionValue) {
            throw ExpenseClaimGuestExceptionMapper.forReceiptUpload(
                exceptionValue
            );
        }
    }

    /**
     * Applies current Expense Type policy to a guest claimant's expense item.
     *
     * @param accessToken Verified guest access token.
     * @param itemDto Expense Item entered by the claimant.
     * @return Expense Item with server-derived policy fields populated.
     */
    @AuraEnabled
    public static ExpenseItemDto applyPolicy(
        String accessToken,
        ExpenseItemDto itemDto
    ) {
        try {
            return applyPolicyInternal(
                accessToken,
                itemDto
            );
        } catch (Exception exceptionValue) {
            throw ExpenseClaimGuestExceptionMapper.forPolicy(
                exceptionValue
            );
        }
    }

    /**
     * Submits an Expense Claim for a verified guest claimant.
     *
     * Claimant identity and all server-controlled values are derived
     * internally from the verified access session and current policy.
     *
     * @param accessToken Verified guest access token.
     * @param request Claimant-supplied Expense Claim request.
     * @return Submitted Expense Claim response.
     */
    @AuraEnabled
    public static ExpenseClaimResponseDto submitClaim(
        String accessToken,
        ExpenseClaimRequestDto request
    ) {
        try {
            return ExpenseClaimGuestSubmissionService.submitClaim(
                accessToken,
                request
            );
        } catch (Exception exceptionValue) {
            throw ExpenseClaimGuestExceptionMapper.forSubmission(
                exceptionValue
            );
        }
    }

    /**
     * Loads configuration and replaces authenticated UserInfo identity with
     * the verified guest Contact identity.
     *
     * @param accessToken Verified guest access token.
     * @return Configuration for the verified claimant.
     */
    private static ExpenseClaimConfigurationDto getConfigurationInternal(
        String accessToken
    ) {
        ExpenseClaimGuestAccessService.AccessContext accessContext =
            validateAccess(
                accessToken
            );

        Expense_Settings__mdt settings =
            ExpensePolicyService.getSettings();

        List<Expense_Type__mdt> expenseTypes =
            ExpensePolicyService.getActiveExpenseTypes();

        ExpenseClaimConfigurationDto configuration =
            ExpenseClaimDtoMapper.toConfiguration(
                settings,
                expenseTypes
            );

        configuration.claimantName =
            accessContext.claimantName;

        configuration.claimantEmail =
            accessContext.claimantEmail;

        return configuration;
    }

    /**
     * Applies Expense Type policy after validating guest access.
     *
     * @param accessToken Verified guest access token.
     * @param itemDto Expense Item entered by the claimant.
     * @return Expense Item with server-derived policy fields populated.
     */
    private static ExpenseItemDto applyPolicyInternal(
        String accessToken,
        ExpenseItemDto itemDto
    ) {
        validateAccess(
            accessToken
        );

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
    }

    /**
     * Requires a valid, unexpired guest access token.
     *
     * @param accessToken Browser-held guest access token.
     * @return Validated guest access context.
     */
    private static ExpenseClaimGuestAccessService.AccessContext validateAccess(
        String accessToken
    ) {
        return ExpenseClaimGuestAccessService.validateAccessToken(
            accessToken
        );
    }
}