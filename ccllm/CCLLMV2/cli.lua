-- CC LLM Agent - CLI Interface
--
-- Single-computer CLI for interacting with the LLM orchestrator

local ORCHESTRATOR_URL = "ws://localhost:8000/ws"
local CLIENT_ID = os.getComputerLabel() or ("computer_" .. os.getComputerID())

-- Load required libraries
local AgentClient = require("agent_client")
local CoreTools = require("core_tools")

-- Terminal colors
local function setColor(color)
    if term.isColor() then
        term.setTextColor(color)
    end
end

local function printStatus(msg)
    setColor(colors.yellow)
    print("[STATUS] " .. msg)
    setColor(colors.white)
end

local function printError(msg)
    setColor(colors.red)
    print("[ERROR] " .. msg)
    setColor(colors.white)
end

local function printSuccess(msg)
    setColor(colors.lime)
    print("[SUCCESS] " .. msg)
    setColor(colors.white)
end

-- Clear screen and show header
term.clear()
term.setCursorPos(1, 1)
setColor(colors.lightBlue)
print("================================")
print("  CC LLM Agent - CLI Interface  ")
print("================================")
setColor(colors.white)
print()

-- Create client
printStatus("Connecting to orchestrator...")
local client = AgentClient.new(
    ORCHESTRATOR_URL .. "/" .. CLIENT_ID,
    CLIENT_ID
)

-- Register core tools BEFORE connecting
CoreTools.registerAll(client)

-- Connect
if not client:connect() then
    printError("Failed to connect to orchestrator")
    printError("Check that the orchestrator is running at:")
    print("  " .. ORCHESTRATOR_URL)
    return
end

printSuccess("Connected!")
print()

-- Track current task
local currentTask = nil
local currentRequestId = nil

-- Handle incoming messages
client.messageHandlers["task_created"] = function(data)
    if data.request_id == currentRequestId then
        currentTask = data.task_id
        printStatus("Task created: " .. currentTask)
    end
end

client.messageHandlers["task_completed"] = function(data)
    if data.task_id == currentTask then
        printSuccess("Task completed!")
        if data.result and data.result.message then
            setColor(colors.white)
            print()
            print(data.result.message)
            print()
        end
        currentTask = nil
        currentRequestId = nil
    end
end

client.messageHandlers["task_failed"] = function(data)
    if data.task_id == currentTask then
        printError("Task failed: " .. tostring(data.error))
        currentTask = nil
        currentRequestId = nil
    end
end

client.messageHandlers["status_update"] = function(data)
    if data.task_id == currentTask then
        printStatus(data.message)
    end
end

client.messageHandlers["user_question"] = function(data)
    if data.task_id == currentTask then
        -- Ask the user the question
        setColor(colors.yellow)
        print()
        print("[QUESTION] " .. data.question)
        setColor(colors.cyan)
        write("Answer> ")
        setColor(colors.white)

        -- Get user's answer
        local answer = read()

        -- Send answer back as command_result
        local response = {
            type = "command_result",
            task_id = data.task_id,
            call_id = data.call_id,
            ok = true,
            result = {
                answer = answer
            }
        }

        local json = textutils.serializeJSON(response)
        client.ws.send(json)
        print()
    end
end

-- Background receive loop - continuously processes messages
local function receiveLoop()
    while client.connected do
        client:receive(0.1)
    end
end

-- Main CLI loop - handles user input
local function cliLoop()
    while client.connected do
        -- Wait for task to complete before showing prompt
        while currentTask do
            os.sleep(0.1)
        end

        -- Show prompt
        setColor(colors.cyan)
        write("> ")
        setColor(colors.white)

        -- Read input
        local input = read()

        if input and #input > 0 then
            -- Handle special commands
            if input == "exit" or input == "quit" then
                printStatus("Disconnecting...")
                client:disconnect()
                break
            elseif input == "clear" then
                term.clear()
                term.setCursorPos(1, 1)
            elseif input == "help" then
                print()
                print("Commands:")
                print("  help  - Show this help")
                print("  clear - Clear screen")
                print("  exit  - Exit the CLI")
                print()
                print("Or type any request for the LLM agent:")
                print("  > Make me a FizzBuzz program")
                print("  > Create a turtle mining script")
                print("  > Write a password manager")
                print()
            else
                -- Send task to orchestrator
                currentRequestId = os.epoch("utc") .. "_" .. math.random(1000, 9999)

                local taskRequest = {
                    type = "create_task",
                    request_id = currentRequestId,
                    task_kind = "code_job",
                    client_id = CLIENT_ID,
                    prompt = input,
                    context = {},
                    allowed_commands = nil
                }

                local json = textutils.serializeJSON(taskRequest)
                client.ws.send(json)
                print()
            end
        end
    end
end

-- Run both loops in parallel
parallel.waitForAny(receiveLoop, cliLoop)

print()
printStatus("Goodbye!")
