import XCTest
import Foundation
@testable import MacCleanKit

final class FileGroupTests: XCTestCase {

    private func makeFile(_ name: String, size: UInt64 = 0, mod: Date? = nil) -> FileItem {
        FileItem(
            url: URL(filePath: "/\(name)"),
            name: name, size: size, allocatedSize: size,
            isDirectory: false, modificationDate: mod
        )
    }

    // MARK: - fileTypeLabel

    // Labels are localized (PT/ZH), so these tests assert the GROUPING logic —
    // extensions of the same kind share one label, distinct from other kinds —
    // rather than hardcoding a language's display string (which rots on
    // translation). `other` is the "Outros/其他/Other" bucket for reference.
    private var otherLabel: String { FileGroup.fileTypeLabel("xyz") }

    func testVideoTypesLabeledVideos() {
        let video = FileGroup.fileTypeLabel("mp4")
        XCTAssertNotEqual(video, otherLabel, "video must not fall into the 'Other' bucket")
        for ext in ["mp4", "mov", "avi", "mkv"] {
            XCTAssertEqual(FileGroup.fileTypeLabel(ext), video, "extension '\(ext)' should share the video label")
        }
    }

    func testAudioTypesLabeledAudio() {
        let audio = FileGroup.fileTypeLabel("mp3")
        XCTAssertNotEqual(audio, otherLabel)
        for ext in ["mp3", "wav", "flac", "aac"] {
            XCTAssertEqual(FileGroup.fileTypeLabel(ext), audio)
        }
    }

    func testImageTypesLabeledImages() {
        let image = FileGroup.fileTypeLabel("jpg")
        XCTAssertNotEqual(image, otherLabel)
        for ext in ["jpg", "jpeg", "png", "heic"] {
            XCTAssertEqual(FileGroup.fileTypeLabel(ext), image)
        }
    }

    func testUnknownTypeIsOther() {
        XCTAssertEqual(FileGroup.fileTypeLabel(""), otherLabel)
        // Unknown must not collide with any known category.
        XCTAssertNotEqual(otherLabel, FileGroup.fileTypeLabel("mp4"))
        XCTAssertNotEqual(otherLabel, FileGroup.fileTypeLabel("pdf"))
    }

    // MARK: - ageLabel

    func testAgeLabels() {
        // Same bucket within the first month; distinct, ordered buckets across
        // each boundary. Language-agnostic — asserts the bucketing, not the copy.
        XCTAssertEqual(FileGroup.ageLabel(days: 0), FileGroup.ageLabel(days: 25))
        XCTAssertNotEqual(FileGroup.ageLabel(days: 25), FileGroup.ageLabel(days: 31),
                          "the 30-day boundary must change bucket")
        let buckets = [0, 31, 91, 181, 400].map { FileGroup.ageLabel(days: $0) }
        XCTAssertEqual(Set(buckets).count, buckets.count, "each age range must have a distinct label")
    }

    // MARK: - group by size

    func testGroupBySize_1GBBucket() {
        let big = makeFile("big.mov", size: 2 * 1024 * 1024 * 1024) // 2 GB
        let groups = FileGroup.bySize.group([big])
        XCTAssertEqual(groups.first?.0, "1 GB+")
        XCTAssertEqual(groups.first?.1.count, 1)
    }

    func testGroupBySize_500MBBucket() {
        let file = makeFile("file.zip", size: 700 * 1024 * 1024) // 700 MB
        let groups = FileGroup.bySize.group([file])
        XCTAssertTrue(groups.contains(where: { $0.0 == "500 MB - 1 GB" }))
    }

    func testGroupBySize_50MBBucket() {
        let file = makeFile("file.zip", size: 60 * 1024 * 1024)
        let groups = FileGroup.bySize.group([file])
        XCTAssertTrue(groups.contains(where: { $0.0 == "50 - 100 MB" }))
    }

    func testGroupBySize_emptyBucketsDropped() {
        let file = makeFile("file.zip", size: 100 * 1024 * 1024)
        let groups = FileGroup.bySize.group([file])
        // Only one bucket has data
        XCTAssertEqual(groups.count, 1)
    }

    // MARK: - group by type

    func testGroupByType_mixedExtensions() {
        let files = [
            makeFile("a.mp4"), makeFile("b.mov"),
            makeFile("c.mp3"), makeFile("d.pdf"),
        ]
        let groups = FileGroup.byType.group(files)
        let dict = Dictionary(uniqueKeysWithValues: groups.map { ($0.0, $0.1.count) })
        XCTAssertEqual(dict[FileGroup.fileTypeLabel("mp4")], 2)
        XCTAssertEqual(dict[FileGroup.fileTypeLabel("mp3")], 1)
        XCTAssertEqual(dict[FileGroup.fileTypeLabel("pdf")], 1)
    }

    // MARK: - group by age

    func testGroupByAge_recentFile() {
        let now = Date()
        let recent = makeFile("recent.txt", mod: now.addingTimeInterval(-3 * 24 * 3600))
        let groups = FileGroup.byAge.group([recent], now: now)
        XCTAssertTrue(groups.contains(where: { $0.0 == FileGroup.ageLabel(days: 3) }))
    }

    func testGroupByAge_oldFile() {
        let now = Date()
        let old = makeFile("old.txt", mod: now.addingTimeInterval(-400 * 24 * 3600))
        let groups = FileGroup.byAge.group([old], now: now)
        XCTAssertTrue(groups.contains(where: { $0.0 == FileGroup.ageLabel(days: 400) }))
    }

    func testGroupByAge_skipsFilesWithoutModDate() {
        let noDate = makeFile("nodate.txt")
        let groups = FileGroup.byAge.group([noDate])
        XCTAssertTrue(groups.allSatisfy { $0.1.isEmpty })
    }
}
