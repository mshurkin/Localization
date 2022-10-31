//
//  LocalizationCommand.swift
//
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

import Foundation
import PackagePlugin

@main
struct LocalizationCommand: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let parameters = try parse(
            arguments: arguments,
            targets: context.package.targets.map(\.name),
            language: try language(in: .package, at: context.package.directory.appending("Package.swift")),
            resources: "Resources"
        )
        let script = try context.tool(named: "localization").path

        var environment: [String: String] = [:]
        if let language = parameters.language {
            environment["DEVELOPMENT_LANGUAGE"] = language
        }

        for target in context.package.targets {
            guard parameters.targets.contains(target.name) else {
                continue
            }

            environment["SRCROOT"] = target.directory.string

            let process = Process()
            process.executableURL = URL(fileURLWithPath: script.string)
            process.arguments = parameters.arguments
            process.environment = environment

            try process.run()
            process.waitUntilExit()

            if process.terminationReason != .exit || process.terminationStatus != 0 {
                let problem = "\(process.terminationReason):\(process.terminationStatus)"
                Diagnostics.error("Localization invocation failed: \(problem)")
            }
        }
    }
}

private extension LocalizationCommand {
    struct Parameters {
        var targets: [String]
        var language: String?
        var arguments: [String]
    }

    func parse(
        arguments: [String],
        targets allTargets: @autoclosure () -> [String],
        language: @autoclosure () throws -> String?,
        resources: String
    ) rethrows -> Parameters {
        var extractor = ArgumentExtractor(arguments)
        var targets = extractor.extractOption(named: "target")
        let language = try extractor.extractOption(named: "language").first ?? language()
        let resources = extractor.remainingArguments.first ?? resources

        if targets.isEmpty {
            targets = allTargets()
        }

        return Parameters(targets: targets, language: language, arguments: [resources])
    }

    enum Pattern: String {
        case project = "developmentRegion = ([a-zA-Z-]+);"
        case package = "defaultLocalization:\\s*\"([a-zA-Z-]+)\""
    }

    func language(in file: Pattern, at path: Path) throws -> String? {
        let regex = try NSRegularExpression(pattern: file.rawValue)
        let contents = try String(contentsOf: URL(fileURLWithPath: path.string))

        let range = NSRange(contents.startIndex..<contents.endIndex, in: contents)
        guard let match = regex.firstMatch(in: contents, range: range) else {
            return nil
        }

        guard let range = Range(match.range(at: 1), in: contents) else {
            return nil
        }
        return String(contents[range])
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension LocalizationCommand: XcodeCommandPlugin {
    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        let project = context.xcodeProject
        let parameters = try parse(
            arguments: arguments,
            targets: project.targets.map(\.displayName),
            language: try language(
                in: .project,
                at: project.directory.appending("\(project.displayName).xcodeproj", "project.pbxproj")
            ),
            resources: "Resources"
        )
        let script = try context.tool(named: "localization").path

        var environment = ["SRCROOT": context.xcodeProject.directory.string]
        if let language = parameters.language {
            environment["DEVELOPMENT_LANGUAGE"] = language
        }

        for target in context.xcodeProject.targets {
            guard parameters.targets.contains(target.displayName) else {
                continue
            }

            environment["TARGET_NAME"] = target.displayName

            let process = Process()
            process.executableURL = URL(fileURLWithPath: script.string)
            process.arguments = parameters.arguments
            process.environment = environment

            try process.run()
            process.waitUntilExit()

            if process.terminationReason != .exit || process.terminationStatus != 0 {
                let problem = "\(process.terminationReason):\(process.terminationStatus)"
                Diagnostics.error("Localization invocation failed: \(problem)")
            }
        }
    }
}
#endif
