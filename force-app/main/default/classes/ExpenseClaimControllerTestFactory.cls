/**
 * Creates reusable controller test DTOs and resolves active test configuration.
 */
@IsTest
public class ExpenseClaimControllerTestFactory {

    /**
     * Finds an active amount-based Expense Type in current test configuration.
     *
     * @return Developer Name, or null when none exists.
     */
    public static String findActiveAmountTypeCode() {
        for (
            Expense_Type__mdt expenseType :
            ExpenseTypeRepository.getActiveExpenseTypes()
        ) {
            if (
                expenseType.Calculation_Method__c == 'Amount' &&
                expenseType.Receipt_Required__c != true
            ) {
                return expenseType.DeveloperName;
            }
        }

        System.assert(
            false,
            'The test requires an active Amount expense type that does not require a receipt.'
        );

        return null;
    }

    /**
     * Creates an amount-based client Expense Item.
     *
     * @param expenseTypeCode Expense Type Developer Name.
     * @param amount Claimed amount.
     * @return Expense Item DTO.
     */
    public static ExpenseItemDto createAmountItem(
        String expenseTypeCode,
        Decimal amount
    ) {
        ExpenseItemDto item =
            new ExpenseItemDto();

        item.expenseDate =
            Date.today();

        item.description =
            'Controller test expense';

        item.expenseTypeCode =
            expenseTypeCode;

        item.claimedAmount =
            amount;

        return item;
    }

    /**
     * Creates a submission request containing one Expense Item.
     *
     * @param expenseTypeCode Expense Type Developer Name.
     * @param amount Claimed amount.
     * @return Expense Claim request.
     */
    public static ExpenseClaimRequestDto createRequest(
        String expenseTypeCode,
        Decimal amount
    ) {
        ExpenseClaimRequestDto request =
            new ExpenseClaimRequestDto();

        request.description =
            'Controller test claim';

        request.items =
            new List<ExpenseItemDto>{
                createAmountItem(
                    expenseTypeCode,
                    amount
                )
            };

        return request;
    }
    /**
     * Finds an active Amount expense type that does not require a receipt.
     *
     * This is used by submission tests that need to exercise claim processing
     * without introducing receipt-upload requirements.
     *
     * @return DeveloperName of a suitable active Expense Type.
     */
    public static String findActiveAmountTypeWithoutRequiredReceipt() {
        for (
            Expense_Type__mdt expenseType :
            ExpenseTypeRepository.getActiveExpenseTypes()
        ) {
            if (
                expenseType.Calculation_Method__c == 'Amount' &&
                expenseType.Receipt_Required__c != true
            ) {
                return expenseType.DeveloperName;
            }
        }

        System.assert(
            false,
            'The test requires an active Amount expense type without a required receipt.'
        );

        return null;
    }

}