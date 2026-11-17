/**
 * Initial configuration required by the Expense Claim Lightning client.
 */
@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
public class ExpenseClaimConfigurationDto {

    /**
     * Current authenticated claimant name.
     */
    @AuraEnabled
    public String claimantName { get; set; }

    /**
     * Current authenticated claimant email address.
     */
    @AuraEnabled
    public String claimantEmail { get; set; }

    /**
     * Application default distance unit.
     */
    @AuraEnabled
    public String defaultDistanceUnit { get; set; }

    /**
     * Indicates whether future expense dates are permitted.
     */
    @AuraEnabled
    public Boolean allowFutureExpenseDates { get; set; }

    /**
     * Maximum permitted age of an expense in days.
     */
    @AuraEnabled
    public Integer maximumExpenseAgeDays { get; set; }

    /**
     * Indicates whether every expense requires a description.
     */
    @AuraEnabled
    public Boolean requireDescription { get; set; }

    /**
     * Indicates whether claimants can adjust submitted claims.
     */
    @AuraEnabled
    public Boolean allowEditAfterSubmission { get; set; }

    /**
     * Active Expense Types available to the claimant.
     */
    @AuraEnabled
    public List<ExpenseTypeDto> expenseTypes { get; set; }
}