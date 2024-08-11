Tracker:AddItems("items/items.json")
Tracker:AddLayouts("layouts/tracker.json")
Tracker:AddLayouts("layouts/broadcast.json")

if PopVersion and PopVersion >= "0.18.0" then
    ScriptHost:LoadScript("scripts/autotracking.lua")
  end  