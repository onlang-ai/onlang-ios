import Foundation

/// A JSON document with the JavaScript data model (numbers are doubles), so canonical
/// serialization and content addresses match the TS compiler byte for byte.
public enum JSONValue: Codable, Equatable, Sendable {
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([JSONValue])
  case object([String: JSONValue])

  public init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    if c.decodeNil() { self = .null }
    else if let b = try? c.decode(Bool.self) { self = .bool(b) }
    else if let n = try? c.decode(Double.self) { self = .number(n) }
    else if let s = try? c.decode(String.self) { self = .string(s) }
    else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
    else { self = .object(try c.decode([String: JSONValue].self)) }
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .null: try c.encodeNil()
    case let .bool(b): try c.encode(b)
    case let .number(n):
      if let i = Self.exactInt(n) { try c.encode(i) } else { try c.encode(n) }
    case let .string(s): try c.encode(s)
    case let .array(a): try c.encode(a)
    case let .object(o): try c.encode(o)
    }
  }

  public static func parse(_ data: Data) throws -> JSONValue {
    try JSONDecoder().decode(JSONValue.self, from: data)
  }

  /// Round-trips any Encodable (e.g. a generated contract type) into a JSON value.
  public static func from<T: Encodable>(_ value: T) throws -> JSONValue {
    try parse(JSONEncoder().encode(value))
  }

  public func decode<T: Decodable>(_ type: T.Type) throws -> T {
    try JSONDecoder().decode(type, from: JSONEncoder().encode(self))
  }

  public subscript(key: String) -> JSONValue? {
    if case let .object(o) = self { return o[key] } else { return nil }
  }

  public var objectValue: [String: JSONValue]? { if case let .object(o) = self { o } else { nil } }
  public var arrayValue: [JSONValue]? { if case let .array(a) = self { a } else { nil } }
  public var stringValue: String? { if case let .string(s) = self { s } else { nil } }
  public var doubleValue: Double? { if case let .number(n) = self { n } else { nil } }
  public var boolValue: Bool? { if case let .bool(b) = self { b } else { nil } }

  /// Foundation representation (`[String: Any]`, NSNumber, NSNull…) for APIs such as DivKit.
  public var foundation: Any {
    switch self {
    case .null: NSNull()
    case let .bool(b): b
    case let .number(n): Self.exactInt(n).map { $0 as Any } ?? n
    case let .string(s): s
    case let .array(a): a.map(\.foundation)
    case let .object(o): o.mapValues(\.foundation)
    }
  }

  /// Without nulls (an absent key and a null are the same for comparisons).
  public var droppingNulls: JSONValue {
    switch self {
    case let .array(a): .array(a.map(\.droppingNulls))
    case let .object(o): .object(o.filter { $0.value != .null }.mapValues(\.droppingNulls))
    default: self
    }
  }

  static func exactInt(_ n: Double) -> Int? {
    n.rounded() == n && abs(n) < 9_007_199_254_740_992 ? Int(n) : nil
  }
}
