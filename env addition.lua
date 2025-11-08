--[[
env additions
by ,_M

getfunc:
local function getfunc(name, hash)
	for i,v in pairs(getgc()) do
		if debug.info(v, "n") == name and getfunctionhash(v) == hash then
			return v
		end
	end
end
]]

type _function = (...any) -> (...any)
local Registry = {}
local function tabletocode(tal)
	local code = "{"
	for i,v in pairs(tal) do
		code ..= "[" .. datatocode(i) .. "] = " .. datatocode(v) .. ", "
	end
	code ..= "}"
	return code
end

local function functocode(func)
	local code = "getfunc(\"" .. debug.info(func, "n") .. "\", \"" .. getfunctionhash(func) .. "\")"
	return code
end

local function moretocode(v)
	local t = typeof(v)
	if v == true then return "true" end
	if v == nil then return "nil" end
	if v == false then return "false" end
	if type(v) == "number" then
		return tostring(v)
	end
	if type(v) == "string" then
		return "\"" .. v:gsub("\"", "\\\"") .. "\""
	end
	if t == "table" then
		return tabletocode(data)
	end
	if t == "function" then
		return functocode(data)
	end
	if t == "EnumItem" then
		return tostring(v)
	end
	if t == "Instance" then
		return v:GetFullName()
	end
	if t == "Vector2" then
		return string.format("Vector2.new(%s, %s)", v.X, v.Y)
	end
	if t == "Vector3" then
		return string.format("Vector3.new(%s, %s, %s)", v.X, v.Y, v.Z)
	end
	if t == "UDim" then
		return string.format("UDim.new(%s, %s)", v.Scale, v.Offset)
	end
	if t == "Font" then
		return string.format("Font.new(%q, %s, %s)", v.Family, toLiteral(v.Weight), toLiteral(v.Style))
	end
	if t == "UDim2" then
		return string.format("UDim2.new(%s, %s, %s, %s)", v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
	end
	if t == "NumberRange" then
		if v.Min == v.Max then
			return string.format("NumberRange.new(%s)", v.Min)
		else
			return string.format("NumberRange.new(%s, %s)", v.Min, v.Max)
		end
	end
	if t == "Color3" then
		return string.format("Color3.fromRGB(%s, %s, %s)", math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5))
	end
	if t == "CFrame" then
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = v:GetComponents()
		return string.format("CFrame.new(%s,%s,%s, %s,%s,%s, %s,%s,%s, %s,%s,%s)", x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	end
	if t == "BrickColor" then
		return string.format("BrickColor.new(%q)", v.Name)
	end
	if t == "ColorSequence" then
		local kps = v.Keypoints
		local tmp = table.create(# kps)
		for i, kp in ipairs(kps) do
			tmp[i] = string.format("ColorSequenceKeypoint.new(%s, %s)", kp.Time, toLiteral(kp.Value))
		end
		return "ColorSequence.new({" .. table.concat(tmp, ", ") .. "})"
	end
	if t == "NumberSequence" then
		local kps = v.Keypoints
		local tmp = table.create(# kps)
		for i, kp in ipairs(kps) do
			tmp[i] = string.format("NumberSequenceKeypoint.new(%s, %s, %s)", kp.Time, kp.Value, kp.Envelope)
		end
		return "NumberSequence.new({" .. table.concat(tmp, ", ") .. "})"
	end
	if t == "Rect" then
		return string.format("Rect.new(%s, %s, %s, %s)", v.Min.X, v.Min.Y, v.Max.X, v.Max.Y)
	end
	if t == "PhysicalProperties" then
		return string.format("PhysicalProperties.new(%s, %s, %s, %s, %s)", v.Density, v.Friction, v.Elasticity, v.FrictionWeight, v.ElasticityWeight)
	end
	return "-- 无法获取类型" .. t
end

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
	assert(debug.getinfo(func).source:sub(2):find("%."), "invalid argument #1, failed to get source")
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

--TODO: make better now just simple
getgenv().datatocode = function(data: any)
	local code = ""
	if data == true then code = "true" end
	if data == nil then code = "nil" end
	if data == false then code = "false" end
	if type(data) == "number" then
		code = tostring(data)
	end
	if type(data) == "string" then
		code = "\"" .. data:gsub("\"", "\\\"") .. "\""
	end
	local t = type(data)
	if t == "table" then
		code = tabletocode(data)
	elseif t == "function" then
		code = functocode(data)
	else
		code = moretocode(data)
	end
	return code
end
