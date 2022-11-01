//
//  LocalizationBuildTool.swift
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
struct LocalizationBuildTool: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let language = try language(
            in: .package,
            at: context.package.directory.appending("Package.swift")
        )

        var environment = ["SRCROOT": target.directory.string]
        if let language {
            environment["DEVELOPMENT_LANGUAGE"] = language
        }

        return [
            .prebuildCommand(
                displayName: "Run Localization for \(target.name)",
                executable: try context.tool(named: "localization").path,
                arguments: ["Resources"],
                environment: environment,
                outputFilesDirectory: context.pluginWorkDirectory
            )
        ]
    }
}

private extension LocalizationBuildTool {
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

extension LocalizationBuildTool: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        let project = context.xcodeProject
        let language = try language(
            in: .project,
            at: project.directory.appending(["\(project.displayName).xcodeproj", "project.pbxproj"])
        )

        var environment = [
            "SRCROOT": project.directory.string,
            "TARGET_NAME": target.displayName
        ]
        if let language {
            environment["DEVELOPMENT_LANGUAGE"] = language
        }

        return [
            .prebuildCommand(
                displayName: "Run Localization for \(target.displayName)",
                executable: try context.tool(named: "localization").path,
                arguments: ["Resources"],
                environment: environment,
                outputFilesDirectory: context.pluginWorkDirectory
            )
        ]
    }
}
#endif
