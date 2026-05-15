# Popguide SDK

These are the sample apps to help you integrating the popguide SDK.

- [Android](./Android/README.md)
- [iOS](./iOS/README.md)

## Swift Package Manager

The iOS SDK can now be integrated with Swift Package Manager.

In Xcode:

1. Open **File** > **Add Package Dependencies...**.
2. Enter the repository URL:

```text
https://github.com/populimited/popguide_sdk_sample.git
```

3. Select the desired version, starting from `1.1.0`.
4. Add the `PopguideSDK` product to your app target.

If you manage dependencies directly from `Package.swift`, add:

```swift
.package(
    url: "https://github.com/populimited/popguide_sdk_sample.git",
    from: "1.1.0"
)
```

Then add `PopguideSDK` to the target dependencies:

```swift
.product(name: "PopguideSDK", package: "popguide_sdk_sample")
```
