//
//  BinaryNode.swift
//  
//
//  Created by roy on 2021/4/22.
//

import Foundation

public indirect enum BinaryNode<Element> {
    case none
    case node(left: Self, element: Element, right: Self)
    
    public init() {
        self = .none
    }
    
    public init(element: Element) {
        self = .node(left: .none, element: element, right: .none)
    }
}

public extension BinaryNode {
    var isEmpty: Bool {
        switch self {
        case .none:
            return true
        default:
            return false
        }
    }
    
    var data: Element? {
        guard case .node(_, let data, _) = self else {
            return nil
        }
        
        return data
    }
    
    var left: Self {
        guard case .node(let left, _, _) = self else {
            return .none
        }
        
        return left
    }
    
    var right: Self {
        guard case .node(_, _, let right) = self else {
            return .none
        }
        
        return right
    }
}

public extension BinaryNode {
    func reduce<T>(none: T, branch node: (T, Element, T) -> T) -> T {
        switch self {
        case .none:
            return none
        case let .node(left, element, right):
            return node(
                left.reduce(none: none, branch: node),
                element,
                right.reduce(none: none, branch: node)
            )
        }
    }
}

public extension BinaryNode {
    var count: Int {
        reduce(none: 0, branch: { $0 + 1 + $2 })
    }
    
    var elements: [Element] {
        reduce(none: [], branch: { $0 + [$1] + $2 })
    }
}

public extension BinaryNode {
    var depth: Int {
        reduce(none: 0) { max($0, $2) + 1 }
    }
}

extension BinaryNode {
    public func treeDescription(wordWidth: Int = 5) -> String {
        let infos = constructDescriptionInfos()
        let group = Dictionary(grouping: infos, by: { $0.y })
        let depth = self.depth
        let width = 2 << depth - 1
        let spacing = "-"
        let wordSpacing = " "
        
        func description(of element: Element, for width: Int) -> String {
            let original = "\(element)"
            switch original.count {
            case let count where count > width:
                return String(original.prefix(width))
            case let count where count < width:
                let preSpaceCount = (width - count) / 2
                let sufSpaceCount = width - count - preSpaceCount
                
                return (0..<preSpaceCount)
                    .map { _ in wordSpacing }
                    .joined()
                    + original
                    + (0..<sufSpaceCount)
                    .map { _ in wordSpacing }
                    .joined()
            default:
                return original
            }
        }
        
        func row(at index: Int) -> String {
            guard let items = group[index] else { return "" }
            
            let itemsInfo = Dictionary(grouping: items, by: { $0.x })
            
            let rowDes = (0..<width).reduce("") {
                let transformX = $1 - width / 2
                if let value = itemsInfo[transformX]?.first {
                    
                    return $0 + description(of: value.element, for: wordWidth)
                } else {
                    return $0 + (0..<wordWidth).map { _ in spacing }.joined()
                }
            }
            
            return rowDes
        }
        
        var rowsDes = (1...depth)
            .map(row(at:))
        
        let rowsDesCount = rowsDes.map(\.count)
        if let max = rowsDesCount.max() {
            (0..<rowsDes.count).forEach {
                let count = max - rowsDesCount[$0]
                if count > 0 {
                    let preSpaceCount = count / 2
                    let sufSpaceCount = count - preSpaceCount
                    
                    let newRow = (0..<preSpaceCount)
                        .map { _ in spacing }
                        .joined()
                        + rowsDes[$0]
                        + (0..<sufSpaceCount)
                        .map { _ in spacing }
                        .joined()
                    
                    rowsDes[$0] = newRow
                }
            }
        }
        
        return rowsDes
            .joined(separator: "\n\n")
    }
    
    struct Info {
        let element: Element
        let x: Int
        let y: Int
    }
    
    func constructDescriptionInfos() -> [Info] {
        var list = [Info]()
        let depth = self.depth
        
        func handle(
            node: Self,
            level: Int,
            left: Bool,
            parent: Info?
        ) {
            guard let data = node.data else { return }
            
            let widthAsRoot = 2 << (depth - level + 1) - 1
            let step = widthAsRoot / 2 + 1
            
            var x = 0
            if let parentInfo = parent {
                
                if left {
                    x = parentInfo.x - step
                } else {
                    x += parentInfo.x + step
                }
            }
            
            // self
            let info = Info(element: data, x: x, y: level)
            list.append(info)
            // left
            handle(node: node.left, level: level + 1, left: true, parent: info)
            // right
            handle(node: node.right, level: level + 1, left: false, parent: info)
        }
        
        handle(node: self, level: 1, left: true, parent: nil)
        
        return list
    }
}

public enum BinaryNodeError: Error, CustomStringConvertible {
    case invalidUpdate(String)
    
    public var description: String {
        switch self {
        case .invalidUpdate(let des):
            return des
        }
    }
}

public extension BinaryNode {
    mutating func update(element: Element) {
        self = .node(left: left, element: element, right: right)
    }
    
    mutating func update(left node: Self) throws {
        guard let element = data else {
            throw BinaryNodeError.invalidUpdate("none has no left")
        }
        
        self = .node(left: node, element: element, right: right)
    }
    
    mutating func update(right node: Self) throws {
        guard let element = data else {
            throw BinaryNodeError.invalidUpdate("none has no right")
        }
        
        self = .node(left: left, element: element, right: node)
    }
    
    mutating func clearn() {
        self = .none
    }
    
    mutating func removeLeft() throws {
        try update(left: .none)
    }
    
    mutating func removeRight() throws {
        try update(right: .none)
    }
}

extension BinaryNode: Equatable where Element: Equatable {}
