# Localization

[![Language Swift](https://img.shields.io/badge/Language-Swift-orange.svg)](https://developer.apple.com/swift/)
![Platform iOS](https://img.shields.io/badge/Platform-iOS-blue.svg)
[![License MIT](https://img.shields.io/github/license/mshurkin/Localization)](https://opensource.org/licenses/MIT)

Simple script that keeps your localization files clean

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

Copy the `Localization.swift` script to your project. Add `Run Script` in `Build Phases` with the following command
```shell
${SRCROOT}/Path_To_Localization.swift
```

## Author

[Maxim Shurkin](https://github.com/mshurkin)

## License

Localization is released under the MIT license. See [LICENSE](LICENSE) file for more info.
