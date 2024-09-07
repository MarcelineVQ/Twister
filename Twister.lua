-- Name: twisterFrame
-- License: LGPL v2.1

-- stop loading addon if no superwow
if not SetAutoloot then
  DEFAULT_CHAT_FRAME:AddMessage("[|cff36c948Twister|r requires |cffffd200SuperWoW|r to operate.")
  return
end

local DEBUG_MODE = false

local success = true
local failure = nil

local amcolor = {
  blue = format("|c%02X%02X%02X%02X", 1, 41,146,255),
  red = format("|c%02X%02X%02X%02X",1, 255, 0, 0),
  green = format("|c%02X%02X%02X%02X",1, 22, 255, 22),
  yellow = format("|c%02X%02X%02X%02X",1, 255, 255, 0),
  orange = format("|c%02X%02X%02X%02X",1, 255, 146, 24),
  red = format("|c%02X%02X%02X%02X",1, 255, 0, 0),
  gray = format("|c%02X%02X%02X%02X",1, 187, 187, 187),
  gold = format("|c%02X%02X%02X%02X",1, 255, 255, 154),
  blizzard = format("|c%02X%02X%02X%02X",1, 180,244,1),
}

local function colorize(msg,color)
  local c = color or ""
  return c..msg..FONT_COLOR_CODE_CLOSE
end

local function showOnOff(setting,on,off)
  on = on or "On"
  off = off or "Off"
  return setting and colorize(on,amcolor.blue) or colorize(off,amcolor.red)
end

local function amprint(msg)
  DEFAULT_CHAT_FRAME:AddMessage(msg)
end

local function debug_print(text)
    if DEBUG_MODE == true then DEFAULT_CHAT_FRAME:AddMessage(text) end
end

local function DisableFrame(frame)
  if frame then
      frame:EnableMouse(false)

      frame:SetScript("OnUpdate", nil)
      frame:SetScript("OnEvent", nil)

      frame:Hide()
  end
end

local function FindSpellIndexByName(spellName)
  local i = 1
  while true do
      local sName = GetSpellName(i, "spell")
      if not sName then
          break
      end
      if sName == spellName then
          return i
      end
      i = i + 1
  end
  return nil -- Return nil if the spell is not found
end

local wf_spell_index = FindSpellIndexByName("Windfury Totem")

-- We need to provide the spell duration to know if we should drop WF first or not
local wf_dropped_at = 0
local wf_was_last = false
local your_totem = nil
local in_combat = false
local extended_totems = false
local player_guid = nil

-- User Options
local defaults =
{
  enabled = true,
  -- controls how much sooner you want to drop WF before its duration expires
  -- experimental results picked 0.5 as the sweet spot
  leeway = 0.5,
  locked = false,
}

-- adapted from supermacros
local function RunLine(...)
	for k=1,arg.n do
		local text=arg[k];
        ChatFrameEditBox:SetText(text);
        ChatEdit_SendText(ChatFrameEditBox);
	end
end

-- adapted from supermacros
local function RunBody(text)
	local body = text;
	local length = strlen(body);
	for w in string.gfind(body, "[^\n]+") do
		RunLine(w);
	end
end

-------------------------------------------------

local librange = {}

-- Function to calculate distance between two points in 3D space
function librange:distance(x1,y1,z1,x2,y2,z2)
  local dx = x2 - x1
  local dy = y2 - y1
  local dz = z2 - z1
  return math.sqrt(dx^2 + dy^2 + dz^2)
end

function librange:InRange(unit, range, unit2)
  -- Determine the source based on the unit2 parameter
  local source = unit2 or "player"

  -- Early exit if the unit does not exist
  if not UnitExists(unit) then return nil end
  if not UnitCanAssist(unit, source) then return nil end
  if UnitIsCharmed(unit) or UnitIsCharmed(unit2) then return nil end

  local x1, y1, z1 = UnitPosition(source)
  local x2, y2, z2 = UnitPosition(unit)

  -- Check for Tauren race to adjust range
  local r = { UnitRace(source),UnitRace(unit) }
  local raceAdjustment = (r[2] == "TAUREN" or r[4] == "TAUREN") and 5 or 3
  -- local raceAdjustment = (UnitRace(source) == "Tauren" or UnitRace(unit) == "Tauren") and 5 or 3

  -- Calculate distance and adjust based on race
  local distance = self:distance(x1, y1, z1, x2, y2, z2)
  local adjustedDistance = distance - raceAdjustment

  -- Return based on the adjusted distance compared to the given range
  return adjustedDistance < range and 1 or nil
end

-------------------------------------------------

local SIZE = 35

local twisterFrame = CreateFrame("Frame","TwisterFrame")
twisterFrame:SetHeight(SIZE)
twisterFrame:SetWidth(SIZE)
twisterFrame:SetPoint("CENTER",UIParent,"CENTER",0,0) -- Position at center of the parent frame
twisterFrame:RegisterForDrag("LeftButton")
twisterFrame:SetMovable(true)

twisterFrame:SetScript("OnDragStart", function () twisterFrame:StartMoving() end)
twisterFrame:SetScript("OnDragStop", function () twisterFrame:StopMovingOrSizing() end)

-- twisterFrame:SetScript("OnClick", function () amprint("huh?") end)

local icon = twisterFrame:CreateTexture()
icon:SetWidth(SIZE) -- Size of the icon
icon:SetHeight(SIZE) -- Size of the icon
icon:SetPoint("CENTER", twisterFrame, "CENTER", 0, 0)
icon:SetTexture("Interface\\Icons\\Spell_Nature_Windfury")
icon:SetVertexColor(1,1,1,0.7)

-- Create a FontString for the frame hide timer
local timerText = twisterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
timerText:SetPoint("LEFT", twisterFrame, "LEFT", 3, 0)
timerText:SetFont("Fonts\\ARIALN.TTF", SIZE)

local carry = 10
local stepped_out = false
twisterFrame:SetScript("OnUpdate", function ()
  local dur = carry - (GetTime() - wf_dropped_at)
  local in_range = your_totem and UnitExists(your_totem) and librange:InRange(your_totem,extended_totems and 30 or 20)
  if dur < 5 and in_range and not stepped_out then
    carry = carry + (10 - dur)
  end
  if dur < 0 and stepped_out and in_range then
    stepped_out = false
    carry = carry + (10 - dur)
    dur = carry - (GetTime() - wf_dropped_at)
  end
  if dur < 5 and not in_range then
    stepped_out = true
  end

  if dur >= 9.9 then
    timerText:SetText("9.9")
  elseif dur > 0 then
    timerText:SetText(format("%.01f", dur))
  else
    timerText:SetText()
    if not in_combat and TwisterSettings.locked then twisterFrame:Hide() end
  end

  if not in_range and UnitExists(your_totem) then
    icon:SetVertexColor(1,0,0,0.7)
  else
    icon:SetVertexColor(1,1,1,0.7)
  end

end)

function TwistIt(macro,spell_dur,prio_twist)
  local wf_dur_rem = (wf_dropped_at + 10) - GetTime()
  local wf_ready = wf_dur_rem - (spell_dur + TwisterSettings.leeway) < 0
  local on_gcd = GetSpellCooldown(wf_spell_index,"spell") ~= 0
  if (not on_gcd or prio_twist) and TwisterSettings.enabled then
    if wf_was_last and not wf_ready then
      SpellStopTargeting()
      CastSpellByName("Grace of Air Totem")
    elseif wf_ready then
      SpellStopTargeting()
      CastSpellByName("Windfury Totem")
    else
      RunBody(macro)  
    end
  else
    RunBody(macro)
  end
end

function Twist()
  local wf_dur_rem = (wf_dropped_at + 10) - GetTime()
  local wf_ready = wf_dur_rem - TwisterSettings.leeway < 0
  local on_gcd = GetSpellCooldown(wf_spell_index,"spell") ~= 0
  -- if (not on_gcd or prio_twist) and TwisterSettings.enabled then, it's a solo twist macro, don't make it need enabled
  if (not on_gcd or prio_twist) then
    if wf_was_last and not wf_ready then
      SpellStopTargeting()
      CastSpellByName("Grace of Air Totem")
    elseif wf_ready then
      SpellStopTargeting()
      CastSpellByName("Windfury Totem")
    end
  end
end

local function OnEvent()
  if event == "UNIT_MODEL_CHANGED" then
    if string.find(UnitName(arg1), "^Windfury Totem") then
      if UnitName(arg1.."owner") == UnitName("player") then
        your_totem = arg1
      end
    end
  elseif event == "UNIT_CASTEVENT" and arg1 == player_guid then
    local name = SpellInfo(arg4)
    if arg3 == "CAST" and arg2 == nil or arg2 == "" then
      if name == "Windfury Totem" then
        wf_dropped_at = GetTime()
        wf_was_last = true
        carry = 10
        twisterFrame:Show()
      elseif name == "Grace of Air Totem" then
        wf_was_last = false
      end
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    in_combat = false
  elseif event == "PLAYER_REGEN_DISABLED" then
    in_combat = true
  elseif event == "PLAYER_ENTERING_WORLD" then
    local _,engClass = UnitClass("player")
    if engClass ~= "SHAMAN" then
      DEFAULT_CHAT_FRAME:AddMessage("|cff00ffffTwister|r is only useful to the Shaman class, the addon is now set to not load again.")
      DisableAddOn("Twister")
      SlashCmdList["TWISTER"] = nil
      twisterFrame:Hide()
      DisableFrame(twisterFrame)
    end

    _,player_guid = UnitExists("player")
    wf_spell_index = FindSpellIndexByName("Windfury Totem")
    _,_,_,_,rank = GetTalentInfo(3,8) -- fetch totem talent
    extended_totems = rank == 1
  elseif event == "ADDON_LOADED" then
    twisterFrame:UnregisterEvent("ADDON_LOADED")
    if not TwisterSettings
      then TwisterSettings = defaults -- initialize default settings
      else -- or check that we only have the current settings format
        local s = {}
        for k,v in pairs(defaults) do
          s[k] = TwisterSettings[k] == nil and defaults[k] or TwisterSettings[k]
        end
        TwisterSettings = s
    end
    if TwisterSettings.locked then
      twisterFrame:Hide()
      twisterFrame:EnableMouse(false)
    else
      twisterFrame:Show()
      twisterFrame:EnableMouse(true)
    end
  end
end

-- add an option to set the toggle the default mode,GoA always or let a cast happen

local function handleCommands(msg,editbox)
  local args = {};
  for word in string.gfind(msg,'%S+') do table.insert(args,word) end
  if args[1] == "leeway" then
    local n = tonumber(args[2])
    if n then
      TwisterSettings.leeway = n
      amprint("Leeway set to : "..n)
    else
      amprint("Usage: /twister leeway <number>")
    end
  elseif args[1] == "enabled" or args[1] == "enable" or args[1] == "toggle" then
    TwisterSettings.enabled = not TwisterSettings.enabled
    amprint("Addon enabled: "..showOnOff(TwisterSettings.enabled))
  elseif args[1] == "reset" then
    twisterFrame:SetPoint("CENTER",UIParent,"CENTER",0,0)
    amprint("Position reset.")
  elseif args[1] == "lock" or args[1] == "locked" then
    TwisterSettings.locked = not TwisterSettings.locked
    if TwisterSettings.locked then
      twisterFrame:EnableMouse(false)
    else
      twisterFrame:EnableMouse(true)
      twisterFrame:Show()
    end
    amprint("Indicator frame locked: " .. showOnOff(TwisterSettings.locked,"Locked","Unlocked"))
  else -- make group size color by if you're in a big enough group currently
    amprint('Twister: Wrap a macro with TwistIt('..colorize("macro",amcolor.yellow)..') to auto-twist when casting.')
    amprint('- Addon '..colorize("enable",amcolor.green)..'d [' .. showOnOff(TwisterSettings.enabled) .. ']')
    amprint('- Set '.. colorize("leeway",amcolor.green) .. ' to add to cast time when considering when to drop WF [' .. TwisterSettings.leeway .. ']')
    amprint('- Toggle indicator '.. colorize("lock",amcolor.green) .. ' [' .. showOnOff(TwisterSettings.locked,"Locked","Unlocked") .. ']')
    amprint('- Indicator position '.. colorize("reset",amcolor.green) .. '.')
  end
end

-- twisterFrame:RegisterEvent("UI_ERROR_MESSAGE")
twisterFrame:RegisterEvent("UNIT_CASTEVENT")
twisterFrame:RegisterEvent("ADDON_LOADED")
twisterFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
twisterFrame:RegisterEvent("UNIT_MODEL_CHANGED")
twisterFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
twisterFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
twisterFrame:SetScript("OnEvent", OnEvent)
  
SLASH_TWISTER1 = "/twister";
SlashCmdList["TWISTER"] = handleCommands
