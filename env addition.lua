--[[
env additions
by ,_M
]]

type _function = (...any) -> (...any)
local Registry = {}

getgenv().writetable = function(tal: table, idx: string|number|table, value: any)
	assert(typeof(tal) == "table", "invalid argument #1, table expected")

	local target = tal
	local path, key

	if typeof(idx) == "table" then
		path, key = {table.unpack(idx, 1, #idx - 1)}, idx[#idx]
		for _, k in ipairs(path) do
			if target[k] == nil then
				glooperror("invalid index '" .. idx .. "'")
			end
			target = target[k]
		end
	else
		key = idx
	end

	local hist = Registry[tal]
	if not hist then
		hist = {}
		Registry[tal] = hist
	end

	table.insert(hist, {
		target = target,
		key = key,
		old = target[key],
	})

	target[key] = value
end

getgenv().restoretable = function(tal: table)
	assert(typeof(tal) == "table", "invalid argument #1, table expected")

	local hist = Registry[tal]
	if not hist then return end

	for i = #hist, 1, -1 do
		local rec = hist[i]
		rec.target[rec.key] = rec.old
	end

	Registry[tal] = nil
end

getgenv().getscriptfromfunc = function(func: _function)
	assert(type(func) == "function", "invalid argument #1, function expected")
	assert(debug.getinfo(func).what ~= "C", "invalid argument #1, Can't to get script from C function")
	assert(not debug.getinfo(func).source:find("^=%a"), "invalid argument #1, Can't to get script from executor script function")
	local info = debug.getinfo(func)
	if not info or not info.source then return nil end
	local source = info.source
	if not source:find("^=") then return nil end
	source = source:sub(2)
	if not source:find("^%.") then
		local parts = string.split(source, ".")
		if #parts == 0 then return nil end
		local parent = game
		for i = 1, #parts do
			local child = parent:FindFirstChild(parts[i])
			if not child then return nil end
			parent = child
		end
		return parent:IsA("LuaSourceContainer") and parent or nil
	else
		local parts = string.split(source, ".")
		if #parts < 2 then return nil end
		local nl = getnilinstances()
		if not nl then return nil end
		for _, instance in pairs(nl) do
			if instance.Name == parts[2] then
				local current = instance
				local valid = true
				for i = 3, #parts do
					local child = current:FindFirstChild(parts[i])
					if not child then
						valid = false
						break
					end
					current = child
				end
				if valid and current:IsA("LuaSourceContainer") then
					return current
				end
			end
		end
		return nil
	end
end

getgenv().findfirstinstance = function(Class: ClassName, Name: string?, Parent: Instance): Instance?
	assert(Class ~= nil and typeof(Class) == "string", "invalid argument #1 to 'findfirstinstance' (string or ClassName expected)")
	assert(Name == nil or typeof(Name) == "string", "invalid argument #2 to 'findfirstinstance' (string or nil expected)")
	assert(Parent ~= nil and typeof(Parent) == "Instance", "invalid argument #3 to 'findfirstinstance' (Instance expected)")
	local func = clonefunction(Parent.GetDescendants)
	local s,instancelist = pcall(func, Parent)
	for _, insta in next, instancelist do
		if not Name then
			if insta.ClassName == Class then
				return insta
			end
		else
			if insta.ClassName == Class and insta.Name == Name then
				return insta
			end
		end
	end
	return nil
end
