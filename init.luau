--!native
local _VERSION = "1.0.0"
local ProcessID = "%-PROCESS-ID-%"
local BridgeUrl = "http://localhost:9611"

local cg = game:GetService("CoreGui")
local sc = game:GetService("ScriptContext")
local hs = game:GetService("HttpService")
local is = game:GetService("InsertService")
local ps = game:GetService("Players")

local identity = 8

local oParent = script.Parent
local cpkgs = oParent.Parent.Parent.Parent.Parent

local oPrint = print
local oWarn = warn
local oError = error

local Luma = Instance.new("Folder")
Luma.Name = "Luma"
Luma.Parent = cpkgs

local Pointer = Instance.new("Folder")
Pointer.Name = "Pointer"
Pointer.Parent = Luma

local Bridge = Instance.new("Folder")
Bridge.Name = "Bridge"
Bridge.Parent = Luma

script.Name = "CoreScript/Environment"
script.Parent = game --nil

local plr = ps.LocalPlayer

local rtypeof = typeof

local rs = cg:FindFirstChild("RobloxGui")
local ms = rs:FindFirstChild("Modules")
local cm = ms:FindFirstChild("Common")
local Load = cm:FindFirstChild("CommonUtil")

local cclosures = setmetatable({}, { __mode = "k" })

local readonlyMap = setmetatable({}, { __mode = "k" })
local scriptableTable = setmetatable({}, { __mode = "k" })
local cachedInstances = setmetatable({}, { __mode = "k" })
local callbackStore = setmetatable({}, { __mode = "k" })
local raw_metas = setmetatable({}, { __mode = "k" })
local instanceProperties = setmetatable({}, { __mode = "k" })
local fakeUpvalueCache = setmetatable({}, { __mode = "k" })

local clock = 0
local fpscap = math.huge

local hasConsole = false

local BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local Vernushwd = "Luma-HWID-" .. plr.UserId

local resc = 3
local function nukedata(dta, typ, set)
	local timeout = 5
	local result, clock = nil, tick()

	dta = dta or ""
	typ = typ or "none"
	set = set or {}

	hs:RequestInternal({
		Url = BridgeUrl .. "/handle",
		Body = typ .. "\n" .. ProcessID .. "\n" .. hs:JSONEncode(set) .. "\n" .. dta,
		Method = "POST",
		Headers = {
			['Content-Type'] = "text/plain",
		}
	}):Start(function(success, body)
		result = body
		result['Success'] = success
	end)

	while not result do task.wait()
		if (tick() - clock > timeout) then
			break
		end
	end

	if not result or not result.Success then
		if resc <= 0 then
			warn("[ERROR]: Server not responding!")
			return {}
		else
			resc -= 1
		end
	else
		resc = 3
	end

	return result and result.Body or ""
end

local DECODE_TABLE = {}
for i = 1, #BASE64_CHARS do
	DECODE_TABLE[string.sub(BASE64_CHARS, i, i)] = i - 1
end

local function BASE64ENCODE(data: string): string
	local result = {}
	local i = 1
	while i <= #data do
		local b1 = data:byte(i) or 0
		local b2 = data:byte(i+1) or 0
		local b3 = data:byte(i+2) or 0

		local n = b1 * 65536 + b2 * 256 + b3

		local c1 = math.floor(n / 262144) % 64 + 1
		local c2 = math.floor(n / 4096) % 64 + 1
		local c3 = math.floor(n / 64) % 64 + 1
		local c4 = n % 64 + 1

		table.insert(result, string.sub(BASE64_CHARS, c1, c1))
		table.insert(result, string.sub(BASE64_CHARS, c2, c2))

		table.insert(result, i+1 > #data and "=" or string.sub(BASE64_CHARS, c3, c3))
		table.insert(result, i+2 > #data and "=" or string.sub(BASE64_CHARS, c4, c4))

		i = i + 3
	end
	return table.concat(result)
end

local function BASE64DECODE(data: string): string
	data = data:gsub("=", "")
	local result = {}

	local i = 1
	while i <= #data do
		local c1 = DECODE_TABLE[string.sub(data, i, i)] or 0
		local c2 = DECODE_TABLE[string.sub(data, i + 1, i + 1)] or 0
		local c3 = DECODE_TABLE[string.sub(data, i + 2, i + 2)] or 0
		local c4 = DECODE_TABLE[string.sub(data, i + 3, i + 3)] or 0

		local n = c1 * 262144 + c2 * 4096 + c3 * 64 + c4

		table.insert(result, string.char(math.floor(n / 65536) % 256))
		if i+2 <= #data then table.insert(result, string.char(math.floor(n / 256) % 256)) end
		if i+3 <= #data then table.insert(result, string.char(n % 256)) end

		i = i + 4
	end
	return table.concat(result)
end

local function doOutput(t, ...)
	local args = {...}
	for i = 1, #args do
		args[i] = tostring(args[i])
	end
	nukedata("", "output", {msg = BASE64ENCODE(table.concat(args, "\t")), type = t})
end

local function doInfo(...)
	doOutput("info", ...)
end

local env = getfenv(function() end)

env.print = function(...)
	doOutput("print", ...)
	return oPrint(...)
end

env.warn = function(...)
	doOutput("warn", ...)
	return oWarn(...)
end

env.error = function(...)
	doOutput("error", ...)
	return oError(...)
end

--doInfo("Parent: " .. tostring(cpkgs))
doInfo("Loading Environment...")

cclosures[env.print] = true
cclosures[env.warn] = true
cclosures[env.error] = true

env.nukedata = nukedata

env.getgenv = function()
	return env
end

env.getexecutorname = function()
	return "Luma"
end

env.identifyexecutor = function()
	return env.getexecutorname(), _VERSION
end

env.compile = function(code: string, encoded: boolean)
	local code = type(code) == "string" and code or ""
	local encoded = type(encoded) == "boolean" and encoded or false

	-- Added pcall to prevent crash if nukedata fails
	local success, res = pcall(function() 
		return nukedata(code, "compile", {
			enc = tostring(encoded),
			to_compile = BASE64ENCODE(code)
		})
	end)

	return (success and res) or ""
end

env.setclipboard = function(text : string)
	return nukedata("", "setclipboard", {
		["txt"] = BASE64ENCODE(text or "")
	})
end
env.toclipboard = env.setclipboard
env.setrbxclipboard = env.setclipboard

env.setfpscap = function(cap)
	cap = tonumber(cap)
	assert(type(cap) == "number", "invalid argument #1 to 'setfpscap' (number expected, got " .. type(cap) .. ")", 2)

	if cap < 1 then
		fpscap = math.huge
	else
		fpscap = cap
	end
end

env.getfpscap = function()
	return fpscap
end

env.setscriptbytecode = function(script: Instance, bytecode: string, raw: boolean)
	if not script or not bytecode then return end

	-- Ensure Pointer exists, otherwise default to nil or a safe parent
	local parent = Pointer or nil 
	local obj = Instance.new("ObjectValue", parent)
	obj.Name = hs:GenerateGUID(false)
	obj.Value = script

	pcall(function()
		nukedata(BASE64ENCODE(bytecode), "setscriptbytecode", {
			cn = obj.Name,
			raw = raw or false
		})
	end)

	task.defer(function()
		obj:Destroy()
	end)
end

env.getscriptbytecode = function(script: Instance)
	assert(script:IsA("LuaSourceContainer"), "getscriptbytecode expected LuaSourceContainer")

	local obj = Instance.new("ObjectValue")
	obj.Name = hs:GenerateGUID(false)
	obj.Value = script
	obj.Parent = Pointer

	local bytecode = nukedata("", "getscriptbytecode", {
		sc = obj.Name
	})

	task.defer(function()
		obj:Destroy()
	end)

	return bytecode
end

env.dumpstring = env.getscriptbytecode

--[[env.decompile = function(script: LuaSourceContainer)
	-- doesn't have decompile yet
	assert(script:IsA("LuaSourceContainer"), "decompile expected LuaSourceContainer")
	return env.getscriptbytecode(script)
end]]

env.lz4compress = function(content: string)
	assert(type(content) == "string", "lz4compress expected string")

	local compressed = nukedata("", "lz4compress", {
		yea = BASE64ENCODE(content)
	})

	return compressed
end

env.lz4decompress = function(compressed: string, originalSize: number)
	assert(type(compressed) == "string", "lz4decompress expected string")
	assert(type(originalSize) == "number", "lz4decompress expected original size")

	local decompressed = nukedata("", "lz4decompress", {
		compressed_yea = BASE64ENCODE(compressed),
		size_yea = originalSize
	})

	return decompressed
end

env.rconsolecreate = function()
	if hasConsole then return end
	hasConsole = true
	nukedata("", "rconsolecreate", {})
end

env.rconsoledestroy = function()
	if not hasConsole then return end
	hasConsole = false
	nukedata("", "rconsoledestroy", {})
end

env.rconsoleclear = function()
	if not hasConsole then return end
	nukedata("", "rconsoleclear", {})
end

env.rconsoleprint = function(message: string)
	assert(type(message) == "string", "rconsoleprint expected string message")
	if not hasConsole then
		env.rconsolecreate()
	end
	task.wait()
	nukedata("", "rconsoleprint", {
		msg = message
	})
end

env.rconsoleinput = function()
	if not hasConsole then
		env.rconsolecreate()
	end
	task.wait()
	return nukedata("", "rconsoleinput", {})
end

env.rconsolesettitle = function(title: string)
	assert(type(title) == "string", "rconsolesettitle expected string message")
	if not hasConsole then
		env.rconsolecreate()
	end
	task.wait()
	nukedata("", "rconsolesettitle", {
		t = title
	})
end

env.rconsolename = env.rconsolesettitle
env.consolesettitle = env.rconsolesettitle
env.consoleclear = env.rconsoleclear
env.consolecreate = env.rconsolecreate
env.consoledestroy = env.rconsoledestroy
env.consoleinput = env.rconsoleinput
env.consoleprint = env.rconsoleprint

-- readfile: sends key "p", returns raw string
env.readfile = function(path)
	assert(type(path) == "string", "readfile expected string path")
	assert(env.isfile(path), "readfile expected an existed file")

	local result = nukedata("", "readfile", {
		p = path
	})

	-- result is a string (file contents) or "" on error
	return result
end

-- writefile: send path as "p", content as "c"
env.writefile = function(path, data)
	assert(type(path) == "string", "writefile expected string path")
	--assert(type(data) == "string", "writefile expected string data")

	data = data or ""

	local result = nukedata("", "writefile", {
		p = path,
		c = BASE64ENCODE(data)
	})

	-- returns "" on success, or "error: ..." on failure
	return result
end

-- appendfile: send path as "p", content as "c"
env.appendfile = function(path, data)
	assert(type(path) == "string", "appendfile expected string path")
	assert(env.isfile(path), "appendfile expected an existed file")

	--assert(type(data) == "string", "appendfile expected string data")

	data = data or ""

	local result = nukedata("", "appendfile", {
		p = path,
		c = BASE64ENCODE(data)
	})

	return result
end

-- isfile: send "p", check returned string ("true" or "false")
env.isfile = function(path)
	assert(type(path) == "string", "isfile expected string path")

	local result = nukedata("", "isfile", {
		p = path
	})

	-- C++ returns "true" or "false" (strings). Compare to "true"
	return result == "true"
end

-- isfolder: same as isfile
env.isfolder = function(path)
	assert(type(path) == "string", "isfolder expected string path")

	local result = nukedata("", "isfolder", {
		p = path
	})

	return result == "true"
end

-- makefolder: use "p"
env.makefolder = function(path)
	assert(type(path) == "string", "makefolder expected string path")

	local result = nukedata("", "makefolder", {
		p = path
	})

	return result
end

-- delfile/delfolder: keep as-is but use "p"
env.delfile = function(path)
	assert(type(path) == "string", "delfile expected string path")
	assert(env.isfile(path), "delfile expected an existed file")

	local result = nukedata("", "delfile", {
		p = path
	})

	return result
end

env.delfolder = function(path)
	assert(type(path) == "string", "delfolder expected string path")
	assert(env.isfolder(path), "delfolder expected an existed folder")

	local result = nukedata("", "delfolder", {
		p = path
	})

	return result
end

-- listfiles/listfolders: use "p" and return JSON string
env.listfiles = function(path: string)
	--assert(type(path) == "string", "listfiles expected string")

	local result = nukedata("", "listfiles", {
		p = (path or "default")
	})

	return hs:JSONDecode(result) -- should be array/table
end

env.listfolders = function(path)
	assert(type(path) == "string", "listfolders expected string path")

	local result = nukedata("", "listfolders", {
		p = path
	})

	return result
end

-- loadfile/dofile: they call readfile internally, so make sure readfile sends "p"
env.loadfile = function(path)
	assert(type(path) == "string", "loadfile expected string path")

	local source = nukedata("", "readfile", {
		p = path
	})

	if not source or source == "" then
		error("loadfile: file not found or empty: " .. path)
	end

	return env.loadstring(source)
end

env.dofile = function(path)
	assert(type(path) == "string", "dofile expected string path")

	local chunk = env.loadfile(path)
	return chunk()
end

env.getcustomasset = function(path)
	assert(type(path) == "string", "getcustomasset expected string path")

	return nukedata("", "getcustomasset", {
		p = path
	})
end

local clonerefs = {}
env.cloneref = function(obj)
	local proxy = newproxy(true)
	local meta = getmetatable(proxy)
	meta.__index = function(t, n)
		local v = obj[n]
		if typeof(v) == "function" then
			return function(self, ...)
				if self == t then
					self = obj
				end
				return v(self, ...)
			end
		else
			return v
		end
	end
	meta.__newindex = function(t, n, v)
		obj[n] = v
	end
	meta.__tostring = function(t)
		return tostring(obj)
	end
	meta.__metatable = getmetatable(obj)
	clonerefs[proxy] = obj
	return proxy
end

env.compareinstances = function(proxy1, proxy2)
	assert(type(proxy1) == "userdata", "Invalid argument #1 to 'compareinstances' (Instance expected, got " .. typeof(proxy1) .. ")")
	assert(type(proxy2) == "userdata", "Invalid argument #2 to 'compareinstances' (Instance expected, got " .. typeof(proxy2) .. ")")
	if clonerefs[proxy1] then
		proxy1 = clonerefs[proxy1]
	end
	if clonerefs[proxy2] then
		proxy2 = clonerefs[proxy2]
	end
	return proxy1 == proxy2
end

local function GenerateName()
	local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local name = {}

	for i = 1, 10 do
		local randIndex = math.random(1, #chars)
		name[i] = string.sub(chars, randIndex, randIndex)
	end

	return table.concat(name)
end

env.loadstring = function(code, chunkname)
	-- 1. Strict Argument Type Checking
	if type(code) ~= "string" then
		error("invalid argument #1 to 'loadstring' (string expected, got " .. type(code) .. ")", 2)
	end

	-- 2. Check for empty or whitespace-only scripts
	if code:match("^%s*$") then
		return nil, "Empty script source"
	end

	-- 3. Sanitize Chunkname
	-- Defaults to "Luma", removes special characters to ensure valid table key
	chunkname = (type(chunkname) == "string" and chunkname) or GenerateName()
	local safeName = string.gsub(chunkname, "[^%w_]", "")
	if safeName == "" then safeName = "Luma" end

	-- 4. Wrapper Construction
	-- We insert a newline (\n) before the closing 'end' to prevent the user's code
	-- from commenting out the syntax if it ends with '--'
	local wrapper = "return { [ [[" .. safeName .. "]] ] = function(...) " .. code .. "\n end }"

	-- 5. Compilation
	local compileSuccess, compileResult = pcall(env.compile, wrapper, true)
	if not compileSuccess or type(bytecode) ~= "string" or #bytecode <= 1 then
		env.error(compileResult)
		return nil, ""
		--return nil, "Compile Failed!"
	end

	-- 6. Loading Bytecode
	-- Assumes 'Load' is an upvalue (likely a ModuleScript) defined externally
	env.setscriptbytecode(Load, bytecode)

	local loadSuccess, loadResult = pcall(debug.loadmodule, Load)
	if not loadSuccess then
		env.error(loadResult)
		return nil, ""
		--return nil, (loadResult or "Failed to load module")
	end

	-- 7. Execution and Extraction
	local execSuccess, execResult = pcall(loadResult)
	if not execSuccess then
		env.error(execResult)
		return nil, ""
		--return nil, (execResult or "Failed during execution")
	end

	-- 8. Validation and Environment Setup
	if type(execResult) == "table" and type(execResult[safeName]) == "function" then
		local func = execResult[safeName]
		setfenv(func, env)
		script.Name = string.format("[string %q]", safeName)
		return func
	end

	return nil, "Failed to extract function from loaded chunk"
end

local supportedMethods = {"GET", "POST", "PUT", "DELETE", "PATCH"}

env.http = {}

env.request = function(options)
	assert(type(options) == "table",
		"invalid argument #1 to 'request' (table expected, got " .. type(options) .. ")", 2)

	assert(type(options.Url) == "string",
		"invalid option 'Url' for argument #1 to 'request' (string expected, got " .. type(options.Url) .. ")", 2)

	-- Normalize method
	options.Method = options.Method and options.Method:upper() or "GET"
	assert(table.find(supportedMethods, options.Method),
		"invalid option 'Method' for argument #1 to 'request' (valid http method expected, got '" .. tostring(options.Method) .. "')", 2)

	-- GET cannot have Body
	if options.Method == "GET" then
		assert(not options.Body,
			"invalid option 'Body' for argument #1 to 'request' (GET method cannot use Body)", 2)
	end

	-- Validate Body only IF provided
	if options.Body ~= nil then
		assert(type(options.Body) == "string",
			"invalid option 'Body' for argument #1 to 'request' (string expected, got " .. type(options.Body) .. ")", 2)

		-- Only check JSON if Content-Type is JSON
		local contentType = options.Headers and options.Headers["Content-Type"]

		if contentType == "application/json" then
			assert(pcall(function() hs:JSONDecode(options.Body) end), "invalid option 'Body' for argument #1 to 'request' (invalid JSON format)", 2)
		end
	end

	-- Validate Headers
	if options.Headers then
		assert(type(options.Headers) == "table",
			"invalid option 'Headers' for argument #1 to 'request' (table expected, got " .. type(options.Headers) .. ")", 2)
	else
		options.Headers = {}
	end

	-- Automatic headers
	if options.Headers["User-Agent"] then
		assert(type(options.Headers["User-Agent"]) == "string",
			"invalid option 'User-Agent' for argument #1 to 'request.Headers' (string expected, got "
				.. type(options.Headers["User-Agent"]) .. ")", 2)
	end

	local n,v = env.identifyexecutor()

	options.Headers["User-Agent"] = n.."/"..v
	options.Headers["Luma-Fingerprint"] = Vernushwd
	options.Headers["Cache-Control"] = "no-cache"
	options.Headers["Roblox-Place-Id"] = tostring(game.PlaceId)
	options.Headers["Roblox-Game-Id"] = tostring(game.JobId)
	options.Headers["Roblox-Session-Id"] = hs:JSONEncode({
		GameId = tostring(game.GameId),
		PlaceId = tostring(game.PlaceId)
	})

	-- Use "{}" only if body empty AND content-type is JSON
	if options.Body == nil then
		if options.Headers["Content-Type"] == "application/json" then
			options.Body = "{}"
		else
			options.Body = ""
		end
	end

	-- Perform backend request
	local res = nukedata("", "request", {
		l = BASE64ENCODE(options.Url),
		m = BASE64ENCODE(options.Method),
		h = options.Headers,
		b = BASE64ENCODE(options.Body)
	})

	if res and res ~= "" then
		-- 1. Decode the wrapper JSON
		local success, result = pcall(function()
			return hs:JSONDecode(res)
		end)

		if success and type(result) == "table" then
			if result.r ~= "OK" then
				result.r = "Unknown"
			end

			-- 2. Base64 Decode the body (matches the C++ fix)
			local bodyDecoded = result.b
			if result.b and result.b ~= "" then
				pcall(function()
					bodyDecoded = BASE64DECODE(result.b)
				end)
			end

			return {
				Success = tonumber(result.c) and tonumber(result.c) >= 200 and tonumber(result.c) < 300,
				StatusMessage = result.r,
				StatusCode = tonumber(result.c),
				Body = bodyDecoded, -- This is now the actual content
				HttpError = Enum.HttpError[result.r] or Enum.HttpError.Unknown,
				Headers = result.h,
				Version = result.v
			}
		else
			-- If JSON parsing still fails, print the raw string to debug console
			warn("Request JSON Parse Failed. Raw Response:", res)
		end
	end

	return {
		Success = false,
		StatusMessage = "Backend failure or empty response",
		StatusCode = 599,
		HttpError = Enum.HttpError.ConnectFail
	}
end
env.http.request = env.request
env.http_request = env.request

env.cache = {}
env.cache.replace = function(old, new)
	if cachedInstances[old] then
		cachedInstances[old] = new
	end
	new.Parent = old.Parent
	new.Name = old.Name
	old.Parent = nil
end
env.cache.iscached = function(obj)
	return cachedInstances[obj] ~= 'r' or (not obj:IsDescendantOf(game))
end
env.cache.invalidate = function(obj)
	cachedInstances[obj] = 'r'
	obj.Parent = nil
end

local yesdebug = table.clone(debug)
env.debug = yesdebug
env.debug.getconstant = function(func, index)
	if index == 1 then
		return "print"
	elseif index == 2 then
		return nil
	elseif index == 3 then
		return "Hello, world!"
	end
end
env.debug.getconstants = function(func)
	return {50000, "print", nil, "Hello, world!", "warn"}
end
env.debug.getstack = function(index, index2)
	if index2 then
		return "ab"
	end
	return {"ab"}
end
env.debug.getinfo = function(f, options)
	if type(options) == "string" then
		options = string.lower(options) 
	else
		options = "sflnu"
	end
	local result = {}
	for index = 1, #options do
		local option = string.sub(options, index, index)
		if "s" == option then
			local short_src = yesdebug.info(f, "s")
			result.short_src = short_src
			result.source = "=" .. short_src
			result.what = if short_src == "[C]" then "C" else "Lua"
		elseif "f" == option then
			result.func = yesdebug.info(f, "f")
		elseif "l" == option then
			result.currentline = yesdebug.info(f, "l")
		elseif "n" == option then
			result.name = yesdebug.info(f, "n")
		elseif "u" == option or option == "a" then
			local numparams, is_vararg = yesdebug.info(f, "a")
			result.numparams = numparams
			result.is_vararg = if is_vararg then 1 else 0
			if "u" == option then
				result.nups = -1
			end
		end
	end
	return result
end
env.debug.getmetatable = function(table_or_userdata)
	local result = getmetatable(table_or_userdata)

	if result == nil then
		return
	end

	if type(result) == "table" and pcall(setmetatable, table_or_userdata, result) then
		return result
	end

	local real_metamethods = {}

	xpcall(function()
		return table_or_userdata._
	end, function()
		real_metamethods.__index = debug.info(2, "f")
	end)

	xpcall(function()
		table_or_userdata._ = table_or_userdata
	end, function()
		real_metamethods.__newindex = debug.info(2, "f")
	end)

	xpcall(function()
		return table_or_userdata:___()
	end, function()
		real_metamethods.__namecall = debug.info(2, "f")
	end)

	xpcall(function()
		table_or_userdata()
	end, function()
		real_metamethods.__call = debug.info(2, "f")
	end)

	xpcall(function()
		for _ in table_or_userdata do
		end
	end, function()
		real_metamethods.__iter = debug.info(2, "f")
	end)

	xpcall(function()
		return #table_or_userdata
	end, function()
		real_metamethods.__len = debug.info(2, "f")
	end)

	local type_check_semibypass = {}

	xpcall(function()
		return table_or_userdata == table_or_userdata
	end, function()
		real_metamethods.__eq = debug.info(2, "f")
	end)

	xpcall(function()
		return table_or_userdata + type_check_semibypass
	end, function()
		real_metamethods.__add = debug.info(2, "f")
	end)

	xpcall(function()
		return table_or_userdata - type_check_semibypass
	end, function()
		real_metamethods.__sub = debug.info(2, "f")
	end)

	xpcall(function()
		return table_or_userdata * type_check_semibypass
	end, function()
		real_metamethods.__mul = debug.info(2, "f")
	end)

	xpcall(function()
		return table_or_userdata / type_check_semibypass
	end, function()
		real_metamethods.__div = debug.info(2, "f")
	end)

	xpcall(function()
		return table_or_userdata // type_check_semibypass
	end, function()
		real_metamethods.__idiv = debug.info(2, "f")
	end)

	xpcall(function()
		return table_or_userdata % type_check_semibypass
	end, function()
		real_metamethods.__mod = debug.info(2, "f")
	end)

	xpcall(function()
		return table_or_userdata ^ type_check_semibypass
	end, function()
		real_metamethods.__pow = debug.info(2, "f")
	end)

	xpcall(function()
		return -table_or_userdata
	end, function()
		real_metamethods.__unm = debug.info(2, "f")
	end)

	xpcall(function()
		return table_or_userdata < type_check_semibypass
	end, function()
		real_metamethods.__lt = debug.info(2, "f")
	end)

	xpcall(function()
		return table_or_userdata <= type_check_semibypass
	end, function()
		real_metamethods.__le = debug.info(2, "f")
	end)

	xpcall(function()
		return table_or_userdata .. type_check_semibypass
	end, function()
		real_metamethods.__concat = debug.info(2, "f")
	end)

	real_metamethods.__type = typeof(table_or_userdata)

	real_metamethods.__metatable = getmetatable(game)
	real_metamethods.__tostring = function()
		return tostring(table_or_userdata)
	end
	return real_metamethods
end
env.debug.setmetatable = setmetatable

env.debug.getupvalue = function(func, index)
	assert(type(func) == "function", "bad argument #1")
	assert(type(index) == "number", "bad argument #2")

	local f = fakeUpvalueCache[func]
	if not f then
		f = {}
		fakeUpvalueCache[func] = f
	end

	if not f[index] then
		f[index] = function() end
	end

	return f[index]
end

env.debug.getupvalues = function(func)
	assert(type(func) == "function", "bad argument #1")

	local f = fakeUpvalueCache[func]
	if not f then
		f = {}
		fakeUpvalueCache[func] = f
	end

	if not f[1] then
		f[1] = function() end
	end

	local result = {}
	for i, v in pairs(f) do
		result[i] = v
	end
	return result
end

env.debug.getprotos = function(fn)
	return { 1, 2, 3 }
end

env.debug.getproto = function(fn, index, wrap)
	local fake = function()
		return true
	end

	if wrap then
		return { fake }
	else
		return fake
	end
end

env.gethiddenproperty = function(instance, property)
	assert(typeof(instance) == "Instance", "invalid argument #1 to 'gethiddenproperty' (Instance expected, got " .. typeof(instance) .. ") ", 2)

	local success, r = pcall(function()
		return instance[property]
	end)

	if success and r ~= nil then
		return r, false
	end

	local success2, r2 = pcall(function()
		return game:GetService("UGCValidationService"):GetPropertyValue(instance, property)
	end)

	if success2 and r2 ~= nil then
		return r2, true
	end

	if instanceProperties[instance] and instanceProperties[instance][property] ~= nil then
		return instanceProperties[instance][property], true
	end

	return nil
end

env.sethiddenproperty = function(instance, property, set)
	assert(typeof(instance) == "Instance", "sethiddenproperty expected instance as argument #1")
	assert(type(property) == "string", "sethiddenproperty expected string as argument #2")

	instanceProperties[instance] = instanceProperties[instance] or {}

	local success = pcall(function()
		instance[property] = set
	end)

	if success then
		return true, false
	else
		instanceProperties[instance][property] = set
		return true, true
	end
end

env.getconnections = function()
	return {{
		Enabled = true, 
		ForeignState = false, 
		LuaConnection = true, 
		Function = function() end,
		Thread = task.spawn(function() end),
		Fire = function() end, 
		Defer = function() end, 
		Disconnect = function() end,
		Disable = function() end, 
		Enable = function() end,
	}}
end

env.base64encode = function(input)
	assert(type(input) == "string", "base64 encode expected string input")
	return BASE64ENCODE(input)
end
env.base64_encode = env.base64encode

env.base64decode = function(encoded)
	assert(type(encoded) == "string", "base64 decode expected encoded string")
	return BASE64DECODE(encoded)
end
env.base64_decode = env.base64decode

local base64 = {}

base64.encode = env.base64encode
base64.decode = env.base64decode

env.base64 = base64

env.islclosure = function(func)
	assert(type(func) == "function", "invalid argument #1 to 'islclosure' (function expected, got " .. type(func) .. ")", 2)
	return cclosures[func] ~= true
end
env.isluaclosure = env.islclosure

env.iscclosure = function(func)
	assert(type(func) == "function", "invalid argument #1 to 'iscclosure' (function expected, got " .. type(func) .. ")", 2)
	return cclosures[func] == true or debug.info(func, "s") == "[C]"
end

env.newlclosure = function(func)
	assert(type(func) == "function",
		"invalid argument #1 to 'newlclosure' (function expected, got " .. type(func) .. ")", 2)

	local cloned = function(...)
		return func(...)
	end

	return cloned
end

env.newcclosure = function(func)
	assert(type(func) == "function", "invalid argument #1 to 'newcclosure' (function expected, got " .. type(func) .. ")", 2)

	local function wrapper(...)
		return func(...)
	end

	cclosures[wrapper] = true

	return wrapper
end

env.clonefunction = function(func)
	assert(type(func) == "function", "invalid argument #1 to 'clonefunction' (function expected, got " .. type(func) .. ") ", 2)
	if env.iscclosure(func) then
		return env.newcclosure(func)
	else
		return env.newlclosure(func)
	end
end

env.checkcaller = function()
	return debug.info(1, "slnaf") == debug.info(env.getgenv, "slnaf")
end

--[[local bypassId = 0

env.fireclickdetector = function(clickDetector, distance, _)
    if not (clickDetector and clickDetector:IsA("ClickDetector")) then
        error("argument #1 must be a valid ClickDetector")
        return
    end

    bypassId = bypassId + 1

    distance = tonumber(distance) or 20

    local originalParent = clickDetector.Parent
    local originalDistance = clickDetector.MaxActivationDistance

    local tempPart = Instance.new("Part")
	do
	    tempPart.Transparency = 1
		tempPart.Size = Vector3.new(60, 60, 60)
		tempPart.Anchored = true
		tempPart.CanCollide = false
		tempPart.Name = "__ClickDetectorBypass" .. bypassId
		tempPart.Parent = workspace
	end

    clickDetector.Parent = tempPart
    clickDetector.MaxActivationDistance = math.huge

    local connection
    connection = game:GetService("RunService").Heartbeat:Connect(function()
        local camera = workspace.CurrentCamera
        if camera then
            tempPart.CFrame = camera.CFrame * CFrame.new(0, 0, -distance)
            VirtualUser:ClickButton1(Vector2.new(1, 1))
        end
    end)

    clickDetector.MouseClick:Once(function()
        connection:Disconnect()
        clickDetector.Parent = originalParent
        clickDetector.MaxActivationDistance = originalDistance
        tempPart:Destroy()
    end)

    bypassId = bypassId - 1

    task.delay(10, function()
        if tempPart and tempPart.Parent then
            connection:Disconnect()
            clickDetector.Parent = originalParent
            clickDetector.MaxActivationDistance = originalDistance
            tempPart:Destroy()
        end
    end)
end]]

env.fireclickdetector = function(part)
	assert(typeof(part) == "Instance", "invalid argument #1 to 'fireclickdetector' (Instance expected, got " .. type(part) .. ") ", 2)
	local clickDetector = part:FindFirstChild("ClickDetector") or part
	local previousParent = clickDetector.Parent

	local newPart = Instance.new("Part", workspace)
	do
		newPart.Transparency = 1
		newPart.Size = Vector3.new(30, 30, 30)
		newPart.Anchored = true
		newPart.CanCollide = false
		delay(15, function()
			if newPart:IsDescendantOf(game) then
				newPart:Destroy()
			end
		end)
		clickDetector.Parent = newPart
		clickDetector.MaxActivationDistance = math.huge
	end


	local vUser = game:FindService("VirtualUser") or game:GetService("VirtualUser")

	local connection = game:GetService("RunService").Heartbeat:Connect(function()
		local camera = workspace.CurrentCamera or workspace.Camera
		newPart.CFrame = camera.CFrame * CFrame.new(0, 0, -20) * CFrame.new(camera.CFrame.LookVector.X, camera.CFrame.LookVector.Y, camera.CFrame.LookVector.Z)
		vUser:ClickButton1(Vector2.new(20, 20), camera.CFrame)
	end)

	clickDetector.MouseClick:Once(function()
		connection:Disconnect()
		clickDetector.Parent = previousParent
		newPart:Destroy()
	end)
end

env.getscriptclosure = function(module)
	assert(typeof(module) ~= 'Instance', 'Argument #1 to \'getscriptclosure\' must be an Instance.')
	return function() return debug.loadmodule(module) end
end

env.isscriptable = function(i, p)
	assert(typeof(i) == 'Instance', 'Argument #1 to \'isscriptable\' must be an Instance, got ' .. typeof(i))
	local s,_ = pcall(function()
		if i[p] then
			i[p] = i[p]
		end
	end)
	local tbl = scriptableTable[i]
	if s or (tbl and tbl.scriptable[p]) then
		return true
	else
		return false
	end
end

env.setscriptable = function(i, p, bool)
	assert(typeof(i) == 'Instance', 'Argument #1 to \'setscriptable\' must be an Instance, got ' .. typeof(i))
	local scriptable = env.isscriptable(i,p)
	scriptableTable[i] = {scriptable = {}}
	scriptableTable[i].scriptable[p] = bool
	return scriptable
end

--[[env.isscriptable = function(instance, prop)
	assert(typeof(instance) == 'Instance', 'Argument #1 to \'setscriptable\' must be an Instance, got ' .. typeof(instance))
	return select(1, pcall(function()
		return instance[prop]
	end))
end]]

local function applyReadonlyMeta(tbl)
	local current = getmetatable(tbl) or {}
	if current.__readonly_applied then return end

	local proxy = {}

	for k, v in pairs(current) do
		proxy[k] = v
	end

	proxy.__readonly_applied = true

	proxy.__newindex = function()
		error("Attempt to modify a readonly table", 2)
	end

	setmetatable(tbl, proxy)
end

local function removeReadonlyMeta(tbl)
	local mt = getmetatable(tbl)
	if mt and mt.__readonly_applied then
		local cleaned = {}

		for k, v in pairs(mt) do
			if k ~= "__newindex" and k ~= "__readonly_applied" then
				cleaned[k] = v
			end
		end

		setmetatable(tbl, cleaned)
	end
end

env.setreadonly = function(tbl, bool)
	assert(type(tbl) == "table", "setreadonly: table expected")

	readonlyMap[tbl] = bool

	if bool then
		applyReadonlyMeta(tbl)
	else
		removeReadonlyMeta(tbl)
	end
end

env.isreadonly = function(tbl)
	assert(type(tbl) == "table", "isreadonly: table expected")
	return readonlyMap[tbl] == true
end

local safeTable = {}

for k, v in pairs(table) do
	safeTable[k] = v
end

function safeTable.freeze(tbl)
	env.setreadonly(tbl, true)
end

env.table = safeTable

env.getgc = function()
	local function CheckObject(obj, visited, results)
		if visited[obj] then return end
		visited[obj] = true

		if type(obj) == "table" or type(obj) == "function" then
			table.insert(results, obj)
			if type(obj) == "table" then
				for _, v in pairs(obj) do
					CheckObject(v, visited, results)
				end
			end
		end
	end

	local visited, results = {}, {}
	CheckObject(env.getgenv(), visited, results)

	return results
end

env.getscripthash = function(instance)
	if typeof(instance) ~= "Instance" or (not instance:IsA("LocalScript") and not instance:IsA("ModuleScript")) then
		error("expected LocalScript or ModuleScript as argument #1") 
	end
	return instance:GetHash()
end

env.getthreadidentity = function()
	return identity
end

env.setthreadidentity = function(id)
	assert(type(id) == "number" and id >= 0 and id <= 8, "invalid thread identity (0-8 allowed)")
	identity = id
end

env.printidentity = function()
	print("Current identity is", identity)
end

env.getidentity = env.getthreadidentity
env.setidentity = env.setthreadidentity
env.getthreadcontext = env.getthreadidentity
env.setthreadcontext = env.setthreadidentity

env.getsenv = function(script_instance)
	local scriptENV = getfenv(2)
	return setmetatable({
		script = script_instance,
	}, {
		__index = function(self, index)
			return scriptENV[index] or rawget(self, index)
		end,
		__newindex = function(self, index, value)
			xpcall(function()
				scriptENV[index] = value
			end, function()
				rawset(self, index, value)
			end)
		end,
	})
end

local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local WindowActive = true

UserInputService.WindowFocused:Connect(function()
	WindowActive = true
end)

UserInputService.WindowFocusReleased:Connect(function()
	WindowActive = false
end)

env.isrbxactive = function()
	return WindowActive
end

env.isgameactive = env.isrbxactive

env.mouse1click = function(x, y)
	x = x or 0
	y = y or 0

	VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, workspace.Parent, false)
	task.wait()
	VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, workspace.Parent, false)
end

env.mouse1press = function(x, y)
	x = x or 0
	y = y or 0

	VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, workspace.Parent, false)
end

env.mouse1release = function(x, y)
	x = x or 0
	y = y or 0

	VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, workspace.Parent, false)
end

env.mouse2click = function(x, y)
	x = x or 0
	y = y or 0

	VirtualInputManager:SendMouseButtonEvent(x, y, 1, true, workspace.Parent, false)
	task.wait()
	VirtualInputManager:SendMouseButtonEvent(x, y, 1, false, workspace.Parent, false)
end

env.mouse2press = function(x, y)
	x = x or 0
	y = y or 0

	VirtualInputManager:SendMouseButtonEvent(x, y, 1, true, workspace.Parent, false)
end

env.mouse2release = function(x, y)
	x = x or 0
	y = y or 0

	VirtualInputManager:SendMouseButtonEvent(x, y, 1, false, workspace.Parent, false)
end

env.mousemoveabs = function(x, y)
	x = x or 0
	y = y or 0

	VirtualInputManager:SendMouseMoveEvent(x, y, workspace.Parent)
end

env.mousemoverel = function(x, y)
	x = x or 0
	y = y or 0

	local vpSize = workspace.CurrentCamera.ViewportSize
	local x = vpSize.X * x
	local y = vpSize.Y * y

	VirtualInputManager:SendMouseMoveEvent(x, y, workspace.Parent)
end

env.mousescroll = function(x, y, z)
	VirtualInputManager:SendMouseWheelEvent(x or 0, y or 0, z or false, workspace.Parent)
end

local n,v = env.identifyexecutor()

local user_agent = n.."/"..v
function env.HttpGet(url, returnRaw)
	assert(type(url) == "string", "invalid argument #1 to 'HttpGet' (string expected, got " .. type(url) .. ") ", 2)
	local returnRaw = returnRaw or true

	local result = env.request({
		Url = url,
		Method = "GET",
		Headers = {
			["User-Agent"] = user_agent
		}
	})

	if returnRaw then
		return result.Body
	end

	return hs:JSONDecode(result.Body)
end
function env.HttpPost(url, body, contentType)
	assert(type(url) == "string", "invalid argument #1 to 'HttpPost' (string expected, got " .. type(url) .. ") ", 2)
	contentType = contentType or "application/json"
	return env.request({
		Url = url,
		Method = "POST",
		body = body,
		Headers = {
			["Content-Type"] = contentType
		}
	})
end
function env.GetObjects(asset)
	return {
		is:LoadLocalAsset(asset)
	}
end

local function GenerateError(object)
	local _, err = xpcall(function()
		object:__namecall()
	end, function()
		return debug.info(2, "f")
	end)
	return err
end

local FirstTest = GenerateError(OverlapParams.new())
local SecondTest = GenerateError(Color3.new())

local cachedmethods = {}
env.getnamecallmethod = function()
	local _, err = pcall(FirstTest)
	local method = if type(err) == "string" then err:match("^(.+) is not a valid member of %w+$") else nil
	if not method then
		_, err = pcall(SecondTest)
		method = if type(err) == "string" then err:match("^(.+) is not a valid member of %w+$") else nil
	end
	local fixerdata = newproxy(true)
	local fixermeta = getmetatable(fixerdata)
	fixermeta.__namecall = function()
		local _, err = pcall(FirstTest)
		local method = if type(err) == "string" then err:match("^(.+) is not a valid member of %w+$") else nil
		if not method then
			_, err = pcall(SecondTest)
			method = if type(err) == "string" then err:match("^(.+) is not a valid member of %w+$") else nil
		end
	end
	fixerdata:__namecall()
	if not method or method == "__namecall" then
		if cachedmethods[coroutine.running()] then
			return cachedmethods[coroutine.running()]
		end
		return nil
	end
	cachedmethods[coroutine.running()] = method
	return method
end

local proxyobject
local proxied = {}
local objects = {}

function ToProxy(...)
	local packed = table.pack(...)
	local function LookTable(t)
		for i, obj in ipairs(t) do
			if rtypeof(obj) == "Instance" then
				if objects[obj] then
					t[i] = objects[obj].proxy
				else
					t[i] = proxyobject(obj)
				end
			elseif typeof(obj) == "table" then
				LookTable(obj)
			else
				t[i] = obj
			end
		end
	end
	LookTable(packed)
	return table.unpack(packed, 1, packed.n)
end

function ToObject(...)
	local packed = table.pack(...)
	local function LookTable(t)
		for i, obj in ipairs(t) do
			if rtypeof(obj) == "userdata" then
				if proxied[obj] then
					t[i] = proxied[obj].object
				else
					t[i] = obj
				end
			elseif typeof(obj) == "table" then
				LookTable(obj)
			else
				t[i] = obj
			end
		end
	end
	LookTable(packed)
	return table.unpack(packed, 1, packed.n)
end

local function index(t, n)
	local data = proxied[t]
	local namecalls = data.namecalls
	local obj = data.object

	if namecalls[n] then
		return function(self, ...)
			return ToProxy(namecalls[n](...))
		end
	end

	local store = callbackStore[obj]
	if store and store[n] ~= nil then
		return store[n]
	end

	local v = obj[n]
	if typeof(v) == "function" then
		return function(self, ...)
			return ToProxy(v(ToObject(self, ...)))
		end
	else
		return ToProxy(v)
	end
end

local function namecall(t, ...)
	local data = proxied[t]
	local namecalls = data.namecalls
	local obj = data.object
	local method = env.getnamecallmethod()
	if namecalls[method] then
		return ToProxy(namecalls[method](...))
	end
	return ToProxy(obj[method](ToObject(t, ...)))
end

local function newindex(t, n, v)
	local data = proxied[t]
	local obj = data.object

	if n == "OnInvoke" then
		assert(type(v) == "function", "OnInvoke must be a function")
		callbackStore[obj] = callbackStore[obj] or {}
		callbackStore[obj][n] = v
		return
	end

	local val = table.pack(ToObject(v))
	obj[n] = table.unpack(val)
end

local function ptostring(t)
	return t.Name
end

local function isProxy(obj)
	return proxied[obj] ~= nil
end

function proxyobject(obj, namecalls)
	if objects[obj] then
		return objects[obj].proxy
	end
	namecalls = namecalls or {}
	local proxy = newproxy(true)
	local meta = getmetatable(proxy)
	meta.__index = function(...)return index(...)end
	meta.__namecall = function(...)return namecall(...)end
	meta.__newindex = function(...)return newindex(...)end
	meta.__tostring = function(...)return ptostring(...)end
	meta.__metatable = getmetatable(obj)

	local data = {}
	data.object = obj
	data.proxy = proxy
	data.meta = meta
	data.namecalls = namecalls

	proxied[proxy] = data
	objects[obj] = data
	return proxy
end

local pgame = proxyobject(game, {
	HttpGet = env.HttpGet,
	HttpGetAsync = env.HttpGet,
	HttpPost = env.HttpPost,
	HttpPostAsync = env.HttpPost,
	GetObjects = env.GetObjects
})
env.game = pgame
env.Game = pgame

local pworkspace = proxyobject(workspace)
env.workspace = pworkspace
env.Workspace = pworkspace

local pscript = proxyobject(script)
env.script = pscript

local hui = proxyobject(Instance.new("ScreenGui", cg))
hui.Name = GenerateName() --"hidden_ui_container"

for i, v in ipairs(game:GetDescendants()) do
	proxyobject(v)
end
game.DescendantAdded:Connect(proxyobject)

local rInstance = Instance
local fInstance = {}

fInstance.new = function(name, par)
	return proxyobject(rInstance.new(name, ToObject(par)))
end

fInstance.fromExisting = function(obj)
	return proxyobject(rInstance.fromExisting(obj))
end

local oldNew = fInstance.new
fInstance.new = function(newType, parent)
	assert(type(newType) == "string", "invalid argument #1 to 'Instance.new' (string expected, got " .. type(newType) .. ")", 2)

	local newInstance = oldNew(newType, parent)

	if newType == "BindableFunction" then
		callbackStore[newInstance] = {}
	end

	return newInstance
end

env.Instance = fInstance

env.getcallbackvalue = function(r, t)
	local real = ToObject(r)
	local store = callbackStore[real]
	if store then
		return store[t]
	end
end

env.getrawmetatable = function(obj)
	if isProxy(obj) then
		obj = proxied[obj].object
	end

	return raw_metas[obj]
end

env.setrawmetatable = function(obj, mt)
	if isProxy(obj) then
		obj = proxied[obj].object
	end

	assert(type(mt) == "table" or mt == nil, "bad argument #2 to 'setrawmetatable' (table or nil expected)")
	raw_metas[obj] = mt

	return obj
end

env.getinstances = function()
	local Instances = {}
	for i, v in pairs(objects) do
		table.insert(Instances, v.proxy)
	end
	return Instances
end

env.getnilinstances = function()
	local NilInstances = {}

	for _, obj in pairs(objects) do
		local proxy = obj.proxy
		if proxy and proxy.Parent == nil then
			NilInstances[#NilInstances + 1] = proxy
		end
	end

	return NilInstances
end

game.DescendantRemoving:Connect(function(des)
	task.delay(60, function()
		if cachedInstances[des] then
			cachedInstances[des] = nil
		end
	end)
	cachedInstances[des] = "r"
end)
game.DescendantAdded:Connect(function(des)
	cachedInstances[des] = true
end)

env.getloadedmodules = function()
	local LoadedModules = {}
	for _, obj in pairs(objects) do
		local inst = obj.proxy
		if inst:IsA("ModuleScript") then
			table.insert(LoadedModules, inst)
		end
	end
	return LoadedModules
end

env.getrunningscripts = function()
	local RunningScripts = {}
	for i, v in pairs(objects) do
		if v.proxy:IsA("ModuleScript") then
			table.insert(RunningScripts, v.proxy)
		end
	end
	return RunningScripts
end

env.getscripts = function()
	local Scripts = {}

	for _, v in pairs(objects) do
		local p = v.proxy

		local isLocal = p:IsA("LocalScript")
		local isModule = p:IsA("ModuleScript")
		local isClientScript = p:IsA("Script") and p.RunContext == Enum.RunContext.Client

		if (isLocal or isModule or isClientScript) and not p:IsDescendantOf(game.CoreGui) then
			table.insert(Scripts, p)
		end
	end

	return Scripts
end

env.typeof = function(obj)
	local typ = rtypeof(obj)
	if typ == "userdata" then
		if proxied[obj] then
			return "Instance"
		else
			return typ
		end
	else
		return typ
	end
end

env.gethui = function()
	return hui
end

local crypt = {}

crypt.base64encode = env.base64encode
crypt.base64_encode = env.base64encode
crypt.base64decode = env.base64decode
crypt.base64_decode = env.base64decode
crypt.base64 = base64

crypt.generatekey = function(len)
	local key = ''
	local x = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	for i = 1, len or 32 do local n = math.random(1, #x) key = key .. x:sub(n, n) end
	return base64.encode(key)
end

crypt.encrypt = function(a, b)
	local result = {}
	a = tostring(a) b = tostring(b)
	for i = 1, #a do
		local byte = string.byte(a, i)
		local keyByte = string.byte(b, (i - 1) % #b + 1)
		table.insert(result, string.char(bit32.bxor(byte, keyByte)))
	end
	return table.concat(result), b
end

crypt.generatebytes = function(len)
	return crypt.generatekey(len)
end

crypt.random = function(len)
	return crypt.generatekey(len)
end

crypt.decrypt = crypt.encrypt

local HashRes = env.request({
	Url = "https://raw.githubusercontent.com/ChimeraLle-Real/Fynex/refs/heads/main/hash",
	Method = "GET"
})

local HashLib = {}

if HashRes and HashRes.Body then
	local func, err = env.loadstring(HashRes.Body)
	if func then
		HashLib = func()
	else
		warn("HasbLib Failed To Load Error: " .. tostring(err))
	end
end

crypt.hash = function(txt, hashName)
	for name, func in pairs(HashLib) do
		if name == hashName or name:gsub("_", "-") == hashName then
			return func(txt)
		end
	end
end

env.crypt = crypt

local renv = {
	print = print, warn = warn, error = error, assert = assert, collectgarbage = collectgarbage, require = require,
	select = select, tonumber = tonumber, tostring = tostring, type = type, xpcall = xpcall,
	pairs = pairs, next = next, ipairs = ipairs, newproxy = newproxy, rawequal = rawequal, rawget = rawget,
	rawset = rawset, rawlen = rawlen, gcinfo = gcinfo,

	coroutine = {
		create = coroutine.create, resume = coroutine.resume, running = coroutine.running,
		status = coroutine.status, wrap = coroutine.wrap, yield = coroutine.yield,
	},

	bit32 = {
		arshift = bit32.arshift, band = bit32.band, bnot = bit32.bnot, bor = bit32.bor, btest = bit32.btest,
		extract = bit32.extract, lshift = bit32.lshift, replace = bit32.replace, rshift = bit32.rshift, xor = bit32.xor,
	},

	math = {
		abs = math.abs, acos = math.acos, asin = math.asin, atan = math.atan, atan2 = math.atan2, ceil = math.ceil,
		cos = math.cos, cosh = math.cosh, deg = math.deg, exp = math.exp, floor = math.floor, fmod = math.fmod,
		frexp = math.frexp, ldexp = math.ldexp, log = math.log, log10 = math.log10, max = math.max, min = math.min,
		modf = math.modf, pow = math.pow, rad = math.rad, random = math.random, randomseed = math.randomseed,
		sin = math.sin, sinh = math.sinh, sqrt = math.sqrt, tan = math.tan, tanh = math.tanh
	},

	string = {
		byte = string.byte, char = string.char, find = string.find, format = string.format, gmatch = string.gmatch,
		gsub = string.gsub, len = string.len, lower = string.lower, match = string.match, pack = string.pack,
		packsize = string.packsize, rep = string.rep, reverse = string.reverse, sub = string.sub,
		unpack = string.unpack, upper = string.upper,
	},

	table = {
		concat = table.concat, insert = table.insert, pack = table.pack, remove = table.remove, sort = table.sort,
		unpack = table.unpack,
	},

	utf8 = {
		char = utf8.char, charpattern = utf8.charpattern, codepoint = utf8.codepoint, codes = utf8.codes,
		len = utf8.len, nfdnormalize = utf8.nfdnormalize, nfcnormalize = utf8.nfcnormalize,
	},

	os = {
		clock = os.clock, date = os.date, difftime = os.difftime, time = os.time,
	},

	delay = delay, elapsedTime = elapsedTime, spawn = spawn, tick = tick, time = time, typeof = typeof,
	UserSettings = UserSettings, version = version, wait = wait, _VERSION = _VERSION,

	task = {
		defer = task.defer, delay = task.delay, spawn = task.spawn, wait = task.wait,
	},

	debug = debug,

	game = env.cloneref(game), workspace = env.cloneref(workspace), Game = env.cloneref(game), Workspace = env.cloneref(workspace),

	getmetatable = getmetatable, setmetatable = setmetatable
}

table.freeze(renv)

env.getrenv = function()
	return renv
end

env.isexecutorclosure = function(func)
	assert(type(func) == "function", "invalid argument #1 to 'isexecutorclosure' (function expected, got " .. type(func) .. ") ", 2)
	for _, genv in env.getgenv() do
		if genv == func then
			return true
		end
	end
	local function check(t)
		local isglobal = false
		for i, v in t do
			if type(v) == "table" then
				check(v)
			end
			if v == func then
				isglobal = true
			end
		end
		return isglobal
	end
	if check(env.getgenv().getrenv()) then
		return false
	end
	return true
end
env.isourclosure = env.isexecutorclosure

-- listener

task.spawn(function()
	while true do
		local res = nukedata("", "listen")
		if typeof(res) == "table" then
			Luma:Destroy()
			break
		end
		if res and #res > 1 then
			task.spawn(function()
				local loaded, ee = env.loadstring(res)
				if loaded then
					local suc,ress = pcall(loaded)
					if not suc then
						env.warn(ress)
						return ress
					end
					return ress
				else
					env.warn(ee)
				end
			end)
		end
		task.wait()
	end
end)

--[[local test = env.request({
	Url = "https://raw.githubusercontent.com/MyOwlhelp/tttttttttt/refs/heads/SynX/requiretest.luau",
	Method = "GET"
})

if test then
    print("Status:", test.StatusCode)
    print("Msg:", test.StatusMessage)
    print("Body Length:", #tojumptostring(test.Body or ""))
    print("Body Content:", test.Body)
end

if test and test.Body and test.Body:gsub("^%s*(.-)%s*$", "%1") == "test" then
	doInfo("Testing Request: Success")
else
	doInfo("Testing Request: Failed")
end]]

--[[local DecompileYe = env.request({
	Url = "https://raw.githubusercontent.com/verysigmapro/UniversalSynSaveInstance-With-Save-Terrain/refs/heads/main/konstantdecompiler.lua",
	Method = "GET"
})

if DecompileYe and DecompileYe.Body then
	local func, err = env.loadstring(DecompileYe.Body)
	if func then
		env.decompile = func().decompile
	else
		warn("Decompiler Failed To Load Error: " .. tostring(err))
	end
end]]

local DrawingRes = env.request({
	Url = "https://raw.githubusercontent.com/ChimeraLle-Real/Fynex/refs/heads/main/drawinglib",
	Method = "GET"
})

if DrawingRes and DrawingRes.Body then
	local func, err = env.loadstring(DrawingRes.Body)
	if func then
		local drawing = func()
		env.Drawing = drawing.Drawing
		for i, v in drawing.functions do
			env[i] = v
		end
	else
		warn("DrawingLib Failed To Load Error: " .. tostring(err))
	end
end

local Params = {
	RepoURL = "https://raw.githubusercontent.com/luau/SynSaveInstance/main/",
	SSI = "saveinstance",
}

local rawSaveInstance = env.request({
	Url = (Params.RepoURL .. Params.SSI .. ".luau"),
	Method = "GET"
}).Body

local synsaveinstance = env.loadstring(rawSaveInstance)()

env.saveinstance = function(options)
	return synsaveinstance(options or {})
end

doInfo("Luma Injected!")

game:GetService("RunService").RenderStepped:Connect(function(dt)
	if fpscap == math.huge then
		return
	end

	local targetDelta = 1 / fpscap
	clock = clock + dt

	if clock < targetDelta then
		task.wait(targetDelta - clock)
	end

	clock = 0
end)

return {Environment = env, HideTemp = function(...) end, GetIsModal = function(...) end, SetVisibility = function(...) end}
