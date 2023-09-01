#!/usr/bin/env xcrun --sdk macosx swift

//  Copyright © 2022 Maxim Shurkin
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

// USAGE: Localization.swift [--language <language>] <directory>
//
// ARGUMENTS:
//   <directory>                   The directory relative to your project path
//                                 that will be used is searching for localization files.
//
// OPTIONS:
//   -l, --language <language>     The development language.

import Foundation

struct Argument {
    let directory: String?
    let language: String?
}

func parseArguments() -> Argument {
    var directory: String?
    var language: String?

    var arguments = CommandLine.arguments.dropFirst()
    while !arguments.isEmpty {
        let argument = arguments.removeFirst()
        if argument == "-l" || argument == "--language" {
            language = arguments.removeFirst()
        } else {
            directory = argument
        }
    }

    return Argument(directory: directory, language: language)
}

let argument = parseArguments()

enum EnvironmentKey: String {
    case rootFolder = "SRCROOT"
    case target = "TARGET_NAME"
    case language = "DEVELOPMENT_LANGUAGE"
}

func environment(_ key: EnvironmentKey) -> String? {
    ProcessInfo.processInfo.environment[key.rawValue]
}

func exit(_ message: String) -> Never {
    print("error: \(message)")
    return exit(1)
}

var numberOfErrors = 0

enum Level: String {
    case warning, error
}

func print(_ level: Level, _ message: String, _ file: String? = nil) {
    if level == .error {
        numberOfErrors += 1
    }
    print([file, "\(level.rawValue):", message].compactMap({ $0 }).joined(separator: " "))
}

struct LocalizationFile {
    let path: String
    let name: String
    let locale: String?

    var fullName: String {
        guard let locale = locale else {
            return name
        }
        return name.replacingOccurrences(of: ".strings", with: " (\(locale)).strings")
    }

    init(rootPath: String, filePath: String) {
        let components = filePath.components(separatedBy: "/")

        path = rootPath + "/" + filePath
        name = components.last ?? ""
        locale = components
            .last(where: { $0.hasSuffix("lproj") })?
            .replacingOccurrences(of: ".lproj", with: "")
    }
}

func localizationFiles() -> (strings: [[LocalizationFile]], stringsdict: [[LocalizationFile]]) {
    let directory = argument.directory?.trimmingCharacters(in: .init(charactersIn: "/"))
    let srcroot = environment(.rootFolder)
    let targetName = environment(.target)
    let path = [srcroot, targetName, directory].compactMap { $0 }.joined(separator: "/")

    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: path) {
        exit("Invalid configuration: \(path) doesn't exist.")
    }

    var stringsFiles = [LocalizationFile]()
    var stringsdictFiles = [LocalizationFile]()
    let enumerator = fileManager.enumerator(atPath: path)
    while let file = enumerator?.nextObject() as? String {
        if file.hasSuffix("strings") {
            stringsFiles.append(LocalizationFile(rootPath: path, filePath: file))
        } else if file.hasSuffix("stringsdict") {
            stringsdictFiles.append(LocalizationFile(rootPath: path, filePath: file))
        }
    }

    let groupedStringsFiles = Dictionary(grouping: stringsFiles, by: \.name)
        .sorted { $0.key < $1.key }
        .map { $0.value }
    let groupedStringsdictFiles = Dictionary(grouping: stringsdictFiles, by: \.name)
        .sorted { $0.key < $1.key }
        .map { $0.value }

    return (groupedStringsFiles, groupedStringsdictFiles)
}

let developmentLanguage = argument.language ?? environment(.language) ?? ""

protocol Localizable {
    var name: String { get }
    var keys: Set<String> { get }

    init(_ file: LocalizationFile)
    func printWarning(_ message: String, for key: String)
}

struct LocalizableFile<File: Localizable> {
    let name: String
    let main: File
    let other: [File]
    let languages: Set<String>

    init?(files: [LocalizationFile]) {
        name = files[0].name

        if developmentLanguage.isEmpty {
            main = File(files[0])
        } else if let file = files.first(where: { $0.locale == developmentLanguage }) {
            main = File(file)
        } else {
            print(.error, #""\#(files[0].name)" is missing for development language (\#(developmentLanguage))"#)
            return nil
        }

        let otherFiles = {
            developmentLanguage.isEmpty ? Array(files.dropFirst()) : files.filter({ $0.locale != developmentLanguage })
        }
        other = otherFiles().map(File.init)

        languages = Set(files.map({ $0.locale ?? "" }))
    }

    func compare(_ languages: Set<String>) {
        languages.subtracting(self.languages).forEach {
            print(.warning, #""\#(name)" is missing for \#($0) language"#)
        }

        other.forEach { file in
            main.keys.subtracting(file.keys).forEach { key in
                main.printWarning(#""\#(key)" is missing from "\#(file.name)" file"#, for: key)
            }
            file.keys.subtracting(main.keys).forEach { key in
                file.printWarning(#""\#(key)" is redundant in "\#(file.name)" file"#, for: key)
            }
        }
    }
}

struct StringsFile: Localizable {
    let path: String
    let name: String
    private(set) var keys: Set<String> = []
    private(set) var lines: [String: Int] = [:]

    init(_ file: LocalizationFile) {
        path = file.path
        name = file.fullName

        let (header, strings) = content(ofFile: path)
        if !strings.isEmpty {
            sort(strings: strings, header: header)
        }
    }

    func printWarning(_ message: String, for key: String) {
        print(.warning, message, "\(path):\(lines[key]!):")
    }

    enum Pattern: String {
        case string = #"\"(.+)\"\s*=\s*\"(.+)\";"#
        case singleLineHeader = #"^\s*(\/\/(?:.|\n[\t ]*\/\/)*)"#
        case multiLineHeader = #"^\s*(\/\*(?:[^*]|\*(?!\/))*\*\/)"#
    }

    struct KeyValue {
        let key: String
        let value: String
    }

    private func content(ofFile path: String) -> (String?, [KeyValue]) {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            exit("Couldn't read file from path: \(path)")
        }

        var strings = [KeyValue]()
        let regex = try? NSRegularExpression(pattern: Pattern.string.rawValue)
        for line in content.components(separatedBy: .newlines) {
            if line.isEmpty {
                continue
            }

            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            if
                let match = regex?.firstMatch(in: line, range: range),
                let keyRange = Range(match.range(at: 1), in: line),
                let valueRange = Range(match.range(at: 2), in: line)
            {
                let value = KeyValue(key: String(line[keyRange]), value: String(line[valueRange]))
                strings.append(value)
            }
        }
        return (header(in: content), strings)
    }

    private func header(in string: String) -> String? {
        if let multiLine = header(.multiLineHeader, in: string) {
            return multiLine
        }

        return header(.singleLineHeader, in: string)?
            .replacingOccurrences(of: #"\n[\t ]*\/\/"#, with: "\n//", options: .regularExpression)
    }

    private func header(_ pattern: Pattern, in string: String) -> String? {
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        guard
            let regex = try? NSRegularExpression(pattern: pattern.rawValue),
            let match = regex.firstMatch(in: string, range: range),
            let headerRange = Range(match.range(at: 1), in: string)
        else {
            return nil
        }
        return String(string[headerRange])
    }

    private mutating func sort(strings: [KeyValue], header: String?) {
        let sortedStrings = strings.sorted { $0.key.localizedCompare($1.key) == .orderedAscending }
        let grouped = Dictionary(grouping: sortedStrings) { item -> String in
            if item.key.contains("."), let name = item.key.components(separatedBy: ".").first {
                return name
            }
            return ""
        }

        var content = [String]()
        if let header {
            content.append(contentsOf: header.components(separatedBy: .newlines))
        }

        var isFirstMark = true
        for (key, strings) in grouped.sorted(by: { $0.key < $1.key }) {
            if strings.isEmpty {
                continue
            }

            content.append("")
            if !key.isEmpty {
                let groupName = key.prefix(1).uppercased() + key.dropFirst().replacingOccurrences(of: "-", with: " ")
                content.append("// MARK: \(isFirstMark ? "" : "- ")\(groupName)")
                content.append("")
                isFirstMark = false
            }

            for string in strings {
                content.append(#""\#(string.key)" = "\#(string.value)";"#)
                if keys.insert(string.key).inserted {
                    lines[string.key] = content.count
                } else {
                    let message = #""\#(string.key)" is dublicated in "\#(name)" file"#
                    print(.error, message, "\(path):\(content.count):")
                }
            }
        }

        content.append("")
        try? content.joined(separator: "\n").write(toFile: path, atomically: false, encoding: .utf8)
    }
}

struct StringsdictFile: Localizable {
    let path: String
    let name: String
    private(set) var keys: Set<String> = []

    init(_ file: LocalizationFile) {
        path = file.path
        name = file.fullName

        let contents = contentsOfFlie()
        if !contents.ranges.isEmpty {
            sort(contents)
        }
    }

    func printWarning(_ message: String, for key: String) {
        print(.warning, message, "\(path):")
    }

    struct Contents {
        let raw: String
        let ranges: [Range<String.Index>]
        let values: [String: String]
    }

    enum PluralRule: String, CaseIterable {
        case specType = "NSStringFormatSpecTypeKey"
        case valueType = "NSStringFormatValueTypeKey"
        case zero, one, two, few, many, other

        var name: String {
            String(describing: self)
        }
    }

    private mutating func contentsOfFlie() -> Contents {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            exit("Couldn't read file from path: \(path)")
        }

        var ranges = [Range<String.Index>]()
        var values = [String: String]()

        let regex = try? NSRegularExpression(pattern: #"\n\t\<key\>(?:.|\n)+?\n\t\<\/dict\>"#)
        let range = NSRange(contents.startIndex..<contents.endIndex, in: contents)
        regex?.matches(in: contents, range: range).forEach { match in
            guard let range = Range(match.range, in: contents) else {
                return
            }

            ranges.append(range)

            let value = String(contents[range])
            let lines = value.components(separatedBy: .newlines)

            let key = lines[1]
                .replacingOccurrences(of: "\t<key>", with: "")
                .replacingOccurrences(of: "</key>", with: "")
            keys.insert(key)

            values[key] = value
        }

        return Contents(raw: contents, ranges: ranges, values: values)
    }

    private func sort(_ contents: Contents) {
        var pattern = #"\t\t<dict>(?:"#
        PluralRule.allCases.forEach {
            pattern += #"(?<\#($0)>\t{3}<key>\#($0.rawValue)<\/key>\n\t{3}<string>.*<\/string>)|"#
        }
        pattern += #"\n)+\t\t<\/dict>"#

        let regex = try? NSRegularExpression(pattern: pattern)

        let sortedKeys = keys
            .sorted(by: { $0.localizedCompare($1) == .orderedAscending })
            .enumerated()
            .reversed()

        var contentsOfFile = contents.raw
        for (index, key) in sortedKeys {
            guard var value = contents.values[key] else {
                continue
            }

            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            regex?.matches(in: value, range: range).reversed().forEach { match in
                guard let matchRange = Range(match.range, in: value) else {
                    return
                }

                var rule: String = "\t\t<dict>\n"
                if let specType = pluralRule(.specType, in: value, match: match) {
                    rule.append(specType + "\n")
                } else {
                    printError(.specType, for: key)
                }
                if let valueType = pluralRule(.valueType, in: value, match: match) {
                    rule.append(valueType + "\n")
                } else {
                    printError(.valueType, for: key)
                }
                [PluralRule.zero, .one, .two, .few, .many].forEach {
                    if let string = pluralRule($0, in: value, match: match) {
                        rule.append(string + "\n")
                    }
                }
                if let other = pluralRule(.other, in: value, match: match) {
                    rule.append(other + "\n")
                } else {
                    printError(.other, for: key)
                }
                rule.append("\t\t</dict>")

                value.replaceSubrange(matchRange, with: rule)
            }

            let valueRange = contents.ranges[index]
            contentsOfFile.replaceSubrange(valueRange, with: value)
        }

        try? contentsOfFile.write(toFile: path, atomically: false, encoding: .utf8)
    }

    private func pluralRule(_ rule: PluralRule, in string: String, match: NSTextCheckingResult) -> String? {
        guard let range = Range(match.range(withName: rule.name), in: string) else {
            return nil
        }
        return String(string[range])
    }

    private func printError(_ rule: PluralRule, for key: String) {
        let message = #""\#(rule.rawValue)" is required for key "\#(key)" in "\#(name)" file"#
        print(.error, message, "\(path):")
    }
}

var (stringsFiles, stringsdictFiles) = localizationFiles()

let languages = stringsFiles.reduce(into: Set<String>()) { result, files in
    files.forEach { result.insert($0.locale ?? "") }
}

stringsFiles
    .compactMap(LocalizableFile<StringsFile>.init(files:))
    .forEach { $0.compare(languages) }

stringsdictFiles
    .compactMap(LocalizableFile<StringsdictFile>.init(files:))
    .forEach { $0.compare(languages) }

if numberOfErrors > 0 {
    exit(1)
}
