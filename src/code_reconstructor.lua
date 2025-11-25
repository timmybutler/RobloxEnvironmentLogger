-- PURE CODE RECONSTRUCTOR
-- Outputs ONLY reconstructed code, nothing else
local process = require("@lune/process")
local fs = require("@lune/fs")

local scriptPath = process.args[1]
if not scriptPath then
    print("Usage: lune run code_reconstructor.lua <script_path>")
    process.exit(1)
end

local scriptContent = fs.readFile(scriptPath)

-- Code reconstruction buffer
local codeLines = {}

-- Simple logging that only captures executable code
local function addCode(code)
    table.insert(codeLines, code)
end

-- Minimal environment
local env = {}

env.print = function(...)
    local args = {...}
    local strs = {}
    for i, v in ipairs(args) do
        if type(v) == "string" then
            strs[i] = '"' .. tostring(v) .. '"'
        else
            strs[i] = tostring(v)
        end
    end
    addCode("print(" .. table.concat(strs, ", ") .. ")")
end

env.warn = function(...)
    local args = {...}
    local strs = {}
    for i, v in ipairs(args) do
        if type(v) == "string" then
            strs[i] = '"' .. tostring(v) .. '"'
        else
            strs[i] = tostring(v)
        end
    end
    addCode("warn(" .. table.concat(strs, ", ") .. ")")
end

-- Instance tracking
local instanceCounter = 0
local instances = {}

env.Instance = {
    new = function(className, parent)
        instanceCounter = instanceCounter + 1
        local varName = "Instance" .. instanceCounter
        instances[varName] = className
        
        if parent then
            addCode("local " .. varName .. ' = Instance.new("' .. className .. '", ' .. tostring(parent) .. ")")
        else
            addCode("local " .. varName .. ' = Instance.new("' .. className .. '")')
        end
        
        -- Return proxy for property tracking
        return setmetatable({__varName = varName}, {
            __index = function(t, k)
                return nil
            end,
            __newindex = function(t, k, v)
                local valueStr
                if type(v) == "string" then
                    valueStr = '"' .. v .. '"'
                elseif type(v) == "number" or type(v) == "boolean" then
                    valueStr = tostring(v)
                elseif type(v) == "table" and v.__varName then
                    valueStr = v.__varName
                else
                    valueStr = tostring(v)
                end
                addCode(varName .. "." .. k .. " = " .. valueStr)
            end,
            __tostring = function()
                return varName
            end
        })
    end
}

-- Math types
env.Vector3 = {
    new = function(x, y, z)
        return {__tostring = function() return string.format("Vector3.new(%g, %g, %g)", x or 0, y or 0, z or 0) end}
    end
}

env.Color3 = {
    fromRGB = function(r, g, b)
        return {__tostring = function() return string.format("Color3.fromRGB(%d, %d, %d)", r, g, b) end}
    end,
    new = function(r, g, b)
        return {__tostring = function() return string.format("Color3.new(%g, %g, %g)", r, g, b) end}
    end
}

env.UDim2 = {
    new = function(xs, xo, ys, yo)
        return {__tostring = function() return string.format("UDim2.new(%g, %g, %g, %g)", xs, xo, ys, yo) end}
    end
}

env.BrickColor = {
    new = function(name)
        return {__tostring = function() return 'BrickColor.new("' .. name .. '")' end}
    end
}

-- Enum
env.Enum = setmetatable({}, {
    __index = function(t, k)
        return setmetatable({}, {
            __index = function(t2, v)
                return setmetatable({}, {
                    __tostring = function() return "Enum." .. k .. "." .. v end
                })
            end
        })
    end
})

-- Game/Services
local services = {}
env.game = setmetatable({}, {
    __index = function(t, k)
        if k == "GetService" then
            return function(self, name)
                if not services[name] then
                    services[name] = setmetatable({__serviceName = name}, {
                        __index = function(st, sk)
                            return setmetatable({}, {
                                __index = function() return nil end,
                                __tostring = function() return 'game:GetService("' .. name .. '").' .. sk end
                            })
                        end,
                        __tostring = function() return 'game:GetService("' .. name .. '")' end
                    })
                end
                return services[name]
            end
        end
        if k == "HttpGet" or k == "HttpGetAsync" then
            return function(self, url)
                addCode('game:HttpGet("' .. url .. '")')
                return ""
            end
        end
        return nil
    end,
    __tostring = function() return "game" end
})

env.workspace = setmetatable({}, {
    __index = function(t, k) return nil end,
    __tostring = function() return "workspace" end
})

env.script = setmetatable({}, {
    __index = function(t, k) return nil end,
    __tostring = function() return "script" end
})

-- HTTP
env.HttpGet = function(url)
    addCode('HttpGet("' .. url .. '")')
    return ""
end

-- File operations
env.writefile = function(filename, content)
    addCode('writefile("' .. filename .. '", [content])')
end

env.readfile = function(filename)
    addCode('readfile("' .. filename .. '")')
    return ""
end

-- Loadstring
env.loadstring = function(code)
    addCode("loadstring([code])")
    return function() end
end

-- Clipboard
env.setclipboard = function(text)
    local preview = tostring(text):sub(1, 50)
    addCode('setclipboard("' .. preview .. '")')
end

-- Exploit functions
env.hookfunction = function(original, hook)
    addCode("hookfunction([function], [hook])")
    return original
end

env.hookmetamethod = function(obj, method, hook)
    addCode('hookmetamethod([obj], "' .. tostring(method) .. '", [hook])')
    return function() end
end

env.Drawing = {
    new = function(drawingType)
        instanceCounter = instanceCounter + 1
        local varName = "Drawing" .. instanceCounter
        addCode('local ' .. varName .. ' = Drawing.new("' .. drawingType .. '")')
        
        return setmetatable({__varName = varName}, {
            __index = function(t, k) return nil end,
            __newindex = function(t, k, v)
                addCode(varName .. "." .. k .. " = " .. tostring(v))
            end,
            __tostring = function() return varName end
        })
    end
}

-- Wait/Task
env.wait = function(t)
    if t then
        addCode("wait(" .. t .. ")")
    else
        addCode("wait()")
    end
    return 0
end

env.task = {
    wait = function(t)
        addCode("task.wait(" .. (t or "") .. ")")
        return 0
    end,
    spawn = function(func)
        addCode("task.spawn(function() end)")
    end,
    delay = function(t, func)
        addCode("task.delay(" .. t .. ", function() end)")
    end
}

-- Standard globals
env.type = type
env.typeof = type
env.tostring = tostring
env.tonumber = tonumber
env.pairs = pairs
env.ipairs = ipairs
env.next = next
env.pcall = pcall
env.xpcall = xpcall
env.assert = assert
env.error = error
env.select = select
env.unpack = unpack
env.getmetatable = getmetatable
env.setmetatable = setmetatable
env.rawget = rawget
env.rawset = rawset
env.rawequal = rawequal

-- Libraries
env.math = math
env.table = table
env.string = string
env.coroutine = coroutine
env.os = os
env.bit32 = bit32
env.utf8 = utf8

-- Environment
env._G = env
env.shared = {}
env._VERSION = "Lua 5.1"
env.getfenv = function() return env end
env.setfenv = function(f, t) return f end

-- Catch undefined globals
setmetatable(env, {
    __index = function(t, k)
        return nil
    end
})

-- Execute
local chunk, err = loadstring(scriptContent, "@script")
if not chunk then
    print("-- Error: " .. tostring(err))
    process.exit(1)
end

setfenv(chunk, env)
local success, result = pcall(chunk)

if not success then
    print("-- Runtime error: " .. tostring(result))
end

-- Check for returned function (VM obfuscators)
if success and type(result) == "function" then
    setfenv(result, env)
    pcall(result)
end

-- Output ONLY the reconstructed code
for _, line in ipairs(codeLines) do
    print(line)
end
