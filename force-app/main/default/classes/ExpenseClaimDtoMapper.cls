/**
 * Converts between Lightning DTOs and Expense Claim domain records.
 */
public inherited sharing class ExpenseClaimDtoMapper {

    /**
     * Creates the initial client configuration.
     *
     * @param settings Global Expense Claim settings.
     * @param expenseTypes Active Expense Types.
     * @return Configuration DTO for the Lightning client.
     */
    public static ExpenseClaimConfigurationDto toConfiguration(
        Expense_Settings__mdt settings,
        List<Expense_Type__mdt> expenseTypes
    ) {
        ExpenseClaimConfigurationDto configuration =
            new ExpenseClaimConfigurationDto();

        configuration.claimantName =
            UserInfo.getName();

        configuration.claimantEmail =
            UserInfo.getUserEmail();

        configuration.defaultDistanceUnit =
            settings.Default_Distance_Unit__c;

        configuration.allowFutureExpenseDates =
            settings.Allow_Future_Expense_Dates__c;

        configuration.maximumExpenseAgeDays =
            settings.Maximum_Expense_Age_Days__c == null
                ? null
                : settings.Maximum_Expense_Age_Days__c.intValue();

        configuration.requireDescription =
            settings.Require_Description__c;

        configuration.allowEditAfterSubmission =
            settings.Allow_Edit_After_Submission__c;

        configuration.expenseTypes =
            toExpenseTypeDtos(expenseTypes);

        return configuration;
    }

    /**
     * Converts client-controlled claim data into an Expense Claim.
     *
     * Only claimant-editable fields are copied.
     *
     * @param request Client submission request.
     * @return Unsaved Expense Claim.
     */
    public static Expense_Claim__c toExpenseClaim(
        ExpenseClaimRequestDto request
    ) {
        return new Expense_Claim__c(
            Description__c = request.description
        );
    }

    /**
     * Converts client Expense Items into Salesforce records.
     *
     * @param itemDtos Client Expense Items.
     * @return Unsaved Expense Items.
     */
    public static List<Expense_Item__c> toExpenseItems(
        List<ExpenseItemDto> itemDtos
    ) {
        List<Expense_Item__c> items =
            new List<Expense_Item__c>();

        if (itemDtos == null) {
            return items;
        }

        for (ExpenseItemDto itemDto : itemDtos) {
            if (itemDto == null) {
                throw new ExpenseClaimService.ExpenseClaimException(
                    'An Expense Item must be provided.'
                );
            }

            items.add(
                toExpenseItem(itemDto)
            );
        }

        return items;
    }

    /**
     * Converts one client Expense Item into a Salesforce record.
     *
     * Policy-derived client properties are deliberately ignored.
     *
     * @param itemDto Client Expense Item.
     * @return Unsaved Expense Item.
     */
    public static Expense_Item__c toExpenseItem(
        ExpenseItemDto itemDto
    ) {
        return new Expense_Item__c(
            Expense_Date__c =
                itemDto.expenseDate,
            Description__c =
                itemDto.description,
            Expense_Type_Code__c =
                itemDto.expenseTypeCode,
            Claimed_Amount__c =
                itemDto.claimedAmount,
            Distance__c =
                itemDto.distance,
            Business_Purpose__c =
                itemDto.businessPurpose
        );
    }

    /**
     * Converts a prepared Expense Item into a Lightning DTO.
     *
     * @param item Prepared Expense Item.
     * @return Expense Item DTO.
     */
    public static ExpenseItemDto toExpenseItemDto(
        Expense_Item__c item
    ) {
        ExpenseItemDto dto =
            new ExpenseItemDto();

        dto.expenseDate =
            item.Expense_Date__c;

        dto.description =
            item.Description__c;

        dto.expenseTypeCode =
            item.Expense_Type_Code__c;

        dto.expenseTypeLabel =
            item.Expense_Type_Label__c;

        dto.calculationMethod =
            item.Calculation_Method__c;

        dto.claimedAmount =
            item.Claimed_Amount__c;

        dto.distance =
            item.Distance__c;

        dto.distanceUnit =
            item.Distance_Unit__c;

        dto.unitRate =
            item.Unit_Rate__c;

        dto.receiptRequired =
            item.Receipt_Required__c;

        dto.businessPurpose =
            item.Business_Purpose__c;

        return dto;
    }

    /**
     * Creates a successful submission response.
     *
     * @param claim Persisted Expense Claim.
     * @param items Persisted Expense Items.
     * @return Submission result DTO.
     */
    public static ExpenseClaimResponseDto toResponse(
        Expense_Claim__c claim,
        List<Expense_Item__c> items
    ) {
        ExpenseClaimResponseDto response =
            new ExpenseClaimResponseDto();

        response.claimId =
            claim.Id;

        response.claimNumber =
            claim.Name;

        response.status =
            claim.Status__c;

        response.submittedAt =
            claim.Submitted_At__c;

        response.totalAmount =
            calculateTotal(items);

        return response;
    }

    /**
     * Converts Expense Type metadata to client DTOs.
     *
     * @param expenseTypes Expense Types to convert.
     * @return Expense Type DTOs.
     */
    private static List<ExpenseTypeDto> toExpenseTypeDtos(
        List<Expense_Type__mdt> expenseTypes
    ) {
        List<ExpenseTypeDto> dtos =
            new List<ExpenseTypeDto>();

        for (Expense_Type__mdt expenseType : expenseTypes) {
            dtos.add(
                toExpenseTypeDto(expenseType)
            );
        }

        return dtos;
    }

    /**
     * Converts one Expense Type metadata record to a DTO.
     *
     * @param expenseType Expense Type metadata.
     * @return Expense Type DTO.
     */
    private static ExpenseTypeDto toExpenseTypeDto(
        Expense_Type__mdt expenseType
    ) {
        ExpenseTypeDto dto =
            new ExpenseTypeDto();

        dto.developerName =
            expenseType.DeveloperName;

        dto.label =
            expenseType.MasterLabel;

        dto.calculationMethod =
            expenseType.Calculation_Method__c;

        dto.rate =
            expenseType.Rate__c;

        dto.distanceUnit =
            expenseType.Distance_Unit__c;

        dto.receiptRequired =
            expenseType.Receipt_Required__c;

        dto.maximumAmount =
            expenseType.Maximum_Amount__c;

        dto.descriptionRequired =
            expenseType.Description_Required__c;

        dto.sortOrder =
            expenseType.Sort_Order__c;

        return dto;
    }

    /**
     * Calculates the total claimed amount.
     *
     * @param items Expense Items.
     * @return Total claimed amount.
     */
    private static Decimal calculateTotal(
        List<Expense_Item__c> items
    ) {
        Decimal total =
            Decimal.valueOf('0');

        for (Expense_Item__c item : items) {
            if (item.Claimed_Amount__c != null) {
                total +=
                    item.Claimed_Amount__c;
            }
        }

        return total;
    }
}