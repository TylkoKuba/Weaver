local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local System = {}

local Symbols = require(script.Parent.Symbols)
local RemoteProperty = require(script.Parent.NetworkActions.RemoteProperty)

local systems = {}
local systemsOrder = {}
local systemFolder
local initialized, started = false, false

local function assertSystemFolder(systemName: string)
	local newSystemFolder = systemFolder:FindFirstChild(systemName)
	if newSystemFolder then
		return newSystemFolder
	end

	newSystemFolder = Instance.new("Folder")
	newSystemFolder.Name = systemName
	newSystemFolder.Parent = systemFolder

	return newSystemFolder
end

function System.new(system: any)
	local systemName: string = system.Name

	if initialized or started then
		error('[ Weaver | System ] Tried to create a system during runtime! "' .. systemName .. '"')
	end

	if systems[systemName] then
		error('[ Weaver | System ] Tried to create a system with the same name! "' .. systemName .. '"')
	end

	system[Symbols.System] = true
	return system
end

function System.Get(name: string)
	return systems[name]
end

function System._prepare()
	systemFolder = Instance.new("Folder")
	systemFolder.Name = "System"
	systemFolder.Parent = ReplicatedStorage["$_Weaver"]
end

function System._gather()
	local systemsFolder: Folder? = ServerScriptService:WaitForChild("Systems")
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
			end
		else
			error('[ Weaver | Core ] The above system has issues. ("' .. instance.Name .. '")')
		end
	end
end

function System._sort()
	table.sort(systemsOrder, function(x, y)
		return x.Priority > y.Priority
	end)
end

function System._prepareNetworking()
	for _, system in systemsOrder do
		local systemName: string = system.Name
		local sFolder = assertSystemFolder(systemName)
		if system.Client then
			for networkActionName, networkAction in system.Client do
				if networkAction == Symbols.CreateSystemRemoteSignal then
					local remoteSignalInstance: RemoteEvent = Instance.new("RemoteEvent")
					remoteSignalInstance:SetAttribute("Type", "Signal")
					remoteSignalInstance.Name = networkActionName
					remoteSignalInstance.Parent = sFolder
					system.Client[networkActionName] = {
						["Connect"] = function(_, ...)
							remoteSignalInstance.OnServerEvent:Connect(...)
						end,
						["Fire"] = function(_, ...)
							remoteSignalInstance:FireClient(...)
						end,
						["FireAll"] = function(_, ...)
							remoteSignalInstance:FireAllClients(...)
						end,
					}
				elseif typeof(networkAction) == "table" and networkAction[1] == Symbols.CreateSystemRemoteProperty then
					local remotePropertyInstance: RemoteEvent = Instance.new("RemoteEvent")
					remotePropertyInstance:SetAttribute("Type", "Property")
					remotePropertyInstance.Name = networkActionName
					remotePropertyInstance.Parent = sFolder
					system.Client[networkActionName] = RemoteProperty.new(remotePropertyInstance, networkAction[2])
				elseif typeof(networkAction) == "function" then
					local remoteFunctionInstance: RemoteFunction = Instance.new("RemoteFunction")
					remoteFunctionInstance:SetAttribute("Type", "Function")
					remoteFunctionInstance.Name = networkActionName
					remoteFunctionInstance.Parent = sFolder

					remoteFunctionInstance.OnServerInvoke = function(...)
						return system.Client[networkActionName](...)
					end
				end
			end
			system.Client.Server = system
		else
			system.Client = { Server = system }
		end
	end
end

function System._cleanup()
	systemsOrder = nil
end

function System._init()
	for _, systemData in systemsOrder do
		if typeof(systemData.Init) == "function" then
			systemData:Init()
		end
	end

	initialized = true
end

function System._start()
	for _, systemData in systemsOrder do
		if typeof(systemData.Start) == "function" then
			systemData:Start()
		end
	end

	started = true
end

function System._register(system: any)
	systems[system.Name] = system
	table.insert(systemsOrder, system)
end

return System
