local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local System = {}

local Symbols = require(script.Parent.Symbols)
local RemoteProperty = require(script.Parent.NetworkActions.RemoteProperty)

local ServerServices = {}

local systems = {}
local systemsOrder = {}
local initialized, started = false, false

local function assertService(service: string)
	if not ServerServices[service] then
		local serviceInstance: Folder? = ReplicatedStorage["$_Weaver"]["System"]:FindFirstChild(service)
		if not serviceInstance then
			error("[ Weaver | System ] System metadata not found! (" .. service .. ")")
		end

		ServerServices[service] = {}
		for _, instance: Instance in serviceInstance:GetChildren() do
			if not instance:IsA("RemoteEvent") and not instance:IsA("RemoteFunction") then
				continue
			end

			local networkActionType: string? = instance:GetAttribute("Type")
			if not networkActionType then
				continue
			end

			if networkActionType == "Signal" then
				ServerServices[service][instance.Name] = {
					["Connect"] = function(_, ...)
						(instance :: RemoteEvent).OnClientEvent:Connect(...)
					end,
					["Fire"] = function(_, ...)
						(instance :: RemoteEvent):FireServer(...)
					end,
				}
			elseif networkActionType == "Property" then
				ServerServices[service][instance.Name] = RemoteProperty.new(instance)
			elseif networkActionType == "Function" then
				ServerServices[service][instance.Name] = function(...)
					return (instance :: RemoteFunction):InvokeServer(...)
				end
			end
		end
	end

	return ServerServices[service]
end

function System.new(system: any)
	if initialized or started then
		error('[ Weaver | System ] Tried to create a system during runtime! "' .. system.Name .. '"')
	end

	if systems[system.Name] then
		error('[ Weaver | System ] Tried to create a system with the same name! "' .. system.Name .. '"')
	end

	system.Server = setmetatable({}, {
		__index = function(_, index)
			return assertService(system.Name)[index]
		end,
	})

	system[Symbols.System] = true
	return system
end

function System.Get(name: string)
	return systems[name]
end

function System._gather()
	local localPlayerScripts: PlayerScripts = Players.LocalPlayer.PlayerScripts

	local systemsFolder: Folder? = localPlayerScripts:WaitForChild("Systems")
	if not systemsFolder then
		return
	end

	for _, instance: Instance in systemsFolder:GetDescendants() do
		if not instance:IsA("ModuleScript") then
			continue
		end

		local success, systemData = pcall(require, instance)
		if success then
			local isWeaverSystem = systemData[Symbols.System] == true
			if isWeaverSystem then
				System._register(systemData)
			else
				warn(
					'[ Weaver | System ] A ModuleScript was found inside of Systems folder, please remove it to avoid any issues. ("'
						.. instance.Name
						.. '")'
				)
			end
		else
			error('[ Weaver | System ] The above system has issues. ("' .. instance.Name .. '")')
		end
	end
end

function System._sort()
	table.sort(systemsOrder, function(x, y)
		return x.Priority > y.Priority
	end)
end

function System._cleanup()
	systemsOrder = nil
end

function System._init()
	for _, systemData in systemsOrder do
		if typeof(systemData.System.Init) == "function" then
			systemData.System:Init()
		end
	end

	initialized = true
end

function System._start()
	for _, systemData in systemsOrder do
		if typeof(systemData.System.Start) == "function" then
			systemData.System:Start()
		end
	end

	started = true
end

function System._register(system: any)
	systems[system.Name] = system
	table.insert(systemsOrder, {
		System = system,
		Priority = system.Priority or 0,
	})
end

function System._waitForData()
	ReplicatedStorage:WaitForChild("$_Weaver"):WaitForChild("System")
end

return System
