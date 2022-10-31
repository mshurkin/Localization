# Localization

[![Language Swift](https://img.shields.io/badge/Language-Swift-orange.svg)](https://developer.apple.com/swift/)
[![SPM Plugin](https://img.shields.io/badge/SPM-Plugin-brightgreen.svg)](https://swift.org/package-manager/)
![Platform iOS](https://img.shields.io/badge/Platform-iOS-blue.svg)
[![License MIT](https://img.shields.io/github/license/mshurkin/Localization)](https://opensource.org/licenses/MIT)

A simple script that keeps your localization files clean. Supports Swift Package Manager

## Features

- Supports `.strings` and `.stringsdict` files
- Removes spaces
- Groups keys in `.strings` files
- Sorts keys alphabetically
- Checks for duplicate, missing and redundant keys
- Checks for missing localization files
  
## Usage

```shell
Localization.swift [--language <language>] <directory>
```

**Arguments:**  
`<directory>` The directory relative to your project path that will be used is searching for localization files.

**Options:**  
`-l, --language <language>` The development language. Default

## Installation

### Add to Package

Add the package as a dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/mshurkin/Localization", from: "1.0.0"),
]
```

Then add `LocalizationBuildPlugin` plugin to your targets:

```swift
targets: [
    .target(
        name: "YOUR_TARGET",
        dependencies: [],
        plugins: [
            .plugin(name: "LocalizationBuildPlugin", package: "Localization")
        ]
    ),
```

### Add to Project

Add this package to your project dependencies. Select a target and open the `Build Phases` inspector. Open `Run Build Tool Plug-ins` and add `LocalizationBuildPlugin` from the list.

### Manual

Copy the `Sources/Localization/main.swift` script to your project. Rename it to `Localization.swift`. Add `Run Script` in `Build Phases` with the following command
```shell
${SRCROOT}/Path_To_Localization.swift
```

## Author

[Maxim Shurkin](https://github.com/mshurkin)

## License

Localization is released under the MIT license. See [LICENSE](LICENSE) file for more info.
