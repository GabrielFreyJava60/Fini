#if canImport(FoundationModels)
import Foundation
import FoundationModels
import CoreModels

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct ReceiptExtraction {
    @Guide(description: "Merchant name as printed, without branch number")
    var merchant: String
    @Guide(description: "Grand total including VAT, as a decimal string, e.g. \"128.40\"")
    var total: String
    @Guide(description: "ISO 4217 currency code")
    var currency: String
    @Guide(description: "Number of installments if stated, otherwise 1")
    var installments: Int
}

/// LLM extractor. Gated on availability; Hebrew is not supported (Oct 2026) so the
/// pipeline falls back to `HeuristicReceiptParser`. Numbers are re-validated deterministically.
@available(iOS 26.0, macOS 26.0, *)
public struct FoundationModelsExtractor: ReceiptExtractor {
    public let id = "foundationModels"
    public init() {}

    public func extract(ocrText: String, currency: CurrencyCode) async throws -> ReceiptDraft? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let session = LanguageModelSession(instructions: "Extract receipt fields. Never guess a total that is not printed.")
        let r = try await session.respond(to: ocrText, generating: ReceiptExtraction.self).content
        guard let amount = Decimal(string: r.total) else { return nil }
        let code = CurrencyCode(rawValue: r.currency)
        var draft = ReceiptDraft(extractorID: id)
        draft.merchant = .init(value: r.merchant, confidence: 0.8)
        draft.total = .init(value: Money(amount, code.isWellFormed ? code : currency), confidence: 0.85)
        draft.installmentCount = max(1, r.installments)
        return draft
    }
}
#endif
