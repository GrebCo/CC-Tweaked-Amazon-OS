# EETodo - Networked Todo List System for CC:Tweaked

A complete todo list system with server and multiple client types for ComputerCraft: Tweaked.

## Features

- **Centralized Server** - Stores and syncs todos across all clients
- **Pocket Client** - Interactive todo manager for pocket computers
- **Monitor Client** - Read-only display for monitors with active/done sections
- **Network Sync** - Real-time updates via Rednet
- **Persistent Storage** - Todos saved to disk and survive restarts
- **Rich Theming** - 15+ built-in themes (Gruvbox, Catppuccin, Nord, etc.)

## Installation

### Server Installation

On the computer that will host the server (requires a modem):

Or manually:
```lua
wget run https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/TodoList/install_server.lua
```

The server will automatically start on boot.

### Monitor Client Installation

On the computer connected to a monitor (requires a modem):

Or manually:
```lua
wget run https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/TodoList/install_monitor.lua
```

The monitor client will automatically start on boot.

### Pocket Client Installation

On a pocket computer (requires a modem):

Or manually:
```lua
wget run https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/TodoList/install_pocket.lua
```

Run manually with: `PocketClient`

## Usage

### Server
- Starts automatically on boot
- Hosts the "EETodo" protocol
- Saves todos to `todolist.dat`
- Broadcasts updates to all clients

### Pocket Client
- **Add todos**: Type in the text field and press Enter or click "Add"
- **Check/uncheck**: Click the checkbox to toggle completion
- **Delete**: Click the red "x" button

### Monitor Client
- **Read-only display**
- **Active section**: Shows uncompleted todos
- **Done section**: Shows completed todos (dimmed)
- **Auto-sync**: Updates in real-time as todos change

## Architecture

```
┌─────────────────┐
│  Server (Comp7) │
│  - todolist.dat │
│  - Rednet host  │
└────────┬────────┘
         │
    ┌────┴────┬──────────┐
    │         │          │
┌───▼───┐ ┌──▼──────┐ ┌─▼────────┐
│Pocket │ │Monitor  │ │Monitor   │
│Client │ │Client   │ │Client    │
└───────┘ └─────────┘ └──────────┘
```

## Files

- `Server.lua` - Server application
- `PocketClient.lua` - Pocket computer client
- `MonitorClient.lua` - Monitor client
- `EETodoCore.lua` - Shared client networking logic
- `UI.lua` - UI framework with hook system
- `themes.lua` - Theme definitions
- `startup.lua` - Auto-start script (server/monitor only)

## Theming

Change the theme by editing the client file:
```lua
UI.setTheme("gruvbox")  -- Change to any theme name
```

Available themes: `default`, `catppuccin`, `gruvbox`, `nord`, `dracula`, `tokyonight`, `onedark`, `solarized`, `monokai`, `material`, `rosepine`, `everforest`, `ayu`, `paper`, `solarized_light`, `gruvbox_light`

## Requirements

- ComputerCraft: Tweaked
- Modems on all computers (wired or wireless)
- Monitor peripheral (for monitor client)

## Network Protocol

Protocol name: `EETodo`

Message types:
- `fetch` - Request current todo list
- `add` - Add new todo
- `modify` - Modify existing todo
- `remove` - Remove todo
- `updated` - Broadcast todo list update

## Credits

Built with the EE UI Framework featuring:
- Hook normalization system
- Semantic theme colors
- `onReady` lifecycle callback
- Full keyboard and touch support
