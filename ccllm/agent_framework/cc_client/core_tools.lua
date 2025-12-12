-- Core Tools for CC Agent Host
--
-- Implements the built-in tools: shell_exec, fs_list, fs_read, fs_write,
-- fs_delete, and run_program

local CoreTools = {}

-- Shell execution tool
-- Executes a CraftOS shell command
function CoreTools.shell_exec(args)
    local command = args.command
    if not command then
        error("Missing required argument: command")
    end

    print("[TOOL] Executing shell command: " .. command)

    -- Capture output by redirecting to a temporary file
    local outputFile = "/tmp/shell_output_" .. os.epoch("utc")

    -- Run command with output redirection
    local success = shell.run(command .. " > " .. outputFile)

    -- Read the output
    local output = ""
    if fs.exists(outputFile) then
        local f = fs.open(outputFile, "r")
        if f then
            output = f.readAll() or ""
            f.close()
        end
        fs.delete(outputFile)
    end

    return {
        success = success,
        output = output
    }
end

-- File system list tool
-- Lists files and directories at a path
function CoreTools.fs_list(args)
    local path = args.path or ""

    if not fs.exists(path) then
        error("Path does not exist: " .. path)
    end

    if not fs.isDir(path) then
        error("Path is not a directory: " .. path)
    end

    local files = fs.list(path)
    local entries = {}

    for _, name in ipairs(files) do
        local fullPath = fs.combine(path, name)
        table.insert(entries, {
            name = name,
            path = fullPath,
            isDir = fs.isDir(fullPath),
            size = fs.getSize(fullPath)
        })
    end

    return {
        path = path,
        entries = entries,
        count = #entries
    }
end

-- File system read tool
-- Reads the contents of a file
function CoreTools.fs_read(args)
    local path = args.path
    if not path then
        error("Missing required argument: path")
    end

    if not fs.exists(path) then
        error("File does not exist: " .. path)
    end

    if fs.isDir(path) then
        error("Path is a directory, not a file: " .. path)
    end

    local f = fs.open(path, "r")
    if not f then
        error("Failed to open file: " .. path)
    end

    local content = f.readAll()
    f.close()

    return {
        path = path,
        content = content,
        size = #content
    }
end

-- File system write tool
-- Writes content to a file (creates or overwrites)
function CoreTools.fs_write(args)
    local path = args.path
    local content = args.content

    if not path then
        error("Missing required argument: path")
    end

    if not content then
        error("Missing required argument: content")
    end

    -- Create parent directory if needed
    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end

    local f = fs.open(path, "w")
    if not f then
        error("Failed to open file for writing: " .. path)
    end

    f.write(content)
    f.close()

    return {
        path = path,
        size = #content,
        created = true
    }
end

-- File system delete tool
-- Deletes a file or directory
function CoreTools.fs_delete(args)
    local path = args.path
    if not path then
        error("Missing required argument: path")
    end

    if not fs.exists(path) then
        error("Path does not exist: " .. path)
    end

    -- Check if it's a directory
    local wasDir = fs.isDir(path)

    fs.delete(path)

    return {
        path = path,
        deleted = true,
        was_directory = wasDir
    }
end

-- Run program tool
-- Runs a Lua program and captures output/errors
function CoreTools.run_program(args)
    local path = args.path
    local programArgs = args.args or {}

    if not path then
        error("Missing required argument: path")
    end

    if not fs.exists(path) then
        error("Program does not exist: " .. path)
    end

    print("[TOOL] Running program: " .. path)

    -- Capture output
    local outputFile = "/tmp/prog_output_" .. os.epoch("utc")
    local errorFile = "/tmp/prog_error_" .. os.epoch("utc")

    -- Build command with arguments
    local cmd = path
    for _, arg in ipairs(programArgs) do
        cmd = cmd .. " " .. tostring(arg)
    end

    -- Redirect output and errors
    cmd = cmd .. " > " .. outputFile .. " 2> " .. errorFile

    -- Run the program
    local success = shell.run(cmd)

    -- Read output
    local output = ""
    if fs.exists(outputFile) then
        local f = fs.open(outputFile, "r")
        if f then
            output = f.readAll() or ""
            f.close()
        end
        fs.delete(outputFile)
    end

    -- Read errors
    local errorOutput = ""
    if fs.exists(errorFile) then
        local f = fs.open(errorFile, "r")
        if f then
            errorOutput = f.readAll() or ""
            f.close()
        end
        fs.delete(errorFile)
    end

    return {
        path = path,
        success = success,
        output = output,
        error = errorOutput
    }
end

-- Register all core tools with a client
-- @param client: AgentClient instance
function CoreTools.registerAll(client)
    client:registerCommand("shell_exec", CoreTools.shell_exec)
    client:registerCommand("fs_list", CoreTools.fs_list)
    client:registerCommand("fs_read", CoreTools.fs_read)
    client:registerCommand("fs_write", CoreTools.fs_write)
    client:registerCommand("fs_delete", CoreTools.fs_delete)
    client:registerCommand("run_program", CoreTools.run_program)

    print("[TOOLS] All core tools registered")
end

return CoreTools
