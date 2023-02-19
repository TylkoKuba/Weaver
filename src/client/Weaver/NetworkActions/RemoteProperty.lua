local Libraries: Folder = script.Parent.Parent.Libraries

local Signal = require(Libraries:FindFirstChild("Signal"))
local Promise = require(Libraries:FindFirstChild("Promise"))

local RemoteProperty = {}
RemoteProperty.__index = RemoteProperty

function RemoteProperty.new(remoteEvent: RemoteEvent)
	local newRemoteProperty = setmetatable({
		_value = nil,
		_initialized = false,
		_remoteEvent = remoteEvent,

		Changed = Signal.new(),
	}, RemoteProperty)
	newRemoteProperty._onInitializedPromise = newRemoteProperty:OnReady():andThen(function()
		newRemoteProperty._onInitializedPromise = nil
		newRemoteProperty.Changed:Fire(newRemoteProperty._value)
		newRemoteProperty._remoteConnection = remoteEvent.OnClientEvent:Connect(function(newValue: any)
			if newValue == newRemoteProperty._value then
				return
			end

			newRemoteProperty._value = newValue
			newRemoteProperty.Changed:Fire(newValue)
		end)
	end)

	remoteEvent:FireServer()
	return newRemoteProperty
end

function RemoteProperty:OnReady(): typeof(Promise)
	if self._initialized then
		return Promise.resolve(self._value)
	end
	return Promise.fromEvent(self._remoteEvent.OnClientEvent, function(value: any)
		self._value = value
		self._initialized = true
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
	self._remoteEvent:Destroy()

	if self._onInitializedPromise then
		self._onInitializedPromise:cancel()
	end

	if self._remoteConnection then
		self._remoteConnection:Disconnect()
	end

	self.Changed:Destroy()
end

return RemoteProperty
