@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class ExpenseClaimGuestControllerTest {

    private static final String VERIFICATION_CODE =
        '123456';

    private static final String VERIFICATION_REQUEST_MESSAGE =
        'If this email belongs to an eligible volunteer, a verification code has been sent.';

    @IsTest
    static void requestVerificationReturnsGenericResponseForKnownEmail() {
        Contact claimant =
            createContact(
                'known@example.com'
            );

        Test.startTest();

        String response =
            ExpenseClaimGuestController.requestVerification(
                claimant.Email
            );

        Test.stopTest();

        System.assertEquals(
            VERIFICATION_REQUEST_MESSAGE,
            response,
            'Known email addresses should receive the generic response.'
        );

        Integer accessCount = [
            SELECT COUNT()
            FROM Expense_Claim_Access__c
            WHERE Contact__c = :claimant.Id
            WITH SYSTEM_MODE
        ];

        System.assertEquals(
            1,
            accessCount,
            'A valid Contact should create a verification request.'
        );
    }

    @IsTest
    static void requestVerificationReturnsGenericResponseForUnknownEmail() {
        Test.startTest();

        String response =
            ExpenseClaimGuestController.requestVerification(
                'unknown@example.com'
            );

        Test.stopTest();

        System.assertEquals(
            VERIFICATION_REQUEST_MESSAGE,
            response,
            'Unknown email addresses must receive the same public response.'
        );

        Integer accessCount = [
            SELECT COUNT()
            FROM Expense_Claim_Access__c
            WITH SYSTEM_MODE
        ];

        System.assertEquals(
            0,
            accessCount,
            'Unknown email addresses should not create access records.'
        );
    }

    @IsTest
    static void verifyCodeReturnsAccessToken() {
        Contact claimant =
            createContact(
                'verify@example.com'
            );

        createPendingAccess(
            claimant,
            VERIFICATION_CODE
        );

        Test.startTest();

        String accessToken =
            ExpenseClaimGuestController.verifyCode(
                claimant.Email,
                VERIFICATION_CODE
            );

        Test.stopTest();

        System.assertEquals(
            64,
            accessToken.length()
        );

        System.assert(
            Pattern.matches(
                '^[0-9a-fA-F]{64}$',
                accessToken
            ),
            'Verified claimants should receive a 64-character hexadecimal access token.'
        );
    }

    @IsTest
    static void verifyCodeRejectsInvalidCode() {
        Contact claimant =
            createContact(
                'invalid-code@example.com'
            );

        createPendingAccess(
            claimant,
            VERIFICATION_CODE
        );

        try {
            ExpenseClaimGuestController.verifyCode(
                claimant.Email,
                '654321'
            );

            System.assert(
                false,
                'Expected an AuraHandledException.'
            );
        } catch (
            AuraHandledException exceptionValue
        ) {
            System.assertEquals(
                'The verification code is invalid or has expired.',
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void getConfigurationUsesVerifiedContactIdentity() {
        Contact claimant =
            createContact(
                'configuration@example.com'
            );

        String accessToken =
            createVerifiedAccessToken(
                claimant
            );

        Test.startTest();

        ExpenseClaimConfigurationDto configuration =
            ExpenseClaimGuestController.getConfiguration(
                accessToken
            );

        Test.stopTest();

        System.assertNotEquals(
            null,
            configuration,
            'Configuration should be returned for a verified guest.'
        );

        System.assertEquals(
            claimant.Name,
            configuration.claimantName,
            'Guest claimant name must come from the verified Contact.'
        );

        System.assertEquals(
            claimant.Email,
            configuration.claimantEmail,
            'Guest claimant email must come from the verified Contact.'
        );

        System.assertNotEquals(
            null,
            configuration.expenseTypes,
            'Configuration should contain the active Expense Types.'
        );

        System.assert(
            !configuration.expenseTypes.isEmpty(),
            'At least one active Expense Type should be available.'
        );
    }

    @IsTest
    static void getConfigurationRejectsInvalidAccessToken() {
        String invalidToken =
            ExpenseClaimGuestSecurity.generateRandomHexToken();

        try {
            ExpenseClaimGuestController.getConfiguration(
                invalidToken
            );

            System.assert(
                false,
                'Expected an AuraHandledException.'
            );
        } catch (
            AuraHandledException exceptionValue
        ) {
            System.assertEquals(
                'The guest access session is invalid or has expired.',
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void createReceiptUploadKeyRequiresVerifiedAccess() {
        Contact claimant =
            createContact(
                'receipt@example.com'
            );

        String accessToken =
            createVerifiedAccessToken(
                claimant
            );

        Test.startTest();

        String receiptUploadKey =
            ExpenseClaimGuestController.createReceiptUploadKey(
                accessToken
            );

        Test.stopTest();

        System.assertEquals(
            64,
            receiptUploadKey.length()
        );

        System.assert(
            Pattern.matches(
                '^[0-9a-fA-F]{64}$',
                receiptUploadKey
            ),
            'Receipt upload key should contain 64 hexadecimal characters.'
        );
    }

    @IsTest
    static void createReceiptUploadKeyRejectsInvalidAccessToken() {
        String invalidToken =
            ExpenseClaimGuestSecurity.generateRandomHexToken();

        try {
            ExpenseClaimGuestController.createReceiptUploadKey(
                invalidToken
            );

            System.assert(
                false,
                'Expected an AuraHandledException.'
            );
        } catch (
            AuraHandledException exceptionValue
        ) {
            System.assertEquals(
                'The guest access session is invalid or has expired.',
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void applyPolicyReturnsServerPolicyForVerifiedGuest() {
        Contact claimant =
            createContact(
                'policy@example.com'
            );

        String accessToken =
            createVerifiedAccessToken(
                claimant
            );

        String expenseTypeCode =
            findActiveAmountTypeCode();

        Expense_Item__c sourceItem =
            new Expense_Item__c(
                Expense_Date__c =
                    Date.today(),
                Expense_Type_Code__c =
                    expenseTypeCode,
                Claimed_Amount__c =
                    Decimal.valueOf('25.50')
            );

        ExpenseItemDto itemDto =
            ExpenseClaimDtoMapper.toExpenseItemDto(
                sourceItem
            );

        Test.startTest();

        ExpenseItemDto result =
            ExpenseClaimGuestController.applyPolicy(
                accessToken,
                itemDto
            );

        Test.stopTest();

        System.assertNotEquals(
            null,
            result
        );

        System.assertEquals(
            expenseTypeCode,
            result.expenseTypeCode,
            'The selected Expense Type should be retained.'
        );

        System.assertEquals(
            'Amount',
            result.calculationMethod,
            'Calculation method should be derived from server policy.'
        );

        System.assertNotEquals(
            null,
            result.expenseTypeLabel,
            'Expense Type label should be derived from server policy.'
        );
    }

    @IsTest
    static void applyPolicyRejectsInvalidAccessToken() {
        String invalidToken =
            ExpenseClaimGuestSecurity.generateRandomHexToken();

        Expense_Item__c sourceItem =
            new Expense_Item__c(
                Expense_Date__c =
                    Date.today(),
                Expense_Type_Code__c =
                    findActiveAmountTypeCode(),
                Claimed_Amount__c =
                    Decimal.valueOf('25')
            );

        ExpenseItemDto itemDto =
            ExpenseClaimDtoMapper.toExpenseItemDto(
                sourceItem
            );

        try {
            ExpenseClaimGuestController.applyPolicy(
                invalidToken,
                itemDto
            );

            System.assert(
                false,
                'Expected an AuraHandledException.'
            );
        } catch (
            AuraHandledException exceptionValue
        ) {
            System.assertEquals(
                'The guest access session is invalid or has expired.',
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void applyPolicyRejectsMissingExpenseItem() {
        Contact claimant =
            createContact(
                'missing-item@example.com'
            );

        String accessToken =
            createVerifiedAccessToken(
                claimant
            );

        try {
            ExpenseClaimGuestController.applyPolicy(
                accessToken,
                null
            );

            System.assert(
                false,
                'Expected an AuraHandledException.'
            );
        } catch (
            AuraHandledException exceptionValue
        ) {
            System.assertEquals(
                'An Expense Item must be provided.',
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void submitClaimCreatesClaimForVerifiedContact() {
        Contact claimant =
            createContact(
                'submit@example.com'
            );

        String accessToken =
            createVerifiedAccessToken(
                claimant
            );

        String expenseTypeCode =
            ExpenseClaimControllerTestFactory.findActiveAmountTypeWithoutRequiredReceipt();

        ExpenseClaimRequestDto request =
            ExpenseClaimControllerTestFactory.createRequest(
                expenseTypeCode,
                Decimal.valueOf('37.50')
            );

        Test.startTest();

        ExpenseClaimResponseDto response =
            ExpenseClaimGuestController.submitClaim(
                accessToken,
                request
            );

        Test.stopTest();

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
                Status__c,
                Claimant_User__c,
                Claimant_Contact__c,
                Claimant_Name__c,
                Claimant_Email__c,
                Submitted_At__c,
                Total_Amount__c
            FROM Expense_Claim__c
            WHERE Id = :response.claimId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        System.assertEquals(
            'Submitted',
            storedClaim.Status__c
        );

        System.assertEquals(
            null,
            storedClaim.Claimant_User__c,
            'Guest claims must not snapshot the guest User.'
        );

        System.assertEquals(
            claimant.Id,
            storedClaim.Claimant_Contact__c
        );

        System.assertEquals(
            claimant.Name,
            storedClaim.Claimant_Name__c
        );

        System.assertEquals(
            claimant.Email,
            storedClaim.Claimant_Email__c
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
    static void successfulSubmissionConsumesAccessToken() {
        Contact claimant =
            createContact(
                'consume@example.com'
            );

        String accessToken =
            createVerifiedAccessToken(
                claimant
            );

        String expenseTypeCode =
            ExpenseClaimControllerTestFactory.findActiveAmountTypeWithoutRequiredReceipt();

        ExpenseClaimRequestDto request =
            ExpenseClaimControllerTestFactory.createRequest(
                expenseTypeCode,
                Decimal.valueOf('20')
            );

        ExpenseClaimGuestController.submitClaim(
            accessToken,
            request
        );

        Expense_Claim_Access__c accessRecord = [
            SELECT
                Status__c,
                Access_Token_Hash__c,
                Access_Expires_At__c
            FROM Expense_Claim_Access__c
            WHERE Contact__c = :claimant.Id
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        System.assertEquals(
            'Used',
            accessRecord.Status__c
        );

        System.assertEquals(
            null,
            accessRecord.Access_Token_Hash__c
        );

        System.assertEquals(
            null,
            accessRecord.Access_Expires_At__c
        );
    }

    @IsTest
    static void usedAccessTokenCannotSubmitSecondClaim() {
        Contact claimant =
            createContact(
                'single-use@example.com'
            );

        String accessToken =
            createVerifiedAccessToken(
                claimant
            );

        String expenseTypeCode =
            ExpenseClaimControllerTestFactory.findActiveAmountTypeWithoutRequiredReceipt();

        ExpenseClaimRequestDto request =
            ExpenseClaimControllerTestFactory.createRequest(
                expenseTypeCode,
                Decimal.valueOf('15')
            );

        ExpenseClaimGuestController.submitClaim(
            accessToken,
            request
        );

        try {
            ExpenseClaimGuestController.submitClaim(
                accessToken,
                request
            );

            System.assert(
                false,
                'A used guest token must not allow another submission.'
            );
        } catch (AuraHandledException exceptionValue) {
            System.assertEquals(
                'The guest access session is invalid or has expired.',
                exceptionValue.getMessage()
            );
        }

        Integer claimCount = [
            SELECT COUNT()
            FROM Expense_Claim__c
            WHERE Claimant_Contact__c = :claimant.Id
            WITH SYSTEM_MODE
        ];

        System.assertEquals(
            1,
            claimCount
        );
    }

    @IsTest
    static void submitClaimRejectsInvalidAccessToken() {
        String invalidToken =
            ExpenseClaimGuestSecurity.generateRandomHexToken();

        String expenseTypeCode =
            ExpenseClaimControllerTestFactory.findActiveAmountTypeWithoutRequiredReceipt();

        ExpenseClaimRequestDto request =
            ExpenseClaimControllerTestFactory.createRequest(
                expenseTypeCode,
                Decimal.valueOf('25')
            );

        try {
            ExpenseClaimGuestController.submitClaim(
                invalidToken,
                request
            );

            System.assert(
                false,
                'Expected an AuraHandledException.'
            );
        } catch (AuraHandledException exceptionValue) {
            System.assertEquals(
                'The guest access session is invalid or has expired.',
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void submitClaimRejectsMissingRequest() {
        Contact claimant =
            createContact(
                'missing-request@example.com'
            );

        String accessToken =
            createVerifiedAccessToken(
                claimant
            );

        try {
            ExpenseClaimGuestController.submitClaim(
                accessToken,
                null
            );

            System.assert(
                false,
                'Expected an AuraHandledException.'
            );
        } catch (AuraHandledException exceptionValue) {
            System.assertEquals(
                'Expense claim request is required.',
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void submitClaimRejectsRequestWithoutItems() {
        Contact claimant =
            createContact(
                'missing-items@example.com'
            );

        String accessToken =
            createVerifiedAccessToken(
                claimant
            );

        ExpenseClaimRequestDto request =
            new ExpenseClaimRequestDto();

        request.description =
            'Guest claim without items';

        request.items =
            new List<ExpenseItemDto>();

        try {
            ExpenseClaimGuestController.submitClaim(
                accessToken,
                request
            );

            System.assert(
                false,
                'Expected an AuraHandledException.'
            );
        } catch (AuraHandledException exceptionValue) {
            System.assertEquals(
                'At least one Expense Item is required.',
                exceptionValue.getMessage()
            );
        }
    }

    @IsTest
    static void failedSubmissionLeavesAccessTokenVerified() {
        Contact claimant =
            createContact(
                'rollback@example.com'
            );

        String accessToken =
            createVerifiedAccessToken(
                claimant
            );

        /*
        * Create a request that will fail during claim processing.
        * An inactive or unknown Expense Type is useful here because the
        * access record will already have been marked Used before policy
        * validation fails.
        */
        ExpenseClaimRequestDto request =
            ExpenseClaimControllerTestFactory.createRequest(
                'NotARealExpenseType',
                Decimal.valueOf('25')
            );

        try {
            ExpenseClaimGuestController.submitClaim(
                accessToken,
                request
            );

            System.assert(
                false,
                'Expected submission to fail.'
            );
        } catch (AuraHandledException exceptionValue) {
            System.assertNotEquals(
                null,
                exceptionValue.getMessage()
            );
        }

        Expense_Claim_Access__c accessRecord = [
            SELECT
                Status__c,
                Access_Token_Hash__c,
                Access_Expires_At__c
            FROM Expense_Claim_Access__c
            WHERE Contact__c = :claimant.Id
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        System.assertEquals(
            'Verified',
            accessRecord.Status__c,
            'Failed submission must roll back the Used status.'
        );

        System.assertNotEquals(
            null,
            accessRecord.Access_Token_Hash__c,
            'Failed submission must restore the token hash.'
        );

        System.assertNotEquals(
            null,
            accessRecord.Access_Expires_At__c,
            'Failed submission must restore the token expiry.'
        );

        Integer claimCount = [
            SELECT COUNT()
            FROM Expense_Claim__c
            WHERE Claimant_Contact__c = :claimant.Id
            WITH SYSTEM_MODE
        ];

        System.assertEquals(
            0,
            claimCount,
            'Failed submission must not leave a partial Expense Claim.'
        );
    }

    private static Contact createContact(
        String email
    ) {
        Contact claimant =
            new Contact(
                FirstName =
                    'Guest',
                LastName =
                    'Volunteer',
                Email =
                    email
            );

        insert claimant;

        return [
            SELECT
                Id,
                Name,
                Email
            FROM Contact
            WHERE Id = :claimant.Id
            LIMIT 1
        ];
    }

    private static String createVerifiedAccessToken(
        Contact claimant
    ) {
        createPendingAccess(
            claimant,
            VERIFICATION_CODE
        );

        return ExpenseClaimGuestController.verifyCode(
            claimant.Email,
            VERIFICATION_CODE
        );
    }

    private static Expense_Claim_Access__c createPendingAccess(
        Contact claimant,
        String verificationCode
    ) {
        String normalizedEmail =
            ExpenseClaimGuestSecurity.normalizeEmail(
                claimant.Email
            );

        String salt =
            ExpenseClaimGuestSecurity.generateRandomHexToken();

        Expense_Claim_Access__c accessRecord =
            new Expense_Claim_Access__c(
                Contact__c =
                    claimant.Id,
                Email_Hash__c =
                    ExpenseClaimGuestSecurity.hashValue(
                        normalizedEmail
                    ),
                Verification_Code_Hash__c =
                    ExpenseClaimGuestSecurity.hashVerificationCode(
                        verificationCode,
                        salt
                    ),
                Verification_Salt__c =
                    salt,
                Verification_Expires_At__c =
                    System.now().addMinutes(
                        10
                    ),
                Verification_Attempts__c =
                    0,
                Last_Code_Sent_At__c =
                    System.now(),
                Code_Send_Count__c =
                    1,
                Status__c =
                    'Pending'
            );

        ExpenseClaimGuestAccessRepository.save(
            accessRecord
        );

        return accessRecord;
    }

    private static String findActiveAmountTypeCode() {
        for (
            Expense_Type__mdt expenseType :
            ExpensePolicyService.getActiveExpenseTypes()
        ) {
            if (
                expenseType.Calculation_Method__c ==
                'Amount'
            ) {
                return expenseType.DeveloperName;
            }
        }

        System.assert(
            false,
            'The test requires an active Amount Expense Type.'
        );

        return null;
    }
}