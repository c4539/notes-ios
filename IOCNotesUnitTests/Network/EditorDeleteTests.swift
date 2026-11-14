// SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
import UIKit
@testable import iOCNotes

extension NetworkIntegrationTests {
    @MainActor
    @Suite("Deleting from the editor", .tags(.hermetic), .timeLimit(.minutes(1)), .isolatedAppState)
    struct EditorDeleteTests {
        let fixture: HermeticFixture

        init() throws {
            fixture = try #require(NetworkFixtures.hermetic)
        }

        private func makeEditor(for note: Note) throws -> EditorViewController {
            let storyboard = UIStoryboard(name: "Main_iPhone", bundle: nil)
            let navigationController = try #require(storyboard.instantiateViewController(withIdentifier: "Editor") as? UINavigationController)
            let editor = try #require(navigationController.topViewController as? EditorViewController)

            editor.loadViewIfNeeded()
            editor.note = note

            return editor
        }

        private func waitUntil(_ condition: () -> Bool) async throws {
            for _ in 0..<500 where !condition() {
                try await Task.sleep(for: .milliseconds(10))
            }
        }

        @Test("Deleting a note that was never uploaded removes it from the device")
        func deleteUnsyncedNote() async throws {
            let note = try fixture.seedLocal(id: -1, addNeeded: true)
            note.guid = "editor-delete"
            let editor = try makeEditor(for: note)

            editor.deleteNote(nil)
            try await waitUntil { fixture.localNote(guid: "editor-delete") == nil }

            #expect(editor.note == nil)
            #expect(fixture.localNote(guid: "editor-delete") == nil)
        }

        @Test("Deleting a synced note in offline mode marks it for deletion")
        func deleteSyncedNoteOffline() async throws {
            KeychainHelper.offlineMode = true

            // Opened as a pending note, so the editor does not fetch it; it counts as synced from here on.
            let note = try fixture.seedLocal(id: 7, addNeeded: true)
            let editor = try makeEditor(for: note)
            note.addNeeded = false

            editor.deleteNote(nil)
            try await waitUntil { fixture.localNote(id: 7)?.deleteNeeded == true }

            #expect(editor.note == nil)
            #expect(fixture.localNote(id: 7)?.deleteNeeded == true)
        }

        @Test("A read-only note is not deleted")
        func deleteReadOnlyNote() async throws {
            let note = try fixture.seedLocal(id: -1, readOnly: true, addNeeded: true)
            note.guid = "editor-read-only"
            let editor = try makeEditor(for: note)

            editor.deleteNote(nil)
            try await Task.sleep(for: .milliseconds(100))

            #expect(editor.note != nil)
            #expect(fixture.localNote(guid: "editor-read-only") != nil)
        }
    }
}
