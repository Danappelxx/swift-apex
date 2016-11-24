@_exported import Axis
@_exported import Venice

public struct Context {
    public let invokeID: String
    public let requestID: String
    public let functionName: String
    public let functionVersion: String
    public let logGroupName: String
    public let logStreamName: String
    public let memoryLimitInMB: String
    public let isDefaultFunctionVersion: Bool
    public let clientContext: Map
}

extension Context {
    public init(map: Map) throws {
        invokeID = try map.get("invokeid")
        requestID = try map.get("awsRequestId")
        functionName = try map.get("functionName")
        functionVersion = try map.get("functionVersion")
        logGroupName = try map.get("logGroupName")
        logStreamName = try map.get("logStreamName")
        memoryLimitInMB = try map.get("memoryLimitInMB")
        isDefaultFunctionVersion = try map.get("isDefaultFunctionVersion")
        clientContext = map["clientContext"]
    }
}

public typealias Lambda<T> = (_ event: T, _ context: Context?) throws -> MapRepresentable

public func λ <T : MapInitializable>(lambda: @escaping Lambda<T>) throws {
    let inputChannel = input()
    let outputChannel = handle(inputChannel, lambda: lambda)
    try output(outputChannel)
}
public func lambda <T : MapInitializable>(lambda: @escaping Lambda<T>) throws {
    return try λ(lambda: lambda)
}

func input() -> FallibleChannel<Map> {
    let inputChannel = FallibleChannel<Map>()

    co {
        while true {
            do {
                let input = try JSONMapParser.parse(standardInputStream, deadline: 5.seconds.fromNow())
                inputChannel.send(input)
            } catch {
                inputChannel.send(error)
                if error is StreamError {
                    inputChannel.close()
                    break
                }
            }
        }
    }

    return inputChannel
}

func handle<T : MapInitializable>(_ inputChannel: FallibleChannel<Map>, lambda: @escaping Lambda<T>) -> FallibleChannel<Map> {
    let outputChannel = FallibleChannel<Map>()
    // let waitGroup = WaitGroup()

    co {
        for result in inputChannel {
            // waitGroup.add()
            co {
                switch result {
                case .value(let message):
                    do {
                        let event = try T(map: message["event"])
                        let context = try? Context(map: message["context"])
                        let value = try lambda(event, context)
                        outputChannel.send(value.map)
                    } catch {
                        outputChannel.send(error)
                    }
                case .error(let error):
                    outputChannel.send(error)
                    if error is StreamError {
                        outputChannel.close()
                        break
                    }
                }
                // waitGroup.done()
            }
        }
        // waitGroup.wait()
    }

    return outputChannel
}

func output(_ channel: FallibleChannel<Map>) throws {
    for result in channel {
        switch result {
        case .value(let value):
            try JSONMapSerializer.serialize(["value": value], stream: standardOutputStream, deadline: 5.seconds.fromNow())
        case .error(let error):
            if error is StreamError {
                break
            }
            let errorDescription = String(describing: error)
            let deadline = 5.seconds.fromNow()
            try JSONMapSerializer.serialize(["error": Map(errorDescription)], stream: standardOutputStream, deadline: deadline)
            try standardOutputStream.write("\n", deadline: deadline)
            try standardOutputStream.flush(deadline: deadline)
        }
    }
}
