-- CCxClaude Tools
-- Tool implementations for ComputerCraft

local Tools = {}

-- Execute a shell command
function Tools.shell_exec(args)
    local command = args.command
    if not command then
        error("Missing argument: command")
    end

    local outputFile = "/tmp/ccxclaude_" .. os.epoch("utc")
    local success = shell.run(command .. " > " .. outputFile)

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

-- List directory contents
function Tools.fs_list(args)
    local path = args.path or ""

    if not fs.exists(path) then
        error("Path does not exist: " .. path)
    end
    if not fs.isDir(path) then
        error("Not a directory: " .. path)
    end

    local entries = {}
    for _, name in ipairs(fs.list(path)) do
        local full = fs.combine(path, name)
        table.insert(entries, {
            name = name,
            isDir = fs.isDir(full),
            size = fs.getSize(full)
        })
    end

    return { path = path, entries = entries }
end

-- Read file contents
function Tools.fs_read(args)
    local path = args.path
    if not path then
        error("Missing argument: path")
    end
    if not fs.exists(path) then
        error("File does not exist: " .. path)
    end
    if fs.isDir(path) then
        error("Path is a directory: " .. path)
    end

    local f = fs.open(path, "r")
    if not f then
        error("Cannot open file: " .. path)
    end

    local content = f.readAll()
    f.close()

    return { path = path, content = content }
end

-- Write file contents
function Tools.fs_write(args)
    local path = args.path
    local content = args.content

    if not path then error("Missing argument: path") end
    if not content then error("Missing argument: content") end

    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end

    local f = fs.open(path, "w")
    if not f then
        error("Cannot write to: " .. path)
    end

    f.write(content)
    f.close()

    return { path = path, written = #content }
end

-- Delete file or directory
function Tools.fs_delete(args)
    local path = args.path
    if not path then error("Missing argument: path") end
    if not fs.exists(path) then
        error("Path does not exist: " .. path)
    end

    fs.delete(path)
    return { path = path, deleted = true }
end

-- Run a Lua program
function Tools.run_program(args)
    local path = args.path
    local progArgs = args.args or {}

    if not path then error("Missing argument: path") end
    if not fs.exists(path) then
        error("Program not found: " .. path)
    end

    local captured = {}
    local oldPrint = print

    _G.print = function(...)
        local parts = {}
        for _, v in ipairs({...}) do
            table.insert(parts, tostring(v))
        end
        table.insert(captured, table.concat(parts, "\t"))
    end

    local func, loadErr = loadfile(path)
    local success, runErr = false, loadErr

    if func then
        success, runErr = pcall(func, table.unpack(progArgs))
    end

    _G.print = oldPrint

    return {
        success = success,
        output = table.concat(captured, "\n"),
        error = success and nil or tostring(runErr)
    }
end

return Tools
