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
            claim.Claimant_User__c,
            'Authenticated submissions should snapshot the running user.'
        );

        System.assertEquals(
            null,
            claim.Claimant_Contact__c,
            'Authenticated submissions should not snapshot a Contact claimant.'
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
    static void prepareForGuestSubmissionSnapshotsContactIdentity() {
        Contact claimantContact =
            new Contact(
                FirstName = 'Guest',
                LastName = 'Volunteer',
                Email = 'guest.volunteer@example.com'
            );

        insert claimantContact;

        claimantContact = [
            SELECT
                Id,
                Name,
                Email
            FROM Contact
            WHERE Id = :claimantContact.Id
            LIMIT 1
        ];

        Expense_Claim__c claim =
            ExpenseClaimTestFactory.createDraftClaim();

        /*
         * Populate values that must not survive guest preparation.
         * This proves the service replaces claimant identity using the
         * verified Contact rather than trusting pre-existing values.
         */
        claim.Claimant_User__c =
            UserInfo.getUserId();

        claim.Claimant_Name__c =
            'Spoofed Name';

        claim.Claimant_Email__c =
            'spoofed@example.com';

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

        ExpenseClaimService.prepareForGuestSubmission(
            claim,
            items,
            claimantContact
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
            null,
            claim.Claimant_User__c,
            'Guest submissions must not identify the site Guest User as the claimant.'
        );

        System.assertEquals(
            claimantContact.Id,
            claim.Claimant_Contact__c,
            'Guest submissions should snapshot the verified Contact.'
        );

        System.assertEquals(
            claimantContact.Name,
            claim.Claimant_Name__c,
            'Claimant name should come from the verified Contact.'
        );

        System.assertEquals(
            claimantContact.Email,
            claim.Claimant_Email__c,
            'Claimant email should come from the verified Contact.'
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
    static void prepareForGuestSubmissionRejectsMissingContact() {
        Expense_Claim__c claim =
            ExpenseClaimTestFactory.createDraftClaim();

        Expense_Item__c item =
            ExpenseClaimTestFactory.createAmountItem(
                'Meals',
                Decimal.valueOf('25'),
                Date.today()
            );

        try {
            ExpenseClaimService.prepareForGuestSubmission(
                claim,
                new List<Expense_Item__c>{ item },
                null
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
                    'verified claimant Contact'
                ),
                exceptionValue.getMessage()
            );
        }
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