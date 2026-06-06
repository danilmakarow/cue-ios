//
//  FieldUpdate.swift
//  cue
//

import Foundation

/// Tri-state value for PATCH request fields, distinguishing three intents the
/// HTTP layer must encode differently:
///
/// - ``unchanged`` — the field was not touched; the key is **omitted** entirely
///   so the backend leaves the stored value as-is.
/// - ``clear`` — the user explicitly removed the value; the key is sent as an
///   explicit JSON `null` so the backend clears the stored value.
/// - ``set(_:)`` — the user provided a new value; the key carries that value.
///
/// Why this exists: Swift's synthesized `Codable` cannot express the
/// omit-vs-explicit-null distinction — an `Optional` property encodes `nil` as a
/// missing key (`encodeIfPresent`), so "clear" is indistinguishable from
/// "unchanged". A struct holding `FieldUpdate` fields implements a custom
/// `encode(to:)` and switches on each field's case to call `encodeNil`,
/// `encode`, or skip. See `UpdateTaskRequest` / `UpdateTaskGroupRequest`.
///
/// Encode-only by design — these are request bodies. (A `Decodable` conformance
/// would clash with the package's `MainActor` default isolation when used as a
/// generic `Sendable` constraint, and is unnecessary for request-only types.)
enum FieldUpdate<Value: Encodable & Sendable>: Sendable {
    case unchanged
    case clear
    case set(Value)

    /// Convenience: maps an optional into ``set(_:)`` (non-nil) or ``clear`` (nil).
    /// Use when the UI models "off" as `nil` and any change should be persisted —
    /// e.g. a recurrence the user can toggle on or fully remove.
    static func from(optional value: Value?) -> FieldUpdate<Value> {
        guard let value else { return .clear }
        return .set(value)
    }

    /// Encodes this field into `container` under `key`, honoring the tri-state:
    /// ``unchanged`` writes nothing, ``clear`` writes an explicit null, ``set``
    /// writes the value. The containing struct's `encode(to:)` calls this per
    /// field so a single helper centralizes the omit/null/value decision.
    func encode<Key: CodingKey>(
        into container: inout KeyedEncodingContainer<Key>,
        forKey key: Key
    ) throws {
        switch self {
        case .unchanged:
            break
        case .clear:
            try container.encodeNil(forKey: key)
        case .set(let value):
            try container.encode(value, forKey: key)
        }
    }
}
