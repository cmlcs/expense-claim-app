/**
 * Tests Expense Claim submission through the controller API.
 */
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class ExpenseClaimControllerSubmitTest {

    @IsTest
    static void submitClaimCreatesSubmittedClaimAndExpenseItem() {
        String expenseTypeCode =
            ExpenseClaimControllerTestFactory.findActiveAmountTypeCode();

        ExpenseClaimRequestDto request =
            ExpenseClaimControllerTestFactory.createRequest(
                expenseTypeCode,
                Decimal.valueOf('25.50')
            );

        Test.startTest();

        ExpenseClaimResponseDto response =
            ExpenseClaimController.submitClaim(
                request
            );

        Test.stopTest();

        System.assertNotEquals(
            null,
            response,
            'Submission should return a response.'
        );

        System.assertNotEquals(
            null,
            response.claimId,
            'The response should contain the persisted claim ID.'
        );

        System.assertEquals(
            'Submitted',
            response.status,
            'The submitted claim should have Submitted status.'
        );

        Expense_Claim__c claim = [
            SELECT
                Id,
                Name,
                Status__c,
                Claimant_User__c,
                Claimant_Name__c,
                Claimant_Email__c,
                Submitted_At__c,
                Total_Amount__c
            FROM Expense_Claim__c
            WHERE Id = :response.claimId
            WITH USER_MODE
            LIMIT 1
        ];

        System.assertEquals(
            'Submitted',
            claim.Status__c,
            'The persisted claim should have Submitted status.'
        );

        System.assertEquals(
            UserInfo.getUserId(),
            claim.Claimant_User__c,
            'The authenticated user should be snapshotted as the claimant.'
        );

        System.assertNotEquals(
            null,
            claim.Submitted_At__c,
            'Submission time should be populated by the server.'
        );

        List<Expense_Item__c> items = [
            SELECT
                Id,
                Expense_Claim__c,
                Expense_Date__c,
                Expense_Type_Code__c,
                Expense_Type_Label__c,
                Calculation_Method__c,
                Claimed_Amount__c,
                Distance__c,
                Distance_Unit__c,
                Unit_Rate__c,
                Receipt_Required__c
            FROM Expense_Item__c
            WHERE Expense_Claim__c = :claim.Id
            WITH USER_MODE
        ];

        System.assertEquals(
            1,
            items.size(),
            'One Expense Item should be created.'
        );

        System.assertEquals(
            expenseTypeCode,
            items[0].Expense_Type_Code__c,
            'The selected Expense Type code should be retained.'
        );

        System.assertEquals(
            Decimal.valueOf('25.50'),
            items[0].Claimed_Amount__c,
            'The claimant-entered amount should be persisted.'
        );
    }

    @IsTest
    static void clientCannotSpoofPolicySnapshot() {
        String expenseTypeCode =
            ExpenseClaimControllerTestFactory.findActiveAmountTypeWithoutRequiredReceipt();

        Expense_Type__mdt expenseType =
            ExpensePolicyService.getExpenseType(
                expenseTypeCode
            );

        ExpenseClaimRequestDto request =
            ExpenseClaimControllerTestFactory.createRequest(
                expenseTypeCode,
                Decimal.valueOf('42.00')
            );

        ExpenseItemDto requestItem =
            request.items[0];

        /*
         * These values are intentionally false. They represent fields that
         * must be derived from server-side policy rather than trusted from
         * the browser.
         */
        requestItem.expenseTypeLabel =
            'Spoofed label';

        requestItem.calculationMethod =
            'Distance';

        requestItem.unitRate =
            Decimal.valueOf('999.9999');

        requestItem.distanceUnit =
            'Miles';

        requestItem.receiptRequired =
            !expenseType.Receipt_Required__c;

        Test.startTest();

        ExpenseClaimResponseDto response =
            ExpenseClaimController.submitClaim(
                request
            );

        Test.stopTest();

        Expense_Item__c persistedItem = [
            SELECT
                Expense_Type_Code__c,
                Expense_Type_Label__c,
                Calculation_Method__c,
                Claimed_Amount__c,
                Distance__c,
                Distance_Unit__c,
                Unit_Rate__c,
                Receipt_Required__c
            FROM Expense_Item__c
            WHERE Expense_Claim__c = :response.claimId
            WITH USER_MODE
            LIMIT 1
        ];

        System.assertEquals(
            expenseTypeCode,
            persistedItem.Expense_Type_Code__c,
            'The selected Expense Type code should be retained.'
        );

        System.assertEquals(
            expenseType.Label,
            persistedItem.Expense_Type_Label__c,
            'The server should derive the Expense Type label from metadata.'
        );

        System.assertEquals(
            expenseType.Calculation_Method__c,
            persistedItem.Calculation_Method__c,
            'The server should derive the calculation method from policy.'
        );

        System.assertEquals(
            expenseType.Receipt_Required__c,
            persistedItem.Receipt_Required__c,
            'The server should derive the receipt requirement from policy.'
        );

        System.assertNotEquals(
            'Spoofed label',
            persistedItem.Expense_Type_Label__c,
            'A client-supplied label must not overwrite the server snapshot.'
        );

        System.assertNotEquals(
            Decimal.valueOf('999.9999'),
            persistedItem.Unit_Rate__c,
            'A client-supplied rate must not overwrite the server snapshot.'
        );

        System.assertNotEquals(
            'Miles',
            persistedItem.Distance_Unit__c,
            'A client-supplied distance unit must not overwrite server policy.'
        );
    }

    @IsTest
    static void submitClaimReturnsCalculatedTotal() {
        String expenseTypeCode =
            ExpenseClaimControllerTestFactory.findActiveAmountTypeCode();

        ExpenseClaimRequestDto request =
            ExpenseClaimControllerTestFactory.createRequest(
                expenseTypeCode,
                Decimal.valueOf('37.50')
            );

        Test.startTest();

        ExpenseClaimResponseDto response =
            ExpenseClaimController.submitClaim(
                request
            );

        Test.stopTest();

        System.assertEquals(
            Decimal.valueOf('37.50'),
            response.totalAmount,
            'The response should contain the total of the submitted items.'
        );
    }
}