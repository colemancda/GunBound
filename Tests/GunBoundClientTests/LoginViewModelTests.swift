import Foundation
import Testing
@testable import GunBound
@testable import GunBoundClient
@testable import GunBoundFile

@Suite @MainActor
struct LoginViewModelTests {

    /// A scratch directory, optionally holding a `graphics.xfs` with the
    /// given bytes.
    private func makeDirectory(graphicsBytes: [UInt8]? = nil) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LoginViewModelTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let graphicsBytes {
            try Data(graphicsBytes).write(to: directory.appendingPathComponent("graphics.xfs"))
        }
        return directory
    }

    @Test func locateFindsTheFirstCandidateWithArchives() throws {
        let empty = try makeDirectory()
        let stocked = try makeDirectory(graphicsBytes: [0x00])
        defer { try? FileManager.default.removeItem(at: empty); try? FileManager.default.removeItem(at: stocked) }

        #expect(LoginViewModel.locateAssetsDirectory(searching: [empty, stocked]) == stocked)
        #expect(LoginViewModel.locateAssetsDirectory(searching: [empty]) == nil)
    }

    @Test func loadFailsWithMessageWhenArchivesAreMissing() async throws {
        let empty = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: empty) }

        let viewModel = LoginViewModel(searchPaths: [empty])
        await viewModel.load()

        #expect(viewModel.assetsDirectory == nil)
        #expect(viewModel.loadFailureMessage?.contains("graphics.xfs wasn't found") == true)
        #expect(viewModel.loadFailureMessage?.contains(empty.path) == true)
    }

    @Test func loadFailsWithMessageWhenArchiveIsUndecodable() async throws {
        // graphics.xfs exists but holds garbage — locate succeeds, the
        // backdrop decode (the pipeline sanity check) fails.
        let corrupt = try makeDirectory(graphicsBytes: [0xDE, 0xAD, 0xBE, 0xEF])
        defer { try? FileManager.default.removeItem(at: corrupt) }

        let viewModel = LoginViewModel(searchPaths: [corrupt])
        await viewModel.load()

        #expect(viewModel.assetsDirectory == nil)
        #expect(viewModel.loadFailureMessage?.contains("couldn't decode") == true)
    }

    @Test func frameConvertsToCGImage() {
        let pixels = [
            ImgFile.Pixel(red: 255, green: 0, blue: 0, alpha: 255),
            ImgFile.Pixel(red: 0, green: 255, blue: 0, alpha: 255),
            ImgFile.Pixel(red: 0, green: 0, blue: 255, alpha: 255),
            ImgFile.Pixel(red: 0, green: 0, blue: 0, alpha: 0),
        ]
        let frame = ImgFile.Frame(width: 2, height: 2, pixels: pixels)
        let image = frame.cgImage
        #expect(image?.width == 2)
        #expect(image?.height == 2)
    }
}
