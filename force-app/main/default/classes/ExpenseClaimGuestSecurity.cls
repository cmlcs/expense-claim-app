/**
 * Provides normalization, hashing, and random-value utilities for
 * unauthenticated Expense Claim access.
 */
public inherited sharing class ExpenseClaimGuestSecurity {

    private static final String VERIFICATION_CODE_PATTERN =
        '^\\d{6}$';

    private static final String ACCESS_TOKEN_PATTERN =
        '^[0-9a-fA-F]{64}$';

    /**
     * Normalizes an email address for matching and hashing.
     *
     * @param email Email address.
     * @return Trimmed lowercase email, or null.
     */
    public static String normalizeEmail(
        String email
    ) {
        if (String.isBlank(email)) {
            return null;
        }

        return email.trim().toLowerCase();
    }

    /**
     * Normalizes and validates a six-digit verification code.
     *
     * @param verificationCode Verification code.
     * @return Normalized code, or null when invalid.
     */
    public static String normalizeVerificationCode(
        String verificationCode
    ) {
        if (String.isBlank(verificationCode)) {
            return null;
        }

        String normalizedCode =
            verificationCode.trim();

        if (
            !Pattern.matches(
                VERIFICATION_CODE_PATTERN,
                normalizedCode
            )
        ) {
            return null;
        }

        return normalizedCode;
    }

    /**
     * Normalizes and validates an access token.
     *
     * @param accessToken Guest access token.
     * @return Normalized token, or null when invalid.
     */
    public static String normalizeAccessToken(
        String accessToken
    ) {
        if (String.isBlank(accessToken)) {
            return null;
        }

        String normalizedToken =
            accessToken.trim();

        if (
            !Pattern.matches(
                ACCESS_TOKEN_PATTERN,
                normalizedToken
            )
        ) {
            return null;
        }

        return normalizedToken;
    }

    /**
     * Generates a six-digit verification code.
     *
     * @return Six-digit verification code.
     */
    public static String generateVerificationCode() {
        Long codeValue =
            Math.mod(
                Crypto.getRandomLong(),
                1000000
            );

        if (codeValue < 0) {
            codeValue =
                -codeValue;
        }

        String code =
            String.valueOf(
                codeValue
            );

        while (code.length() < 6) {
            code =
                '0' + code;
        }

        return code;
    }

    /**
     * Generates a cryptographically random 256-bit hexadecimal value.
     *
     * @return 64-character hexadecimal value.
     */
    public static String generateRandomHexToken() {
        return EncodingUtil.convertToHex(
            Crypto.generateAesKey(
                256
            )
        );
    }

    /**
     * Hashes a verification code together with its random salt.
     *
     * @param verificationCode Verification code.
     * @param salt Random salt.
     * @return SHA-256 hexadecimal digest.
     */
    public static String hashVerificationCode(
        String verificationCode,
        String salt
    ) {
        return hashValue(
            salt +
            ':' +
            verificationCode
        );
    }

    /**
     * Produces a SHA-256 digest of a string.
     *
     * @param value Value to hash.
     * @return SHA-256 hexadecimal digest.
     */
    public static String hashValue(
        String value
    ) {
        Blob digest =
            Crypto.generateDigest(
                'SHA-256',
                Blob.valueOf(
                    value
                )
            );

        return EncodingUtil.convertToHex(
            digest
        );
    }

    /**
     * Converts a nullable Decimal counter to an Integer.
     *
     * @param value Counter value.
     * @return Integer value, or zero when null.
     */
    public static Integer integerValue(
        Decimal value
    ) {
        if (value == null) {
            return 0;
        }

        return value.intValue();
    }
}