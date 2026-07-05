//
//  APIErrorMappingTests.swift
//  cueTests
//
//  Covers APIError's user/diagnostic message mapping and the private
//  ServerErrorBody / FlexibleMessage parsing that backs it. The private
//  structs are exercised indirectly through `APIError.userMessage` with
//  crafted `.http` bodies, since that is their only public entry point.
//

import Foundation
import Testing
@testable import cue

struct APIErrorMappingTests {

    // MARK: - userMessage: parsed NestJS body

    @Test func userMessageSurfacesParsedStringMessage() {
        let body = #"{"statusCode":400,"message":"Title must not be empty","error":"Bad Request"}"#
        let error = APIError.http(status: 400, body: body)
        #expect(error.userMessage == "Title must not be empty")
    }

    @Test func userMessageJoinsValidationArrayWithNewlines() {
        let body = #"{"statusCode":400,"message":["title should not be empty","color must be a hex"],"error":"Bad Request"}"#
        let error = APIError.http(status: 400, body: body)
        #expect(error.userMessage == "title should not be empty\ncolor must be a hex")
    }

    @Test func userMessageFallsBackToErrorLabelWhenMessageMissing() {
        // No `message` field at all -> displayMessage falls back to `error`.
        let body = #"{"statusCode":403,"error":"Forbidden"}"#
        let error = APIError.http(status: 403, body: body)
        #expect(error.userMessage == "Forbidden")
    }

    @Test func userMessagePrefersJoinedMessageOverErrorLabel() {
        // Both present: the `message` line wins over the `error` label.
        let body = #"{"statusCode":409,"message":"Already linked","error":"Conflict"}"#
        let error = APIError.http(status: 409, body: body)
        #expect(error.userMessage == "Already linked")
    }

    @Test func userMessageWithEmptyMessageArrayFallsBackToErrorLabel() {
        // Empty array -> joined is "" -> guard !joined.isEmpty skips it -> error label.
        let body = #"{"statusCode":400,"message":[],"error":"Bad Request"}"#
        let error = APIError.http(status: 400, body: body)
        #expect(error.userMessage == "Bad Request")
    }

    // MARK: - userMessage: unparseable body -> generic by status family

    @Test func unparseableBodyFallsBackToGenericAndIsNotRawBody() {
        let htmlBody = "<html><body>502 Bad Gateway</body></html>"
        let error = APIError.http(status: 502, body: htmlBody)
        // The HTML must NOT be surfaced as the user message.
        #expect(error.userMessage != htmlBody)
        #expect(!error.userMessage.isEmpty)
    }

    @Test func emptyBodyFallsBackToGenericMessage() {
        let error = APIError.http(status: 500, body: "")
        // Empty body is not a decodable envelope -> generic server-error copy.
        #expect(!error.userMessage.isEmpty)
        #expect(error.userMessage != "")
    }

    @Test func genericMessagesDifferAcrossStatusFamilies() {
        // Each distinct branch of genericMessage(for:) should yield a distinct
        // string so the user can tell the failure classes apart.
        let unauthorized = APIError.http(status: 401, body: "nope").userMessage
        let forbidden = APIError.http(status: 403, body: "nope").userMessage
        let notFound = APIError.http(status: 404, body: "nope").userMessage
        let timeout = APIError.http(status: 408, body: "nope").userMessage
        let rateLimited = APIError.http(status: 429, body: "nope").userMessage
        let clientError = APIError.http(status: 418, body: "nope").userMessage
        let serverError = APIError.http(status: 500, body: "nope").userMessage

        let all = [unauthorized, forbidden, notFound, timeout, rateLimited, clientError, serverError]
        #expect(Set(all).count == all.count)
    }

    @Test func timeoutFamilyMapsBothStatusesToSameMessage() {
        // 408 and 504 both route to api.userError.timeout.
        let plain408 = APIError.http(status: 408, body: "x").userMessage
        let plain504 = APIError.http(status: 504, body: "x").userMessage
        #expect(plain408 == plain504)
    }

    @Test func unknownStatusFamilyUsesUnknownBranch() {
        // A 3xx (not handled by any explicit family) hits the default branch.
        let error = APIError.http(status: 302, body: "redirect-ish")
        #expect(!error.userMessage.isEmpty)
    }

    // MARK: - userMessage: other cases

    @Test func transportUserMessageIsNonEmpty() {
        let error = APIError.transport("Connection lost")
        #expect(!error.userMessage.isEmpty)
    }

    @Test func decodingUserMessageIsNonEmpty() {
        let error = APIError.decoding("keyNotFound")
        #expect(!error.userMessage.isEmpty)
    }

    @Test func linkCodeInvalidUserMessageIsTheServerMessageVerbatim() {
        let error = APIError.linkCodeInvalid(message: "This code is no longer valid")
        #expect(error.userMessage == "This code is no longer valid")
    }

    // MARK: - diagnosticDetail

    @Test func diagnosticDetailForEmptyBodyContainsStatusOnly() {
        let error = APIError.http(status: 503, body: "")
        let detail = error.diagnosticDetail
        // Status-only framing: must mention the status, must not embed a body.
        #expect(detail.contains("503"))
    }

    @Test func diagnosticDetailForNonEmptyBodyContainsStatusAndBody() {
        let body = "boom-internal-trace"
        let error = APIError.http(status: 500, body: body)
        let detail = error.diagnosticDetail
        #expect(detail.contains("500"))
        #expect(detail.contains(body))
    }

    @Test func diagnosticDetailEmptyVsNonEmptyUseDifferentFraming() {
        let emptyDetail = APIError.http(status: 500, body: "").diagnosticDetail
        let bodyDetail = APIError.http(status: 500, body: "trace").diagnosticDetail
        #expect(emptyDetail != bodyDetail)
        #expect(bodyDetail.contains("trace"))
    }

    @Test func diagnosticDetailForLinkCodeInvalidFramesAs422WithMessage() {
        let error = APIError.linkCodeInvalid(message: "burned nonce")
        let detail = error.diagnosticDetail
        #expect(detail.contains("422"))
        #expect(detail.contains("burned nonce"))
    }

    @Test func diagnosticDetailForTransportIncludesUnderlyingMessage() {
        let error = APIError.transport("offline")
        #expect(error.diagnosticDetail.contains("offline"))
    }

    @Test func diagnosticDetailForDecodingIncludesUnderlyingMessage() {
        let error = APIError.decoding("typeMismatch at coordinate")
        #expect(error.diagnosticDetail.contains("typeMismatch at coordinate"))
    }

    // MARK: - errorDescription mirrors userMessage

    @Test func errorDescriptionEqualsUserMessage() {
        let httpError = APIError.http(status: 400, body: #"{"message":"bad input"}"#)
        #expect(httpError.errorDescription == httpError.userMessage)

        let linkError = APIError.linkCodeInvalid(message: "stale")
        #expect(linkError.errorDescription == linkError.userMessage)
    }

    // MARK: - isUnauthorized

    @Test func isUnauthorizedTrueOnlyForHttp401() {
        #expect(APIError.http(status: 401, body: "").isUnauthorized)
    }

    @Test func isUnauthorizedFalseForOtherStatuses() {
        #expect(!APIError.http(status: 403, body: "").isUnauthorized)
        #expect(!APIError.http(status: 400, body: "").isUnauthorized)
        #expect(!APIError.http(status: 500, body: "").isUnauthorized)
    }

    @Test func isUnauthorizedFalseForNonHttpCases() {
        #expect(!APIError.transport("x").isUnauthorized)
        #expect(!APIError.decoding("x").isUnauthorized)
        #expect(!APIError.linkCodeInvalid(message: "x").isUnauthorized)
    }

    // MARK: - isInvalidLinkCode

    @Test func isInvalidLinkCodeTrueOnlyForLinkCodeInvalid() {
        #expect(APIError.linkCodeInvalid(message: "x").isInvalidLinkCode)
    }

    @Test func isInvalidLinkCodeFalseForOtherCases() {
        // A generic 422 .http is NOT the typed invalid-link-code case.
        #expect(!APIError.http(status: 422, body: "x").isInvalidLinkCode)
        #expect(!APIError.transport("x").isInvalidLinkCode)
        #expect(!APIError.decoding("x").isInvalidLinkCode)
        #expect(!APIError.http(status: 401, body: "").isInvalidLinkCode)
    }

    // MARK: - FlexibleMessage decode tolerance (via userMessage)

    @Test func flexibleMessageDecodesSingleString() {
        let body = #"{"message":"just one line"}"#
        #expect(APIError.http(status: 400, body: body).userMessage == "just one line")
    }

    @Test func flexibleMessageDecodesArrayOfStrings() {
        let body = #"{"message":["a","b","c"]}"#
        #expect(APIError.http(status: 400, body: body).userMessage == "a\nb\nc")
    }

    @Test func singleElementArrayJoinsToThatElement() {
        let body = #"{"message":["only"]}"#
        #expect(APIError.http(status: 400, body: body).userMessage == "only")
    }

    // MARK: - ServerErrorBody robustness

    @Test func bodyWithOnlyMessageStillParses() {
        // statusCode and error absent; message alone drives displayMessage.
        let body = #"{"message":"lonely message"}"#
        #expect(APIError.http(status: 400, body: body).userMessage == "lonely message")
    }

    @Test func validJsonWithoutAnyRecognizedFieldsFallsBackToGeneric() {
        // Decodes as ServerErrorBody (all fields optional) but displayMessage is
        // nil -> userMessage falls through to the generic status message.
        let body = #"{"foo":"bar"}"#
        let error = APIError.http(status: 404, body: body)
        let genericNotFound = APIError.http(status: 404, body: "<not json>").userMessage
        #expect(error.userMessage == genericNotFound)
    }
}
