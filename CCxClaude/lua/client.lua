-- CCxClaude Client
-- Connects to CCxClaude server and executes tool commands

local SERVER_URL = "ws://localhost:8000/ws"

-- Load tools
local Tools = require("tools")

-- Wrap print to also send to server
local ws = nil
local clientName = nil
local originalPrint = print

local function serverPrint(...)
    originalPrint(...)
    if ws and clientName then
        local parts = {}
        for _, v in ipairs({...}) do
            table.insert(parts, tostring(v))
        end
        pcall(function()
            ws.send(textutils.serialiseJSON({
                type = "output",
                text = table.concat(parts, "\t")
            }))
        end)
    end
end

-- Execute a tool and return result
local function executeTool(tool, args)
    local toolFunc = Tools[tool]
    if not toolFunc then
        return false, "Unknown tool: " .. tool
    end

    local ok, result = pcall(toolFunc, args)
    if ok then
        return true, result
    else
        return false, tostring(result)
    end
end

-- Main loop
local function main()
    term.clear()
    term.setCursorPos(1, 1)

    print("=== CCxClaude Client ===")
    print()

    -- Get server URL
    print("Server URL [" .. SERVER_URL .. "]:")
    local inputUrl = read()
    if inputUrl and #inputUrl > 0 then
        SERVER_URL = inputUrl
    end

    -- Get client name
    print()
    print("Enter client name:")
    clientName = read()

    if not clientName or #clientName == 0 then
        print("Name cannot be empty!")
        return
    end

    -- Connect to server
    print()
    print("Connecting to " .. SERVER_URL .. "...")

    local ok, handle = pcall(http.websocket, SERVER_URL)
    if not ok or not handle then
        print("Failed to connect: " .. tostring(handle))
        return
    end

    ws = handle
    print("Connected!")

    -- Replace print with server-forwarding version
    _G.print = serverPrint

    -- Login
    ws.send(textutils.serialiseJSON({
        type = "login",
        name = clientName
    }))

    -- Wait for login response
    local loginResp = ws.receive(5)
    if not loginResp then
        print("Login timeout!")
        ws.close()
        return
    end

    local loginData = textutils.unserialiseJSON(loginResp)
    if loginData.type == "error" then
        print("Login failed: " .. loginData.message)
        ws.close()
        return
    end

    print("Logged in as: " .. clientName)
    print()
    print("Waiting for commands...")
    print("Press Ctrl+T to disconnect")
    print()

    -- Main message loop
    while true do
        local msg = ws.receive()
        if not msg then
            print("Disconnected from server")
            break
        end

        local data = textutils.unserialiseJSON(msg)
        if not data then
            print("Invalid message received")
        elseif data.type == "exec" then
            -- Execute tool command
            local tool = data.tool
            local args = data.args or {}
            local requestId = data.request_id

            print("[EXEC] " .. tool)

            local success, result = executeTool(tool, args)

            -- Send result back
            ws.send(textutils.serialiseJSON({
                type = "result",
                request_id = requestId,
                ok = success,
                result = success and result or nil,
                error = success and nil or result
            }))

            if success then
                print("[OK] " .. tool)
            else
                print("[ERR] " .. result)
            end

        elseif data.type == "pong" then
            -- Ignore pong
        elseif data.type == "error" then
            print("[SERVER ERROR] " .. (data.message or "unknown"))
        end
    end

    ws.close()
    _G.print = originalPrint
    print("Disconnected.")
end

-- Run with error handling
local ok, err = pcall(main)
if not ok then
    print("Error: " .. tostring(err))
end

-- Restore print if needed
if _G.print ~= originalPrint then
    _G.print = originalPrint
end
