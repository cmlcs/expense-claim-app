@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class ExpenseClaimServiceTest {

    @IsTest
    static void prepareForSubmissionSnapshotsClaimAndPolicy() {
        Expense_Claim__c claim =
            ExpenseClaimTestFactory.createDraftClaim();

        Expense_Item__c item =
            ExpenseClaimTestFactory.createAmountItem(
                'Meals',
                Decimal.valueOf('25.50'),
                Date.today()
            );

        List<Expense_Item__c> items =
            new List<Expense_Item__c>{ item };

        Datetime beforeSubmission =
            System.now();

        ExpenseClaimService.prepareForSubmission(
            claim,
            items
        );

        Datetime afterSubmission =
            System.now();

        System.assertEquals(
            'Submitted',
            claim.Status__c
        );

        System.assertNotEquals(
            null,
            claim.Submitted_At__c
        );

        System.assert(
            claim.Submitted_At__c >= beforeSubmission
        );

        System.assert(
            claim.Submitted_At__c <= afterSubmission
        );

        System.assertEquals(
            UserInfo.getUserId(),
            claim.Claimant_User__c
        );

        System.assertEquals(
            UserInfo.getName(),
            claim.Claimant_Name__c
        );

        System.assertEquals(
            UserInfo.getUserEmail(),
            claim.Claimant_Email__c
        );

        System.assertEquals(
            'Meals',
            item.Expense_Type_Code__c
        );

        System.assertEquals(
            'Meals',
            item.Expense_Type_Label__c
        );

        System.assertEquals(
            'Amount',
            item.Calculation_Method__c
        );

        System.assertEquals(
            Decimal.valueOf('25.50'),
            item.Claimed_Amount__c
        );
    }

    @IsTest
    static void prepareForSubmissionRejectsNonDraftClaim() {
        Expense_Claim__c claim =
            ExpenseClaimTestFactory.createDraftClaim();

        claim.Status__c =
            'Submitted';

        List<Expense_Item__c> items =
            new List<Expense_Item__c>{
                ExpenseClaimTestFactory.createAmountItem(
                    'Meals',
                    Decimal.valueOf('25'),
                    Date.today()
                )
            };

        try {
            ExpenseClaimService.prepareForSubmission(
                claim,
                items
            );

            System.assert(
                false,
                'Expected an ExpenseClaimException.'
            );
        } catch (
            ExpenseClaimService.ExpenseClaimException exceptionValue
        ) {
            System.assert(
                exceptionValue.getMessage().contains(
                    'Only a Draft'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void prepareForSubmissionRejectsEmptyClaim() {
        Expense_Claim__c claim =
            ExpenseClaimTestFactory.createDraftClaim();

        try {
            ExpenseClaimService.prepareForSubmission(
                claim,
                new List<Expense_Item__c>()
            );

            System.assert(
                false,
                'Expected an ExpenseClaimException.'
            );
        } catch (
            ExpenseClaimService.ExpenseClaimException exceptionValue
        ) {
            System.assert(
                exceptionValue.getMessage().contains(
                    'At least one Expense Item'
                ),
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void prepareForSubmissionRejectsMissingExpenseType() {
        Expense_Claim__c claim =
            ExpenseClaimTestFactory.createDraftClaim();

        Expense_Item__c item =
            new Expense_Item__c(
                Expense_Date__c = Date.today(),
                Claimed_Amount__c =
                    Decimal.valueOf('25')
            );

        try {
            ExpenseClaimService.prepareForSubmission(
                claim,
                new List<Expense_Item__c>{ item }
            );

            System.assert(
                false,
                'Expected an ExpenseClaimException.'
            );
        } catch (
            ExpenseClaimService.ExpenseClaimException exceptionValue
        ) {
            System.assert(
                exceptionValue.getMessage().contains(
                    'Expense Type must be selected'
                ),
                exceptionValue.getMessage()
            );
        }
    }
}