import Foundation
import SwiftGodot

// MARK: - Port Configuration

/// Configuration for a graph node port (input or output).
public struct Port {
    public let color: Color

    public init(_ color: Color = .white) {
        self.color = color
    }
}

// MARK: - Slot Elements

/// An element that can appear as a slot in a GraphNode.
public protocol GraphNodeSlotElement {
    /// Adds this slot to the given GraphNode at the specified index.
    func addTo(_ graphNode: GraphNode, slotIndex: Int32)
}

/// A slot in a GraphNode with optional left/right ports.
public struct Slot<Content: GView>: GraphNodeSlotElement {
    let content: Content
    let leftPort: Port?
    let rightPort: Port?

    /// Creates a slot with optional input/output ports.
    /// - Parameters:
    ///   - left: Input port configuration (nil = no input port).
    ///   - right: Output port configuration (nil = no output port).
    ///   - content: The control to display in this slot.
    public init(
        left: Port? = nil,
        right: Port? = nil,
        @GViewBuilder content: () -> Content
    ) {
        self.leftPort = left
        self.rightPort = right
        self.content = content()
    }

    public func addTo(_ graphNode: GraphNode, slotIndex: Int32) {
        let node = content.toNode()
        graphNode.addChild(node: node)

        graphNode.setSlot(
            slotIndex: slotIndex,
            enableLeftPort: leftPort != nil,
            typeLeft: 0,
            colorLeft: leftPort?.color ?? .white,
            enableRightPort: rightPort != nil,
            typeRight: 0,
            colorRight: rightPort?.color ?? .white
        )
    }
}

// MARK: - SlotBuilder Result Builder

@resultBuilder
public struct SlotBuilder {
    public static func buildExpression(_ element: GraphNodeSlotElement) -> [GraphNodeSlotElement] {
        [element]
    }

    public static func buildBlock(_ components: [GraphNodeSlotElement]...) -> [GraphNodeSlotElement] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [GraphNodeSlotElement]?) -> [GraphNodeSlotElement] {
        component ?? []
    }

    public static func buildEither(first component: [GraphNodeSlotElement]) -> [GraphNodeSlotElement] {
        component
    }

    public static func buildEither(second component: [GraphNodeSlotElement]) -> [GraphNodeSlotElement] {
        component
    }

    public static func buildArray(_ components: [[GraphNodeSlotElement]]) -> [GraphNodeSlotElement] {
        components.flatMap { $0 }
    }
}

// MARK: - GNode<GraphNode> Extension

public extension GNode where T == GraphNode {
    /// Creates a GraphNode with declarative slots.
    ///
    /// ### Example
    /// ```swift
    /// GraphNode$("add_node", title: "Add") {
    ///     Slot(left: Port(.green)) {
    ///         Label$().text("A")
    ///     }
    ///     Slot(left: Port(.green)) {
    ///         Label$().text("B")
    ///     }
    ///     Slot(right: Port(.green)) {
    ///         Label$().text("Result")
    ///     }
    /// }
    /// .positionOffset([100, 100])
    /// ```
    init(_ name: String, title: String, @SlotBuilder slots: () -> [GraphNodeSlotElement]) {
        let slotElements = slots()
        self.init(name, make: {
            let node = GraphNode()
            node.title = title
            for (index, slot) in slotElements.enumerated() {
                slot.addTo(node, slotIndex: Int32(index))
            }
            return node
        })
    }

    /// Sets the position offset of the node in the graph.
    func positionOffset(_ offset: Vector2) -> Self {
        configure { node in
            node.positionOffset = offset
        }
    }

    /// Connects to the `position_offset_changed` signal.
    func onPositionOffsetChanged(_ handler: @escaping (Vector2) -> Void) -> Self {
        configure { node in
            node.positionOffsetChanged.connect {
                handler(node.positionOffset)
            }
        }
    }

    /// Connects to the `node_selected` signal.
    func onNodeSelected(_ handler: @escaping () -> Void) -> Self {
        configure { node in
            node.nodeSelected.connect {
                handler()
            }
        }
    }

    /// Connects to the `node_deselected` signal.
    func onNodeDeselected(_ handler: @escaping () -> Void) -> Self {
        configure { node in
            node.nodeDeselected.connect {
                handler()
            }
        }
    }

    /// Connects to the `slot_updated` signal.
    func onSlotUpdated(_ handler: @escaping (Int64) -> Void) -> Self {
        configure { node in
            node.slotUpdated.connect { slotIndex in
                handler(slotIndex)
            }
        }
    }
}

// MARK: - GNode<GraphEdit> Extension

public extension GNode where T == GraphEdit {
    /// Connects to the `connection_request` signal.
    func onConnectionRequest(_ handler: @escaping (StringName, Int64, StringName, Int64) -> Void) -> Self {
        configure { graphEdit in
            graphEdit.connectionRequest.connect { fromNode, fromPort, toNode, toPort in
                handler(fromNode, fromPort, toNode, toPort)
            }
        }
    }

    /// Connects to the `disconnection_request` signal.
    func onDisconnectionRequest(_ handler: @escaping (StringName, Int64, StringName, Int64) -> Void) -> Self {
        configure { graphEdit in
            graphEdit.disconnectionRequest.connect { fromNode, fromPort, toNode, toPort in
                handler(fromNode, fromPort, toNode, toPort)
            }
        }
    }

    /// Connects to the `connection_to_empty` signal.
    func onConnectionToEmpty(_ handler: @escaping (StringName, Int64, Vector2) -> Void) -> Self {
        configure { graphEdit in
            graphEdit.connectionToEmpty.connect { fromNode, fromPort, releasePosition in
                handler(fromNode, fromPort, releasePosition)
            }
        }
    }

    /// Connects to the `connection_from_empty` signal.
    func onConnectionFromEmpty(_ handler: @escaping (StringName, Int64, Vector2) -> Void) -> Self {
        configure { graphEdit in
            graphEdit.connectionFromEmpty.connect { toNode, toPort, releasePosition in
                handler(toNode, toPort, releasePosition)
            }
        }
    }

    /// Connects to the `node_selected` signal.
    func onNodeSelected(_ handler: @escaping (Node) -> Void) -> Self {
        configure { graphEdit in
            graphEdit.nodeSelected.connect { node in
                if let node {
                    handler(node)
                }
            }
        }
    }

    /// Connects to the `node_deselected` signal.
    func onNodeDeselected(_ handler: @escaping (Node) -> Void) -> Self {
        configure { graphEdit in
            graphEdit.nodeDeselected.connect { node in
                if let node {
                    handler(node)
                }
            }
        }
    }

    /// Connects to the `delete_nodes_request` signal.
    func onDeleteNodesRequest(_ handler: @escaping (TypedArray<StringName>) -> Void) -> Self {
        configure { graphEdit in
            graphEdit.deleteNodesRequest.connect { nodes in
                handler(nodes)
            }
        }
    }

    /// Connects to the `copy_nodes_request` signal.
    func onCopyNodesRequest(_ handler: @escaping () -> Void) -> Self {
        configure { graphEdit in
            graphEdit.copyNodesRequest.connect {
                handler()
            }
        }
    }

    /// Connects to the `paste_nodes_request` signal.
    func onPasteNodesRequest(_ handler: @escaping () -> Void) -> Self {
        configure { graphEdit in
            graphEdit.pasteNodesRequest.connect {
                handler()
            }
        }
    }

    /// Connects to the `duplicate_nodes_request` signal.
    func onDuplicateNodesRequest(_ handler: @escaping () -> Void) -> Self {
        configure { graphEdit in
            graphEdit.duplicateNodesRequest.connect {
                handler()
            }
        }
    }

    /// Connects to the `scroll_offset_changed` signal.
    func onScrollOffsetChanged(_ handler: @escaping (Vector2) -> Void) -> Self {
        configure { graphEdit in
            graphEdit.scrollOffsetChanged.connect { offset in
                handler(offset)
            }
        }
    }

    /// Connects to the `begin_node_move` signal.
    func onBeginNodeMove(_ handler: @escaping () -> Void) -> Self {
        configure { graphEdit in
            graphEdit.beginNodeMove.connect {
                handler()
            }
        }
    }

    /// Connects to the `end_node_move` signal.
    func onEndNodeMove(_ handler: @escaping () -> Void) -> Self {
        configure { graphEdit in
            graphEdit.endNodeMove.connect {
                handler()
            }
        }
    }

    /// Connects to the `popup_request` signal.
    func onPopupRequest(_ handler: @escaping (Vector2) -> Void) -> Self {
        configure { graphEdit in
            graphEdit.popupRequest.connect { position in
                handler(position)
            }
        }
    }
}

