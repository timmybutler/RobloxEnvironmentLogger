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

-- Read settings from environment variables
local settings = {
    hookOp = process.env.SETTING_HOOKOP == "1",
    explore_funcs = process.env.SETTING_EXPLORE_FUNCS == "1",
    spyexeconly = process.env.SETTING_SPYEXECONLY == "1",
    no_string_limit = process.env.SETTING_NO_STRING_LIMIT == "1",
    minifier = process.env.SETTING_MINIFIER == "1",
    comments = process.env.SETTING_COMMENTS == "1",
    ui_detection = process.env.SETTING_UI_DETECTION == "1",
    notify_scamblox = process.env.SETTING_NOTIFY_SCAMBLOX == "1",
    constant_collection = process.env.SETTING_CONSTANT_COLLECTION == "1",
    duplicate_searcher = process.env.SETTING_DUPLICATE_SEARCHER == "1",
    neverNester = process.env.SETTING_NEVERNESTER == "1"
}

-- Code reconstruction buffer
local codeLines = {}

-- String truncation helper
local function truncateString(str, maxLen)
    if settings.no_string_limit or #str <= maxLen then
        return str
    end
    local remaining = #str - maxLen
    return str:sub(1, maxLen) .. "...(" .. remaining .. " bytes left)"
end

-- Simple logging that only captures executable code
local function addCode(code)
    table.insert(codeLines, code)
end

-- Add comment helper
local function addComment(comment)
    if settings.comments then
        table.insert(codeLines, "-- " .. comment)
    end
end

-- Minimal environment
local env = {}

env.print = function(...)
    local args = {...}
    local strs = {}
    for i, v in ipairs(args) do
        if type(v) == "string" then
            strs[i] = '"' .. truncateString(tostring(v), 256) .. '"'
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
            strs[i] = '"' .. truncateString(tostring(v), 256) .. '"'
        else
            strs[i] = tostring(v)
        end
    end
    addCode("warn(" .. table.concat(strs, ", ") .. ")")
end

-- ═══════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS - Must be defined before use
-- ═══════════════════════════════════════════════════════════════

-- Create event/signal mock
local function createEvent()
    return setmetatable({}, {
        __index = function(t, k)
            if k == "Wait" or k == "wait" then
                return function() return nil end
            elseif k == "Connect" or k == "connect" then
                return function(self, callback) 
                    return setmetatable({}, {
                        __index = function(t, k)
                            if k == "Disconnect" then
                                return function() end
                            end
                            return function() end -- Return function for any access
                        end
                    })
                end
            end
            return createEvent()
        end,
        __call = function(t, ...)
            -- If the event itself is called, return nothing
            return nil
        end
    })
end

-- Create generic proxy that returns events/mocks
local function createGenericProxy(name)
    return setmetatable({__name = name}, {
        __index = function(t, k)
            -- Return a callable that returns an event
            return function(...)
                return createEvent()
            end
        end,
        __newindex = function(t, k, v)
            -- Silently ignore
        end,
        __call = function(t, ...)
            -- If the proxy itself is called, return event
            return createEvent()
        end,
        __tostring = function() return name end
    })
end

-- Create mock instance with common Roblox methods
local function createMockInstance(className, varName)
    local mock = {
        __className = className,
        __varName = varName,
        Name = className,
    }
    
    return setmetatable(mock, {
        __index = function(t, k)
            -- Common methods that return mocks
            if k == "WaitForChild" or k == "FindFirstChild" or k == "FindFirstChildOfClass" then
                return function(self, childName)
                    return createMockInstance(childName or "Child", childName or "Child")
                end
            elseif k == "GetPropertyChangedSignal" then
                return function(self, propName)
                    return createEvent()
                end
            elseif k == "Destroy" then
                return function() end
            elseif k == "Clone" then
                return function() return createMockInstance(className, varName .. "_Clone") end
            elseif k == "Connect" then
                return function(self, callback) return createEvent() end
            -- Common events
            elseif k == "MouseButton1Click" or k == "MouseButton1Down" or k == "MouseButton1Up" then
                return createEvent()
            elseif k == "InputBegan" or k == "InputChanged" or k == "InputEnded" then
                return createEvent()
            elseif k == "Changed" or k == "ChildAdded" or k == "ChildRemoved" then
                return createEvent()
            elseif k == "Heartbeat" or k == "RenderStepped" or k == "Stepped" then
                return createEvent()
            elseif k == "CharacterAdded" or k == "PlayerAdded" or k == "PlayerRemoving" then
                return createEvent()
            -- Return event for unknown properties
            else
                return createEvent()
            end
        end,
        __newindex = function(t, k, v)
            -- Log property assignment as code
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
        __call = function(t, ...)
            -- If instance is called directly, return event
            return createEvent()
        end,
        __tostring = function()
            return varName
        end
    })
end

-- ═══════════════════════════════════════════════════════════════
-- INSTANCE TRACKING
-- ═══════════════════════════════════════════════════════════════

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
        
        -- Return mock instance with full method support
        return createMockInstance(className, varName)
    end
}

-- Math types
env.Vector3 = {
    new = function(x, y, z)
        return setmetatable({}, {
            __tostring = function() return string.format("Vector3.new(%g, %g, %g)", x or 0, y or 0, z or 0) end
        })
    end
}

env.Color3 = {
    fromRGB = function(r, g, b)
        return setmetatable({}, {
            __tostring = function() return string.format("Color3.fromRGB(%d, %d, %d)", r, g, b) end
        })
    end,
    new = function(r, g, b)
        return setmetatable({}, {
            __tostring = function() return string.format("Color3.new(%g, %g, %g)", r, g, b) end
        })
    end,
    fromHSV = function(h, s, v)
        return setmetatable({}, {
            __tostring = function() return string.format("Color3.fromHSV(%g, %g, %g)", h, s, v) end
        })
    end
}

env.UDim = {
    new = function(s, o)
        return setmetatable({}, {
            __tostring = function() return string.format("UDim.new(%g, %g)", s, o) end
        })
    end
}

env.UDim2 = {
    new = function(xs, xo, ys, yo)
        return setmetatable({}, {
            __tostring = function() return string.format("UDim2.new(%g, %g, %g, %g)", xs, xo, ys, yo) end
        })
    end
}

env.Vector2 = {
    new = function(x, y)
        return setmetatable({}, {
            __tostring = function() return string.format("Vector2.new(%g, %g)", x, y) end
        })
    end
}

env.BrickColor = {
    new = function(name)
        return setmetatable({}, {
            __tostring = function() return 'BrickColor.new("' .. name .. '")' end
        })
    end
}

env.NumberRange = {
    new = function(...)
        local args = {...}
        return setmetatable({}, {
            __tostring = function() return "NumberRange.new(" .. table.concat(args, ", ") .. ")" end
        })
    end
}

env.NumberSequence = {
    new = function(...)
        return setmetatable({}, {
            __tostring = function() return "NumberSequence.new(...)" end
        })
    end
}

env.NumberSequenceKeypoint = {
    new = function(...)
        return setmetatable({}, {
            __tostring = function() return "NumberSequenceKeypoint.new(...)" end
        })
    end
}

env.ColorSequence = {
    new = function(...)
        return setmetatable({}, {
            __tostring = function() return "ColorSequence.new(...)" end
        })
    end
}

env.ColorSequenceKeypoint = {
    new = function(...)
        return setmetatable({}, {
            __tostring = function() return "ColorSequenceKeypoint.new(...)" end
        })
    end
}

env.TweenInfo = {
    new = function(...)
        return setmetatable({}, {
            __tostring = function() return "TweenInfo.new(...)" end
        })
    end
}

env.tick = function() return os.clock() end
env.wait = function(t) return 0 end
env.delay = function(t, f) return 0 end
env.spawn = function(f) f() end

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
                    services[name] = createMockInstance(name, 'game:GetService("' .. name .. '")')
                    -- Special handling for Players service
                    if name == "Players" then
                        services[name].LocalPlayer = createMockInstance("Player", "LocalPlayer")
                        services[name].LocalPlayer.Character = createMockInstance("Character", "Character")
                        services[name].LocalPlayer.CharacterAdded = createEvent()
                    end
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
        -- Return event for other accesses
        return createEvent()
    end,
    __tostring = function() return "game" end
})

env.workspace = createMockInstance("Workspace", "workspace")
env.script = createMockInstance("Script", "script")

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

-- ═══════════════════════════════════════════════════════════════
-- HOOKOP - OPERATION TRACKING
-- ═══════════════════════════════════════════════════════════════

if settings.hookOp then
    -- Track comparisons and operations
    local operationCount = 0
    
    -- Create tracked number type for arithmetic operations
    local function createTrackedNumber(value)
        return setmetatable({__value = value}, {
            __add = function(a, b)
                local av = type(a) == "table" and a.__value or a
                local bv = type(b) == "table" and b.__value or b
                if settings.comments then
                    addComment("Operation: " .. av .. " + " .. bv .. " = " .. (av + bv))
                end
                return createTrackedNumber(av + bv)
            end,
            __sub = function(a, b)
                local av = type(a) == "table" and a.__value or a
                local bv = type(b) == "table" and b.__value or b
                if settings.comments then
                    addComment("Operation: " .. av .. " - " .. bv .. " = " .. (av - bv))
                end
                return createTrackedNumber(av - bv)
            end,
            __mul = function(a, b)
                local av = type(a) == "table" and a.__value or a
                local bv = type(b) == "table" and b.__value or b
                if settings.comments then
                    addComment("Operation: " .. av .. " * " .. bv .. " = " .. (av * bv))
                end
                return createTrackedNumber(av * bv)
            end,
            __div = function(a, b)
                local av = type(a) == "table" and a.__value or a
                local bv = type(b) == "table" and b.__value or b
                if settings.comments then
                    addComment("Operation: " .. av .. " / " .. bv .. " = " .. (av / bv))
                end
                return createTrackedNumber(av / bv)
            end,
            __mod = function(a, b)
                local av = type(a) == "table" and a.__value or a
                local bv = type(b) == "table" and b.__value or b
                if settings.comments then
                    addComment("Operation: " .. av .. " % " .. bv .. " = " .. (av % bv))
                end
                return createTrackedNumber(av % bv)
            end,
            __pow = function(a, b)
                local av = type(a) == "table" and a.__value or a
                local bv = type(b) == "table" and b.__value or b
                if settings.comments then
                    addComment("Operation: " .. av .. " ^ " .. bv .. " = " .. (av ^ bv))
                end
                return createTrackedNumber(av ^ bv)
            end,
            __unm = function(a)
                local av = type(a) == "table" and a.__value or a
                if settings.comments then
                    addComment("Operation: -" .. av .. " = " .. (-av))
                end
                return createTrackedNumber(-av)
            end,
            __eq = function(a, b)
                local av = type(a) == "table" and a.__value or a
                local bv = type(b) == "table" and b.__value or b
                local result = av == bv
                addComment("Comparison: " .. av .. " == " .. bv .. " -> " .. tostring(result))
                return result
            end,
            __lt = function(a, b)
                local av = type(a) == "table" and a.__value or a
                local bv = type(b) == "table" and b.__value or b
                local result = av < bv
                addComment("Comparison: " .. av .. " < " .. bv .. " -> " .. tostring(result))
                return result
            end,
            __le = function(a, b)
                local av = type(a) == "table" and a.__value or a
                local bv = type(b) == "table" and b.__value or b
                local result = av <= bv
                addComment("Comparison: " .. av .. " <= " .. bv .. " -> " .. tostring(result))
                return result
            end,
            __tostring = function(self)
                return tostring(self.__value)
            end,
            __tonumber = function(self)
                return self.__value
            end
        })
    end
    
    -- Enhance tonumber to return tracked numbers
    local original_tonumber = env.tonumber
    env.tonumber = function(...)
        local result = original_tonumber(...)
        if result and settings.hookOp then
            return createTrackedNumber(result)
        end
        return result
    end
end

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

-- ═══════════════════════════════════════════════════════════════
-- ADVANCED FUNCTION RECONSTRUCTION
-- ═══════════════════════════════════════════════════════════════

local functionCounter = 0
local trackedFunctions = {}

-- Smart value serializer for reconstruction
local function serializeValue(value, depth)
    depth = depth or 0
    if depth > 3 then return "..." end
    
    local valueType = type(value)
    
    if valueType == "nil" then
        return "nil"
    elseif valueType == "boolean" then
        return tostring(value)
    elseif valueType == "number" then
        return tostring(value)
    elseif valueType == "string" then
        return '"' .. truncateString(value:gsub('"', '\\"'), 256) .. '"'
    elseif valueType == "table" then
        -- Check for special types
        if value.__varName then
            return value.__varName
        elseif value.__className then
            return value.__className
        elseif value.__tostring then
            return tostring(value)
        else
            -- Try to serialize table
            local parts = {}
            local count = 0
            for k, v in pairs(value) do
                count = count + 1
                if count > 5 then
                    table.insert(parts, "...")
                    break
                end
                if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                    table.insert(parts, k .. " = " .. serializeValue(v, depth + 1))
                else
                    table.insert(parts, "[" .. serializeValue(k, depth + 1) .. "] = " .. serializeValue(v, depth + 1))
                end
            end
            return "{" .. table.concat(parts, ", ") .. "}"
        end
    elseif valueType == "function" then
        if trackedFunctions[value] then
            return trackedFunctions[value].name
        else
            return "function() end"
        end
    else
        return tostring(value)
    end
end

-- Extract function parameters using debug info (if available) or fallback
local function getFunctionParams(func)
    -- Try debug.getinfo if available
    local hasDebug, debugInfo = pcall(debug.getinfo, func, "u")
    if hasDebug and debugInfo then
        local paramCount = debugInfo.nparams or 0
        local params = {}
        for i = 1, paramCount do
            params[i] = "arg" .. i
        end
        if debugInfo.isvararg then
            table.insert(params, "...")
        end
        return params
    end
    
    -- Fallback: assume common patterns
    return {"..."}
end

-- Wrap function to track calls and reconstruct
local function wrapFunction(func, funcName, params)
    if not settings.explore_funcs then
        -- Return placeholder
        return function(...)
            addComment("Function " .. funcName .. " called (explore_funcs disabled)")
            return nil
        end
    end
    
    trackedFunctions[func] = {
        name = funcName,
        params = params,
        calls = 0
    }
    
    return function(...)
        local args = {...}
        trackedFunctions[func].calls = trackedFunctions[func].calls + 1
        
        -- Log function call
        local argStrs = {}
        for i, arg in ipairs(args) do
            argStrs[i] = serializeValue(arg)
        end
        
        local callStr = funcName .. "(" .. table.concat(argStrs, ", ") .. ")"
        
        if settings.comments then
            addComment("Function call: " .. callStr)
        end
        
        -- Execute original function in controlled environment
        local results = {pcall(func, ...)}
        local success = table.remove(results, 1)
        
        if success then
            if settings.comments and #results > 0 then
                addComment("Returned: " .. serializeValue(results[1]))
            end
            return unpack(results)
        else
            if settings.comments then
                addComment("Function errored: " .. tostring(results[1]))
            end
            return nil
        end
    end
end

-- Track function definitions through setfenv wrapping
local function trackFunctionDefinition(func, name)
    functionCounter = functionCounter + 1
    local funcName = name or ("func" .. functionCounter)
    local params = getFunctionParams(func)
    
    -- Add function definition to reconstruction
    if settings.explore_funcs then
        local paramStr = table.concat(params, ", ")
        addCode("local function " .. funcName .. "(" .. paramStr .. ")")
        addComment("Function body execution tracked below")
        addCode("end")
    else
        addCode("local function " .. funcName .. "(...) --[[enable explore_funcs to view]] end")
    end
    
    return wrapFunction(func, funcName, params)
end

-- Enhanced loadstring that reconstructs the loaded code
env.loadstring = function(code, chunkname)
    if settings.explore_funcs then
        addCode("-- loadstring code:")
        addCode(truncateString(code, 1000))
    else
        addCode("loadstring([[" .. truncateString(code, 100) .. "]])")
    end
    addComment("[SECURITY] loadstring NOT executed")
    
    -- Return wrapped function
    return function(...)
        addComment("loadstring function called")
        return nil
    end
end

-- Track pcall/xpcall for better flow
local original_pcall = env.pcall
env.pcall = function(func, ...)
    local results = {original_pcall(func, ...)}
    local success = results[1]
    
    -- Disabled: too noisy
    -- if settings.comments then
    --     addComment("pcall " .. (success and "succeeded" or "failed"))
    -- end
    
    return unpack(results)
end

local original_xpcall = env.xpcall
env.xpcall = function(func, errorHandler, ...)
    local results = {original_xpcall(func, errorHandler, ...)}
    local success = results[1]
    
    -- Disabled: too noisy
    -- if settings.comments then
    --     addComment("xpcall " .. (success and "succeeded" or "failed"))
    -- end
    
    return unpack(results)
end

-- ═══════════════════════════════════════════════════════════════
-- SCRIPT EXECUTION
-- ═══════════════════════════════════════════════════════════════

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
