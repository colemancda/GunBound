# GunBound
GunBound Classic (Thor's Hammer) Server

## Requirements

- Swift 6.0+
- macOS 13.0+

## Building

```bash
swift build
```

## Running the Server

This project provides two server types:

### World Server

The main game server. Default port: `8370`

```bash
# Basic usage (runs on default port 8370)
swift run GunBoundServer

# Custom port and address
swift run GunBoundServer world --port 8370 --address 0.0.0.0

# With persistent state (saves to JSON file on shutdown)
swift run GunBoundServer world --path server-state.json

# With GunBoundServ setting.txt configuration
swift run GunBoundServer world --setting-path setting.txt

# With channel/room MOTD files
swift run GunBoundServer world \
  --channel-ment-path channel_ment.txt \
  --room-ment-path room_ment.txt

# Full example with all options
swift run GunBoundServer world \
  --port 8370 \
  --address 0.0.0.0 \
  --path server-state.json \
  --setting-path setting.txt \
  --channel-ment-path channel_ment.txt \
  --room-ment-path room_ment.txt
```

The server will automatically create an admin user:
- Username: `admin`
- Password: `1234`

### Broker Server

The directory/login server. Default port: `8372`

```bash
# Requires a server directory JSON file
swift run GunBoundServer broker --path servers.json

# Custom address and port
swift run GunBoundServer broker \
  --path servers.json \
  --address 0.0.0.0 \
  --port 8372
```

Create a `servers.json` file with the following structure:

```json
[
  {
    "name": "GunBound World",
    "address": "127.0.0.1",
    "port": 8370
  }
]
```

## Configuration Files

### setting.txt

Optional GunBoundServ-compatible configuration file:

```ini
Port=8370
VersionFirst=0
VersionLast=999
GradeLimitFirst=-4
GradeLimitLast=20
FuncRestrict=1048575
NoRoomCreate=0
Accept=127.0.0.1;192.168.1.1
GuildMarkLimit=0
RecommendedMan=1
```

### channel_ment.txt

Message displayed to users when joining a channel.

### room_ment.txt

Message displayed to users when joining a room.

## Development

Run tests:

```bash
swift test
```
