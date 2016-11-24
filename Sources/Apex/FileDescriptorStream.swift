import CLibvenice
import Axis

public let standardInputStream = FileDescriptorStream(fileDescriptor: STDIN_FILENO)
public let standardOutputStream = FileDescriptorStream(fileDescriptor: STDOUT_FILENO)

public final class FileDescriptorStream : Stream {
    fileprivate var file: mfile?
    public fileprivate(set) var closed = false

    init(file: mfile) {
        self.file = file
    }

    public convenience init(fileDescriptor: FileDescriptor) {
        let file = fileattach(fileDescriptor)
        self.init(file: file!)
    }

    deinit {
        if let file = file, !closed {
            fileclose(file)
        }
    }
}

extension FileDescriptorStream {
    public func write(_ buffer: UnsafeBufferPointer<Byte>, deadline: Double) throws {
        try ensureFileIsOpen()

        let bytesWritten = filewrite(file, buffer.baseAddress, buffer.count, deadline.int64milliseconds)

        if bytesWritten == 0 {
            try ensureLastOperationSucceeded()
        }
    }

    public func read(into readBuffer: UnsafeMutableBufferPointer<Byte>, deadline: Double) throws -> UnsafeBufferPointer<Byte> {
        try ensureFileIsOpen()

        let bytesRead = filereadlh(file, readBuffer.baseAddress, 1, readBuffer.count, deadline.int64milliseconds)

        if bytesRead == 0 {
            try ensureLastOperationSucceeded()
        }

        return UnsafeBufferPointer(start: readBuffer.baseAddress, count: bytesRead)
    }

    public func flush(deadline: Double) throws {
        try ensureFileIsOpen()
        fileflush(file, deadline.int64milliseconds)
        try ensureLastOperationSucceeded()
    }

    public func open(deadline: Double) throws {
        // file already open
    }

    public func close() {
        if !closed {
            fileclose(file)
        }
        closed = true
    }

    private func ensureFileIsOpen() throws {
        if closed {
            throw StreamError.closedStream
        }
    }
}
