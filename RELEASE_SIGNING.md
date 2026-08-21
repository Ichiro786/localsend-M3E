# LocalSend M3E Release Signing

LocalSend M3E uses the unique Android application ID `com.localsend.m3e`. The visible application label remains **LocalSend**. Because the application ID differs from the official LocalSend application ID (`org.localsend.localsend_app`), Android treats M3E as a separate installable application and the two packages can coexist on the same device.

## Final v1.0.0 identity

The first public M3E release uses version name **1.0.0** and Android versionCode **64**. The previous M3E build used versionCode 63, so 64 preserves normal update ordering. Gradle namespace, manifest package metadata, and app-owned Kotlin packages are aligned to `com.localsend.m3e`; Dart package/import names and the existing Flutter method-channel identifier remain unchanged.

The public Android release contains only these split APKs:

| Architecture | Artifact |
| --- | --- |
| ARM64 | `LocalSend-1.0.0-arm64-v8a.apk` |
| ARMv7 | `LocalSend-1.0.0-armeabi-v7a.apk` |

The Android production workflow is manually dispatched from the verified `main` branch. It validates `1.0.0+64`, builds and verifies both Android APKs, creates tag `v1.0.0` only after verification succeeds, and then publishes the matching GitHub Release.

## Production signing inputs

The release workflows use two GitHub Actions secrets:

| Secret | Required content |
| --- | --- |
| `ANDROID_KEY_PROPERTIES` | Base64-encoded contents of the Android `key.properties` file. |
| `ANDROID_KEY_STORE` | Base64-encoded binary keystore file, such as `.jks` or `.keystore`. |

The decoded `key.properties` file must contain the signing alias and passwords expected by `app/android/app/build.gradle`. Its `storeFile` value is rewritten by the release workflow to the temporary CI path of the decoded keystore, so the maintainer’s local filesystem path does not need to be portable.

A typical local `key.properties` file has this shape, but real passwords and paths must never be copied into the repository:

```properties
storePassword=<keystore-password>
keyPassword=<key-password>
keyAlias=<release-alias>
storeFile=<local-keystore-path>
```

To create the secret values, encode the files locally and paste the resulting strings into the repository’s Actions secrets. Do not print the encoded values in logs, issues, pull requests, or committed files.

```bash
base64 -w 0 app/android/key.properties
base64 -w 0 /secure/path/localsend-m3e-release.jks
```

## Workflow behavior

`.github/workflows/android-release.yml` is the **canonical Phase 5 production release workflow**. It is manually dispatched from `main`, requires both encrypted signing secrets before any Android build, decodes them only inside the CI runner, builds only ARM64 and ARMv7 release APKs, verifies their certificates and installability-related package structure, creates tag `v1.0.0` only after all checks pass, uploads exactly the two expected APK assets, and publishes the matching GitHub Release last.

`.github/workflows/phase4-release-apk.yml` is a legacy/manual validation workflow and is not the final release mechanism. It is also fail-closed and cannot create an unsigned APK when signing credentials are missing. It must not be used instead of the canonical production workflow.

The release checks verify the following conditions:

1. The package identity is `com.localsend.m3e`.
2. The visible application label is `LocalSend`.
3. The official package identity is not present in the generated APK.
4. The ARM64 and ARMv7 split release APKs are produced with no x86 or x86_64 libraries.
5. Each APK has exactly one verified signing certificate and is not debug-signed.
6. No unsigned `base.apk` is accepted as a release artifact.
7. Temporary signing files are removed at the end of the CI job.
8. The GitHub Release is published only after both verified Android assets and all required release jobs succeed.

## Update and installation policy

A production update is installable only when it has the same application ID and is signed with the same release key as the previously published M3E build. Changing the application ID or release key creates a different Android application and requires a fresh installation rather than an in-place update. The first M3E release should therefore establish `com.localsend.m3e` as the permanent package identity.

## Security requirements

Never commit a private keystore, signing certificate with private material, password, `key.properties`, or encoded secret value. The repository must contain only this documentation and the workflow logic. Store production signing material in a restricted password manager and GitHub Actions encrypted secrets, and rotate the key only through a planned Android migration process because an unrecoverable signing-key change prevents normal updates.

## Maintainer release checklist

Before publishing a signed release, confirm that the two Actions secrets are configured, the canonical `.github/workflows/android-release.yml` completes successfully from `main`, `apksigner` verifies both APKs against the permanent certificate, the generated APKs report `com.localsend.m3e`, `LocalSend`, version `1.0.0`, and ABI version codes `642` and `643`, and the ARM64 release artifact is measured against another ARM64 **release** artifact rather than a debug build. Real-device installation, update, coexistence, and transfer testing remain required before public distribution.
