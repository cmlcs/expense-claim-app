@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class ExpenseClaimGuestSecurityTest {

    @IsTest
    static void normalizeEmailTrimsAndLowercases() {
        System.assertEquals(
            'volunteer@example.com',
            ExpenseClaimGuestSecurity.normalizeEmail(
                '  Volunteer@Example.COM  '
            )
        );

        System.assertEquals(
            null,
            ExpenseClaimGuestSecurity.normalizeEmail(
                '   '
            )
        );
    }

    @IsTest
    static void normalizeVerificationCodeAcceptsSixDigits() {
        System.assertEquals(
            '012345',
            ExpenseClaimGuestSecurity.normalizeVerificationCode(
                ' 012345 '
            )
        );

        System.assertEquals(
            null,
            ExpenseClaimGuestSecurity.normalizeVerificationCode(
                '12345'
            )
        );

        System.assertEquals(
            null,
            ExpenseClaimGuestSecurity.normalizeVerificationCode(
                '12A456'
            )
        );
    }

    @IsTest
    static void normalizeAccessTokenAcceptsSixtyFourHexCharacters() {
        String token =
            ExpenseClaimGuestSecurity.generateRandomHexToken();

        System.assertEquals(
            token,
            ExpenseClaimGuestSecurity.normalizeAccessToken(
                ' ' + token + ' '
            )
        );

        System.assertEquals(
            null,
            ExpenseClaimGuestSecurity.normalizeAccessToken(
                'not-a-valid-token'
            )
        );
    }

    @IsTest
    static void generateVerificationCodeCreatesSixDigits() {
        String code =
            ExpenseClaimGuestSecurity.generateVerificationCode();

        System.assertEquals(
            6,
            code.length()
        );

        System.assert(
            Pattern.matches(
                '^\\d{6}$',
                code
            ),
            'Verification code should contain exactly six digits.'
        );
    }

    @IsTest
    static void generateRandomHexTokenCreatesUniqueTokens() {
        String firstToken =
            ExpenseClaimGuestSecurity.generateRandomHexToken();

        String secondToken =
            ExpenseClaimGuestSecurity.generateRandomHexToken();

        System.assertEquals(
            64,
            firstToken.length()
        );

        System.assert(
            Pattern.matches(
                '^[0-9a-fA-F]{64}$',
                firstToken
            ),
            'Token should contain 64 hexadecimal characters.'
        );

        System.assertNotEquals(
            firstToken,
            secondToken,
            'Random tokens should not be identical.'
        );
    }

    @IsTest
    static void hashValueIsDeterministic() {
        String firstHash =
            ExpenseClaimGuestSecurity.hashValue(
                'example'
            );

        String secondHash =
            ExpenseClaimGuestSecurity.hashValue(
                'example'
            );

        String differentHash =
            ExpenseClaimGuestSecurity.hashValue(
                'different'
            );

        System.assertEquals(
            64,
            firstHash.length()
        );

        System.assertEquals(
            firstHash,
            secondHash
        );

        System.assertNotEquals(
            firstHash,
            differentHash
        );
    }

    @IsTest
    static void verificationHashIncludesSalt() {
        String firstHash =
            ExpenseClaimGuestSecurity.hashVerificationCode(
                '123456',
                'salt-one'
            );

        String secondHash =
            ExpenseClaimGuestSecurity.hashVerificationCode(
                '123456',
                'salt-two'
            );

        System.assertNotEquals(
            firstHash,
            secondHash,
            'The same verification code should hash differently with different salts.'
        );
    }

    @IsTest
    static void integerValueHandlesNullAndDecimal() {
        System.assertEquals(
            0,
            ExpenseClaimGuestSecurity.integerValue(
                null
            )
        );

        System.assertEquals(
            7,
            ExpenseClaimGuestSecurity.integerValue(
                Decimal.valueOf('7')
            )
        );
    }
}