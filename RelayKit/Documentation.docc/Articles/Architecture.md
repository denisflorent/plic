# Architecture

Understanding the Protocol + Proxy pattern and reactive bridging.

## Overview

RelayKit bridges the Matrix Rust SDK's UniFFI-generated Swift types to
SwiftUI using three key patterns:

### Protocol + Proxy

Every SDK type gets a Swift protocol and an `@Observable` proxy class:

- **Protocol** defines the public API (e.g., ``ClientProxyProtocol``)
- **Proxy** implements the protocol by wrapping the SDK object (e.g., ``ClientProxy``)
- **Mocks** can implement the protocol for testing and SwiftUI previews

This enables dependency injection and testability without a live server.

### SDKListener + AsyncStream

The SDK delivers reactive state via callback-based listener protocols.
``SDKListener`` is a generic adapter that forwards any SDK callback to
a Swift closure. ``AsyncStreamBridge`` combines `SDKListener` with
`AsyncStream` to create streams that SwiftUI views consume via `.task`:

```
SDK Listener Protocol
    → SDKListener<T> (closure adapter)
        → AsyncStream.Continuation
            → AsyncStream<T>
                → .task { for await value in stream { ... } }
```

The `TaskHandle` returned by each SDK subscription is retained for the
stream's lifetime and cancelled on termination.

### DiffEngine

Both timelines and room lists deliver state changes as VectorDiff
operations (append, insert, set, remove, etc.). ``DiffEngine`` applies
these operations to Swift arrays, maintaining a local mirror of the
SDK's internal state.

## Threading Model

- SDK listener callbacks arrive on unspecified threads (Tokio runtime)
- `@Observable` property mutations trigger SwiftUI updates
- `AsyncStream` handles the bridging between threads
- SwiftUI's `.task` modifier manages structured concurrency

## Topics

### Core Infrastructure
- ``SDKListener``
- ``AsyncStreamBridge``
- ``DiffEngine``
- ``DiffOperation``

### Multi-Parameter Listeners
- ``SendQueueUpdateListenerAdapter``
- ``RoomAccountDataListenerAdapter``
