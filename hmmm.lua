-- // cool helicopter model converted with mokiros m2s

local ht

do
	local function Decode(str)
		local StringLength = #str

		do
			local decoder = {}
			for b64code, char in pairs(('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/='):split('')) do
				decoder[char:byte()] = b64code-1
			end
			local n = StringLength
			local t,k = table.create(math.floor(n/4)+1),1
			local padding = str:sub(-2) == '==' and 2 or str:sub(-1) == '=' and 1 or 0
			for i = 1, padding > 0 and n-4 or n, 4 do
				local a, b, c, d = str:byte(i,i+3)
				local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40 + decoder[d]
				t[k] = string.char(bit32.extract(v,16,8),bit32.extract(v,8,8),bit32.extract(v,0,8))
				k = k + 1
			end
			if padding == 1 then
				local a, b, c = str:byte(n-3,n-1)
				local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40
				t[k] = string.char(bit32.extract(v,16,8),bit32.extract(v,8,8))
			elseif padding == 2 then
				local a, b = str:byte(n-3,n-2)
				local v = decoder[a]*0x40000 + decoder[b]*0x1000
				t[k] = string.char(bit32.extract(v,16,8))
			end
			str = table.concat(t)
			print(str)
		end

		local Position = 1
		local function Parse(fmt)
			local Values = {string.unpack(fmt,str,Position)}
			Position = table.remove(Values)
			return table.unpack(Values)
		end

		local Settings = Parse('B')
		local Flags = Parse('B')
		Flags = {
			bit32.extract(Flags, 6, 2) + 1,
			bit32.extract(Flags, 4, 2) + 1,
			bit32.extract(Flags, 2, 2) + 1,
			bit32.extract(Flags, 0, 2) + 1,
			bit32.band(Settings, 0b1) > 0
		}

		local ValueFMT = ('I'..Flags[1])
		local InstanceFMT = ('I'..Flags[2])
		local ConnectionFMT = ('I'..Flags[3])
		local PropertyLengthFMT = ('I'..Flags[4])

		local ValuesLength = Parse(ValueFMT)
		local Values = table.create(ValuesLength)
		local CFrameIndexes = {}

		local ValueDecoders = {
			--!!Start
			[1] = function(Modifier)
				return Parse('s'..Modifier)
			end,
			--!!Split
			[2] = function(Modifier)
				return Modifier ~= 0
			end,
			--!!Split
			[3] = function()
				return Parse('d')
			end,
			--!!Split
			[4] = function(_,Index)
				table.insert(CFrameIndexes,{Index,Parse(('I'..Flags[1]):rep(3))})
			end,
			--!!Split
			[5] = {CFrame.new,Flags[5] and 'dddddddddddd' or 'ffffffffffff'},
			--!!Split
			[6] = {Color3.fromRGB,'BBB'},
			--!!Split
			[7] = {BrickColor.new,'I2'},
			--!!Split
			[8] = function(Modifier)
				local len = Parse('I'..Modifier)
				local kpts = table.create(len)
				for i = 1,len do
					kpts[i] = ColorSequenceKeypoint.new(Parse('f'),Color3.fromRGB(Parse('BBB')))
				end
				return ColorSequence.new(kpts)
			end,
			--!!Split
			[9] = function(Modifier)
				local len = Parse('I'..Modifier)
				local kpts = table.create(len)
				for i = 1,len do
					kpts[i] = NumberSequenceKeypoint.new(Parse(Flags[5] and 'ddd' or 'fff'))
				end
				return NumberSequence.new(kpts)
			end,
			--!!Split
			[10] = {Vector3.new,Flags[5] and 'ddd' or 'fff'},
			--!!Split
			[11] = {Vector2.new,Flags[5] and 'dd' or 'ff'},
			--!!Split
			[12] = {UDim2.new,Flags[5] and 'di2di2' or 'fi2fi2'},
			--!!Split
			[13] = {Rect.new,Flags[5] and 'dddd' or 'ffff'},
			--!!Split
			[14] = function()
				local flags = Parse('B')
				local ids = {"Top","Bottom","Left","Right","Front","Back"}
				local t = {}
				for i = 0,5 do
					if bit32.extract(flags,i,1)==1 then
						table.insert(t,Enum.NormalId[ids[i+1]])
					end
				end
				return Axes.new(unpack(t))
			end,
			--!!Split
			[15] = function()
				local flags = Parse('B')
				local ids = {"Top","Bottom","Left","Right","Front","Back"}
				local t = {}
				for i = 0,5 do
					if bit32.extract(flags,i,1)==1 then
						table.insert(t,Enum.NormalId[ids[i+1]])
					end
				end
				return Faces.new(unpack(t))
			end,
			--!!Split
			[16] = {PhysicalProperties.new,Flags[5] and 'ddddd' or 'fffff'},
			--!!Split
			[17] = {NumberRange.new,Flags[5] and 'dd' or 'ff'},
			--!!Split
			[18] = {UDim.new,Flags[5] and 'di2' or 'fi2'},
			--!!Split
			[19] = function()
				return Ray.new(Vector3.new(Parse(Flags[5] and 'ddd' or 'fff')),Vector3.new(Parse(Flags[5] and 'ddd' or 'fff')))
			end
			--!!End
		}

		for i = 1,ValuesLength do
			local TypeAndModifier = Parse('B')
			local Type = bit32.band(TypeAndModifier,0b11111)
			local Modifier = (TypeAndModifier - Type) / 0b100000
			local Decoder = ValueDecoders[Type]
			if type(Decoder)=='function' then
				Values[i] = Decoder(Modifier,i)
			else
				Values[i] = Decoder[1](Parse(Decoder[2]))
			end
		end

		for i,t in pairs(CFrameIndexes) do
			Values[t[1]] = CFrame.fromMatrix(Values[t[2]],Values[t[3]],Values[t[4]])
		end

		local InstancesLength = Parse(InstanceFMT)
		local Instances = {}
		local NoParent = {}

		for i = 1,InstancesLength do
			local ClassName = Values[Parse(ValueFMT)]
			local obj
			local MeshPartMesh,MeshPartScale
			if ClassName == "UnionOperation" then
				obj = DecodeUnion(Values,Flags,Parse)
				obj.UsePartColor = true
			elseif ClassName:find("Script") then
				obj = Instance.new("Folder")
				Script(obj,ClassName=='ModuleScript')
			elseif ClassName == "MeshPart" then
				obj = Instance.new("Part")
				MeshPartMesh = Instance.new("SpecialMesh")
				MeshPartMesh.MeshType = Enum.MeshType.FileMesh
				MeshPartMesh.Parent = obj
			else
				obj = Instance.new(ClassName)
			end
			local Parent = Instances[Parse(InstanceFMT)]
			local PropertiesLength = Parse(PropertyLengthFMT)
			local AttributesLength = Parse(PropertyLengthFMT)
			Instances[i] = obj
			for i = 1,PropertiesLength do
				local Prop,Value = Values[Parse(ValueFMT)],Values[Parse(ValueFMT)]

				-- ok this looks awful
				if MeshPartMesh then
					if Prop == "MeshId" then
						MeshPartMesh.MeshId = Value
						continue
					elseif Prop == "TextureID" then
						MeshPartMesh.TextureId = Value
						continue
					elseif Prop == "Size" then
						if not MeshPartScale then
							MeshPartScale = Value
						else
							MeshPartMesh.Scale = Value / MeshPartScale
						end
					elseif Prop == "MeshSize" then
						if not MeshPartScale then
							MeshPartScale = Value
							MeshPartMesh.Scale = obj.Size / Value
						else
							MeshPartMesh.Scale = MeshPartScale / Value
						end
						continue
					end
				end

				obj[Prop] = Value
			end
			if MeshPartMesh then

				MeshPartMesh.Scale *= Vector3.new(-1, 1, 1)

				if MeshPartMesh.MeshId=='' then
					if MeshPartMesh.TextureId=='' then
						MeshPartMesh.TextureId = 'rbxasset://textures/meshPartFallback.png'
					end
					MeshPartMesh.Scale = obj.Size
				end
			end
			for i = 1,AttributesLength do
				obj:SetAttribute(Values[Parse(ValueFMT)],Values[Parse(ValueFMT)])
			end
			if not Parent then
				table.insert(NoParent,obj)
			else
				obj.Parent = Parent
			end
		end

		local ConnectionsLength = Parse(ConnectionFMT)
		for i = 1,ConnectionsLength do
			local a,b,c = Parse(InstanceFMT),Parse(ValueFMT),Parse(InstanceFMT)
			Instances[a][Values[b]] = Instances[c]
		end

		return NoParent
	end


	local Objects = Decode('AACKIQVNb2RlbCEETmFtZSEHQ2hhcmxlcyELUHJpbWFyeVBhcnQhCE1lc2hQYXJ0IQpQcm9wZWxsZXIxIQhBbmNob3JlZCIhFkFzc2VtYmx5TGluZWFyVmVsb2NpdHkKAAAAAAmeXsIAAAAAIQZDRnJhbWUEFXl6IRBDb2xsaXNpb25Hcm91cElkAwAAAAAAABBAIQhN'
		..'YXNzbGVzcyEITWF0ZXJpYWwDAAAAAACAlEAhC09yaWVudGF0aW9uCgAAAAC4HmlCAAAAACEIUG9zaXRpb24KAAAkPEAh0EAAo+XAIQhSb3RhdGlvbiEEU2l6ZQp1lwBCoIq+PXeXAEIhBk1lc2hJZCEXcmJ4YXNzZXRpZDovLzc0MjQ3ODQwNjYhCE1lc2hTaXplChza'
		..'m0RA72ZAHdqbRCEJVGV4dHVyZUlEIRdyYnhhc3NldGlkOi8vNzQyNDc4NDEzMSEKQXR0YWNobWVudCEGQ2VudGVyIQVXaW5nMQQje3oKAAAAAAAAAAAAAIBBIQVXaW5nMgQme3oKAAAAAAAAAAAAAIDBIQVXaW5nNAQqfHoKAAAAAAAAtEIAAAAACgAAgMEAAAAAAAAA'
		..'ACEFV2luZzMELXx6CgAAgEEAAAAAAAAAACEFVHJhaWwhC0hvbGRlclRyYWlsIQtBdHRhY2htZW50MCELQXR0YWNobWVudDEhBUNvbG9yKAIAAAAAGio0AACAPxoqNCEITGlmZXRpbWUDAAAAoJmZmT8hDkxpZ2h0SW5mbHVlbmNlAwAAAAAAAPA/IQlNaW5MZW5ndGgD'
		..'AAAAAAAAAAAhDFRyYW5zcGFyZW5jeSkCAAAAAAAAQD8AAAAAAACAPwAAgD8AAAAAIQlCYWNrV2hlZWwEQHt6IQpDYW5Db2xsaWRlAgoAACg7ZIXWwICdZEEK1bogP9+ZV0Ah6JZAIRdyYnhhc3NldGlkOi8vNzQyNDc4NDMxMgqgzcJBPKcCQ9DlNkMhF3JieGFzc2V0'
		..'aWQ6Ly83NDI0Nzg0MzM3IQpQcm9wZWxsZXIyBEh7fQq4HmlCAAAAAAAAAAAKADA1P8AWuEC/NbdBCo2MXT2MKwRBI5feQCEXcmJ4YXNzZXRpZDovLzc0MjQ3ODM5NDkKAEIGQGAwoEOK44ZDIRdyYnhhc3NldGlkOi8vNzQyNDc4Mzk3NwROe3oKAAAAAAAAQL8AAAAA'
		..'BFF7fgoAALRCAAAAAAAAAAAKAAAAABAAhMAAAGBABFN7fgoAAAAAEACEwAAAYMAEVXt+CgAAAADw/4NAAAAAACEESHVsbArfXfBAIHRlQbWSQ0IhF3JieGFzc2V0aWQ6Ly83NDI0NzgzNzYyCkapkUNADAtEbAjtRCEXcmJ4YXNzZXRpZDovLzc0MjQ3ODM4NTIhBFdl'
		..'bGQhEUZyb250IFdoZWVsIFJpZ2h0IQJDMAR/e3ohBVBhcnQwIQVQYXJ0MSEKQmFjayBXaGVlbASAe3ohEEZyb250IFdoZWVsIExlZnQEgXt6IQdNb3RvcjZEBIJ7gyECQzEEToSFBIaHegSIiYohDkZyb250V2hlZWxMZWZ0BG17egoA1jbA5BH1wAB2eMEKzp2jP8P2'
		..'n0DOHeVAIRdyYnhhc3NldGlkOi8vNzQyNDc4NDM3OQpATUZC9N9BQ/bXikMhF3JieGFzc2V0aWQ6Ly83NDI0Nzg0NDA0IQ9Gcm9udFdoZWVsUmlnaHQEdHt6CgD+MEDkEfXAAHZ4wQqR6po/w/afQM4d5UAhF3JieGFzc2V0aWQ6Ly83NDI0Nzg0MjE5CtzBO0L030FD'
		..'9teKQyEXcmJ4YXNzZXRpZDovLzc0MjQ3ODQyNTIKbp0GPwAAAADbv1m/CgAAAAAAAIA/AAAAAAoAAIA/AAAAAAAAAAAKAAAAAAAAAAAAAIC/CgAAAABunQY/279ZPwoAAAAAAAAAAAAAgD8KAP4wQOAR9cAAdnjBCgAAKDtohdbAgJ1kQQoA1jbA4BH1wAB2eMEKADA1'
		..'P/B3q0BAG7JBCgAAAACbml8/HEz5PgoAAIA/AAAAAAAAAIAKAAAAgJuaXz8cTPm+CgAAJDwwIdBAAKPlwAqbml8/AAAAABxM+b4KAAAAAAAAAAAAAAAACpuaXz8AAAAAHEz5PgoAAACAAACAPwAAAAAcAQABAAIDBQEOAAIGBwgJCgsMDQ4PCBAREhMUFRYTFxgZGhsc'
		..'HR4fAgEAAiAfAgMAAiELIhQjHwIDAAIkCyUUJh8CBAACJwsoEikUKh8CBAACKwssEikULS4CBgACLzIzNDU2Nzg5OjsuAgYAAi8yMzQ1Njc4OTo7LgIGAAIvMjM0NTY3ODk6Oy4CBgACLzIzNDU2Nzg5OjsFAQ0AAjwHCAkKCz0+Pw0ODwgQERRAF0EZQhtDHUQFAQ4A'
		..'AkUHCAkKC0YNDg8IEBESRxRIFkcXSRlKG0sdTB8NAwACIAtNFE4fDQQAAiELTxJQFFEfDQQAAiQLUhJQFFMfDQQAAisLVBJQFFUuDQYAAi8yMzQ1Njc4OTo7Lg0GAAIvMjM0NTY3ODk6Oy4NBgACLzIzNDU2Nzg5OjsFAQkAAlYHCAkKDQ4QERdXGVgbWR1aWxUCAAJc'
		..'XV5bFQIAAmFdYlsVAgACY11kZRUDAAJFXWZnaGUVAwACBl1pZ2oFAQ0AAmsHCAkKC2w+Pw0ODwgQERRtF24ZbxtwHXEFAQ0AAnIHCAkKC3M+Pw0ODwgQERR0F3UZdht3HXgZAQQVCDADCDEECTADCTEFCjADCjEGCzADCzEHEjAOEjEPEzAOEzEQFDAOFDERFl8VFmAc'
		..'F18VF2AMGF8VGGAbGV8VGWANGl8VGmAC')
	ht = Objects[1]

	for _, v in pairs(ht:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Anchored = false
			-- // v.CanCollide = false

			if not v:FindFirstChild("HolderTrail") then
				local a1 = Instance.new("Attachment", v)
				a1.CFrame = CFrame.new(0, 0, -(v.Size.Z / 2))

				local a2 = Instance.new("Attachment", v)
				a2.CFrame = CFrame.new(0, 0, v.Size.Z / 2)

				local trl = ht.Propeller1.HolderTrail:Clone()
				trl.Attachment0 = a1
				trl.Attachment1 = a2

				trl.Parent = v
			end

			if v.Name == "Hull" then
				v.HolderTrail.Color = ColorSequence.new(BrickColor.new("Bright green").Color)
			end
		end
	end
end

local helidb = false
local radio = Instance.new("Tool", owner.Backpack)
radio.Name = "plan"
radio.ToolTip = "its a really great plan"
radio.CanBeDropped = false
radio.Grip = CFrame.new(-.329, -.576, .157, -.292, 0, -.956, .1, .995, -.031, .951, -.105, -.291)
local h = Instance.new("SpawnLocation", radio)
h.Enabled = false
h.Name = "Handle"
h.Parent = radio
h.Size = Vector3.new(.8, 2.3, .4)
local msh = Instance.new("SpecialMesh", h)
msh.Parent = h
msh.MeshId = "rbxassetid://88742707"
msh.TextureId = "rbxassetid://88742969"
msh.Scale = Vector3.new(1, 1, 1)

local function createheli()
	return ht:Clone()
end

local getmhit = Instance.new("RemoteFunction" , radio)

local nls = [[
    local rf = script.Parent
    function rf.OnClientInvoke(ef)
        if ef then
            ef.Transparency = 0
        end

        return game:GetService("Players").LocalPlayer:GetMouse().Hit
    end
]]

NLS(nls, getmhit)

local alright = Instance.new("Sound", h)
alright.SoundId = "rbxassetid://7478675352"
alright.Volume = 1.5
alright.EmitterSize = 25
local greatestplan = Instance.new("Sound", h)
greatestplan.SoundId = "rbxassetid://5633063536"
greatestplan.Volume = 1.5
greatestplan.EmitterSize = 25

local hullbounces = {
	7430228704,
	7430229337,
	7430237829
}

local proprattles = {
	7430240330,
	7430240942,
	7430246006
}

local helihit = Instance.new("Sound", game:GetService("VRService"))
helihit.Volume = 1.5
helihit.EmitterSize = 15
helihit.PlayOnRemove = true

local function chat(txt)
	coroutine.wrap(function()
		if h:FindFirstChild("RadioBBG") then
			h.RadioBBG:Destroy()
		end
		local bbg = Instance.new("BillboardGui", h)
		bbg.Size = UDim2.new(2, 0, 1, 0)
		bbg.StudsOffset = Vector3.new(0, 1, 0)
		bbg.Name = "RadioBBG"
		local txtbox = Instance.new("TextBox", bbg)
		txtbox.BackgroundTransparency = 1
		txtbox.BorderSizePixel = 0
		txtbox.Text = ""
		txtbox.Font = "Code"
		txtbox.TextWrapped = true
		txtbox.TextSize = 35
		txtbox.TextScaled = true
		txtbox.TextStrokeTransparency = 0
		txtbox.TextColor3 = Color3.new(1, 1, 1)
		txtbox.TextStrokeTransparency = Color3.new()
		txtbox.Size = UDim2.new(1, 0, .5,0)
		for i = 1, string.len(txt) do
			txtbox.Text = string.sub(txt, 1, i)
			task.wait(.05)
		end
	end)()
end

radio.Activated:Connect(function()
	if helidb == true then return end
	helidb = true
	local tl = 1
	local q = math.random(1, 2)

	local hit = getmhit:InvokeClient(owner)
	local effect = Instance.new("SpawnLocation", script)
	effect.Enabled = false
	effect.Name = "Effect"
	effect.Anchored = true
	effect.Transparency = 1
	effect.CanCollide = false
	effect.Size = Vector3.new()
	effect.BrickColor = BrickColor.new("Lime green")
	effect.CFrame = CFrame.new(hit.p) * CFrame.Angles(math.pi / 2, 0, 0)
	local msh = Instance.new("SpecialMesh", effect)
	msh.MeshId = "rbxassetid://3270017"
	msh.Scale = Vector3.new(40, 40, 1)

	getmhit:InvokeClient(owner, effect)

	pcall(function()
		if q == 1 then
			tl = 4
			alright:Play()
			chat("Alright, here I come!")
		elseif q == 2 then
			tl = 4
			greatestplan:Play()
			chat("I got the Perfect Plan.")
		end
	end)

	local heli = createheli()

	local hull = heli.Hull
	hull.RotVelocity = Vector3.new(math.random(-3, 3), math.random(-3, 3), math.random(-3, 3))

	heli:TranslateBy(hit.Position + Vector3.new(0, 2500, 0))
	heli.Parent = script

	for _, v in pairs(heli:GetDescendants()) do
		if v:IsA("BasePart") then
			v.Velocity = Vector3.new(0, -50, 0)
			v.CanCollide = false
		end
	end

	task.wait(tl / 2)

	alright.EmitterSize = 500
	greatestplan.EmitterSize = 500
	alright.Parent = hull
	greatestplan.Parent = hull

	if h:FindFirstChild("RadioBBG") then
		h.RadioBBG:Destroy()
	end

	radio.Parent = nil

	task.wait(tl / 2)

	coroutine.wrap(function()
		local gottem = {}
		while task.wait() do

			if hull.Velocity.Magnitude <= 5 then
				break
			end

			for i, hit in pairs(workspace:GetPartBoundsInBox(hull.CFrame, hull.Size * 1.5)) do
				if hit:FindFirstAncestorOfClass("Model") and hit:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid")  and hit:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid").Health ~= 0 and not table.find(gottem, hit:FindFirstAncestorOfClass("Model")) then
					local hum =  hit:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid")
					table.insert(gottem, hum.Parent)
					hum.BreakJointsOnDeath = false
					hum.PlatformStand = true
					hum.Health -= 50

					local tors = hum.Parent:FindFirstChild("HumanoidRootPart") or hum.Parent:FindFirstChild("Torso")
					if tors then
						tors.Velocity = (CFrame.new(tors.Position, hull.Position)).lookVector * math.random(75, 125)
						tors.RotVelocity = Vector3.new(math.random(-3, 3), math.random(-3, 3), math.random(-3, 3))
					end

					coroutine.wrap(function()
						task.wait(3)
						hum.PlatformStand = false
					end)()
				elseif not (hit:FindFirstAncestorOfClass("Model") and hit:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid")) and hit.Name ~= "Base" and hit:IsDescendantOf(script) == false then
					hit.Anchored = false
					hit.Velocity = Vector3.new(0, -(hit:GetMass() / 2), 0)
					hit:BreakJoints()
				end
			end

			if not heli or heli.Parent == nil then
				break
			end
		end
	end)()

	game:GetService("Debris"):AddItem(effect, 6)

	local db = false

	coroutine.wrap(function()
		local hn = ""
		local landed = false

		-- // check for base

		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {script}
		params.FilterType = Enum.RaycastFilterType.Blacklist

		local r = workspace:Raycast(hull.Position, hull.Position - Vector3.new(0, 5000, 0), params)

		if r and r.Instance then
			if r.Instance.Name == "Base" and r.Instance.Parent == workspace then
				for _, v in pairs(heli:GetDescendants()) do
					if v:IsA("BasePart") then
						v.CanCollide = true
					end
				end
			end
		end

		local cnt = hull.Touched:Connect(function(hit)
			if hit:IsDescendantOf(script) == false then
				landed = true
				hn = hit.Name
			end
		end)

		repeat
			task.wait()
		until landed == true

		cnt:Disconnect()

		for _, v in pairs(heli:GetDescendants()) do
			if v:IsA("BasePart") then
				v:BreakJoints()
				v.Velocity = Vector3.new(math.random(-50, 50), math.random(10, 50), math.random(-50, 50)) * 3
				v.RotVelocity = Vector3.new(math.random(-15, 15), math.random(-15, 15), math.random(-15, 15)) / 3
			end
		end

		coroutine.wrap(function()
			if hn ~= "Base" then
				task.wait(.5)
			end

			for _, v in pairs(heli:GetDescendants()) do
				if v:IsA("BasePart") then
					v.CanCollide = true
				end
			end
		end)()

		hull.Touched:Connect(function(hit)
			if hit:IsDescendantOf(script) == false and hull.Velocity.Magnitude >= 25 and db == false then
				db = true
				helihit.Parent = hull
				helihit.SoundId = "rbxassetid://" .. hullbounces[Random.new():NextInteger(1, table.getn(hullbounces))]
				helihit.Parent = nil
				task.wait(.5)
				db = false
			end
		end)

		local p1, p2 = heli.Propeller1, heli.Propeller2

		p1.Touched:Connect(function(hit)
			if hit:IsDescendantOf(script) == false and p1.Velocity.Magnitude >= 25 and db == false then
				db = true
				helihit.Parent = p1
				helihit.SoundId = "rbxassetid://" .. proprattles[Random.new():NextInteger(1, table.getn(proprattles))]
				helihit.Parent = nil
				task.wait(.5)
				db = false
			end
		end)

		p2.Touched:Connect(function(hit)
			if hit:IsDescendantOf(script) == false and p2.Velocity.Magnitude >= 25 and db == false then
				db = true
				helihit.Parent = p2
				helihit.SoundId = "rbxassetid://" .. proprattles[Random.new():NextInteger(1, table.getn(proprattles))]
				helihit.Parent = nil
				task.wait(.5)
				db = false
			end
		end)

		effect:Destroy()

		helihit.Parent = hull
		helihit.SoundId = "rbxassetid://7430219892"
		helihit.Parent = nil
	end)()

	game:GetService("Debris"):AddItem(heli, 10)
	task.wait(1)
	radio.Parent = owner.Character
	alright.EmitterSize = 25
	greatestplan.EmitterSize = 25
	alright.Parent = h
	greatestplan.Parent = h
	if getmhit:FindFirstChild("NLS") then getmhit.NLS:Destroy() end
	NLS(nls, getmhit)
	task.wait(.5)
	helidb = false
end)
