# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

Project overview
- CC:Tweaked programs for an in-game “browser” client plus simple DNS and web servers over rednet. All code is Lua and intended to run on CC:Tweaked computers (or CraftOS-PC). No build step.

Common commands
- Install/update the Browser on a CC:Tweaked computer (latest dev build):
```lua
wget run https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/dev/Elliot/Client/Installer.lua
```
- Start the Browser after install (on the CC computer):
```lua
EEBrowser/browser.lua
```
- Install the WebServer on a CC computer (serves .txt pages for a site name over protocol EENet):
```lua
wget run https://raw.githubusercontent.com/GrebCo/CC-Tweaked-Amazon-OS/refs/heads/main/WebServer/install.lua install.lua
```
- Start the WebServer (on the CC computer with a modem):
```lua
WebServer/webServer.lua
```
- Start the DNS Server (on a CC computer with a modem and a DNS_Master.json file present):
```lua
DNSServer/DNSServer.lua
```
- Run the MiniMark test harness (renders a page, prints UI registry and extracted scripts):
```lua
EEBrowser/test_minimark.lua EEBrowser/Default.txt
```
Notes
- Lint/test: No configured linter or automated tests in this repo; tests are manual inside CC. The MiniMark harness above is the primary single-file test runner.

High-level architecture
- Client (Browser + OS utilities)
  - Applications/EEBrowser/browser.lua
    - Scene-based UI: Splash → Browser → Settings, with a small confirmation popup scene.
    - Fetches pages via rednet using protocol EENet and caches responses under /browser_cache.
    - Renders pages using OSUtil/MiniMark.lua; clickable links and form-like widgets are mapped into UI elements.
    - Integrates the Fizzle script layer to execute page-provided scripts via an event system.
  - OSUtil/UI.lua
    - Minimal UI framework over term: scenes, child scenes, and elements (label, button, checkbox, textfield, rectangle).
    - Central render loop driven by a dirty flag, plus input handling for mouse/key and basic focus.
  - OSUtil/MiniMark.lua
    - MiniMark v0.91 renderer and tokenizer. Supports alignment markers (#/##/###), <br>, <hr>, fg/bg color tags, links, buttons, checkboxes, textboxes.
    - Returns a UI registry for interactive regions and extracts <script> blocks via getScripts(path).
  - Applications/EEBrowser/fizzle.lua
    - Sandboxed script loader/executor for MiniMark <script> blocks. Recognizes @EventName annotations or event:"Name" attributes.
    - Builds function→event mappings and registers them via OSUtil/events.lua, then triggers events (e.g., onLoad).
  - OSUtil/events.lua
    - Lightweight event bus: registerEvent, registerFunction, triggerEvent, resetEvents.
  - OSUtil/ClientNetworkHandler.lua
    - Rednet helper providing ensureRednet/open/close, DNS hostname resolution, send/query helpers.
    - DNS cache stored as JSON in dns_cache.txt, populated from a network DNS server.
  - OSUtil/Logger.lua
    - File logger with auto-trimming; used by components when ENABLE_LOG is true.
  - Client/Installer.lua
    - Self-updater: removes prior client folders, recreates them, and fetches the latest client files from the dev branch; writes version.txt.

- Servers
  - WebServer/webServer.lua
    - Hosts protocol EENet; serves WEBSITE_NAME.txt (and subpaths mapped to .txt files). Requires a modem peripheral.
  - DNSServer/DNSServer.lua
    - Hosts protocol DNS; on "get" replies with contents of DNS_Master.json. Requires a modem peripheral.

Configuration
- Client/Config/network_config.lua provides defaults for the DNS client (protocol name, cache path, logging toggles). ClientNetworkHandler supports init(config) to override.

Key workflows to be aware of
- Page lifecycle: Browser fetches a MiniMark page → MiniMark renders UI and extracts scripts → Fizzle caches and loads scripts in a sandbox → functions are registered on events via events.lua → Browser’s loop renders and dispatches events, including link clicks and text input.
- Networking: Client uses DNS to resolve hostnames (via DNS server) and then queries a web server using protocol EENet; responses are cached locally.
