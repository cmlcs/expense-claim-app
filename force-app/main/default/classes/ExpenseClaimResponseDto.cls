/**
 * Result returned after an Expense Claim is submitted successfully.
 */
public class ExpenseClaimResponseDto {

    /**
     * Salesforce ID of the submitted Expense Claim.
     */
    @AuraEnabled
    public Id claimId { get; set; }

    /**
     * Auto-number assigned to the submitted claim.
     */
    @AuraEnabled
    public String claimNumber { get; set; }

    /**
     * Current claim lifecycle status.
     */
    @AuraEnabled
    public String status { get; set; }

    /**
     * Date and time at which the claim was submitted.
     */
    @AuraEnabled
    public Datetime submittedAt { get; set; }

    /**
     * Total amount claimed across the submitted items.
     */
    @AuraEnabled
    public Decimal totalAmount { get; set; }
}