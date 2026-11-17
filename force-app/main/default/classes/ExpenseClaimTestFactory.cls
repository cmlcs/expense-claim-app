/**
 * Creates reusable Expense Claim test fixtures.
 */
@IsTest
public class ExpenseClaimTestFactory {

    /**
     * Creates an in-memory Draft Expense Claim.
     *
     * @return Draft Expense Claim.
     */
    public static Expense_Claim__c createDraftClaim() {
        return new Expense_Claim__c(
            Status__c = 'Draft'
        );
    }

    /**
     * Creates an amount-based Expense Item test fixture.
     *
     * @param expenseTypeCode Expense Type Developer Name.
     * @param amount Claimed amount.
     * @param expenseDate Expense date.
     * @return In-memory Expense Item.
     */
    public static Expense_Item__c createAmountItem(
        String expenseTypeCode,
        Decimal amount,
        Date expenseDate
    ) {
        return new Expense_Item__c(
            Expense_Type_Code__c = expenseTypeCode,
            Claimed_Amount__c = amount,
            Expense_Date__c = expenseDate,
            Description__c = 'Test expense'
        );
    }
}