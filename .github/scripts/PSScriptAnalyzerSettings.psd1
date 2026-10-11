@{
    # Correctness/security gates for runtime and CI code. Style-only legacy warnings are outside this explicit scope.
    IncludeRules = @(
        'PSAvoidUsingInvokeExpression'
        'PSAvoidUsingPlainTextForPassword'
        'PSAvoidUsingConvertToSecureStringWithPlainText'
        'PSAvoidUsingUsernameAndPasswordParams'
        'PSAvoidUsingAllowUnencryptedAuthentication'
        'PSAvoidUsingBrokenHashAlgorithms'
        'PSUsePSCredentialType'
        'PSAvoidAssignmentToAutomaticVariable'
        'PSMisleadingBacktick'
        'PSUseCompatibleSyntax'
    )
    Rules = @{
        PSUseCompatibleSyntax = @{ Enable = $true; TargetVersions = @('5.1', '7.0') }
    }
}
