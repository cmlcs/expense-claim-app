@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class ExpenseClaimControllerSubmitTest {

    @IsTest
    static void submitClaimPersistsClaimAndItem() {
        String expenseTypeCode =
            ExpenseClaimControllerTestFactory.findActiveAmountTypeCode();

        System.assertNotEquals(
            null,
            expenseTypeCode,
            'Test requires an active amount-based Expense Type.'
        );

        ExpenseClaimRequestDto request =
            ExpenseClaimControllerTestFactory.createRequest(
                expenseTypeCode,
                Decimal.valueOf('37.50')
            );

        ExpenseClaimResponseDto response =
            ExpenseClaimController.submitClaim(
                request
            );

        System.assertNotEquals(
            null,
            response.claimId
        );

        System.assertEquals(
            'Submitted',
            response.status
        );

        System.assertEquals(
            Decimal.valueOf('37.50'),
            response.totalAmount
        );

        Expense_Claim__c storedClaim = [
            SELECT
                Id,
                Status__c,
                Claimant_User__c,
                Submitted_At__c,
                Total_Amount__c
            FROM Expense_Claim__c
            WHERE Id = :response.claimId
            WITH USER_MODE
        ];

        System.assertEquals(
            'Submitted',
            storedClaim.Status__c
        );

        System.assertEquals(
            UserInfo.getUserId(),
            storedClaim.Claimant_User__c
        );

        System.assertNotEquals(
            null,
            storedClaim.Submitted_At__c
        );

        System.assertEquals(
            Decimal.valueOf('37.50'),
            storedClaim.Total_Amount__c
        );
    }

    @IsTest
    static void clientCannotSpoofPolicySnapshot() {
        String expenseTypeCode =
            ExpenseClaimControllerTestFactory.findActiveAmountTypeCode();

        System.assertNotEquals(
            null,
            expenseTypeCode,
            'Test requires an active amount-based Expense Type.'
        );

        ExpenseClaimRequestDto request =
            ExpenseClaimControllerTestFactory.createRequest(
                expenseTypeCode,
                Decimal.valueOf('20')
            );

        ExpenseItemDto clientItem =
            request.items[0];

        clientItem.expenseTypeLabel =
            'Fake Type';

        clientItem.calculationMethod =
            'Distance';

        clientItem.distanceUnit =
            'Miles';

        clientItem.unitRate =
            Decimal.valueOf('999');

        clientItem.receiptRequired =
            true;

        ExpenseClaimResponseDto response =
            ExpenseClaimController.submitClaim(
                request
            );

        List<Expense_Item__c> storedItems = [
            SELECT
                Expense_Type_Code__c,
                Expense_Type_Label__c,
                Calculation_Method__c,
                Claimed_Amount__c,
                Distance_Unit__c,
                Unit_Rate__c
            FROM Expense_Item__c
            WHERE Expense_Claim__c = :response.claimId
            WITH USER_MODE
        ];

        System.assertEquals(
            1,
            storedItems.size()
        );

        Expense_Item__c storedItem =
            storedItems[0];

        System.assertEquals(
            expenseTypeCode,
            storedItem.Expense_Type_Code__c
        );

        System.assertEquals(
            'Amount',
            storedItem.Calculation_Method__c
        );

        System.assertEquals(
            Decimal.valueOf('20'),
            storedItem.Claimed_Amount__c
        );

        System.assertEquals(
            null,
            storedItem.Distance_Unit__c
        );

        System.assertEquals(
            null,
            storedItem.Unit_Rate__c
        );

        System.assertNotEquals(
            'Fake Type',
            storedItem.Expense_Type_Label__c
        );
    }

    @IsTest
    static void nullRequestIsRejected() {
        AuraHandledException exceptionValue;

        try {
            ExpenseClaimController.submitClaim(
                null
            );
        } catch (AuraHandledException caughtException) {
            exceptionValue =
                caughtException;
        }

        System.assertNotEquals(
            null,
            exceptionValue,
            'Expected a handled client exception.'
        );
    }

    @IsTest
    static void emptyClaimIsRejected() {
        ExpenseClaimRequestDto request =
            new ExpenseClaimRequestDto();

        request.items =
            new List<ExpenseItemDto>();

        AuraHandledException exceptionValue;

        try {
            ExpenseClaimController.submitClaim(
                request
            );
        } catch (AuraHandledException caughtException) {
            exceptionValue =
                caughtException;
        }

        System.assertNotEquals(
            null,
            exceptionValue,
            'Expected a handled client exception.'
        );
    }
}