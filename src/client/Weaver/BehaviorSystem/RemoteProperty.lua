local Libraries: Folder = script.Parent.Parent.Libraries

local Signal = require(Libraries:FindFirstChild("Signal"))
local Promise = require(Libraries:FindFirstChild("Promise"))

local RemoteProperty = {}
RemoteProperty.__index = RemoteProperty

function RemoteProperty.new(remoteEvent: RemoteEvent, instance: Instance)
	local newRemoteProperty = setmetatable({
		_value = nil,
		_initialized = false,
		_remoteEvent = remoteEvent,
		_instance = instance,

		Changed = Signal.new(),
	}, RemoteProperty)
	newRemoteProperty._onInitializedPromise = newRemoteProperty:OnReady():andThen(function()
		newRemoteProperty._onInitializedPromise = nil
		newRemoteProperty.Changed:Fire(newRemoteProperty._value)
		newRemoteProperty._remoteConnection = remoteEvent.OnClientEvent:Connect(function(inst: Instance, newValue: any)
			if inst ~= newRemoteProperty._instance or newValue == newRemoteProperty._value then
				return
			end

			newRemoteProperty._value = newValue
			newRemoteProperty.Changed:Fire(newValue)
		end)
	end)

	remoteEvent:FireServer(instance)
	return newRemoteProperty
end

function RemoteProperty:OnReady(): typeof(Promise)
	if self._initialized then
		return Promise.resolve(self._value)
	end

	return Promise.new(function(resolve, _, onCancel)
		local connection

		connection = self._remoteEvent.OnClientEvent:Connect(function(instance: Instance, newValue: any)
			if instance ~= self._instance then
				return
			end

			connection:Disconnect()
			self._value = newValue
			self._initialized = true
			resolve(newValue)
		end)

		onCancel(function()
			connection:Disconnect()
		end)

		return true
	end):andThen(function()
		return self._value
	end)
end

function RemoteProperty:IsReady(): boolean
	return self._initialized
end

function RemoteProperty:Get(): any
	return self._value
end

function RemoteProperty:Observe(observer: (any) -> ())
	if self._initialized then
		task.defer(observer, self._value)
	end
	return self.Changed:Connect(observer)
end

function RemoteProperty:Subscribe(subscriber: (any) -> ())
	return self.Changed:Connect(subscriber)
end

function RemoteProperty:Destroy()
	if self._onInitializedPromise then
		self._onInitializedPromise:cancel()
	end

	if self._remoteConnection then
		self._remoteConnection:Disconnect()
	end

	self.Changed:Destroy()
end

function RemoteProperty:__tostring()
	return "RemoteProperty<" .. self._instance.Name .. " / " .. tostring(self._value) .. ">"
end

return RemoteProperty
