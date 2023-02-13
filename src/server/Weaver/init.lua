local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local System = require(script.System)
local Symbols = require(script.Symbols)
local ModelBehavior = require(script.ModelBehavior)

local function createSystemRemoteProperty(initialValue: any)
	return { Symbols.CreateSystemRemoteProperty, initialValue }
end

local Weaver = {
	System = {
		new = System.new,
		Get = System.Get,
		RemoteProperty = createSystemRemoteProperty,
		RemoteSignal = Symbols.CreateSystemRemoteSignal,
	},
	SharedBehavior = {
		new = ModelBehavior.newBehavior,
	},
}

function Weaver.Init()
	if RunService:IsRunMode() then
		local weaverFolder = Instance.new("Folder")
		weaverFolder.Name = "$_Weaver"
		weaverFolder.Parent = ReplicatedStorage

		System._prepare()
		System._gather()
		System._sort()
		System._prepareNetworking()
		System._init()
		System._start()
		System._cleanup()

		ModelBehavior._prepare()
		ModelBehavior._gatherBehaviors()
		ModelBehavior._prepareNetworking()
		ModelBehavior._gatherModels()
		ModelBehavior._init()
	end
end

return Weaver
