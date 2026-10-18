import XCTest
@testable import TourCore

final class NarrationVoiceSelectionTests: XCTestCase {
    private func voice(_ id: String, language: String = "en-US", male: Bool = true,
                       quality: SpeechVoiceOption.Quality = .standard) -> SpeechVoiceOption {
        SpeechVoiceOption(identifier: id, language: language, isMale: male, quality: quality)
    }

    func testSelectsMaleEnglishInsteadOfFemaleOrOtherLanguages() {
        let male = voice("english-male")
        let choices = [voice("female", male: false, quality: .premium),
                       voice("french-male", language: "fr-FR", quality: .premium), male]
        XCTAssertEqual(NarrationVoiceSelection.maleEnglishVoice(from: choices), male)
    }

    func testPrefersNaturalQualityVoices() {
        let enhanced = voice("enhanced", quality: .enhanced)
        let premium = voice("premium", quality: .premium)
        XCTAssertEqual(NarrationVoiceSelection.maleEnglishVoice(from: [voice("default"), enhanced]), enhanced)
        XCTAssertEqual(NarrationVoiceSelection.maleEnglishVoice(from: [enhanced, premium]), premium)
    }

    func testPrefersUSEnglishAtTheSameQuality() {
        let american = voice("us", language: "en_US", quality: .enhanced)
        XCTAssertEqual(NarrationVoiceSelection.maleEnglishVoice(from: [voice("uk", language: "en-GB", quality: .enhanced), american]), american)
    }

    func testHigherQualityEnglishVoiceCanBeUsedWhenUSVoiceIsBasic() {
        let english = voice("uk-enhanced", language: "en-GB", quality: .enhanced)
        XCTAssertEqual(NarrationVoiceSelection.maleEnglishVoice(from: [voice("us-basic"), english]), english)
    }

    func testDoesNotSilentlySubstituteAnotherGenderOrLanguage() {
        XCTAssertNil(NarrationVoiceSelection.maleEnglishVoice(from: []))
        XCTAssertNil(NarrationVoiceSelection.maleEnglishVoice(from: [voice("female", male: false), voice("spanish", language: "es-US")]))
    }

    func testDoesNotSelectNoveltyOrPersonalVoices() {
        let novelty = SpeechVoiceOption(identifier: "novelty", language: "en-US", isMale: true, quality: .premium, isNovelty: true)
        let personal = SpeechVoiceOption(identifier: "personal", language: "en-US", isMale: true, quality: .premium, isPersonal: true)
        let regular = voice("regular")
        XCTAssertEqual(NarrationVoiceSelection.maleEnglishVoice(from: [novelty, personal, regular]), regular)
        XCTAssertNil(NarrationVoiceSelection.maleEnglishVoice(from: [novelty, personal]))
    }

    func testSelectionDoesNotChangeWhenInventoryOrderChanges() {
        let first = voice("a"), second = voice("b")
        XCTAssertEqual(NarrationVoiceSelection.maleEnglishVoice(from: [second, first]), first)
        XCTAssertEqual(NarrationVoiceSelection.maleEnglishVoice(from: [first, second]), first)
    }
}
