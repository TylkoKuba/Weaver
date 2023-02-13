local Players = game:GetService("Players")
local RemoteProperty = {}
RemoteProperty.__index = RemoteProperty

function RemoteProperty.new(remoteEvent: RemoteEvent, initialValue: any)
	local newRemoteProperty = setmetatable({
		_value = initialValue,
		_perPlayerValues = {},
		_remoteEvent = remoteEvent,
	}, RemoteProperty)

	newRemoteProperty._playerRemovingSignal = Players.PlayerRemoving:Connect(function(player: Player)
		newRemoteProperty._perPlayerValues[player] = nil
	end)
	newRemoteProperty._remoteConnection = remoteEvent.OnServerEvent:Connect(function(player: Player)
		local playerValue: any = newRemoteProperty._perPlayerValues[player]
		local value: any = playerValue ~= nil and playerValue or newRemoteProperty._value
		newRemoteProperty._remoteEvent:FireClient(player, value)
	end)
	return newRemoteProperty
end

function RemoteProperty:Get(): any
	return self._value
end

function RemoteProperty:GetFor(player: Player): any
	local playerValue: any = self._perPlayerValues[player]
	local value: any = playerValue ~= nil and playerValue or self._value
	return value
end

function RemoteProperty:Set(newValue: any)
	self._value = newValue
	table.clear(self._perPlayerValues)
	self._remoteEvent:FireAllClients(self.value)
end

function RemoteProperty:SetGlobal(newValue: any)
	self._value = newValue
	for _, player in Players:GetPlayers() do
		if self._perPlayerValues[player] == nil then
			self._remoteEvent:FireClient(player, self._value)
		end
	end
end

function RemoteProperty:SetFor(player: Player, newValue: any)
	if player.Parent then
		self._perPlayerValues[player] = newValue
		self._remoteEvent:FireClient(player, newValue)
	end
end

function RemoteProperty:SetForFilter(filter: (Player, any) -> boolean, newValue: any)
	for _, player in Players:GetPlayers() do
		if filter(player, newValue) then
			self:SetFor(player, newValue)
		end
	end
end

function RemoteProperty:SetForList(list: { Player }, newValue: any)
	for _, player in list do
		self:SetFor(player, newValue)
	end
end

function RemoteProperty:ClearFor(player: Player)
	if self._perPlayerValues[player] == nil then
		return
	end

	self._perPlayerValues[player] = nil
	self._remoteEvent:FireClient(player, self._value)
end

function RemoteProperty:ClearForFilter(filter: (Player) -> boolean)
	for _, player in Players:GetPlayers() do
		if filter(player) then
			self:ClearFor(player)
		end
	end
end

function RemoteProperty:ClearForList(list: { Player })
	for player, _ in list do
		self:ClearFor(player)
	end
end

function RemoteProperty:Destroy()
	self._remoteEvent:Destroy()
	self._playerRemovingSignal:Disconnect()
	self._remoteConnection:Disconnect()
end

return RemoteProperty
