import Foundation
import SwiftData
import CoreModels

// MARK: - Schema V1
//
// Conventions (see ARCHITECTURE.md §4):
// * Money is stored as `Int64` minor units + ISO 4217 `currencyCode` String. Never Double.
//   Exact rates/quantities that are not money are stored as decimal Strings.
// * Enums are stored as `...Raw: String` with typed computed accessors.
// * Every syncable model carries `id: UUID` (unique), `updatedHLC: String` and
//   `isTombstoned: Bool`. User-facing deletes are soft (tombstones) so sync can
//   propagate them; the SwiftData delete rules below apply to hard purges
//   (retention / "erase all data") only.
// * Relationship inverses are declared on exactly one side.
// * Automatic CloudKit mirroring is OFF (`cloudKitDatabase: .none`); sync is CKSyncEngine
//   with client-side encrypted payloads (SyncVault), so @Attribute(.unique) is allowed.

public enum SchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            Account.self,
            CardBillingCycle.self,
            LedgerTransaction.self,
            Category.self,
            Budget.self,
            Merchant.self,
            Receipt.self,
            LineItem.self,
            RecurringRule.self,
            InstallmentPlan.self,
            InstallmentPayment.self,
            LedgerEvent.self,
        ]
    }

    // MARK: Account

    @Model
    public final class Account {
        #Index<Account>([\.isArchived], [\.kindRaw])

        @Attribute(.unique) public var id: UUID
        public var name: String
        public var kindRaw: String
        public var currencyCode: String
        public var openingBalanceMinor: Int64
        public var openingBalanceDate: Date
        public var institutionName: String?
        public var last4: String?
        public var isArchived: Bool
        public var sortOrder: Int
        public var createdAt: Date
        public var updatedHLC: String
        public var isTombstoned: Bool

        /// Purging an account purges its transactions.
        @Relationship(deleteRule: .cascade, inverse: \LedgerTransaction.account)
        public var transactions: [LedgerTransaction] = []

        /// Credit cards own their billing-cycle history.
        @Relationship(deleteRule: .cascade, inverse: \CardBillingCycle.account)
        public var billingCycles: [CardBillingCycle] = []

        @Relationship(deleteRule: .nullify, inverse: \RecurringRule.account)
        public var recurringRules: [RecurringRule] = []

        @Relationship(deleteRule: .cascade, inverse: \InstallmentPlan.account)
        public var installmentPlans: [InstallmentPlan] = []

        public init(
            id: UUID = UUID(),
            name: String,
            kind: AccountKind,
            currency: CurrencyCode = .default,
            openingBalance: Money? = nil,
            openingBalanceDate: Date = .now,
            institutionName: String? = nil,
            last4: String? = nil,
            sortOrder: Int = 0,
            hlc: String = ""
        ) {
            self.id = id
            self.name = name
            self.kindRaw = kind.rawValue
            self.currencyCode = currency.rawValue
            self.openingBalanceMinor = openingBalance?.minorUnits ?? 0
            self.openingBalanceDate = openingBalanceDate
            self.institutionName = institutionName
            self.last4 = last4
            self.isArchived = false
            self.sortOrder = sortOrder
            self.createdAt = .now
            self.updatedHLC = hlc
            self.isTombstoned = false
        }

        public var kind: AccountKind {
            get { AccountKind(rawValue: kindRaw) ?? .checking }
            set { kindRaw = newValue.rawValue }
        }
        public var currency: CurrencyCode { CurrencyCode(rawValue: currencyCode) }
        public var openingBalance: Money { Money(minorUnits: openingBalanceMinor, currency: currency) }

        /// Billing cycle in effect on `date` (cycles are versioned by `effectiveFrom`).
        public func billingCycle(on date: Date) -> CardBillingCycle? {
            billingCycles
                .filter { !$0.isTombstoned && $0.effectiveFrom <= date }
                .max { $0.effectiveFrom < $1.effectiveFrom }
        }
    }

    // MARK: CardBillingCycle (Israeli deferred-debit)

    @Model
    public final class CardBillingCycle {
        #Index<CardBillingCycle>([\.effectiveFrom])

        @Attribute(.unique) public var id: UUID
        public var issuerRaw: String
        /// Day of month the bank account is debited (2 / 10 / 15 are common).
        public var chargeDay: Int
        /// Last purchase day (inclusive) included in the upcoming charge.
        public var statementCloseDay: Int
        /// Lets a user change their charge day without rewriting history.
        public var effectiveFrom: Date
        /// Account the card settles against (the bank account being debited).
        public var settlementAccountID: UUID?
        public var updatedHLC: String
        public var isTombstoned: Bool

        public var account: Account?

        public init(
            id: UUID = UUID(),
            issuer: CardIssuer,
            chargeDay: Int,
            statementCloseDay: Int,
            effectiveFrom: Date = .distantPast,
            settlementAccountID: UUID? = nil,
            hlc: String = ""
        ) {
            self.id = id
            self.issuerRaw = issuer.rawValue
            self.chargeDay = chargeDay
            self.statementCloseDay = statementCloseDay
            self.effectiveFrom = effectiveFrom
            self.settlementAccountID = settlementAccountID
            self.updatedHLC = hlc
            self.isTombstoned = false
        }

        public var issuer: CardIssuer { CardIssuer(rawValue: issuerRaw) ?? .other }
        public var rule: CardSettlementRule {
            CardSettlementRule(chargeDay: chargeDay, statementCloseDay: statementCloseDay)
        }
    }

    // MARK: LedgerTransaction
    // Named LedgerTransaction to avoid clashing with SwiftUI.Transaction.

    @Model
    public final class LedgerTransaction {
        #Index<LedgerTransaction>(
            [\.date],
            [\.settlementDate],
            [\.isTombstoned, \.date],
            [\.kindRaw, \.date],
            [\.externalID],
            [\.needsReview]
        )

        @Attribute(.unique) public var id: UUID
        /// Purchase date (what the user sees).
        public var date: Date
        /// When cash actually leaves/enters the account (card charge day, installment due date).
        public var settlementDate: Date?
        /// Signed minor units in `currencyCode`: negative = outflow.
        public var amountMinor: Int64
        public var currencyCode: String
        /// Foreign-currency purchases: original amount/currency and the exact rate as a decimal String.
        public var originalAmountMinor: Int64?
        public var originalCurrencyCode: String?
        public var fxRate: String?
        public var kindRaw: String
        public var sourceRaw: String
        public var payee: String?
        public var note: String?
        public var isPending: Bool
        public var needsReview: Bool
        /// 0...1 confidence of the predicted category (smart defaults / Snap).
        public var categoryConfidence: Double?
        /// Idempotency key from an import/aggregator (bank txn id or CSV row hash).
        public var externalID: String?
        /// Links both legs of a transfer.
        public var transferGroupID: UUID?
        public var createdAt: Date
        public var updatedHLC: String
        public var isTombstoned: Bool

        public var account: Account?

        @Relationship(deleteRule: .nullify)
        public var category: Category?

        @Relationship(deleteRule: .nullify)
        public var merchant: Merchant?

        /// Receipt is enrichment; deleting a transaction keeps the receipt (back to the Snap inbox).
        @Relationship(deleteRule: .nullify)
        public var receipt: Receipt?

        /// Set when this row is the materialized charge of an installment payment.
        @Relationship(deleteRule: .nullify)
        public var installmentPayment: InstallmentPayment?

        @Relationship(deleteRule: .nullify)
        public var recurringRule: RecurringRule?

        /// Splits: children must sum to the parent (enforced in LedgerActor).
        public var splitParent: LedgerTransaction?
        @Relationship(deleteRule: .cascade, inverse: \LedgerTransaction.splitParent)
        public var splits: [LedgerTransaction] = []

        public init(
            id: UUID = UUID(),
            date: Date = .now,
            settlementDate: Date? = nil,
            amount: Money,
            kind: TransactionKind,
            source: TransactionSource = .manual,
            payee: String? = nil,
            note: String? = nil,
            isPending: Bool = false,
            externalID: String? = nil,
            hlc: String = ""
        ) {
            self.id = id
            self.date = date
            self.settlementDate = settlementDate
            self.amountMinor = amount.minorUnits
            self.currencyCode = amount.currency.rawValue
            self.kindRaw = kind.rawValue
            self.sourceRaw = source.rawValue
            self.payee = payee
            self.note = note
            self.isPending = isPending
            self.needsReview = false
            self.externalID = externalID
            self.createdAt = .now
            self.updatedHLC = hlc
            self.isTombstoned = false
        }

        public var amount: Money {
            get { Money(minorUnits: amountMinor, currency: CurrencyCode(rawValue: currencyCode)) }
            set { amountMinor = newValue.minorUnits; currencyCode = newValue.currency.rawValue }
        }
        public var originalAmount: Money? {
            guard let minor = originalAmountMinor, let code = originalCurrencyCode else { return nil }
            return Money(minorUnits: minor, currency: CurrencyCode(rawValue: code))
        }
        public var kind: TransactionKind {
            get { TransactionKind(rawValue: kindRaw) ?? .expense }
            set { kindRaw = newValue.rawValue }
        }
        public var source: TransactionSource { TransactionSource(rawValue: sourceRaw) ?? .manual }
        /// Date used for cash-flow (Runway): settlement if known, else purchase date.
        public var cashFlowDate: Date { settlementDate ?? date }

        public var snapshot: TransactionSnapshot {
            TransactionSnapshot(id: id, date: date, settlementDate: settlementDate, amount: amount, kind: kind,
                                categoryID: category?.id, accountID: account?.id,
                                merchantName: merchant?.displayName ?? payee)
        }
    }

    // MARK: Category

    @Model
    public final class Category {
        #Index<Category>([\.kindRaw, \.sortOrder])

        @Attribute(.unique) public var id: UUID
        public var name: String
        /// Localization key for system categories (e.g. "category.arnona"); nil for user-created.
        public var systemKey: String?
        public var symbolName: String
        /// DesignSystem color token (e.g. "category.teal"). Never a raw color.
        public var colorToken: String
        public var kindRaw: String
        public var sortOrder: Int
        /// Essential spend feeds Pulse "buffer depth".
        public var isEssential: Bool
        public var isHidden: Bool
        public var updatedHLC: String
        public var isTombstoned: Bool

        public var parent: Category?
        @Relationship(deleteRule: .cascade, inverse: \Category.parent)
        public var children: [Category] = []

        /// Transactions keep existing when a category is purged (become uncategorized).
        @Relationship(deleteRule: .nullify, inverse: \LedgerTransaction.category)
        public var transactions: [LedgerTransaction] = []

        @Relationship(deleteRule: .cascade, inverse: \Budget.category)
        public var budgets: [Budget] = []

        @Relationship(deleteRule: .nullify, inverse: \LineItem.category)
        public var lineItems: [LineItem] = []

        public init(
            id: UUID = UUID(),
            name: String,
            systemKey: String? = nil,
            symbolName: String,
            colorToken: String,
            kind: CategoryKind = .expense,
            sortOrder: Int = 0,
            isEssential: Bool = false,
            hlc: String = ""
        ) {
            self.id = id
            self.name = name
            self.systemKey = systemKey
            self.symbolName = symbolName
            self.colorToken = colorToken
            self.kindRaw = kind.rawValue
            self.sortOrder = sortOrder
            self.isEssential = isEssential
            self.isHidden = false
            self.updatedHLC = hlc
            self.isTombstoned = false
        }

        public var kind: CategoryKind { CategoryKind(rawValue: kindRaw) ?? .expense }
    }

    // MARK: Budget

    @Model
    public final class Budget {
        #Index<Budget>([\.startDate])

        @Attribute(.unique) public var id: UUID
        public var periodRaw: String
        public var limitMinor: Int64
        public var currencyCode: String
        public var startDate: Date
        public var endDate: Date?
        public var rolloverEnabled: Bool
        /// Percent of limit (0...100) at which Pulse/notifications start nudging.
        public var alertThresholdPercent: Int
        public var updatedHLC: String
        public var isTombstoned: Bool

        public var category: Category?

        public init(
            id: UUID = UUID(),
            period: BudgetPeriod,
            limit: Money,
            startDate: Date,
            endDate: Date? = nil,
            rolloverEnabled: Bool = false,
            alertThresholdPercent: Int = 80,
            hlc: String = ""
        ) {
            self.id = id
            self.periodRaw = period.rawValue
            self.limitMinor = limit.minorUnits
            self.currencyCode = limit.currency.rawValue
            self.startDate = startDate
            self.endDate = endDate
            self.rolloverEnabled = rolloverEnabled
            self.alertThresholdPercent = alertThresholdPercent
            self.updatedHLC = hlc
            self.isTombstoned = false
        }

        public var period: BudgetPeriod { BudgetPeriod(rawValue: periodRaw) ?? .monthly }
        public var limit: Money { Money(minorUnits: limitMinor, currency: CurrencyCode(rawValue: currencyCode)) }
    }

    // MARK: Merchant

    @Model
    public final class Merchant {
        #Index<Merchant>([\.normalizedKey])

        @Attribute(.unique) public var id: UUID
        public var displayName: String
        /// Lowercased, diacritics/branch-number stripped key used for matching (e.g. "shufersal").
        @Attribute(.unique) public var normalizedKey: String
        /// Raw strings seen on statements/receipts ("SHUFERSAL DEAL 123", "שופרסל דיל").
        public var aliases: [String]
        public var logoAssetName: String?
        public var updatedHLC: String
        public var isTombstoned: Bool

        /// Learned default category (Snap / smart defaults rule).
        @Relationship(deleteRule: .nullify)
        public var defaultCategory: Category?

        @Relationship(deleteRule: .nullify, inverse: \LedgerTransaction.merchant)
        public var transactions: [LedgerTransaction] = []

        @Relationship(deleteRule: .nullify, inverse: \RecurringRule.merchant)
        public var recurringRules: [RecurringRule] = []

        public init(id: UUID = UUID(), displayName: String, normalizedKey: String, aliases: [String] = [], hlc: String = "") {
            self.id = id
            self.displayName = displayName
            self.normalizedKey = normalizedKey
            self.aliases = aliases
            self.updatedHLC = hlc
            self.isTombstoned = false
        }
    }

    // MARK: Receipt + LineItem (Snap)

    @Model
    public final class Receipt {
        #Index<Receipt>([\.statusRaw, \.capturedAt], [\.purchaseDate])

        @Attribute(.unique) public var id: UUID
        public var capturedAt: Date
        public var statusRaw: String
        /// File name of the AES-GCM-encrypted image in the app container (never stored in the DB).
        public var encryptedImageFileName: String?
        public var merchantName: String?
        public var purchaseDate: Date?
        public var totalMinor: Int64?
        public var vatMinor: Int64?
        public var currencyCode: String
        /// Installment count printed on the slip ("3 תשלומים"); 1 if absent.
        public var installmentCount: Int
        /// Overall extraction confidence 0...1; per-field confidences in `fieldConfidenceJSON`.
        public var confidence: Double
        public var fieldConfidenceJSON: Data?
        /// "foundationModels" | "heuristic" | "manual" — for the evaluation dashboard.
        public var extractorID: String
        public var updatedHLC: String
        public var isTombstoned: Bool

        @Relationship(deleteRule: .cascade, inverse: \LineItem.receipt)
        public var lineItems: [LineItem] = []

        /// Bank/card transaction this receipt was merged into.
        @Relationship(deleteRule: .nullify, inverse: \LedgerTransaction.receipt)
        public var transaction: LedgerTransaction?

        public init(
            id: UUID = UUID(),
            capturedAt: Date = .now,
            status: ReceiptStatus = .processing,
            currency: CurrencyCode = .default,
            extractorID: String = "heuristic",
            hlc: String = ""
        ) {
            self.id = id
            self.capturedAt = capturedAt
            self.statusRaw = status.rawValue
            self.currencyCode = currency.rawValue
            self.installmentCount = 1
            self.confidence = 0
            self.extractorID = extractorID
            self.updatedHLC = hlc
            self.isTombstoned = false
        }

        public var status: ReceiptStatus {
            get { ReceiptStatus(rawValue: statusRaw) ?? .needsReview }
            set { statusRaw = newValue.rawValue }
        }
        public var total: Money? {
            totalMinor.map { Money(minorUnits: $0, currency: CurrencyCode(rawValue: currencyCode)) }
        }
        /// Deterministic validation: line items should sum to the printed total.
        public var lineItemsMatchTotal: Bool {
            guard let totalMinor else { return false }
            return lineItems.reduce(Int64(0)) { $0 + $1.totalMinor } == totalMinor
        }
    }

    @Model
    public final class LineItem {
        @Attribute(.unique) public var id: UUID
        public var position: Int
        public var text: String
        /// Exact decimal string ("1", "0.452" kg).
        public var quantity: String
        public var unitPriceMinor: Int64?
        public var totalMinor: Int64
        public var updatedHLC: String
        public var isTombstoned: Bool

        public var receipt: Receipt?
        public var category: Category?

        public init(id: UUID = UUID(), position: Int, text: String, quantity: Decimal = 1,
                    unitPrice: Money? = nil, total: Money, hlc: String = "") {
            self.id = id
            self.position = position
            self.text = text
            self.quantity = "\(quantity)"
            self.unitPriceMinor = unitPrice?.minorUnits
            self.totalMinor = total.minorUnits
            self.updatedHLC = hlc
            self.isTombstoned = false
        }

        public var quantityDecimal: Decimal { Decimal(string: quantity) ?? 1 }
    }

    // MARK: RecurringRule

    @Model
    public final class RecurringRule {
        #Index<RecurringRule>([\.isActive, \.nextDueDate])

        @Attribute(.unique) public var id: UUID
        public var name: String
        public var frequencyRaw: String
        /// Every N periods (e.g. 2 + monthly = bi-monthly arnona).
        public var interval: Int
        public var anchorDate: Date
        public var nextDueDate: Date
        public var endDate: Date?
        /// Signed expected amount (negative = bill, positive = salary).
        public var expectedAmountMinor: Int64
        public var currencyCode: String
        public var kindRaw: String
        /// Detection tolerances from the blueprint: ±3 days, ±10 % amount drift.
        public var toleranceDays: Int
        public var tolerancePercent: Int
        /// true = detected by Runway's periodicity detector; false = user-entered.
        public var isDetected: Bool
        public var detectionConfidence: Double?
        public var isActive: Bool
        public var updatedHLC: String
        public var isTombstoned: Bool

        public var account: Account?
        public var merchant: Merchant?
        @Relationship(deleteRule: .nullify)
        public var category: Category?

        @Relationship(deleteRule: .nullify, inverse: \LedgerTransaction.recurringRule)
        public var occurrences: [LedgerTransaction] = []

        public init(
            id: UUID = UUID(),
            name: String,
            frequency: RecurrenceFrequency,
            interval: Int = 1,
            anchorDate: Date,
            expectedAmount: Money,
            kind: TransactionKind,
            isDetected: Bool = false,
            hlc: String = ""
        ) {
            self.id = id
            self.name = name
            self.frequencyRaw = frequency.rawValue
            self.interval = max(1, interval)
            self.anchorDate = anchorDate
            self.nextDueDate = anchorDate
            self.expectedAmountMinor = expectedAmount.minorUnits
            self.currencyCode = expectedAmount.currency.rawValue
            self.kindRaw = kind.rawValue
            self.toleranceDays = 3
            self.tolerancePercent = 10
            self.isDetected = isDetected
            self.isActive = true
            self.updatedHLC = hlc
            self.isTombstoned = false
        }

        public var frequency: RecurrenceFrequency { RecurrenceFrequency(rawValue: frequencyRaw) ?? .monthly }
        public var expectedAmount: Money {
            Money(minorUnits: expectedAmountMinor, currency: CurrencyCode(rawValue: currencyCode))
        }
    }

    // MARK: InstallmentPlan + InstallmentPayment (תשלומים)

    @Model
    public final class InstallmentPlan {
        #Index<InstallmentPlan>([\.isCompleted, \.firstChargeDate])

        @Attribute(.unique) public var id: UUID
        public var title: String
        public var kindRaw: String
        public var purchaseDate: Date
        public var firstChargeDate: Date
        public var totalMinor: Int64
        public var currencyCode: String
        public var paymentCount: Int
        /// Annual rate as decimal string for `credit` plans ("0.089"); nil when interest-free.
        public var annualInterestRate: String?
        public var isCompleted: Bool
        public var updatedHLC: String
        public var isTombstoned: Bool

        public var account: Account?
        @Relationship(deleteRule: .nullify)
        public var merchant: Merchant?
        @Relationship(deleteRule: .nullify)
        public var category: Category?
        /// The original purchase row (full amount, excluded from cash-flow; payments carry the cash).
        @Relationship(deleteRule: .nullify)
        public var originatingTransaction: LedgerTransaction?

        @Relationship(deleteRule: .cascade, inverse: \InstallmentPayment.plan)
        public var payments: [InstallmentPayment] = []

        public init(
            id: UUID = UUID(),
            title: String,
            kind: InstallmentKind = .tashlumim,
            purchaseDate: Date,
            firstChargeDate: Date,
            total: Money,
            paymentCount: Int,
            annualInterestRate: Decimal? = nil,
            hlc: String = ""
        ) {
            self.id = id
            self.title = title
            self.kindRaw = kind.rawValue
            self.purchaseDate = purchaseDate
            self.firstChargeDate = firstChargeDate
            self.totalMinor = total.minorUnits
            self.currencyCode = total.currency.rawValue
            self.paymentCount = max(1, paymentCount)
            self.annualInterestRate = annualInterestRate.map { "\($0)" }
            self.isCompleted = false
            self.updatedHLC = hlc
            self.isTombstoned = false
        }

        public var kind: InstallmentKind { InstallmentKind(rawValue: kindRaw) ?? .tashlumim }
        public var total: Money { Money(minorUnits: totalMinor, currency: CurrencyCode(rawValue: currencyCode)) }
        public var remaining: Money {
            let left = payments.filter { !$0.isSettled }.reduce(Int64(0)) { $0 + $1.amountMinor }
            return Money(minorUnits: left, currency: total.currency)
        }

        /// Creates the payment rows (exact agorot split; remainder on the first payment).
        public func generatePayments(calendar: Calendar) throws {
            let schedule = try InstallmentSchedule.payments(
                total: total, count: paymentCount, firstChargeDate: firstChargeDate, calendar: calendar)
            payments = schedule.map {
                InstallmentPayment(index: $0.index, dueDate: $0.dueDate, amount: $0.amount, hlc: updatedHLC)
            }
        }
    }

    @Model
    public final class InstallmentPayment {
        #Index<InstallmentPayment>([\.dueDate], [\.isSettled, \.dueDate])

        @Attribute(.unique) public var id: UUID
        /// 1-based ("payment 2 of 3").
        public var index: Int
        public var dueDate: Date
        public var amountMinor: Int64
        public var currencyCode: String
        public var isSettled: Bool
        public var updatedHLC: String
        public var isTombstoned: Bool

        public var plan: InstallmentPlan?
        /// The card-charge transaction that settled this payment, once it posts.
        @Relationship(deleteRule: .nullify, inverse: \LedgerTransaction.installmentPayment)
        public var settlingTransaction: LedgerTransaction?

        public init(id: UUID = UUID(), index: Int, dueDate: Date, amount: Money, hlc: String = "") {
            self.id = id
            self.index = index
            self.dueDate = dueDate
            self.amountMinor = amount.minorUnits
            self.currencyCode = amount.currency.rawValue
            self.isSettled = false
            self.updatedHLC = hlc
            self.isTombstoned = false
        }

        public var amount: Money { Money(minorUnits: amountMinor, currency: CurrencyCode(rawValue: currencyCode)) }
    }

    // MARK: LedgerEvent (append-only log; source of sync + undo)

    @Model
    public final class LedgerEvent {
        #Index<LedgerEvent>([\.syncStateRaw, \.hlc], [\.entityID], [\.hlc])

        @Attribute(.unique) public var id: UUID
        public var entityType: String        // "LedgerTransaction", "Category", ...
        public var entityID: UUID
        public var operationRaw: String
        /// HLC string; lexicographic order == causal order.
        public var hlc: String
        /// JSON of the changed fields only (field-level LWW). Encrypted by SyncVault before upload,
        /// protected at rest locally by NSFileProtectionComplete.
        public var changedFieldsJSON: Data
        public var syncStateRaw: String
        public var originDeviceID: String

        public init(id: UUID = UUID(), entityType: String, entityID: UUID, operation: LedgerOperation,
                    hlc: String, changedFieldsJSON: Data, originDeviceID: String) {
            self.id = id
            self.entityType = entityType
            self.entityID = entityID
            self.operationRaw = operation.rawValue
            self.hlc = hlc
            self.changedFieldsJSON = changedFieldsJSON
            self.syncStateRaw = SyncState.pending.rawValue
            self.originDeviceID = originDeviceID
        }

        public var operation: LedgerOperation { LedgerOperation(rawValue: operationRaw) ?? .update }
        public var syncState: SyncState {
            get { SyncState(rawValue: syncStateRaw) ?? .pending }
            set { syncStateRaw = newValue.rawValue }
        }
    }
}

// MARK: - Current-version aliases (the rest of the app only uses these)

public typealias Account = SchemaV1.Account
public typealias CardBillingCycle = SchemaV1.CardBillingCycle
public typealias LedgerTransaction = SchemaV1.LedgerTransaction
public typealias Category = SchemaV1.Category
public typealias Budget = SchemaV1.Budget
public typealias Merchant = SchemaV1.Merchant
public typealias Receipt = SchemaV1.Receipt
public typealias LineItem = SchemaV1.LineItem
public typealias RecurringRule = SchemaV1.RecurringRule
public typealias InstallmentPlan = SchemaV1.InstallmentPlan
public typealias InstallmentPayment = SchemaV1.InstallmentPayment
public typealias LedgerEvent = SchemaV1.LedgerEvent
