//
//  MeContactPhotoLoader.swift
//  cue
//

import Foundation

/// Attempts to source the user's profile picture at sign-in time.
///
/// Apple Sign-In itself doesn't expose a profile picture, and iOS (unlike
/// macOS) has no public API to read the "Me" contact — `unifiedMeContactWithKeys`
/// is macOS-only. Without a reliable system source, this loader currently
/// returns `nil` and the avatar stays empty until the user picks one in
/// Settings (to be added).
///
/// The BE flow is fully wired for a base64 avatar — once a photo-picker lands,
/// only this function needs to produce a base64 string and the rest works.
enum MeContactPhotoLoader {
    /// Returns a base64-encoded JPEG of the user's profile picture, or `nil`
    /// when no source is available. Async to leave room for future
    /// implementations that have to hit disk or user-permission prompts.
    static func load() async -> String? {
        return nil
    }
}
