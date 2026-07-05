//
//  EffectiveSettings.swift
//  cue
//
//  Client port of the backend `resolveEffectiveSettings` / `resolveEffectiveRecurrence`
//  (cue-api, src/modules/task/effective-settings.ts). Task-wins inheritance over the
//  owning group: each setting is the task's own value when set, else the group's, else
//  a hard default. The replica projection layer (Phase 3) resolves these at projection
//  time — the engine expands the EFFECTIVE recurrence config this returns.
//
//  Kept as pure value functions (no SwiftData / model dependency) so they can be
//  unit-tested directly and reused by the projector.
//

import Foundation

/// Task-wins effective-settings resolution, mirroring the backend resolver exactly.
nonisolated enum EffectiveSettings {
    /// Effective recurrence with the one override-aware rule on top of task-wins
    /// inheritance: an OVERRIDE CHILD (`isOverrideChild`) NEVER recurs — it is a
    /// materialized one-off replacing a single generated slot, so it must not expand
    /// via its own config (disallowed anyway) nor via group inheritance. Otherwise
    /// the task's own inline config wins, then the group default, then nil.
    static func recurrence(
        taskConfig: RecurrenceConfig?,
        groupConfig: RecurrenceConfig?,
        isOverrideChild: Bool
    ) -> RecurrenceConfig? {
        if isOverrideChild { return nil }

        return taskConfig ?? groupConfig
    }

    /// Effective completion requirement: task own ?? group default ?? false. The
    /// `false` default lives HERE, never as a stored default (ADR 0054 parity).
    static func requiresCompletion(taskValue: Bool?, groupValue: Bool?) -> Bool {
        taskValue ?? groupValue ?? false
    }

    /// Effective color: task own ?? group default ?? nil.
    static func color(taskValue: String?, groupValue: String?) -> String? {
        taskValue ?? groupValue
    }
}
