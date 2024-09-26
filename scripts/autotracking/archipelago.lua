-- this is an example/ default implementation for AP autotracking
-- it will use the mappings defined in item_mapping.lua and location_mapping.lua to track items and locations via thier ids
-- it will also load the AP slot data in the global SLOT_DATA, keep track of the current index of on_item messages in CUR_INDEX
-- addition it will keep track of what items are local items and which one are remote using the globals LOCAL_ITEMS and GLOBAL_ITEMS
-- this is useful since remote items will not reset but local items might
ScriptHost:LoadScript("scripts/autotracking/item_mapping.lua")
ScriptHost:LoadScript("scripts/autotracking/location_mapping.lua")
ScriptHost:LoadScript("scripts/autotracking/sectionID.lua")

CUR_INDEX = -1
SLOT_DATA = nil
LOCAL_ITEMS = {}
GLOBAL_ITEMS = {}

function onClear(slot_data)
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called onClear, slot_data:\n%s", dump_table(slot_data)))
    end
    SLOT_DATA = slot_data
    CUR_INDEX = -1
    
    -- reset locations
    for _, v in pairs(LOCATION_MAPPING) do
        if v[1] then
            if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
                print(string.format("onClear: clearing location %s", v[1]))
            end
            local obj = Tracker:FindObjectForCode(v[1])
            if obj then
                if v[1]:sub(1, 1) == "@" then
                    obj.AvailableChestCount = obj.ChestCount
                else
                    obj.Active = false
                end
            elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
                print(string.format("onClear: could not find object for code %s", v[1]))
            end
        end
    end
    -- reset items
    for _, v in pairs(ITEM_MAPPING) do
        if v[1] and v[2] then
            if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
                print(string.format("onClear: clearing item %s of type %s", v[1], v[2]))
            end
            local obj = Tracker:FindObjectForCode(v[1])
            if obj then
                if v[2] == "toggle" then
                    obj.Active = false
                elseif v[2] == "progressive" then
                    obj.CurrentStage = 0
                    obj.Active = false
                elseif v[2] == "consumable" then
                    if v[1] == "film" then
                        obj.AcquiredCount = 15
                    else
                        obj.AcquiredCount = 0
                    end
                elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
                    print(string.format("onClear: unknown item type %s for code %s", v[2], v[1]))
                end
            elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
                print(string.format("onClear: could not find object for code %s", v[1]))
            end
        end
    end

    print(dump_table(slot_data))
    
    local obj = Tracker:FindObjectForCode("normal")
    if slot_data["Normal_Pic_Checks_enabled"] == 1 then
        obj.Active = true
    else    
        obj.Active = false
    end

    local obj = Tracker:FindObjectForCode("wonderful")
    if slot_data["Wonderful_Pic_Checks_enabled"] == 1 then
        obj.Active = true
    else    
        obj.Active = false
    end

    LOCAL_ITEMS = {}
    GLOBAL_ITEMS = {}
    -- manually run snes interface functions after onClear in case we are already ingame
    if PopVersion < "0.20.1" or AutoTracker:GetConnectionState("SNES") == 3 then
        -- add snes interface functions here
    end
end

-- called when an item gets collected
function onItem(index, item_id, item_name, player_number)
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called onItem: %s, %s, %s, %s, %s", index, item_id, item_name, player_number, CUR_INDEX))
    end
    if index <= CUR_INDEX then
        return
    end
    local is_local = player_number == Archipelago.PlayerNumber
    CUR_INDEX = index;
    local v = ITEM_MAPPING[item_id]
    if not v then
        if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
            print(string.format("onItem: could not find item mapping for id %s", item_id))
        end
        return
    end
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("onItem: code: %s, type %s", v[1], v[2]))
    end
    if not v[1] then
        return
    end
    local obj = Tracker:FindObjectForCode(v[1])
    if obj then
        if v[2] == "toggle" then
            obj.Active = true
        elseif v[2] == "progressive" then
            if obj.Active then
                obj.CurrentStage = obj.CurrentStage + 1
            else
                if v[1] == "signpics" then
                    obj.CurrentStage = obj.CurrentStage + 1
                end
                obj.Active = true
            end
        elseif v[2] == "consumable" then
            obj.AcquiredCount = obj.AcquiredCount + obj.Increment
        elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
            print(string.format("onItem: unknown item type %s for code %s", v[2], v[1]))
        end
    elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("onItem: could not find object for code %s", v[1]))
    end
    -- track local items via snes interface
    if is_local then
        if LOCAL_ITEMS[v[1]] then
            LOCAL_ITEMS[v[1]] = LOCAL_ITEMS[v[1]] + 1
        else
            LOCAL_ITEMS[v[1]] = 1
        end
    else
        if GLOBAL_ITEMS[v[1]] then
            GLOBAL_ITEMS[v[1]] = GLOBAL_ITEMS[v[1]] + 1
        else
            GLOBAL_ITEMS[v[1]] = 1
        end
    end
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("local items: %s", dump_table(LOCAL_ITEMS)))
        print(string.format("global items: %s", dump_table(GLOBAL_ITEMS)))
    end
    if PopVersion < "0.20.1" or AutoTracker:GetConnectionState("SNES") == 3 then
        -- add snes interface functions here for local item tracking
    end
end

-- called when a location gets cleared
function onLocation(location_id, location_name)
    local location_array = LOCATION_MAPPING[location_id]
    if not location_array or not location_array[1] then
        print(string.format("onLocation: could not find location mapping for id %s", location_id))
        return
    end

    for _, location in pairs(location_array) do
        local obj = Tracker:FindObjectForCode(location)
        -- print(location, obj)
        if obj then
            if location:sub(1, 1) == "@" then
                obj.AvailableChestCount = obj.AvailableChestCount - 1
            else
                obj.Active = true
            end
        else
            print(string.format("onLocation: could not find object for code %s", location))
        end
    end
end

-- called when a locations is scouted
function onScout(location_id, location_name, item_id, item_name, item_player)
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called onScout: %s, %s, %s, %s, %s", location_id, location_name, item_id, item_name,
            item_player))
    end
    -- not implemented yet :(
end

-- called when a bounce message is received 
function onBounce(json)
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("called onBounce: %s", dump_table(json)))
    end
    -- your code goes here
end

magikarp = {
    "@Magikarp/Beach Picture",
    "@Magikarp/Tunnel Picture",
    "@Magikarp/Volcano Picture",
    "@Magikarp/River Picture",
    "@Magikarp/Cave Picture",
    "@Magikarp/Valley Picture"
}
magikarpWonderful = {
    "@Magikarp/Beach Wonderful Picture",
    "@Magikarp/Tunnel Wonderful Picture",
    "@Magikarp/Volcano Wonderful Picture",
    "@Magikarp/River Wonderful Picture",
    "@Magikarp/Cave Wonderful Picture",
    "@Magikarp/Valley Wonderful Picture"
}
pikachu = {
    "@Pikachu/Beach Picture",
    "@Pikachu/Tunnel Picture",
    "@Pikachu/River Picture",
    "@Pikachu/Cave Picture"
}
pikachuWonderful = {
    "@Pikachu/Beach Wonderful Picture",
    "@Pikachu/Tunnel Wonderful Picture",
    "@Pikachu/River Wonderful Picture",
    "@Pikachu/Cave Wonderful Picture"
}
bulbasaur = {
    "@Bulbasaur/River Picture",
    "@Bulbasaur/Cave Picture"
}
bulbasaurWonderful = {
    "@Bulbasaur/River Wonderful Picture",
    "@Bulbasaur/Cave Wonderful Picture"
}
zubat = {
    "@Zubat/Tunnel Picture",
    "@Zubat/Cave Picture"
}
zubatWonderful = {
    "@Zubat/Tunnel Wonderful Picture",
    "@Zubat/Cave Wonderful Picture"
}

ScriptHost:AddOnLocationSectionChangedHandler("manual", function(section)
    local sectionID = section.FullID
    if sectionID == "Mew/Picture (Game Completion)" and section.AvailableChestCount == 0 then
        local res = Archipelago:StatusUpdate(Archipelago.ClientStatus.GOAL)
        if res then
            print("Sent Victory")
            local obj = Tracker:FindObjectForCode("complete")
            obj.Active = true
        else
            print("Error sending Victory")
        end
    elseif sectionID == "Release/Release/Click Here To !release Game" and section.AvailableChestCount == 0 then
        for _, apID in pairs(sectionIDToAPID) do
            if apID ~= nil then
                local res = Archipelago:LocationChecks({apID})
                if res then
                    print("Sent " .. tostring(apID) .. " for " .. tostring(sectionID))
                else
                    print("Error sending " .. tostring(apID) .. " for " .. tostring(sectionID))
                end
            else
                print(tostring(sectionID) .. " is not an AP location")
            end
        end
    elseif (section.AvailableChestCount == 0) then  -- this only works for 1 chest per section
        -- AP location cleared
        local sectionID = section.FullID
        local apID = sectionIDToAPID[sectionID]
        if apID ~= nil then
            local res = Archipelago:LocationChecks({apID})
            if res then
                print("Sent " .. tostring(apID) .. " for " .. tostring(sectionID))
            else
                print("Error sending " .. tostring(apID) .. " for " .. tostring(sectionID))
            end
        else
            print(tostring(sectionID) .. " is not an AP location")
        end
    
        if sectionID == "Bulbasaur/River Picture" or sectionID == "Bulbasaur/Cave Picture" then
            for i, location in ipairs(bulbasaur) do
                local obj = Tracker:FindObjectForCode(location)
                if obj then
                    obj.AvailableChestCount = 0
                end
            end
        elseif sectionID == "Bulbasaur/River Wonderful Picture" or sectionID == "Bulbasaur/Cave Wonderful Picture" then
            for i, location in ipairs(bulbasaurWonderful) do
                local obj = Tracker:FindObjectForCode(location)
                if obj then
                    obj.AvailableChestCount = 0
                end
            end
        elseif sectionID == "Zubat/Tunnel Picture" or sectionID == "Zubat/Cave Picture" then
            for i, location in ipairs(zubat) do
                local obj = Tracker:FindObjectForCode(location)
                if obj then
                    obj.AvailableChestCount = 0
                end
            end
        elseif sectionID == "Zubat/Tunnel Wonderful Picture" or sectionID == "Zubat/Cave Wonderful Picture" then
            for i, location in ipairs(zubatWonderful) do
                local obj = Tracker:FindObjectForCode(location)
                if obj then
                    obj.AvailableChestCount = 0
                end
            end
        elseif sectionID == "Pikachu/Tunnel Picture" or sectionID == "Pikachu/Cave Picture" or sectionID == "Pikachu/Beach Picture" or sectionID == "Pikachu/River Picture" then
            for i, location in ipairs(pikachu) do
                local obj = Tracker:FindObjectForCode(location)
                if obj then
                    obj.AvailableChestCount = 0
                end
            end
        elseif sectionID == "Pikachu/Tunnel Wonderful Picture" or sectionID == "Pikachu/Cave Wonderful Picture" or sectionID == "Pikachu/Beach Wonderful Picture" or sectionID == "Pikachu/River Wonderful Picture" then
            for i, location in ipairs(pikachuWonderful) do
                local obj = Tracker:FindObjectForCode(location)
                if obj then
                    obj.AvailableChestCount = 0
                end
            end
        elseif sectionID == "Magikarp/Tunnel Picture" or sectionID == "Magikarp/Cave Picture" or sectionID == "Magikarp/Beach Picture" or sectionID == "Magikarp/River Picture" or sectionID == "Magikarp/Volcano Picture" or sectionID == "Magikarp/Valley Picture" then
            for i, location in ipairs(magikarp) do
                local obj = Tracker:FindObjectForCode(location)
                if obj then
                    obj.AvailableChestCount = 0
                end
            end
        elseif sectionID == "Magikarp/Tunnel Wonderful Picture" or sectionID == "Magikarp/Cave Wonderful Picture" or sectionID == "Magikarp/Beach Wonderful Picture" or sectionID == "Magikarp/River Wonderful Picture" or sectionID == "Magikarp/Volcano Wonderful Picture" or sectionID == "Magikarp/Valley Wonderful Picture" then
            for i, location in ipairs(magikarpWonderful) do
                local obj = Tracker:FindObjectForCode(location)
                if obj then
                    obj.AvailableChestCount = 0
                end
            end
        end
    end

end)

-- add AP callbacks
-- un-/comment as needed
Archipelago:AddClearHandler("clear handler", onClear)
Archipelago:AddItemHandler("item handler", onItem)
Archipelago:AddLocationHandler("location handler", onLocation)
-- Archipelago:AddScoutHandler("scout handler", onScout)
-- Archipelago:AddBouncedHandler("bounce handler", onBounce)
