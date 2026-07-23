# Macqueen IPC

Macqueen IPC is the compositor's public, versioned shell API. Version 1 is
available on the D-Bus session bus:

- service: `org.macqueen.Compositor1`
- object: `/org/macqueen/Compositor1`
- interface: `org.macqueen.Compositor1`

## Version 1

The initial interface is deliberately read-only. A session client can discover
the protocol and compositor versions, list windows, outputs and workspaces, and
subscribe to changes.

Methods:

- `protocolVersion() -> uint`
- `compositorVersion() -> string`
- `activeWindow() -> map`
- `windows() -> list<map>`
- `outputs() -> list<map>`
- `workspaces() -> list<map>`

Signals:

- `windowAdded(id)`
- `windowRemoved(id)`
- `windowChanged(id, fields)`
- `activeWindowChanged(id)`
- `outputsChanged()`
- `workspacesChanged()`

The maps use stable lower-camel-case field names. Consumers must ignore unknown
fields so version 1 can gain optional data without breaking clients.

## Test from a terminal

Within a running Macqueen session:

```bash
qdbus6 org.macqueen.Compositor1 /org/macqueen/Compositor1 \
    org.macqueen.Compositor1.protocolVersion
```

Mutating window commands, shortcut registration, screen capture and remote
input are intentionally not part of this first interface. They require an
authorization design rather than unrestricted access for every session-bus
client.
