/**
 * Serializable Expense Type configuration exposed to Lightning clients.
 */
@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
public class ExpenseTypeDto {

    /**
     * Stable Expense Type Developer Name.
     */
    @AuraEnabled
    public String developerName { get; set; }

    /**
     * Display label for the Expense Type.
     */
    @AuraEnabled
    public String label { get; set; }

    /**
     * Calculation method used by the Expense Type.
     */
    @AuraEnabled
    public String calculationMethod { get; set; }

    /**
     * Configured rate for distance-based expenses.
     */
    @AuraEnabled
    public Decimal rate { get; set; }

    /**
     * Configured distance unit.
     */
    @AuraEnabled
    public String distanceUnit { get; set; }

    /**
     * Indicates whether a receipt is required.
     */
    @AuraEnabled
    public Boolean receiptRequired { get; set; }

    /**
     * Maximum amount allowed for an individual expense.
     */
    @AuraEnabled
    public Decimal maximumAmount { get; set; }

    /**
     * Indicates whether a description is required.
     */
    @AuraEnabled
    public Boolean descriptionRequired { get; set; }

    /**
     * Configured UI sort order.
     */
    @AuraEnabled
    public Decimal sortOrder { get; set; }
}