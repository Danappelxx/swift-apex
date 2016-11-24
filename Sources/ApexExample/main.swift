import Apex

struct Event : MapInitializable {
    let message: String

    init(map: Map) throws {
        self.message = try map.get("message")
    }
}

try λ { (event: Event, context) in
    event.message.uppercased()
}
