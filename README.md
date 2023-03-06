# Overview
Contracts showcasing the work of the Wisp Protocol. Minimalistic bridge capped at 0.01 ETH per transfer.

```ml
crc-messages
├─ Bridge — "Base contract for a bridge. Sends and receives wisp messages."
├─ BridgeETH — "Minimalistic contract used for bridging ETH between rollups via the wisp protocol."
├─ interfaces
|  ├─ ICRCOutbox - "Interface for external contracts to work with the outbox"
|  ├─ IMessageReceiver - "Interface that the contracts receiving messages should implement"
|  ├─ Types - "Contains the messages types used within the protocol."
```