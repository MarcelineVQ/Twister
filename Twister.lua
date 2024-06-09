-- Name: twisterFrame
-- License: LGPL v2.1

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
twisterFrame:SetScript("OnUpdate", function ()
  local dur = carry - (GetTime() - wf_dropped_at)
  if dur < 5 and UnitExists(your_totem) then
      carry = carry + (10 - dur)
  end
  if dur >= 9.9 then
    timerText:SetText("9.9")
  elseif dur > 0 then
    timerText:SetText(format("%.01f", dur))
  else
    timerText:SetText()
    -- carry = 10
    if not in_combat and TwisterSettings.locked then twisterFrame:Hide() end
  end
end)

function TwistIt(macro,spell_dur)
  local wf_dur_rem = (wf_dropped_at + 10) - GetTime()
  local wf_ready = wf_dur_rem - (spell_dur + TwisterSettings.leeway) < 0
  local on_gcd = GetSpellCooldown(wf_spell_index,"spell") ~= 0
  if not on_gcd and TwisterSettings.enabled then
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

local function OnEvent()
  if event == "UNIT_MODEL_CHANGED" then
    if string.find(UnitName(arg1), "^Windfury Totem") then
      if UnitName(arg1.."owner") == UnitName("player") then
        your_totem = arg1
      end
    end
  elseif event == "UNIT_CASTEVENT" and UnitName(arg1) == UnitName("player") then
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
    wf_spell_index = FindSpellIndexByName("Windfury Totem")
    if TwisterSettings.locked then
      twisterFrame:Hide()
      twisterFrame:EnableMouse(false)
    else
      twisterFrame:Show()
      twisterFrame:EnableMouse(true)
    end
  end
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
twisterFrame:RegisterEvent("UNIT_MODEL_CHANGED")
twisterFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
twisterFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
twisterFrame:SetScript("OnEvent", OnEvent)
  
SLASH_TWISTER1 = "/twister";
SlashCmdList["TWISTER"] = handleCommands
