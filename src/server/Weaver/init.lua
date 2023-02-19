local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local System = require(script.System)
local Symbols = require(script.Symbols)
local BehaviorSystem = require(script.BehaviorSystem)

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
	Behavior = {
		new = BehaviorSystem.newBehavior,
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

		BehaviorSystem._prepare()
		BehaviorSystem._gatherBehaviors()
		BehaviorSystem._prepareNetworking()
		BehaviorSystem._gatherModels()
		BehaviorSystem._init()
	end
end

return Weaver
