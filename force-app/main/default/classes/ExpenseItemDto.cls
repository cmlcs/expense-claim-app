/**
 * Serializable Expense Item used for Lightning input and policy responses.
 */
@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
public class ExpenseItemDto {

    /**
     * Date on which the expense was incurred.
     */
    @AuraEnabled
    public Date expenseDate { get; set; }

    /**
     * Claimant-entered expense description.
     */
    @AuraEnabled
    public String description { get; set; }

    /**
     * Selected Expense Type Developer Name.
     */
    @AuraEnabled
    public String expenseTypeCode { get; set; }

    /**
     * Server-derived Expense Type display label.
     */
    @AuraEnabled
    public String expenseTypeLabel { get; set; }

    /**
     * Server-derived calculation method.
     */
    @AuraEnabled
    public String calculationMethod { get; set; }

    /**
     * Claimed reimbursement amount.
     */
    @AuraEnabled
    public Decimal claimedAmount { get; set; }

    /**
     * Distance claimed for distance-based expenses.
     */
    @AuraEnabled
    public Decimal distance { get; set; }

    /**
     * Server-derived effective distance unit.
     */
    @AuraEnabled
    public String distanceUnit { get; set; }

    /**
     * Server-derived reimbursement rate.
     */
    @AuraEnabled
    public Decimal unitRate { get; set; }

    /**
     * Server-derived indication that a receipt is required.
     */
    @AuraEnabled
    public Boolean receiptRequired { get; set; }

    /**
     * Business purpose supplied by the claimant.
     */
    @AuraEnabled
    public String businessPurpose { get; set; }
}