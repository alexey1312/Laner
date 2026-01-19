import Foundation

public extension FileManager {
    /// Checks if a file exists at the given path.
    /// - Parameter path: The path to check.
    /// - Returns: `true` if a file (not directory) exists at the path.
    func fileExists(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && !isDirectory.boolValue
    }

    /// Checks if a directory exists at the given path.
    /// - Parameter path: The path to check.
    /// - Returns: `true` if a directory exists at the path.
    func directoryExists(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    /// Creates a directory at the given path, including intermediate directories.
    /// - Parameter path: The path where to create the directory.
    /// - Throws: An error if the directory cannot be created.
    func createDirectoryIfNeeded(atPath path: String) throws {
        if !directoryExists(atPath: path) {
            try createDirectory(atPath: path, withIntermediateDirectories: true)
        }
    }

    /// Returns the current working directory path.
    var currentDirectoryURL: URL {
        URL(fileURLWithPath: currentDirectoryPath)
    }

    /// Finds an executable in the system PATH.
    /// - Parameter name: The name of the executable to find.
    /// - Returns: The full path to the executable, or `nil` if not found.
    func findExecutable(_ name: String) -> String? {
        // Check if name is already an absolute path
        if name.hasPrefix("/") {
            return fileExists(atPath: name) ? name : nil
        }

        // Search in PATH
        guard let pathEnv = ProcessInfo.processInfo.environment["PATH"] else {
            return nil
        }

        let paths = pathEnv.split(separator: ":").map(String.init)
        for path in paths {
            let fullPath = (path as NSString).appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            if fileExists(atPath: fullPath, isDirectory: &isDirectory),
               !isDirectory.boolValue,
               isExecutableFile(atPath: fullPath)
            {
                return fullPath
            }
        }

        return nil
    }
}
