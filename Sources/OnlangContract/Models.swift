// This file was generated from JSON Schema using quicktype, do not modify it directly.
// To parse the JSON, add this file to your project and do:
//
//   let registry = try Registry(json)
//   let bundleHeader = try BundleHeader(json)
//   let flowManifest = try FlowManifest(json)
//   let flowResponse = try FlowResponse(json)
//   let event = try Event(json)
//   let behaviorVector = try BehaviorVector(json)

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

import Foundation

// MARK: - Registry
public struct Registry: Codable, Equatable, Sendable {
    public let components: [String: ComponentSpec]
    public let products: [String]
    public let registry: String
    public let version: String

    public enum CodingKeys: String, CodingKey {
        case components = "components"
        case products = "products"
        case registry = "registry"
        case version = "version"
    }

    public init(components: [String: ComponentSpec], products: [String], registry: String, version: String) {
        self.components = components
        self.products = products
        self.registry = registry
        self.version = version
    }
}

// MARK: Registry convenience initializers and mutators

public extension Registry {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Registry.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        components: [String: ComponentSpec]? = nil,
        products: [String]? = nil,
        registry: String? = nil,
        version: String? = nil
    ) -> Registry {
        return Registry(
            components: components ?? self.components,
            products: products ?? self.products,
            registry: registry ?? self.registry,
            version: version ?? self.version
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - ComponentSpec
public struct ComponentSpec: Codable, Equatable, Sendable {
    public let emits: [Verb]?
    public let heightDP: Int?
    public let interactive: Bool?
    public let platforms: [Platform]?
    public let props: [String: PropSpec]

    public enum CodingKeys: String, CodingKey {
        case emits = "emits"
        case heightDP = "height_dp"
        case interactive = "interactive"
        case platforms = "platforms"
        case props = "props"
    }

    public init(emits: [Verb]?, heightDP: Int?, interactive: Bool?, platforms: [Platform]?, props: [String: PropSpec]) {
        self.emits = emits
        self.heightDP = heightDP
        self.interactive = interactive
        self.platforms = platforms
        self.props = props
    }
}

// MARK: ComponentSpec convenience initializers and mutators

public extension ComponentSpec {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(ComponentSpec.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        emits: [Verb]?? = nil,
        heightDP: Int?? = nil,
        interactive: Bool?? = nil,
        platforms: [Platform]?? = nil,
        props: [String: PropSpec]? = nil
    ) -> ComponentSpec {
        return ComponentSpec(
            emits: emits ?? self.emits,
            heightDP: heightDP ?? self.heightDP,
            interactive: interactive ?? self.interactive,
            platforms: platforms ?? self.platforms,
            props: props ?? self.props
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

public enum Verb: String, Codable, Equatable, Sendable {
    case answer = "answer"
    case close = "close"
    case next = "next"
    case purchase = "purchase"
    case restore = "restore"
    case select = "select"
    case verbOpen = "open"
}

public enum Platform: String, Codable, Equatable, Sendable {
    case android = "android"
    case ios = "ios"
    case web = "web"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - PropSpec
public struct PropSpec: Codable, Equatable, Sendable {
    public let maxChars: Int?
    public let propSpecOptional: Bool?
    public let type: PropSpecType
    public let maxItems: Int?
    public let minItems: Int?
    public let values: [String]?
    public let max: Int?
    public let min: Int?

    public enum CodingKeys: String, CodingKey {
        case maxChars = "max_chars"
        case propSpecOptional = "optional"
        case type = "type"
        case maxItems = "max_items"
        case minItems = "min_items"
        case values = "values"
        case max = "max"
        case min = "min"
    }

    public init(maxChars: Int?, propSpecOptional: Bool?, type: PropSpecType, maxItems: Int?, minItems: Int?, values: [String]?, max: Int?, min: Int?) {
        self.maxChars = maxChars
        self.propSpecOptional = propSpecOptional
        self.type = type
        self.maxItems = maxItems
        self.minItems = minItems
        self.values = values
        self.max = max
        self.min = min
    }
}

// MARK: PropSpec convenience initializers and mutators

public extension PropSpec {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(PropSpec.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        maxChars: Int?? = nil,
        propSpecOptional: Bool?? = nil,
        type: PropSpecType? = nil,
        maxItems: Int?? = nil,
        minItems: Int?? = nil,
        values: [String]?? = nil,
        max: Int?? = nil,
        min: Int?? = nil
    ) -> PropSpec {
        return PropSpec(
            maxChars: maxChars ?? self.maxChars,
            propSpecOptional: propSpecOptional ?? self.propSpecOptional,
            type: type ?? self.type,
            maxItems: maxItems ?? self.maxItems,
            minItems: minItems ?? self.minItems,
            values: values ?? self.values,
            max: max ?? self.max,
            min: min ?? self.min
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

public enum PropSpecType: String, Codable, Equatable, Sendable {
    case asset = "asset"
    case bool = "bool"
    case int = "int"
    case product = "product"
    case products = "products"
    case token = "token"
    case tokenList = "token_list"
    case typeEnum = "enum"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - BundleHeader
public struct BundleHeader: Codable, Equatable, Sendable {
    public let assignment: [String: String]
    public let bundleID: String
    public let contract: Contract
    public let ctaNode: String?
    public let depthTotal: Int
    public let divkit: Divkit
    public let globals: [String]
    public let interactiveIDS: [String]
    public let kind: Kind
    public let locale: String
    public let products: [String]
    public let registry: RegistryRef
    public let screen: String
    public let template: String

    public enum CodingKeys: String, CodingKey {
        case assignment = "assignment"
        case bundleID = "bundle_id"
        case contract = "contract"
        case ctaNode = "cta_node"
        case depthTotal = "depth_total"
        case divkit = "divkit"
        case globals = "globals"
        case interactiveIDS = "interactive_ids"
        case kind = "kind"
        case locale = "locale"
        case products = "products"
        case registry = "registry"
        case screen = "screen"
        case template = "template"
    }

    public init(assignment: [String: String], bundleID: String, contract: Contract, ctaNode: String?, depthTotal: Int, divkit: Divkit, globals: [String], interactiveIDS: [String], kind: Kind, locale: String, products: [String], registry: RegistryRef, screen: String, template: String) {
        self.assignment = assignment
        self.bundleID = bundleID
        self.contract = contract
        self.ctaNode = ctaNode
        self.depthTotal = depthTotal
        self.divkit = divkit
        self.globals = globals
        self.interactiveIDS = interactiveIDS
        self.kind = kind
        self.locale = locale
        self.products = products
        self.registry = registry
        self.screen = screen
        self.template = template
    }
}

// MARK: BundleHeader convenience initializers and mutators

public extension BundleHeader {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(BundleHeader.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        assignment: [String: String]? = nil,
        bundleID: String? = nil,
        contract: Contract? = nil,
        ctaNode: String?? = nil,
        depthTotal: Int? = nil,
        divkit: Divkit? = nil,
        globals: [String]? = nil,
        interactiveIDS: [String]? = nil,
        kind: Kind? = nil,
        locale: String? = nil,
        products: [String]? = nil,
        registry: RegistryRef? = nil,
        screen: String? = nil,
        template: String? = nil
    ) -> BundleHeader {
        return BundleHeader(
            assignment: assignment ?? self.assignment,
            bundleID: bundleID ?? self.bundleID,
            contract: contract ?? self.contract,
            ctaNode: ctaNode ?? self.ctaNode,
            depthTotal: depthTotal ?? self.depthTotal,
            divkit: divkit ?? self.divkit,
            globals: globals ?? self.globals,
            interactiveIDS: interactiveIDS ?? self.interactiveIDS,
            kind: kind ?? self.kind,
            locale: locale ?? self.locale,
            products: products ?? self.products,
            registry: registry ?? self.registry,
            screen: screen ?? self.screen,
            template: template ?? self.template
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

public enum Contract: String, Codable, Equatable, Sendable {
    case the10 = "1.0"
}

public enum Divkit: String, Codable, Equatable, Sendable {
    case the3360 = "33.6.0"
}

public enum Kind: String, Codable, Equatable, Sendable {
    case onboarding = "onboarding"
    case paywall = "paywall"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - RegistryRef
public struct RegistryRef: Codable, Equatable, Sendable {
    public let hash: String
    public let name: String

    public enum CodingKeys: String, CodingKey {
        case hash = "hash"
        case name = "name"
    }

    public init(hash: String, name: String) {
        self.hash = hash
        self.name = name
    }
}

// MARK: RegistryRef convenience initializers and mutators

public extension RegistryRef {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(RegistryRef.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        hash: String? = nil,
        name: String? = nil
    ) -> RegistryRef {
        return RegistryRef(
            hash: hash ?? self.hash,
            name: name ?? self.name
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - FlowResponse
public struct FlowResponse: Codable, Equatable, Sendable {
    public let assignment: [String: String]
    public let locale: String
    public let manifest: FlowManifest
    public let placement: String
    public let releaseID: String

    public enum CodingKeys: String, CodingKey {
        case assignment = "assignment"
        case locale = "locale"
        case manifest = "manifest"
        case placement = "placement"
        case releaseID = "release_id"
    }

    public init(assignment: [String: String], locale: String, manifest: FlowManifest, placement: String, releaseID: String) {
        self.assignment = assignment
        self.locale = locale
        self.manifest = manifest
        self.placement = placement
        self.releaseID = releaseID
    }
}

// MARK: FlowResponse convenience initializers and mutators

public extension FlowResponse {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(FlowResponse.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        assignment: [String: String]? = nil,
        locale: String? = nil,
        manifest: FlowManifest? = nil,
        placement: String? = nil,
        releaseID: String? = nil
    ) -> FlowResponse {
        return FlowResponse(
            assignment: assignment ?? self.assignment,
            locale: locale ?? self.locale,
            manifest: manifest ?? self.manifest,
            placement: placement ?? self.placement,
            releaseID: releaseID ?? self.releaseID
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - FlowManifest
public struct FlowManifest: Codable, Equatable, Sendable {
    public let assignment: [String: String]
    public let contract: Contract
    public let flowID: String
    public let locale: String
    public let registry: RegistryRef
    public let screens: [Screen]

    public enum CodingKeys: String, CodingKey {
        case assignment = "assignment"
        case contract = "contract"
        case flowID = "flow_id"
        case locale = "locale"
        case registry = "registry"
        case screens = "screens"
    }

    public init(assignment: [String: String], contract: Contract, flowID: String, locale: String, registry: RegistryRef, screens: [Screen]) {
        self.assignment = assignment
        self.contract = contract
        self.flowID = flowID
        self.locale = locale
        self.registry = registry
        self.screens = screens
    }
}

// MARK: FlowManifest convenience initializers and mutators

public extension FlowManifest {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(FlowManifest.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        assignment: [String: String]? = nil,
        contract: Contract? = nil,
        flowID: String? = nil,
        locale: String? = nil,
        registry: RegistryRef? = nil,
        screens: [Screen]? = nil
    ) -> FlowManifest {
        return FlowManifest(
            assignment: assignment ?? self.assignment,
            contract: contract ?? self.contract,
            flowID: flowID ?? self.flowID,
            locale: locale ?? self.locale,
            registry: registry ?? self.registry,
            screens: screens ?? self.screens
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - Screen
public struct Screen: Codable, Equatable, Sendable {
    public let bundleID: String
    public let screen: String

    public enum CodingKeys: String, CodingKey {
        case bundleID = "bundle_id"
        case screen = "screen"
    }

    public init(bundleID: String, screen: String) {
        self.bundleID = bundleID
        self.screen = screen
    }
}

// MARK: Screen convenience initializers and mutators

public extension Screen {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Screen.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        bundleID: String? = nil,
        screen: String? = nil
    ) -> Screen {
        return Screen(
            bundleID: bundleID ?? self.bundleID,
            screen: screen ?? self.screen
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - Event
public struct Event: Codable, Equatable, Sendable {
    public let app: String
    public let assignment: [String: String]
    public let bundleID: String
    public let eventID: String
    public let installID: String
    public let node: String?
    public let payload: Payload?
    public let registryHash: String
    public let screen: String
    public let seq: Int
    public let sessionID: String
    public let tsClientMS: Int
    public let type: EventType

    public enum CodingKeys: String, CodingKey {
        case app = "app"
        case assignment = "assignment"
        case bundleID = "bundle_id"
        case eventID = "event_id"
        case installID = "install_id"
        case node = "node"
        case payload = "payload"
        case registryHash = "registry_hash"
        case screen = "screen"
        case seq = "seq"
        case sessionID = "session_id"
        case tsClientMS = "ts_client_ms"
        case type = "type"
    }

    public init(app: String, assignment: [String: String], bundleID: String, eventID: String, installID: String, node: String?, payload: Payload?, registryHash: String, screen: String, seq: Int, sessionID: String, tsClientMS: Int, type: EventType) {
        self.app = app
        self.assignment = assignment
        self.bundleID = bundleID
        self.eventID = eventID
        self.installID = installID
        self.node = node
        self.payload = payload
        self.registryHash = registryHash
        self.screen = screen
        self.seq = seq
        self.sessionID = sessionID
        self.tsClientMS = tsClientMS
        self.type = type
    }
}

// MARK: Event convenience initializers and mutators

public extension Event {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Event.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        app: String? = nil,
        assignment: [String: String]? = nil,
        bundleID: String? = nil,
        eventID: String? = nil,
        installID: String? = nil,
        node: String?? = nil,
        payload: Payload?? = nil,
        registryHash: String? = nil,
        screen: String? = nil,
        seq: Int? = nil,
        sessionID: String? = nil,
        tsClientMS: Int? = nil,
        type: EventType? = nil
    ) -> Event {
        return Event(
            app: app ?? self.app,
            assignment: assignment ?? self.assignment,
            bundleID: bundleID ?? self.bundleID,
            eventID: eventID ?? self.eventID,
            installID: installID ?? self.installID,
            node: node ?? self.node,
            payload: payload ?? self.payload,
            registryHash: registryHash ?? self.registryHash,
            screen: screen ?? self.screen,
            seq: seq ?? self.seq,
            sessionID: sessionID ?? self.sessionID,
            tsClientMS: tsClientMS ?? self.tsClientMS,
            type: type ?? self.type
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - Payload
public struct Payload: Codable, Equatable, Sendable {
    public let interactive: Bool?
    public let logID: String?
    public let params: [String: String]?
    public let purchased: Bool?
    public let reason: Reason?
    public let stat: Stat?
    public let vector: BehaviorVector?
    public let verb: Verb?
    public let x: Double?
    public let y: Double?

    public enum CodingKeys: String, CodingKey {
        case interactive = "interactive"
        case logID = "log_id"
        case params = "params"
        case purchased = "purchased"
        case reason = "reason"
        case stat = "stat"
        case vector = "vector"
        case verb = "verb"
        case x = "x"
        case y = "y"
    }

    public init(interactive: Bool?, logID: String?, params: [String: String]?, purchased: Bool?, reason: Reason?, stat: Stat?, vector: BehaviorVector?, verb: Verb?, x: Double?, y: Double?) {
        self.interactive = interactive
        self.logID = logID
        self.params = params
        self.purchased = purchased
        self.reason = reason
        self.stat = stat
        self.vector = vector
        self.verb = verb
        self.x = x
        self.y = y
    }
}

// MARK: Payload convenience initializers and mutators

public extension Payload {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(Payload.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        interactive: Bool?? = nil,
        logID: String?? = nil,
        params: [String: String]?? = nil,
        purchased: Bool?? = nil,
        reason: Reason?? = nil,
        stat: Stat?? = nil,
        vector: BehaviorVector?? = nil,
        verb: Verb?? = nil,
        x: Double?? = nil,
        y: Double?? = nil
    ) -> Payload {
        return Payload(
            interactive: interactive ?? self.interactive,
            logID: logID ?? self.logID,
            params: params ?? self.params,
            purchased: purchased ?? self.purchased,
            reason: reason ?? self.reason,
            stat: stat ?? self.stat,
            vector: vector ?? self.vector,
            verb: verb ?? self.verb,
            x: x ?? self.x,
            y: y ?? self.y
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

public enum Reason: String, Codable, Equatable, Sendable {
    case close = "close"
    case converted = "converted"
    case dropOff = "drop_off"
    case next = "next"
}

public enum Stat: String, Codable, Equatable, Sendable {
    case click = "click"
    case disappear = "disappear"
    case visible = "visible"
}

//
// Hashable or Equatable:
// The compiler will not be able to synthesize the implementation of Hashable or Equatable
// for types that require the use of JSONAny, nor will the implementation of Hashable be
// synthesized for types that have collections (such as arrays or dictionaries).

// MARK: - BehaviorVector
public struct BehaviorVector: Codable, Equatable, Sendable {
    public let converted: Bool
    public let ctaHesitationMS: Int?
    public let deadClicks: [String: Int]
    public let dwellMS: [String: Int]
    public let impressions: [String: Int]
    public let planSwitches: Int
    public let rageClicks: Int
    public let screen: String
    public let scrollDepth: Double
    public let timeOnScreenMS: Int
    public let timeToFirstInteractionMS: Int?

    public enum CodingKeys: String, CodingKey {
        case converted = "converted"
        case ctaHesitationMS = "cta_hesitation_ms"
        case deadClicks = "dead_clicks"
        case dwellMS = "dwell_ms"
        case impressions = "impressions"
        case planSwitches = "plan_switches"
        case rageClicks = "rage_clicks"
        case screen = "screen"
        case scrollDepth = "scroll_depth"
        case timeOnScreenMS = "time_on_screen_ms"
        case timeToFirstInteractionMS = "time_to_first_interaction_ms"
    }

    public init(converted: Bool, ctaHesitationMS: Int?, deadClicks: [String: Int], dwellMS: [String: Int], impressions: [String: Int], planSwitches: Int, rageClicks: Int, screen: String, scrollDepth: Double, timeOnScreenMS: Int, timeToFirstInteractionMS: Int?) {
        self.converted = converted
        self.ctaHesitationMS = ctaHesitationMS
        self.deadClicks = deadClicks
        self.dwellMS = dwellMS
        self.impressions = impressions
        self.planSwitches = planSwitches
        self.rageClicks = rageClicks
        self.screen = screen
        self.scrollDepth = scrollDepth
        self.timeOnScreenMS = timeOnScreenMS
        self.timeToFirstInteractionMS = timeToFirstInteractionMS
    }
}

// MARK: BehaviorVector convenience initializers and mutators

public extension BehaviorVector {
    init(data: Data) throws {
        self = try newJSONDecoder().decode(BehaviorVector.self, from: data)
    }

    init(_ json: String, using encoding: String.Encoding = .utf8) throws {
        guard let data = json.data(using: encoding) else {
            throw NSError(domain: "JSONDecoding", code: 0, userInfo: nil)
        }
        try self.init(data: data)
    }

    init(fromURL url: URL) throws {
        try self.init(data: try Data(contentsOf: url))
    }

    func with(
        converted: Bool? = nil,
        ctaHesitationMS: Int?? = nil,
        deadClicks: [String: Int]? = nil,
        dwellMS: [String: Int]? = nil,
        impressions: [String: Int]? = nil,
        planSwitches: Int? = nil,
        rageClicks: Int? = nil,
        screen: String? = nil,
        scrollDepth: Double? = nil,
        timeOnScreenMS: Int? = nil,
        timeToFirstInteractionMS: Int?? = nil
    ) -> BehaviorVector {
        return BehaviorVector(
            converted: converted ?? self.converted,
            ctaHesitationMS: ctaHesitationMS ?? self.ctaHesitationMS,
            deadClicks: deadClicks ?? self.deadClicks,
            dwellMS: dwellMS ?? self.dwellMS,
            impressions: impressions ?? self.impressions,
            planSwitches: planSwitches ?? self.planSwitches,
            rageClicks: rageClicks ?? self.rageClicks,
            screen: screen ?? self.screen,
            scrollDepth: scrollDepth ?? self.scrollDepth,
            timeOnScreenMS: timeOnScreenMS ?? self.timeOnScreenMS,
            timeToFirstInteractionMS: timeToFirstInteractionMS ?? self.timeToFirstInteractionMS
        )
    }

    func jsonData() throws -> Data {
        return try newJSONEncoder().encode(self)
    }

    func jsonString(encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: try self.jsonData(), encoding: encoding)
    }
}

public enum EventType: String, Codable, Equatable, Sendable {
    case action = "action"
    case deadClick = "dead_click"
    case purchaseResult = "purchase_result"
    case rageClick = "rage_click"
    case screenEnd = "screen_end"
    case screenStart = "screen_start"
    case stat = "stat"
    case tap = "tap"
}

// MARK: - Helper functions for creating encoders and decoders

func newJSONDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom({ (decoder) -> Date in
        let container = try decoder.singleValueContainer()
        let dateStr = try container.decode(String.self)

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        if let date = formatter.date(from: dateStr) {
            return date
        }
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        if let date = formatter.date(from: dateStr) {
            return date
        }
        throw DecodingError.typeMismatch(Date.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Could not decode date"))
    })
    return decoder
}

func newJSONEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
    encoder.dateEncodingStrategy = .formatted(formatter)
    return encoder
}
