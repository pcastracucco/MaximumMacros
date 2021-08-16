SmartMacro = {}
if not _G["SmartMacroMasterFrame"] then
    SmartMacro.Frame = CreateFrame("Frame", "SmartMacroMasterFrame")
else
    SmartMacro.Frame = _G["SmartMacroMasterFrame"]
end
SmartMacro.Frame:RegisterEvent("PLAYER_ENTERING_WORLD")

SmartMacro.Macro = {}
SmartMacro.Macros = {}
SmartMacro.RegisteredActions = {}

SmartMacro.Setup = {}
SmartMacro.Setups = {}

SmartMacro.DefaultBody = "#showtooltip\n"
SmartMacro.LastUpdate = 0
SmartMacro.RateLimit = 1.5

function SmartMacro:FindMacro(name)
    local gmc = GetNumMacros()
    local index = -1
    for i=1, gmc do
        if name == GetMacroInfo(i) then
            index = i
            break
        end
    end
    return index
end

function SmartMacro:CreateMacro(name)
    local id = self:FindMacro(name)
    if id == -1 then
        id = CreateMacro(name, "INV_MISC_QUESTIONMARK", "#showtooltip\n", nil)
    end
end

function SmartMacro:Register(macro)
    for k,v in pairs(macro.EventActions) do
        if not self.RegisteredActions[k] then
            self.RegisteredActions[k] = {}
            self.Frame:RegisterEvent(k)
        end
        tinsert(self.RegisteredActions[k], macro.Update)
    end
end

function SmartMacro:Update(event, ...)
    if time() - self.LastUpdate <= self.RateLimit then
        return
    end
    self.LastUpdate = time()
    for _,f in pairs(self.RegisteredActions[event]) do
        f(event, ...)
    end
end

function SmartMacro.Setup.New(name, items)
    local setup = setmetatable({}, SmartMacro.Setup)
    setup.Name = name
    setup.EventActions = {}
    setup.Items = items
    setup.Loaded = false
    setup.Default = nil
    setup.Container = ContinuableContainer:Create()
    for i, item in pairs(items) do
        if item.IsDefault then
            setup.Default = item
        end
        setup.Container:AddContinuable(item)
    end
    setup.Container:ContinueOnLoad(function()
        setup.Loaded = true
        for id,item in pairs(setup.Items) do
            setup.Items[id].UseString = "/use " .. item:GetItemName() .. "\n"
        end
        setup.Build = function()
            local tempstore = -1
            local body = "\n"
            for _, item in pairs(setup.Items) do
                if item.itemID == 34062 and item:Condition() then
                    tempstore = 1
                end
            end
            if tempstore == 1 then
                body = "\n"
            else
                body = setup.Default.UseString
            end
            for _, item in pairs(setup.Items) do
                if not item.IsDefault and item:Condition() then
                    body = item.UseString .. body
                end
            end
            return body
        end
        setup.EventActions["UNIT_INVENTORY_CHANGED"] = function (unitId)
            if unitId == 'player' then
                return setup.Build()
            end
        end
        setup.EventActions["PLAYER_ENTERING_WORLD"] = setup.Build
        setup.EventActions["PLAYER_TARGET_CHANGED"] = setup.Build
        SmartMacro.Macros[setup.Name] = SmartMacro.Macro.New(setup.Name, setup.EventActions)
    end)
    return setup
end

function SmartMacro:BuildItem(id, isDefault, condition)
    local item = Item:CreateFromItemID(id)
    item.IsDefault = false
    if isDefault then
        item.IsDefault = isDefault
    end
    if condition then
        item.Condition = condition
    else
        item.Condition = function() return GetItemCount(item:GetItemID()) > 0 end
    end
    return item
end

function SmartMacro.Macro.New(name, eventActions)
    local self = setmetatable({}, SmartMacro.Macro)
    self.Name = name
    SmartMacro:CreateMacro(self.Name)
    self.EventActions = eventActions
    self.Update = function(event, ...)
        local newbody = self.EventActions[event](...)
        if newbody then
            EditMacro(self.Name, nil, nil, SmartMacro.DefaultBody .. newbody, 1, 1)
        end
    end
    SmartMacro:Register(self)
    return self
end

SmartMacro.Maps = {}
SmartMacro.Maps.NetherStorm = {[552]=true, [553]=true, [554]=true, [550]=true}
--SmartMacro.Maps.Terokkar = {[555]=true, [556]=true, [557]=true, [558]=true}


function SmartMacro:InZone(zones)
    local map,_ = select(8, GetInstanceInfo())
    return zones[map]
end

function SmartMacro.NetherstormCondition(item)
    return SmartMacro:InZone(SmartMacro.Maps.NetherStorm) and GetItemCount(item:GetItemID())
end

--function SmartMacro.TerokkarCondition(item)
--    return SmartMacro:InZone(SmartMacro.Maps.Terokkar) and GetItemCount(item:GetItemID())
--end

function SmartMacro:SetupMana()
    local name = "MaximumMP"
    local items = { SmartMacro:BuildItem(22832, true),
                    SmartMacro:BuildItem(33093),
                    SmartMacro:BuildItem(32948),
                    SmartMacro:BuildItem(32902, false, self.NetherstormCondition)}
    SmartMacro.Setups[name] = SmartMacro.Setup.New(name, items)
end

function SmartMacro:SetupHealth()
    local name = "MaximumHP"
    local items = { SmartMacro:BuildItem(22829, true),
                    SmartMacro:BuildItem(33092),
                    SmartMacro:BuildItem(32947),
                    SmartMacro:BuildItem(32905, false, self.NetherstormCondition)}
    self.Setups[name] = SmartMacro.Setup.New(name, items)
end

function SmartMacro:SetupWater()
    local name = "MaximumWater"
    local items = { SmartMacro:BuildItem(27860, true),
                    SmartMacro:BuildItem(22018, false),
                    SmartMacro:BuildItem(34062, false)}
    self.Setups[name] = SmartMacro.Setup.New(name, items)
end

SmartMacro.Frame:SetScript("OnEvent", function(self, event, ...)
    if InCombatLockdown() then
        return
    end
    if not SmartMacro.Setups["MaximumMP"] then
        SmartMacro:SetupMana()
    end
    if not SmartMacro.Setups["MaximumHP"] then
        SmartMacro:SetupHealth()
    end
    if not SmartMacro.Setups["MaximumWater"] then
        SmartMacro:SetupWater()
    end
    if SmartMacro.Setups["MaximumMP"].Loaded and SmartMacro.Setups["MaximumHP"].Loaded and SmartMacro.Setups["MaximumWater"].Loaded then
        SmartMacro.Frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        SmartMacro.Frame:SetScript("OnEvent", function (self, event, ...)
            if InCombatLockdown() then
                return
            end
            SmartMacro:Update(event, ...)
        end)
        SmartMacro:Update(event, ...)
    end
end)
