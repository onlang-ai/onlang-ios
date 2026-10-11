import CryptoKit
import Foundation
import OnlangContract

/// Store values the app provides (StoreKit): kind (price|period|trial) → product → text.
public typealias StoreValues = [String: [String: String]]

public enum BundleError: Error, Equatable {
  case malformed(String)
}

/// A delivered bundle: the typed header plus the raw `div-data` handed to DivKit.
public struct LoadedBundle: Sendable {
  public let raw: JSONValue
  public let header: BundleHeader

  public init(_ raw: JSONValue) throws {
    guard let onlang = raw["onlang"], raw["card"]?.objectValue != nil else { throw BundleError.malformed("not a bundle") }
    self.raw = raw
    header = try onlang.decode(BundleHeader.self)
  }

  public init(data: Data) throws { try self.init(JSONValue.parse(data)) }

  public var card: JSONValue { raw["card"] ?? .object([:]) }
  public var templates: JSONValue { raw["templates"] ?? .object([:]) }

  /// Recomputes the content address; delivery data that does not match is rejected.
  public func verify() -> Bool { Bundles.bundleId(raw) == header.bundleID }
}

public enum Bundles {
  /// Deterministic JSON identical to the TS `canonicalJson` (keys sorted by UTF-16 code
  /// units, no whitespace, `JSON.stringify` escaping and number formatting).
  public static func canonicalJson(_ value: JSONValue) -> String {
    var out = ""
    write(value, &out)
    return out
  }

  private static func write(_ value: JSONValue, _ out: inout String) {
    switch value {
    case .null: out += "null"
    case let .bool(b): out += b ? "true" : "false"
    case let .number(n): out += number(n)
    case let .string(s): string(s, &out)
    case let .array(a):
      out += "["
      for (i, v) in a.enumerated() {
        if i > 0 { out += "," }
        write(v, &out)
      }
      out += "]"
    case let .object(o):
      out += "{"
      for (i, k) in o.keys.sorted(by: { $0.utf16.lexicographicallyPrecedes($1.utf16) }).enumerated() {
        if i > 0 { out += "," }
        string(k, &out)
        out += ":"
        write(o[k]!, &out)
      }
      out += "}"
    }
  }

  /// JS number formatting for the values bundles carry (integers and plain decimals).
  private static func number(_ n: Double) -> String {
    if let i = JSONValue.exactInt(n) { return String(i) }
    return "\(n)"
  }

  private static func string(_ s: String, _ out: inout String) {
    out += "\""
    for u in s.unicodeScalars {
      switch u {
      case "\"": out += "\\\""
      case "\\": out += "\\\\"
      case "\u{08}": out += "\\b"
      case "\u{0C}": out += "\\f"
      case "\n": out += "\\n"
      case "\r": out += "\\r"
      case "\t": out += "\\t"
      default:
        if u.value < 0x20 { out += String(format: "\\u%04x", u.value) } else { out.unicodeScalars.append(u) }
      }
    }
    out += "\""
  }

  public static func sha256(_ text: String) -> String {
    "sha256:" + SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
  }

  /// Content address of a bundle: everything except `onlang.bundle_id`.
  public static func bundleId(_ bundle: JSONValue) -> String {
    var header = bundle["onlang"]?.objectValue ?? [:]
    header["bundle_id"] = nil
    let body = JSONValue.object([
      "onlang": .object(header),
      "templates": bundle["templates"] ?? .object([:]),
      "card": bundle["card"] ?? .null,
    ])
    return sha256(canonicalJson(body))
  }

  private static let placeholder = try! NSRegularExpression(pattern: OnlangConstants.storeTokenPattern)
  private static let global = try! NSRegularExpression(pattern: #"^onl_(price|period|trial)_(.+)$"#)

  /// Resolves `{{price|period|trial.<product>}}` inside every `custom_props` (they don't
  /// support DivKit expressions; ADR-0002). Text elsewhere uses DivKit globals instead.
  public static func prepass(_ card: JSONValue, store: StoreValues) -> JSONValue {
    transform(card, store, inCustomProps: false)
  }

  private static func transform(_ v: JSONValue, _ store: StoreValues, inCustomProps: Bool) -> JSONValue {
    switch v {
    case let .object(o):
      let isCustom = o["type"]?.stringValue == "custom"
      return .object(o.mapValuesWithKeys { k, x in transform(x, store, inCustomProps: inCustomProps || (isCustom && k == "custom_props")) })
    case let .array(a): return .array(a.map { transform($0, store, inCustomProps: inCustomProps) })
    case let .string(s) where inCustomProps: return .string(fill(s, store: store))
    default: return v
    }
  }

  public static func fill(_ text: String, store: StoreValues) -> String {
    let ns = text as NSString
    var out = ""
    var last = 0
    for m in placeholder.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
      out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
      let kind = ns.substring(with: m.range(at: 1))
      let product = ns.substring(with: m.range(at: 2))
      out += store[kind]?[product] ?? ns.substring(with: m.range)
      last = m.range.location + m.range.length
    }
    return out + ns.substring(from: last)
  }

  /// Values for the header's DivKit globals (`onl_<kind>_<product>`). Missing store data → "".
  public static func globalValues(_ header: BundleHeader, store: StoreValues) -> [String: String] {
    var out: [String: String] = [:]
    for g in header.globals {
      let ns = g as NSString
      if let m = global.firstMatch(in: g, range: NSRange(location: 0, length: ns.length)) {
        out[g] = store[ns.substring(with: m.range(at: 1))]?[ns.substring(with: m.range(at: 2))] ?? ""
      } else {
        out[g] = ""
      }
    }
    return out
  }
}

extension Dictionary {
  func mapValuesWithKeys<T>(_ f: (Key, Value) -> T) -> [Key: T] {
    Dictionary<Key, T>(uniqueKeysWithValues: map { ($0.key, f($0.key, $0.value)) })
  }
}
