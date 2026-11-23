/**
 * Submits Expense Claims for verified unauthenticated claimants.
 *
 * This service is an internal privileged boundary. The browser supplies only
 * claimant-controlled values. Claimant identity, policy snapshots, status,
 * submission timestamps, calculated values, and receipt requirements are
 * derived and enforced server-side.
 */
public without sharing class ExpenseClaimGuestSubmissionService {

    private static final String STATUS_DRAFT =
        'Draft';

/**
 * Submits an Expense Claim for a verified guest claimant.
 *
 * The access session is consumed within a savepoint-controlled transaction.
 * If claim preparation, receipt validation, persistence, or receipt linking
 * fails, all submission changes are explicitly rolled back and the access
 * session remains usable.
 *
 * @param accessToken Verified guest access token.
 * @param request Claimant-supplied Expense Claim request.
 * @return Submitted Expense Claim response.
 */
public static ExpenseClaimResponseDto submitClaim(
    String accessToken,
    ExpenseClaimRequestDto request
) {
    requireRequest(
        request
    );

    ExpenseClaimGuestAccessService.AccessContext accessContext =
        ExpenseClaimGuestAccessService.validateAccessToken(
            accessToken
        );

    Contact claimantContact =
        findClaimantContact(
            accessContext.contactId
        );

    Savepoint submissionSavepoint =
        Database.setSavepoint();

    try {
        return submitClaimTransactional(
            accessContext,
            claimantContact,
            request
        );
    } catch (Exception exceptionValue) {
        Database.rollback(
            submissionSavepoint
        );

        throw exceptionValue;
    }
}

    /**
    * Performs the state-changing portion of guest claim submission.
    *
    * The access record is consumed first so its row lock prevents concurrent
    * submissions from using the same verified session. The caller owns the
    * savepoint and rolls all changes back if this method throws.
    *
    * @param accessContext Validated guest access context.
    * @param claimantContact Verified claimant Contact.
    * @param request Claimant-supplied Expense Claim request.
    * @return Submitted Expense Claim response.
    */
    private static ExpenseClaimResponseDto submitClaimTransactional(
        ExpenseClaimGuestAccessService.AccessContext accessContext,
        Contact claimantContact,
        ExpenseClaimRequestDto request
    ) {
        ExpenseClaimGuestAccessService.markUsed(
            accessContext.accessId
        );

        Expense_Claim__c claim =
            createGuestClaim(
                request
            );

        List<Expense_Item__c> items =
            createGuestItems(
                request.items
            );

        ExpenseClaimService.prepareForGuestSubmission(
            claim,
            items,
            claimantContact
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
     * Requires a valid submission request with expense items.
     *
     * @param request Claimant-supplied submission request.
     */
    private static void requireRequest(
        ExpenseClaimRequestDto request
    ) {
        if (request == null) {
            throw new ExpenseClaimService.ExpenseClaimException(
                'Expense claim request is required.'
            );
        }

        if (
            request.items == null ||
            request.items.isEmpty()
        ) {
            throw new ExpenseClaimService.ExpenseClaimException(
                'At least one Expense Item is required.'
            );
        }
    }

    /**
     * Loads the Contact previously bound to the verified guest session.
     *
     * The browser never supplies this Contact ID.
     *
     * @param contactId Verified Contact ID from the access context.
     * @return Verified claimant Contact.
     */
    private static Contact findClaimantContact(
        Id contactId
    ) {
        if (contactId == null) {
            throw missingClaimantException();
        }

        List<Contact> contacts = [
            SELECT
                Id,
                Name,
                Email
            FROM Contact
            WHERE
                Id = :contactId
                AND Email != null
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (contacts.isEmpty()) {
            throw missingClaimantException();
        }

        return contacts[0];
    }

    /**
     * Creates a claim containing only claimant-controlled claim fields.
     *
     * The normal DTO mapper is used to interpret the request, but a new
     * SObject is then constructed explicitly so claimant identity and
     * server-owned lifecycle fields cannot be injected by the browser.
     *
     * @param request Claimant-supplied request.
     * @return Allowlisted Draft Expense Claim.
     */
    private static Expense_Claim__c createGuestClaim(
        ExpenseClaimRequestDto request
    ) {
        Expense_Claim__c mappedClaim =
            ExpenseClaimDtoMapper.toExpenseClaim(
                request
            );

        return new Expense_Claim__c(
            Status__c =
                STATUS_DRAFT,
            Description__c =
                mappedClaim.Description__c,
            External_Reference__c =
                mappedClaim.External_Reference__c
        );
    }

    /**
     * Creates Expense Items containing only claimant-controlled fields.
     *
     * Policy-derived and approval fields are deliberately discarded even
     * if they were supplied by the browser.
     *
     * @param requestItems Claimant-supplied Expense Item DTOs.
     * @return Allowlisted Expense Items.
     */
    private static List<Expense_Item__c> createGuestItems(
        List<ExpenseItemDto> requestItems
    ) {
        List<Expense_Item__c> mappedItems =
            ExpenseClaimDtoMapper.toExpenseItems(
                requestItems
            );

        List<Expense_Item__c> guestItems =
            new List<Expense_Item__c>();

        for (Expense_Item__c mappedItem : mappedItems) {
            guestItems.add(
                createGuestItem(
                    mappedItem
                )
            );
        }

        return guestItems;
    }

    /**
     * Creates one Expense Item using only claimant-controlled fields.
     *
     * @param mappedItem Expense Item produced by the DTO mapper.
     * @return Allowlisted Expense Item.
     */
    private static Expense_Item__c createGuestItem(
        Expense_Item__c mappedItem
    ) {
        if (mappedItem == null) {
            return null;
        }

        return new Expense_Item__c(
            Expense_Date__c =
                mappedItem.Expense_Date__c,
            Description__c =
                mappedItem.Description__c,
            Expense_Type_Code__c =
                mappedItem.Expense_Type_Code__c,
            Claimed_Amount__c =
                mappedItem.Claimed_Amount__c,
            Distance__c =
                mappedItem.Distance__c,
            Business_Purpose__c =
                mappedItem.Business_Purpose__c
        );
    }

    /**
     * Creates the missing verified claimant exception.
     *
     * @return Expense Claim domain exception.
     */
    private static ExpenseClaimService.ExpenseClaimException
        missingClaimantException() {
        return new ExpenseClaimService.ExpenseClaimException(
            'A verified claimant Contact is required.'
        );
    }
}