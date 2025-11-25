-- ADVANCED CODE RECONSTRUCTOR
-- Combines source parsing with runtime tracking for near-perfect reconstruction
local process = require("@lune/process")
local fs = require("@lune/fs")

local scriptPath = process.args[1]
if not scriptPath then
    print("Usage: lune run code_reconstructor_advanced.lua <script_path>")
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
local functionDefinitions = {}
local variableDeclarations = {}
local stringConstants = {}

-- ═══════════════════════════════════════════════════════════════
-- SOURCE CODE PARSING FOR FUNCTION EXTRACTION
-- ═══════════════════════════════════════════════════════════════

local function extractFunctionsFromSource(source)
    local functions = {}
    
    -- Pattern for local function declarations
    for funcDef in source:gmatch("(local%s+function%s+[%w_]+%s*%([^%)]*%).-end)") do
        table.insert(functions, funcDef)
    end
    
    -- Pattern for global function declarations
    for funcDef in source:gmatch("(function%s+[%w_.]+%s*%([^%)]*%).-end)") do
        table.insert(functions, funcDef)
    end
    
    -- Pattern for inline function assignments
    for varName, params in source:gmatch("local%s+([%w_]+)%s*=%s*function%s*%(([^%)]*)%)") do
        table.insert(functions, {name = varName, params = params})
    end
    
    return functions
end

local function extractVariablesFromSource(source)
    local vars = {}
    
    -- Extract local variable declarations
    for varDecl in source:gmatch("(local%s+[%w_]+%s*=.-)%s*\n") do
        -- Don't include function declarations
        if not varDecl:match("function") then
            table.insert(vars, varDecl)
        end
    end
    
    return vars
end

-- Parse source for functions
local sourceFunctions = extractFunctionsFromSource(scriptContent)
local sourceVariables = extractVariablesFromSource(scriptContent)

-- String truncation helper
local function truncateString(str, maxLen)
    if settings.no_string_limit or #str <= maxLen then
        return str
    end
    local remaining = #str - maxLen
    return str:sub(1, maxLen) .. "...(" .. remaining .. " bytes left)"
end

-- Add code line
local function addCode(code)
    table.insert(codeLines, code)
end

-- Add comment
local function addComment(comment)
    table.insert(codeLines, "-- " .. comment)
end

-- ═══════════════════════════════════════════════════════════════
-- SMART VALUE SERIALIZATION
-- ═══════════════════════════════════════════════════════════════

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
        local escaped = value:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
        return '"' .. truncateString(escaped, 256) .. '"'
    elseif valueType == "table" then
        local mt = getmetatable(value)
        if mt and mt.__tostring then
            return tostring(value)
        elseif value.__varName then
            return value.__varName
        elseif value.__className then
            return value.__className
        else
            -- Try to serialize table contents
            local parts = {}
            local count = 0
            for k, v in pairs(value) do
                count = count + 1
                if count > 5 then
                    table.insert(parts, "...")
                    break
                end
                if type(k) == "string" and k:match("^[%a_][%w_]*$") and not k:match("^__") then
                    table.insert(parts, k .. " = " .. serializeValue(v, depth + 1))
                end
            end
            if #parts > 0 then
                return "{" .. table.concat(parts, ", ") .. "}"
            else
                addComment("Table value (memory address hidden)")
                return "{}"
            end
        end
    elseif valueType == "function" then
        return "function() end"
    else
        addComment("Unknown type: " .. valueType)
        return "nil"
    end
end

-- ═══════════════════════════════════════════════════════════════
-- ENVIRONMENT SETUP
-- ═══════════════════════════════════════════════════════════════

local env = {}
local instanceCounter = 0

-- Create event mock
local function createEvent()
    return setmetatable({}, {
        __index = function(t, k)
            if k == "Wait" or k == "wait" then
                return function() return nil end
            elseif k == "Connect" or k == "connect" then
                return function(self, callback)
                    return setmetatable({}, {
                        __index = function(t, k)
                            if k == "Disconnect" then return function() end end
                            return function() end
                        end
                    })
                end
            end
            return createEvent()
        end,
        __call = function() return nil end
    })
end

-- Create mock instance
local function createMockInstance(className, varName)
    return setmetatable({
        __className = className,
        __varName = varName,
        Name = className,
    }, {
        __index = function(t, k)
            if k == "WaitForChild" or k == "FindFirstChild" then
                return function(self, childName)
                    return createMockInstance(childName or "Child", childName or "Child")
                end
            elseif k == "GetPropertyChangedSignal" then
                return function() return createEvent() end
            elseif k == "Destroy" or k == "Clone" then
                return function() end
            elseif k:match("Click") or k:match("Input") or k:match("Changed") or k:match("beat") or k:match("Added") then
                return createEvent()
            else
                return createEvent()
            end
        end,
        __newindex = function(t, k, v)
            local valueStr = serializeValue(v)
            addCode(varName .. "." .. k .. " = " .. valueStr)
        end,
        __tostring = function() return varName end
    })
end

-- Print/W function
env.print = function(...)
    local args = {...}
    local strs = {}
    for i, v in ipairs(args) do
        strs[i] = serializeValue(v)
    end
    addCode("print(" .. table.concat(strs, ", ") .. ")")
end

env.warn = env.print

-- Instance.new
env.Instance = {
    new = function(className, parent)
        instanceCounter = instanceCounter + 1
        local varName = "Instance" .. instanceCounter
        
        local parentStr = parent and (", " .. tostring(parent)) or ""
        addCode("local " .. varName .. ' = Instance.new("' .. className .. '"' .. parentStr .. ")")
        
        return createMockInstance(className, varName)
    end
}

-- Roblox types with proper serialization
env.Vector3 = {
    new = function(x, y, z)
        return setmetatable({X = x or 0, Y = y or 0, Z = z or 0}, {
            __tostring = function(self)
                return string.format("Vector3.new(%g, %g, %g)", self.X, self.Y, self.Z)
            end
        })
    end
}

env.Vector2 = {
    new = function(x, y)
        return setmetatable({X = x or 0, Y = y or 0}, {
            __tostring = function(self)
                return string.format("Vector2.new(%g, %g)", self.X, self.Y)
            end
        })
    end
}

env.UDim2 = {
    new = function(xs, xo, ys, yo)
        return setmetatable({
            X = {Scale = xs or 0, Offset = xo or 0},
            Y = {Scale = ys or 0, Offset = yo or 0}
        }, {
            __tostring = function(self)
                return string.format("UDim2.new(%g, %g, %g, %g)",
                    self.X.Scale, self.X.Offset, self.Y.Scale, self.Y.Offset)
            end
        })
    end
}

env.UDim = {
    new = function(s, o)
        return setmetatable({Scale = s or 0, Offset = o or 0}, {
            __tostring = function(self)
                return string.format("UDim.new(%g, %g)", self.Scale, self.Offset)
            end
        })
    end
}

env.Color3 = {
    fromRGB = function(r, g, b)
        return setmetatable({R = (r or 0)/255, G = (g or 0)/255, B = (b or 0)/255}, {
            __tostring = function(self)
                return string.format("Color3.fromRGB(%d, %d, %d)",
                    math.floor(self.R * 255), math.floor(self.G * 255), math.floor(self.B * 255))
            end
        })
    end,
    new = function(r, g, b)
        return setmetatable({R = r or 0, G = g or 0, B = b or 0}, {
            __tostring = function(self)
                return string.format("Color3.new(%g, %g, %g)", self.R, self.G, self.B)
            end
        })
    end,
    fromHSV = function(h, s, v)
        return setmetatable({H = h or 0, S = s or 0, V = v or 0}, {
            __tostring = function(self)
                return string.format("Color3.fromHSV(%g, %g, %g)", self.H, self.S, self.V)
            end
        })
    end
}

env.NumberRange = {
    new = function(min, max)
        return setmetatable({Min = min or 0, Max = max or min or 0}, {
            __tostring = function(self)
                return string.format("NumberRange.new(%g, %g)", self.Min, self.Max)
            end
        })
    end
}

env.NumberSequence = {
    new = function(...) return setmetatable({}, {__tostring = function() return "NumberSequence.new(...)" end}) end
}

env.NumberSequenceKeypoint = {
    new = function(...) return setmetatable({}, {__tostring = function() return "NumberSequenceKeypoint.new(...)" end}) end
}

env.ColorSequence = {
    new = function(...) return setmetatable({}, {__tostring = function() return "ColorSequence.new(...)" end}) end
}

env.TweenInfo = {
    new = function(...) return setmetatable({}, {__tostring = function() return "TweenInfo.new(...)" end}) end
}

env.BrickColor = {
    new = function(name) return setmetatable({Name = name}, {__tostring = function(self) return 'BrickColor.new("' .. self.Name .. '")' end}) end
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
                    services[name] = createMockInstance(name, 'game:GetService("' .. name .. '")')
                    if name == "Players" then
                        services[name].LocalPlayer = createMockInstance("Player", "LocalPlayer")
                        services[name].LocalPlayer.Character = createMockInstance("Character", "Character")
                        services[name].LocalPlayer.CharacterAdded = createEvent()
                    end
                end
                return services[name]
            end
        elseif k == "HttpGet" then
            return function(self, url)
                addCode('game:HttpGet("' .. url .. '")')
                return ""
            end
        end
        return createEvent()
    end,
    __tostring = function() return "game" end
})

env.workspace = createMockInstance("Workspace", "workspace")
env.script = createMockInstance("Script", "script")

-- Standard library
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
env.unpack = unpack or table.unpack
env.getmetatable = getmetatable
env.setmetatable = setmetatable
env.rawget = rawget
env.rawset = rawset
env.rawequal = rawequal

env.math = math
env.table = table
env.string = string
env.os = {clock = os.clock, time = os.time, date = os.date}
env.tick = function() return os.clock() end
env.wait = function(t) return 0 end

env.task = {
    wait = function(t) return 0 end,
    spawn = function(f) end,
    delay = function(t, f) end
}

env._G = env
env.shared = {}
env._VERSION = _VERSION

-- ═══════════════════════════════════════════════════════════════
-- EXECUTE SCRIPT
-- ═══════════════════════════════════════════════════════════════

-- Add source-extracted functions first
if settings.explore_funcs and #sourceFunctions > 0 then
    addComment("=== EXTRACTED FUNCTIONS ===")
    for _, funcDef in ipairs(sourceFunctions) do
        if type(funcDef) == "string" then
            addCode(funcDef)
        elseif type(funcDef) == "table" then
            addCode("local function " .. funcDef.name .. "(" .. funcDef.params .. ")")
            addComment("Function body (execution tracked below)")
            addCode("end")
        end
    end
    addComment("=== RUNTIME EXECUTION ===")
end

local chunk, err = loadstring(scriptContent)
if not chunk then
    addComment("Parse error: " .. tostring(err))
else
    setfenv(chunk, env)
    local success, result = pcall(chunk)
    
    if not success then
        addComment("Runtime error: " .. tostring(result))
    end
end

-- ═══════════════════════════════════════════════════════════════
-- OUTPUT VALID LUA
-- ═══════════════════════════════════════════════════════════════

-- Output header
print("-- Reconstructed Lua Code")
print("-- Generated by Advanced Code Reconstructor")
print("-- Original file: " .. scriptPath)
print("")

-- Output all code
for _, line in ipairs(codeLines) do
    print(line)
end

print("")
print("-- End of reconstructed code")
