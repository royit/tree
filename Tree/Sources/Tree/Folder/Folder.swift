//
//  Folder.swift
//  
//
//  Created by roy on 2021/4/22.
//

import Foundation

public struct FolderEditChange: Equatable {
	static let none = FolderEditChange()

	let insertIndexPaths: [IndexPath]
	let removeIndexPaths: [IndexPath]
	let insertIndexSet: IndexSet
	let removeIndexSet: IndexSet
    
    init(
        insertIndexPaths: [IndexPath] = [],
        removeIndexPaths: [IndexPath] = [],
        insertIndexSet: IndexSet = [],
        removeIndexSet: IndexSet = []
    ) {
        self.insertIndexPaths = insertIndexPaths
        self.removeIndexPaths = removeIndexPaths
        self.insertIndexSet = insertIndexSet
        self.removeIndexSet = removeIndexSet
    }
}

public struct Folder<Element: FolderElementConstructable> {
    public typealias Item = FolderItem<Element>
    
    public var enabledFold: Bool
    
    typealias Node = BinaryNode<Item>
    private(set) var root: Node
    private(set) var sections = [Section]()
    
    var numberOfSections: Int { sections.count }
    
    public init(elements: [Element] = [], enabledFold: Bool = true) {
        self.enabledFold = enabledFold
        self.root = Item.recursiveConstructNode(with: elements)
        
		constructTableDataSource()
    }
}

extension Folder {
	func item(forRowAt indexPath: IndexPath) -> Item {
		sections[indexPath.section].subItems[indexPath.row]
	}

	func item(for section: Int) -> Item {
		sections[section].item
	}
}

public extension Folder {
	struct Section: Equatable {
        let item: Item
        var subItems: [Item]
        
        init(item: Item, subItems: [Item] = []) {
            self.item = item
            self.subItems = subItems
        }
        
        var numberOfRows: Int {
            subItems.count
        }
        
        mutating func append(subItems new: [Item]) {
            subItems += new
        }
    }
}

// MARK: - Toggle
extension Folder {
	public typealias ToogleTreeResult = (change: FolderEditChange, newState: FolderItemState)
	public mutating func toggle(section: Int) throws -> ToogleTreeResult {
		@discardableResult
		func toggle() throws -> ToggleResult {
			// 1. search node
			// ??????section???superSection?????????????????????
			let secitonInfos = Dictionary(grouping: sections[0..<section], by: { $0.item.id })

			var pathIdentifiers = [sections[section].item.id]
			var element: Element? = sections[section].item.element

            while let id = element?.parentIdentifier, id != Element.invisableRootIdentifier {
				pathIdentifiers.append(id)
				element = secitonInfos[id]?.first?.item.element
			}

            let result = try toggleNode(for: pathIdentifiers, in: root)
            return result
		}

		let result = try toggle()
        
        guard let newState = result.destinationNode.element?.state else {
            throw FolderError.toggle("destinationNode should be branch")
        }
        
        var expandedSections = sections
        
        root = result.node
        constructTableDataSource()
        
        if newState == .expand {
            expandedSections = sections
        }
        
        let change = caculateChange(
            of: result.destinationNode,
            at: section,
            with: newState,
            expandedSections: expandedSections
        )

        return (change, .expand)
	}
    
    /// ?????????????????????????????? tableDateSource Change
    /// - Parameters:
    ///   - node: ???????????????????????????
    ///   - section: ???????????????section index
    ///   - state: ??????????????????
    /// - Returns: ??????tableView???????????????
    private func caculateChange(
        of node: Node,
        at section: Int,
        with state: FolderItemState,
        expandedSections: [Section]
    ) -> FolderEditChange {
        let left = constructDataSource(node: node.left, isOnlyExpand: true)
        
        var insertIndexPaths = [IndexPath]()
        var removeIndexPaths = [IndexPath]()
        var insertIndexSet = IndexSet()
        var removeIndexSet = IndexSet()
        
        switch left {
        case .none:
            return .none
        case .rows(let rows):
            switch state {
            case .collapse:
                removeIndexPaths = (0..<rows.count).map { .init(row: $0, section: section) }
            case .expand:
                insertIndexPaths = (0..<rows.count).map { .init(row: $0, section: section) }
            }
        case let .sections(sections, rows):
            let indexSet = IndexSet((1...sections.count).map { $0 + section })
            let indexPathes = (0..<rows.count).map { IndexPath(row: $0, section: section) }
            
            // ???????????? node ???????????? ???rows??????????????????node???????????????section?????????
            var otherIndexPathes = [IndexPath]()
            if let last = sections.last,
               let expandSection = expandedSections.first(where: { $0.item.id == last.item.id }),
               last.subItems.count < expandSection.subItems.count {
                
                otherIndexPathes = (0..<(expandSection.subItems.count - last.subItems.count))
                    .map { IndexPath(row: $0, section: section) }
            }
            
            switch state {
            case .collapse:
                removeIndexSet = indexSet
                removeIndexPaths = indexPathes
                insertIndexPaths = otherIndexPathes
            case .expand:
                insertIndexSet = indexSet
                insertIndexPaths = indexPathes
                removeIndexPaths = otherIndexPathes
            }
        }
        
        return .init(
            insertIndexPaths: insertIndexPaths,
            removeIndexPaths: removeIndexPaths,
            insertIndexSet: insertIndexSet,
            removeIndexSet: removeIndexSet
        )
    }

	/// node?????????path?????????????????????node???destinationNode????????????????????????????????????????????????
	typealias ToggleResult = (node: Node, destinationNode: Node)

	/// ??????????????? id ??????????????????node??????????????????node????????????
	/// - Parameters:
	///   - ids: ????????? id ??????????????????id???????????????????????????????????????id???????????????id?????????node??????subnodes??????????????????
	///   - node: path????????????node????????????????????????node
	/// - Returns:
	private func toggleNode(for ids: [Element.ID], in node: Node) throws -> ToggleResult {
		guard let id = ids.last else {
            throw FolderError.toggle("ids should not empty")
		}

		var node = node
		let destinationNode: Node

		if id == node.element?.id {
			if ids.count > 1 {
				var ids = ids
				ids.removeLast()
				let result = try toggleNode(for: ids, in: node.left)
                try node.update(left: result.node)
                destinationNode = result.destinationNode
			} else {
                node = toggle(node: node)
                destinationNode = node
			}
		} else {
			let result = try toggleNode(for: ids, in: node.right)
            try node.update(right: result.node)
			destinationNode = result.destinationNode
		}

		return (node, destinationNode)
	}

	/// ????????????????????????
	/// - Parameter node: ??????
	/// - Returns: ??????????????????
	private func toggle(node: Node) -> Node {
		guard let element = node.element else {
			return node
		}

		var node = node
		node.update(element: Item(element: element.element, depth: element.depth, state: element.state.toggled))
		return node
	}
}

// MARK: - Construct
extension Folder {
    enum NodeDataSource {
		/// ??????rows??????????????????
        case rows([Item])
		/// ??????????????????
        case sections([Section], [Item])
		/// ??????
        case none
        
        var rows: [Item] {
            switch self {
            case .rows(let rows):
                return rows
            case .sections(_, let rows):
                return rows
            case .none:
                return []
            }
        }
    }
    
    mutating func constructTableDataSource() {
        self.sections = construct(node: root, isOnlyExpand: enabledFold)
    }
    
    private func construct(node: Node, isOnlyExpand flag: Bool = false) -> [Section] {
        let info = constructDataSource(node: node, isOnlyExpand: flag)
        
        switch info {
        // ??????
        case .none:
            return []
        // ???????????????
        case .rows(let rows):
            return rows.map { .init(item: $0) }
        case let .sections(sections, rows):
            return rows.map { .init(item: $0) } + sections
        }
    }
    
    private func constructDataSource(node: Node, isOnlyExpand flag: Bool) -> NodeDataSource {
        node.reduce(none: NodeDataSource.none) { left , element, right in
            switch (left, right) {
            // left???none???right???none??? ????????????
            case (.none, .none):
                return .rows([element])
                
            // left???none???right???right????????????????????????
            case (.none, .rows(let rows)):
                return .rows([element] + rows)
                
            // left???left???????????????????????????right???none
            case (.rows(let leftRows), .none):
                let rows = (!flag || element.state.isExpand) ? leftRows : []
                return .sections([Section(item: element, subItems: rows)], [])
                
            case let (.rows(leftRows), .rows(rightRows)):
                let rows = (!flag || element.state.isExpand) ? leftRows + rightRows : rightRows
                let section = Section(item: element, subItems: rows)
                return .sections([section], [])
                
            // left???none???right????????????????????????????????????????????????????????????
            case let (.none, .sections(sections, rows)):
                return .sections(sections, [element] + rows)
                
            // left: ?????????????????????????????????????????????????????????; right???none
            case let (.sections(sections, leftRows), .none):
                guard !flag || element.state.isExpand else {
                    return .sections([Section(item: element)], [])
                }
                
                let section = Section(item: element, subItems: leftRows)
                return .sections([section] + sections, [])
                
            // left: ?????????????????????????????????????????????????????????; right???right????????????????????????
            case (.sections(var sections, let leftRows), .rows(let rightRows)):
                guard !flag || element.state.isExpand else {
                    let section = Section(item: element, subItems: rightRows)
                    return .sections([section] , [])
                }
                
                if !sections.isEmpty {
                    var last = sections.removeLast()
                    last.append(subItems: rightRows)
                    sections.append(last)
                }
                
                let section = Section(item: element, subItems: leftRows)
                return .sections([section] + sections, [])
                
            // left???left???????????????????????????right: ?????????????????????????????????????????????????????????
            case let (.rows(leftRows), .sections(sections, rightRows)):
                let rows = (!flag || element.state.isExpand) ? leftRows + rightRows : rightRows
                let section = Section(item: element, subItems: rows)
                return .sections([section] + sections, [])
                
            // left: ?????????????????????????????????????????????????????????; right: ?????????????????????????????????????????????????????????
            case (.sections(var leftSections, let leftRows), .sections(let rightSections, let rightRows)):
                guard !flag || element.state.isExpand else {
                    let section = Section(item: element, subItems: rightRows)
                    return .sections([section] + rightSections, [])
                }
                
                if !leftSections.isEmpty {
                    var last = leftSections.removeLast()
                    last.append(subItems: rightRows)
                    leftSections.append(last)
                }
                
                let section = Section(item: element, subItems: leftRows)
                return .sections([section] + leftSections + rightSections, [])
            }
        }
    }
}

extension Folder {
    enum FolderError: Error {
        case toggle(String)
    }
}
