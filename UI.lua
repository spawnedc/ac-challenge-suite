local ADDON_NAME, ChallengeSuite = ...

-- Prefer the real Hardcore aura's icon (present once the client-patch repo,
-- ac-challenge-suite-clientpatch, is installed); otherwise fall back to a stock
-- Blizzard icon so the minimap button never shows a blank texture.
local HARDCORE_AURA_SPELL_ID = 666666
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_Skull_01"

local function GetButtonIcon()
  local _, _, icon = GetSpellInfo(HARDCORE_AURA_SPELL_ID)
  return icon or FALLBACK_ICON
end

local function DescribeStatus(info)
  if not info.enabled then
    return "disabled"
  elseif info.label ~= "" then
    return info.label
  elseif info.active then
    return "Active"
  else
    return "Available"
  end
end

local function SortedIds()
  local ids = {}
  for id in pairs(ChallengeSuite.state) do
    table.insert(ids, id)
  end
  table.sort(ids)
  return ids
end

local dataObject = LibStub("LibDataBroker-1.1"):NewDataObject(ADDON_NAME, {
  type = "data source",
  text = "Challenges",
  icon = GetButtonIcon(),
  OnClick = function()
    ChallengeSuite:TogglePanel()
  end,
  OnTooltipShow = function(tooltip)
    tooltip:AddLine("Challenge Suite")

    local ids = SortedIds()
    if #ids == 0 then
      tooltip:AddLine("No challenges reported by the server yet.")
    else
      for _, id in ipairs(ids) do
        tooltip:AddDoubleLine(id, DescribeStatus(ChallengeSuite.state[id]))
      end
    end

    tooltip:AddLine(" ")
    tooltip:AddLine("Click to manage challenges")
  end,
})

ChallengeSuiteDB = ChallengeSuiteDB or {}

local panel

local function EnsurePanel()
  if panel then
    return panel
  end

  panel = CreateFrame("Frame", "ChallengeSuitePanel", UIParent, "BasicFrameTemplateWithInset")
  panel:SetSize(260, 100)
  panel:SetPoint("CENTER")
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", panel.StartMoving)
  panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
  panel:Hide()

  panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  panel.title:SetPoint("TOP", 0, -6)
  panel.title:SetText("Challenge Suite")

  panel.rows = {}
  return panel
end

local function RefreshPanel()
  local p = EnsurePanel()

  for _, row in ipairs(p.rows) do
    row:Hide()
  end

  local ids = SortedIds()
  local y = -32

  for i, id in ipairs(ids) do
    local info = ChallengeSuite.state[id]
    local row = p.rows[i]
    if not row then
      row = CreateFrame("Frame", nil, p)
      row:SetSize(240, 24)

      row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      row.label:SetPoint("LEFT", 4, 0)

      row.button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
      row.button:SetSize(70, 20)
      row.button:SetPoint("RIGHT", -4, 0)
      row.button:SetText("Enable")
      row.button:SetScript("OnClick", function(btn)
        ChallengeSuite:RequestEnable(btn.challengeId)
      end)

      p.rows[i] = row
    end

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 10, y)
    y = y - 26

    row.label:SetText(("%s (%s)"):format(id, DescribeStatus(info)))
    row.button.challengeId = id
    if info.enabled and not info.active then
      row.button:Enable()
    else
      row.button:Disable()
    end

    row:Show()
  end

  p:SetHeight(math.max(60, 40 + (#ids * 26)))
end

function ChallengeSuite:TogglePanel()
  local p = EnsurePanel()
  if p:IsShown() then
    p:Hide()
  else
    RefreshPanel()
    p:Show()
  end
end

function ChallengeSuite:ShowPanel()
  RefreshPanel()
  EnsurePanel():Show()
end

ChallengeSuite:On("StateUpdated", function()
  if panel and panel:IsShown() then
    RefreshPanel()
  end
end)

ChallengeSuite:On("ShowPanel", function()
  ChallengeSuite:ShowPanel()
end)

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
  LibStub("LibDBIcon-1.0"):Register(ADDON_NAME, dataObject, ChallengeSuiteDB)
end)
