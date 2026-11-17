/**
 * Request submitted by the Lightning client when submitting an Expense Claim.
 */
public class ExpenseClaimRequestDto {

    /**
     * Overall claim description supplied by the claimant.
     */
    @AuraEnabled
    public String description { get; set; }

    /**
     * Expense Items included in the claim.
     */
    @AuraEnabled
    public List<ExpenseItemDto> items { get; set; }
}