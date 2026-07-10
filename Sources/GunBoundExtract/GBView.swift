import ArgumentParser
import Foundation

/// Reads a `gbview` runtime dump — a JSON snapshot of the live game-state
/// object and the panel-manager widget tree, captured from the original
/// client's memory. Pretty-prints it (with a vtable/typeId legend so nodes are
/// self-describing) and can `--verify` the known Server Select panel geometry
/// against the port's own constants, turning eyeballed rects into a checkable
/// oracle.
extension GunBoundExtract {

    struct GBView: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "gbview",
            abstract: "Pretty-prints (and optionally verifies) a gbview runtime state/panel-tree dump."
        )

        @Argument(help: "Path to the gbview .json dump.")
        var dumpPath: String

        @Flag(help: "Check known panel geometry against the port's expected rects.")
        var verify: Bool = false

        func run() throws {
            let data = try Data(contentsOf: URL(fileURLWithPath: dumpPath))
            let dump = try JSONDecoder().decode(GBViewDump.self, from: data)

            let state = dump.gameState
            print("Game state #\(state.id) \(state.name)  \(state.object) vtable \(state.vtable)")
            for (key, value) in state.fields.sorted(by: { $0.key < $1.key }) {
                print("  \(key) = \(value)")
            }
            print("\nPanels (manager \(dump.view.manager)):")
            for panel in dump.view.panels {
                printNode(panel, depth: 1)
            }

            if verify {
                print("")
                try runVerify(dump)
            }
        }

        private func printNode(_ node: GBViewNode, depth: Int) {
            let indent = String(repeating: "  ", count: depth)
            let cls = GBViewLegend.className(forVTable: node.vtable)
            let kind = GBViewLegend.typeName(forTypeId: node.typeId)
            let flags = [node.hidden ? "hidden" : nil, node.enabled ? nil : "disabled", node.focused ? "focused" : nil]
                .compactMap { $0 }.joined(separator: ",")
            let r = node.rect
            print("\(indent)\(cls) [\(kind)] id \(node.id) rect (\(r.x),\(r.y),\(r.w)×\(r.h))\(flags.isEmpty ? "" : "  {\(flags)}")")
            for child in node.children {
                printNode(child, depth: depth + 1)
            }
        }

        // MARK: Verify

        /// Rect the port expects for a `(vtable, id, parentVTable)` node in the
        /// WORLD LIST panel — the constants Server Select is built from.
        private static let serverSelectExpected: [(label: String, vtable: String, rect: [Int])] = [
            ("WorldListPanel", "0x00557f08", [11, 13, 545, 530]),
            ("View All tab",   "0x00557da0", [336, 504, 74, 26]),   // id 0 under the panel
            ("Friends tab",    "0x00557da0", [430, 504, 74, 26]),   // id 1 under the panel
            ("Scroll list",    "0x00557e90", [526, 87, 18, 377]),
            ("Scroll up",      "0x00557da0", [526, 59, 18, 18]),
            ("Scroll down",    "0x00557da0", [526, 474, 18, 18]),
            // Buddy panel (id 20000) — only present when the panel is open.
            ("Buddy panel",    "0x00557be4", [568, 11, 211, 267]),
            ("Buddy Add",      "0x00557da0", [662, 18, 39, 20]),   // id 1
            ("Buddy Del",      "0x00557da0", [705, 18, 39, 20]),   // id 2
            ("Buddy close",    "0x00557da0", [748, 18, 22, 20]),   // id 0
            ("Buddy scroll",   "0x00557e90", [751, 84, 18, 152]),
            // Add-buddy dialog (id 10000) — present only while it's shown.
            ("Add-buddy dialog", "0x00557e68", [281, 206, 241, 148]),
        ]

        private func runVerify(_ dump: GBViewDump) throws {
            guard dump.gameState.id == 2 else {
                print("verify: only Server Select (state 2) is known; dump is state \(dump.gameState.id). Skipping.")
                return
            }
            // Flatten every node's rect keyed by (label we can recognize).
            var rects: [String: [Int]] = [:]
            func walk(_ node: GBViewNode, parent: GBViewNode?) {
                let r = [node.rect.x, node.rect.y, node.rect.w, node.rect.h]
                switch (node.vtable, node.id, parent?.vtable) {
                case ("0x00557f08", _, _): rects["WorldListPanel"] = r
                case ("0x00557da0", 0, "0x00557f08"): rects["View All tab"] = r
                case ("0x00557da0", 1, "0x00557f08"): rects["Friends tab"] = r
                case ("0x00557e90", _, "0x00557f08"): rects["Scroll list"] = r
                case ("0x00557da0", 0, "0x00557e90") where parent?.id == 0: rects["Scroll up"] = r
                case ("0x00557da0", 1, "0x00557e90") where parent?.id == 0: rects["Scroll down"] = r
                case ("0x00557be4", _, _): rects["Buddy panel"] = r
                case ("0x00557da0", 1, "0x00557be4"): rects["Buddy Add"] = r
                case ("0x00557da0", 2, "0x00557be4"): rects["Buddy Del"] = r
                case ("0x00557da0", 0, "0x00557be4"): rects["Buddy close"] = r
                case ("0x00557e90", _, "0x00557be4"): rects["Buddy scroll"] = r
                case ("0x00557e68", _, _): rects["Add-buddy dialog"] = r
                default: break
                }
                for child in node.children { walk(child, parent: node) }
            }
            for panel in dump.view.panels { walk(panel, parent: nil) }

            var mismatches = 0
            for expected in Self.serverSelectExpected {
                guard let actual = rects[expected.label] else {
                    print("  ? \(expected.label): not found in dump")
                    continue
                }
                if actual == expected.rect {
                    print("  ✓ \(expected.label): \(fmt(actual))")
                } else {
                    mismatches += 1
                    print("  ✗ \(expected.label): dump \(fmt(actual)) ≠ port \(fmt(expected.rect))")
                }
            }
            if mismatches == 0 {
                print("verify: OK — all known Server Select rects match the port.")
            } else {
                throw ValidationError("verify: \(mismatches) geometry mismatch(es).")
            }
        }

        private func fmt(_ r: [Int]) -> String { "(\(r[0]),\(r[1]),\(r[2])×\(r[3]))" }
    }
}

// MARK: - Dump model

private struct GBViewDump: Decodable {
    let gameState: GBViewGameState
    let view: GBViewTree
}

private struct GBViewGameState: Decodable {
    let id: Int
    let name: String
    let object: String
    let vtable: String
    let fields: [String: Int]
}

private struct GBViewTree: Decodable {
    let manager: String
    let panels: [GBViewNode]
}

private struct GBViewNode: Decodable {
    let addr: String
    let vtable: String
    let typeId: Int
    let id: Int
    let rect: GBViewRect
    let focused: Bool
    let enabled: Bool
    let hidden: Bool
    let children: [GBViewNode]
}

private struct GBViewRect: Decodable {
    let x, y, w, h: Int
}

// MARK: - Legend

private enum GBViewLegend {
    /// Widget-class names by vtable address (from `src/cxx/Widget.h`).
    static func className(forVTable vtable: String) -> String {
        switch vtable.lowercased() {
        case "0x00557f08": return "CWorldListPanel"
        case "0x00557da0": return "CLabel"
        case "0x00557e90": return "CScrollList"
        case "0x00557cac": return "CChannelUserListPanel"
        case "0x00557ee0": return "CReadyRoomChatPanel"
        case "0x00557cd4": return "CLobbyChatPanel"
        case "0x00557eb8": return "CAvatarStorePanel"
        default: return "CWidget(\(vtable))"
        }
    }

    /// Widget kind by the dump's `typeId`.
    static func typeName(forTypeId typeId: Int) -> String {
        switch typeId {
        case 0: return "panel"
        case 1: return "label"
        case 4: return "scroll"
        default: return "type\(typeId)"
        }
    }
}
