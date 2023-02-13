-- function ComponentSystem._trackInstanceLifecycle(instance: Instance)
-- 	instanceId += 1
-- 	instanceLifecycleData[instance] = {
-- 		Id = instanceId,
-- 		AncestryChanged = instance.AncestryChanged:Connect(function(_, parent)
-- 			if parent and instance:IsDescendantOf(workspace) then
-- 				ComponentSystem._createComponentInstance(instance)
-- 			else
-- 				ComponentSystem._destroyComponentInstances(instance)
-- 			end
-- 		end),
-- 	}

-- 	if instance:IsDescendantOf(workspace) then
-- 		ComponentSystem._createComponentInstance(instance)
-- 	end

-- 	instanceIdMap[instanceId] = instanceLifecycleData[instance]
-- end

-- function ComponentSystem._stopTrackingInstanceLifecycle(instance: Instance)
-- 	local instanceData = instanceLifecycleData[instance]
-- 	if not instanceData then
-- 		warn('[ Weaver | Component ] Instance data not found for "' .. instance.Name .. '"')
-- 		return
-- 	end

-- 	instanceData.AncestryChanged:Disconnect()

-- 	instanceIdMap[instanceData.Id] = nil
-- 	instanceData[instance] = nil
-- end

-- function ComponentSystem._createComponentInstance(instance: Instance)
-- 	local instanceData = instanceLifecycleData[instance]
-- 	if not instanceData then
-- 		warn("[ Weaver | Component ] Tried to create component instance for instance whos lifecycle isn't tracked!")
-- 		return
-- 	end

-- 	local metadataFolder: Folder? = instance:FindFirstChild("$_Metadata")
-- 	if not metadataFolder then
-- 		warn("[ Weaver | Component ] Tried to create component instance for instance whos metadata doesn't exist!")
-- 		return
-- 	end

-- 	instanceData.Components = {}
-- 	metadataFolder:SetAttribute("ObjectId", instanceLifecycleData[instance].Id)
-- 	for _, child: Instance in metadataFolder:GetChildren() do
-- 		if componentRegistry[child.Name] then
-- 			local newComponentInstance = componentRegistry[child.Name]:_construct(instance)
-- 			newComponentInstance:_constructed()
-- 			table.insert(instanceData.Components, newComponentInstance)
-- 		end
-- 	end
-- end

-- function ComponentSystem._destroyComponentInstances(instance: Instance)
-- 	local instanceData = instanceLifecycleData[instance]
-- 	if not instanceData then
-- 		warn("[ Weaver | Component ] Tried to destroy component instance for instance whos lifecycle isn't tracked!")
-- 		return
-- 	end

-- 	for _, componentInstance in instanceData.Components do
-- 		componentInstance:_destroy()
-- 	end
-- 	instanceData.Components = nil
-- end
