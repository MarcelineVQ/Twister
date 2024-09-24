-- Name: twisterFrame
-- License: LGPL v2.1

-- stop loading addon if no superwow
if not (SetAutoloot) then
  StaticPopupDialogs["NO_SUPERWOW_UNITXP_TWISTER"] = {
    text = "[|cff36c948Twister|r requires |cffffd200SuperWoW|r to operate.",
    button1 = TEXT(OKAY),
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    showAlert = 1,
  }

  StaticPopup_Show("NO_SUPERWOW_UNITXP_TWISTER")
  return
end

BINDING_HEADER_TWISTER = "Twister"
BINDING_NAME_TOGGLE_KEY = "Toggle automated twisting"

-- TODO:
-- Allow non-sham to use this to know when they're in WF range at a glance

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

local function trim(str)
  if str == "" or str == nil then return str end
  local s = string.find(str, "%S*")
  local e = string.find(str, "%S%s*$")
  return string.sub(str,s,e) or ""
end

local function DisableFrame(frame)
  if frame then
      frame:EnableMouse(false)

      frame:SetScript("OnUpdate", nil)
      frame:SetScript("OnEvent", nil)

      frame:Hide()
  end
end

-- We need to provide the spell duration to know if we should drop WF first or not
local wf_dropped_at = 0
local wf_was_last = false
local your_totem = nil
local extended_totems = false
local player_guid = nil
local spellstore = {}
local wf_spell_index = nil

-- User Options
local defaults =
{
  enabled = false,
  -- controls how much sooner you want to drop WF before its duration expires
  leeway = 0.3,
  locked = false,
  prio_twist = false,
  indicator_shown = true,
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

local function FetchSpellId(spell,maybe_rank)
  if not spell or spell == "" then return nil end
  local name,rank
  local s,e,name = string.find(spell,"([^(]+)")
  if s and not maybe_rank then
    _,_,rank = string.find(string.sub(spell,e), "(Rank %d+)")
  end
  rank = maybe_rank or rank
  name = string.lower(trim(name))
  rank = rank and string.lower(rank)
  
  if not spellstore[name] then return nil end
  if name and rank and spellstore[name][rank] then
    return spellstore[name][rank]
  end

  local highest = { rank = 0, id = nil }
  for rank,index in pairs(spellstore[name]) do
    local _,_,r = string.find(rank, "rank (%d+)")
    local r2 = tonumber(r)
    if r2 and r2 > highest.rank then highest = { rank = r2, id = index} end
  end
  return highest.id
end

-- Create a hidden tooltip for scanning
local tooltip = CreateFrame("GameTooltip", "SpellCastTimeTooltip", UIParent, "GameTooltipTemplate")
tooltip:SetOwner(UIParent, "ANCHOR_NONE")
function GetSpellCastTime(spellName, spellRank)

  -- print(spellName)
  -- print(spellRank)
  local id = FetchSpellId(spellName,spellRank)

  if not id then return nil end -- idkman

  tooltip:SetSpell(id, BOOKTYPE_SPELL)
  local cast_line = getglobal("SpellCastTimeTooltipTextLeft3"):GetText()
  local _, _, castTime = string.find(cast_line or "", "(%d+%.?%d*)")
  return tonumber(castTime) or 0
end

-------------------------------------------------

local librange2 = {}
do
  -- Function to calculate distance between two points in 3D space
  function librange2:distance(x1,y1,z1,x2,y2,z2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dz = z2 - z1
    return math.sqrt(dx^2 + dy^2 + dz^2)
  end

  function librange2:InRange(unit, range, unit2)
    -- Determine the source based on the unit2 parameter
    local source = unit2 or "player"

    -- Early exit if the unit does not exist or is trivial
    if unit == source then return 1 end 
    if not UnitExists(unit) or not UnitExists(source) then return nil end

    -- determine what distance checker we can use
    local unitxp,r = pcall(UnitXP, "distanceBetween", source, unit)
    if unitxp then
      distance = r
    elseif SetAutoloot then
      if not UnitCanAssist(unit, source) then return nil end
      if UnitIsCharmed(unit) or UnitIsCharmed(unit2) then return nil end
      local x1, y1, z1 = UnitPosition(source)
      local x2, y2, z2 = UnitPosition(unit)
      -- Calculate distance and adjust based on race
      distance = self:distance(x1, y1, z1, x2, y2, z2)
    else
      CheckInteractDistance(unit,4) -- meh
    end

    -- race doesn't seem to matter for totem auras, use standard model radius, probaly the totem's
    local adjustedDistance = distance - 1.5

    -- Return based on the adjusted distance compared to the given range
    return adjustedDistance < range and 1 or nil
  end
end

-------------------------------------------------

local SIZE = 35

local twisterTimerFrame = CreateFrame("Frame")
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
twisterTimerFrame:SetScript("OnUpdate", function ()
  local dur = carry - (GetTime() - wf_dropped_at)
  local has_totem = your_totem and UnitExists(your_totem)
  local in_range = has_totem and librange2:InRange(your_totem,extended_totems and 30 or 20)
  if dur < 5 and in_range and not stepped_out then
    carry = carry + (10 - dur)
  end
  if dur < 0 and stepped_out and in_range then
    stepped_out = false
    carry = carry + (10 - dur)
    dur = carry - (GetTime() - wf_dropped_at)
  end
  if dur < 5 and not in_range and has_totem then
    stepped_out = true
  end

  if dur >= 9.9 then
    timerText:SetText("9.9")
  elseif dur > 0 then
    timerText:SetText(format("%.01f", dur))
  else
    timerText:SetText()
    if not TwisterSettings.in_combat and TwisterSettings.locked then twisterFrame:Hide() end
  end

  if not in_range and has_totem then
    icon:SetVertexColor(1,0,0,0.7)
  else
    icon:SetVertexColor(1,1,1,0.7)
  end
end)

local orig_CastSpellByName = CastSpellByName
local orig_CastSpell = CastSpell

-- Helper function for Windfury totem logic
local function handleTotemCasting(spellname, spell_dur)
  local wf_dur_rem = (wf_dropped_at + 10) - GetTime()
  local wf_ready = wf_dur_rem - (spell_dur + TwisterSettings.leeway) < 0
  local on_gcd = GetSpellCooldown(wf_spell_index, BOOKTYPE_SPELL) ~= 0

  if (not on_gcd or TwisterSettings.prio_twist) and TwisterSettings.in_combat then
    if wf_was_last and not wf_ready then
      SpellStopTargeting()
      orig_CastSpellByName("Grace of Air Totem")
    elseif wf_ready then
      SpellStopTargeting()
      orig_CastSpellByName("Windfury Totem")
    else
      return false -- Signal to cast the original spell
    end
    return true -- Totem was cast, no need to cast the original spell
  end

  return false -- Signal to cast the original spell
end

function Twister_CastSpellByName(spellname,a2,a3,a4,a5,a6,a7,a8,a9,a10)
  if not TwisterSettings.enabled or string.find(spellname,"Totem$") then
    orig_CastSpellByName(spellname,a2,a3,a4,a5,a6,a7,a8,a9,a10)
    return
  end

  local spell_dur = GetSpellCastTime(spellname) or 0

  local wf_dur_rem = (wf_dropped_at + 10) - GetTime()
  local wf_ready = wf_dur_rem - (spell_dur + TwisterSettings.leeway) < 0
  local on_gcd = GetSpellCooldown(wf_spell_index,BOOKTYPE_SPELL) ~= 0

  if not handleTotemCasting(spellname,spell_dur) then
    orig_CastSpellByName(spellname,a2,a3,a4,a5,a6,a7,a8,a9,a10)
  end
end
CastSpellByName = Twister_CastSpellByName

function Twister_CastSpell(bookSpellId,bookType,a3,a4,a5,a6,a7,a8,a9,a10)
  if not TwisterSettings.enabled or string.find(GetSpellName(bookSpellId,bookType),"Totem$") then
    orig_CastSpell(bookSpellId,bookType,a3,a4,a5,a6,a7,a8,a9,a10)
    return
  end

  local spellname = GetSpellName(bookSpellId,bookType)
  local spell_dur = GetSpellCastTime(spellname) or 0
  
  local wf_dur_rem = (wf_dropped_at + 10) - GetTime()
  local wf_ready = wf_dur_rem - (spell_dur + TwisterSettings.leeway) < 0
  local on_gcd = GetSpellCooldown(wf_spell_index,BOOKTYPE_SPELL) ~= 0

  if not handleTotemCasting(spellname,spell_dur) then
    orig_CastSpell(bookSpellId,bookType,a3,a4,a5,a6,a7,a8,a9,a10)
  end
end
CastSpell = Twister_CastSpell

-- set and restore flags
function Twist()
  local ic = TwisterSettings.in_combat
  local en = TwisterSettings.enabled
  TwisterSettings.enabled = true
  TwisterSettings.in_combat = true
  Twister_CastSpellByName("")
  TwisterSettings.in_combat = ic
  TwisterSettings.enabled = en
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
        if TwisterSettings.indicator_shown then twisterFrame:Show() end
      elseif name == "Grace of Air Totem" then
        wf_was_last = false
      end
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    TwisterSettings.in_combat = false
  elseif event == "PLAYER_REGEN_DISABLED" then
    TwisterSettings.in_combat = true
    if TwisterSettings.indicator_shown then twisterFrame:Show() end
  elseif event == "PLAYER_ENTERING_WORLD" then
    local _,engClass = UnitClass("player")
    if engClass ~= "SHAMAN" then
      DEFAULT_CHAT_FRAME:AddMessage("|cff00ffffTwister|r is only useful to the Shaman class, the addon is now set to not load again.")
      DisableAddOn("Twister")
      SlashCmdList["TWISTER"] = nil
      twisterFrame:Hide()
      DisableFrame(twisterFrame)
    end

    if UnitAffectingCombat("player") then TwisterSettings.in_combat = true end

    -- fill spellstore
    spellstore = {}
    local i = 1
    while true do
      local name, rank, id = GetSpellName(i, BOOKTYPE_SPELL)
      -- local name,tank,texture,minrange,maxrange = SpellInfo(id) 
      if not name then
          break
      end
      name = string.lower(name)
      rank = rank and string.lower(rank) or "none"

      spellstore[name] = spellstore[name] or {}
      spellstore[name][rank] = i

      i = i + 1
    end

    _,player_guid = UnitExists("player")
    wf_spell_index = FetchSpellId("Windfury Totem")
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
    elseif TwisterSettings.indicator_shown then
      twisterFrame:Show()
      twisterFrame:EnableMouse(true)
    end
  end
  twisterFrame:RegisterEvent("UNIT_CASTEVENT")
  twisterFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  twisterFrame:RegisterEvent("UNIT_MODEL_CHANGED")
  twisterFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
  twisterFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end


function Twister_Toggle(report)
  TwisterSettings.enabled = not TwisterSettings.enabled
  if report then UIErrorsFrame:AddMessage("Twister "..showOnOff(TwisterSettings.enabled,"Enabled","Disabled"), 1.0, 1.0, 0.0) end
end

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
  elseif args[1] == "twistprio" or args[1] == "priotwist" then
    if n then
      TwisterSettings.prio_twist = not TwisterSettings.prio_twist
      amprint("Prioritize twisting over casts: " .. showOnOff(TwisterSettings.prio_twist))
    else
      amprint("Usage: /twister twistprio")
    end
  elseif (args[1] == "enable" or args[1] == "on") or (args[1] == "disable" or args[1] == "off") then
    if (args[1] == "enable" or args[1] == "on") then
      TwisterSettings.enabled = true
    elseif (args[1] == "disable" or args[1] == "off") then
      TwisterSettings.enabled = false
    end
    amprint("Addon enabled: "..showOnOff(TwisterSettings.enabled))
  elseif args[1] == "toggle" then
    Twister_Toggle(true)
  elseif args[1] == "pause" or args[1] == "unpause" or args[1] == "resume" then
    if args[1] == "pause" then
      TwisterSettings.enabled = false
    else
      TwisterSettings.enabled = true
    end
  elseif args[1] == "reset" then
    twisterFrame:SetPoint("CENTER",UIParent,"CENTER",0,0)
    amprint("Indicator position reset.")
  elseif args[1] == "show" or args[1] == "hide" then
    TwisterSettings.indicator_shown = not TwisterSettings.indicator_shown
    if TwisterSettings.indicator_shown then
      twisterFrame:Show()
    else
      twisterFrame:Hide()
    end
    amprint("Indicator: "..showOnOff(TwisterSettings.indicator_shown, "Shown", "Hidden"))
  elseif args[1] == "lock" or args[1] == "locked" then
    TwisterSettings.locked = not TwisterSettings.locked
    if TwisterSettings.locked then
      twisterFrame:EnableMouse(false)
    elseif TwisterSettings.indicator_shown then
      twisterFrame:EnableMouse(true)
      twisterFrame:Show()
    end
    amprint("Indicator frame locked: " .. showOnOff(TwisterSettings.locked,"Locked","Unlocked"))
  else
    amprint('Twister: /twister <option>')
    amprint(format("- Addon %s/%s/%s [%s]",colorize("enable",amcolor.green),colorize("disable",amcolor.red),colorize("toggle",amcolor.yellow),showOnOff(TwisterSettings.enabled, "Enabled", "Disabled")))
    amprint('- Toggle '..colorize("priotwist",amcolor.green)..' [' .. showOnOff(TwisterSettings.enabled) .. ']')
    amprint('- Set '.. colorize("leeway",amcolor.green) .. ' to adjust WF drop time [' .. colorize(TwisterSettings.leeway, amcolor.blizzard) .. ']')
    amprint('- Toggle indicator '.. colorize("lock",amcolor.green) .. ' [' .. showOnOff(TwisterSettings.locked,"Locked","Unlocked") .. ']')
    amprint('- Indicator position '.. colorize("reset",amcolor.green))
    amprint('- '..colorize("show",amcolor.green).."/"..colorize("hide",amcolor.green)..' indicator [' .. showOnOff(TwisterSettings.locked,"Shown","Hidden") .. ']')
  end
end

-- TODO extend this tocheck any shaman in party not just player, add partychange event to detect when your shaman has changed. This is to allow this addon to be useful to any melee
-- twisterFrame:RegisterEvent("UI_ERROR_MESSAGE")
twisterFrame:RegisterEvent("ADDON_LOADED")
twisterFrame:SetScript("OnEvent", OnEvent)
  
SLASH_TWISTER1 = "/twister";
SlashCmdList["TWISTER"] = handleCommands
