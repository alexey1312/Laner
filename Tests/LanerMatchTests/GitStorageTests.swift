import Foundation
@testable import LanerMatch
import Testing

@Suite("GitStorage Tests")
struct GitStorageTests {
    @Test("Initialization with SSH URL")
    func initWithSSH() async {
        let storage = GitStorage(gitUrl: "git@github.com:user/repo.git")

        await #expect(storage.gitUrl == "git@github.com:user/repo.git")
        await #expect(storage.branch == "master")
    }

    @Test("Initialization with HTTPS URL")
    func initWithHTTPS() async {
        let storage = GitStorage(gitUrl: "https://github.com/user/repo.git")

        await #expect(storage.gitUrl == "https://github.com/user/repo.git")
        await #expect(storage.branch == "master")
    }

    @Test("Initialization with custom branch")
    func initWithCustomBranch() async {
        let storage = GitStorage(
            gitUrl: "git@github.com:user/repo.git",
            branch: "develop"
        )

        await #expect(storage.gitUrl == "git@github.com:user/repo.git")
        await #expect(storage.branch == "develop")
    }

    @Test("URL parsing for SSH")
    func urlParsingSSH() async {
        let urls = [
            "git@github.com:user/repo.git",
            "git@gitlab.com:organization/project.git",
            "git@bitbucket.org:team/repository.git",
        ]

        for url in urls {
            let storage = GitStorage(gitUrl: url)
            await #expect(storage.gitUrl == url)
        }
    }

    @Test("URL parsing for HTTPS")
    func urlParsingHTTPS() async {
        let urls = [
            "https://github.com/user/repo.git",
            "https://gitlab.com/organization/project.git",
            "https://bitbucket.org/team/repository.git",
        ]

        for url in urls {
            let storage = GitStorage(gitUrl: url)
            await #expect(storage.gitUrl == url)
        }
    }

    @Test("Default branch is master")
    func defaultBranch() async {
        let storage = GitStorage(gitUrl: "git@github.com:user/repo.git")
        await #expect(storage.branch == "master")
    }

    @Test("Custom branch is respected")
    func customBranch() async {
        let branches = ["main", "develop", "feature/test", "release/1.0"]

        for branch in branches {
            let storage = GitStorage(
                gitUrl: "git@github.com:user/repo.git",
                branch: branch
            )
            await #expect(storage.branch == branch)
        }
    }
}
