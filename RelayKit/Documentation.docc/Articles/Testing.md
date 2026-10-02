# Testing

Using protocols and mocks for unit tests and SwiftUI previews.

## Overview

Every proxy type in RelayKit conforms to a protocol. This enables
replacing real SDK objects with mock implementations in tests and previews.

### Creating Mocks

Implement the protocol with controllable behavior:

```swift
final class MockClientProxy: ClientProxyProtocol {
    var userID = "@test:matrix.org"
    var deviceID = "TESTDEVICE"
    var homeserver = "https://matrix.org"
    var avatarURL: URL? = nil
    var displayName: String? = "Test User"
    
    // Track method calls
    var loginCallCount = 0
    
    func login(username: String, password: String, 
               initialDeviceName: String?, deviceId: String?) async throws {
        loginCallCount += 1
    }
    
    // ... implement remaining protocol requirements
}
```

### SwiftUI Previews

Inject mocks via initializers or environment:

```swift
#Preview {
    let mock = MockRoomSummaryProvider()
    mock.rooms = [
        RoomSummary(roomInfo: previewRoomInfo)
    ]
    return RoomListView(provider: mock)
}
```

### Unit Tests

Verify behavior through protocol interfaces:

```swift
@Test func test_login_updatesState() async throws {
    let mock = MockClientProxy()
    try await mock.login(username: "alice", password: "pass",
                         initialDeviceName: nil, deviceId: nil)
    #expect(mock.loginCallCount == 1)
}
```

## Topics

### Protocols
- ``ClientProxyProtocol``
- ``SyncServiceProxyProtocol``
- ``JoinedRoomProxyProtocol``
- ``TimelineProxyProtocol``
- ``RoomSummaryProviderProtocol``
- ``EncryptionProxyProtocol``
