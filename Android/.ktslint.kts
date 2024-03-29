val ktlint by lazy { rootProject.file("buildSrc/src/main/kotlin/ktlint.gradle.kts") }

importPlugins(ktlint)

ktlintRulesConfig {
    rule(WildcardImportRule::class) {
        disabled = true
    }
}
