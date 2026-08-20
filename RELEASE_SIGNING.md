# LocalSend M3E Release Signing

LocalSend M3E uses the unique Android application ID `com.localsend.m3e`. The visible application label remains **LocalSend**. Because the application ID differs from the official LocalSend application ID (`org.localsend.localsend_app`), Android treats M3E as a separate installable application and the two packages can coexist on the same device.

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

The existing production release workflow remains responsible for signed split-per-ABI release builds. The Phase 4 workflow is manually dispatched and uses the same two secrets when available. If either secret is absent, it intentionally performs an **unsigned release build for size and package-identity validation only**; that output is not a production release and must not be distributed as a signed update.

The release checks verify the following conditions:

1. The package identity is `com.localsend.m3e`.
2. The visible application label is `LocalSend`.
3. The official package identity is not present in the generated APK.
4. The ARM64 split APK and universal release APK are produced.
5. Temporary signing files are removed at the end of the CI job.

## Update and installation policy

A production update is installable only when it has the same application ID and is signed with the same release key as the previously published M3E build. Changing the application ID or release key creates a different Android application and requires a fresh installation rather than an in-place update. The first M3E release should therefore establish `com.localsend.m3e` as the permanent package identity.

## Security requirements

Never commit a private keystore, signing certificate with private material, password, `key.properties`, or encoded secret value. The repository must contain only this documentation and the workflow logic. Store production signing material in a restricted password manager and GitHub Actions encrypted secrets, and rotate the key only through a planned Android migration process because an unrecoverable signing-key change prevents normal updates.

## Maintainer release checklist

Before publishing a signed release, confirm that the two Actions secrets are configured, the production release workflow completes successfully, the generated APKs report `com.localsend.m3e` and `LocalSend`, and the ARM64 release artifact is measured against another ARM64 **release** artifact rather than a debug build. Real-device installation and update testing remain required before public distribution.
