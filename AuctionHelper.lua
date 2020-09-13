-- AuctionHelper is designed to streamline in-game auction calling in
-- Elder Scrolls Online. Its application is pretty specific to one guild,
-- although any guild willing to adjust their process a bit to match
-- (or modify this code to meet their needs) could find it useful.
-- Author: @jeffk42

AuctionHelper = {}
AuctionHelper.variableVersion = 1
AuctionHelper.savedVariables = {}
AuctionHelper.Default = {
  AuctionHelperData = {},
  currentIndex = 1
}
local AuctionHelperData = {}
local currentIndex = 1
-- The expected format of the source data. Our guild has a Google Sheets document updated
-- for the auction each week, and the data for the add-on is populated by exporting
-- the sheet as a CSV that matches the regex below.
local csvRegex = "^(%d+),(.-),[\"%$]*(.-)[\"]*,\"%$.-\",[\"%$]*(%w+,?%w+)[\"]*,.-[\n]"
local csvRegexWithItems = "^(%d+),(.-),(.-),.-,(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),.-[\n]"
-- Tab-delimited version not currently used because while it would be easier, EditBox
-- doesn't understand tabs. 
local tsvRegex = "^(%d+)\t(.-)\t[\"\$]*(.-)[\"]*\t\"\$.-\"\t[\"\$]*(.-)[\"]*\t.-[\n]"
-- Lua doesn't seem to have a string.trim() equivalent, or I just never found it. So
-- this will do the same thing.
local stringTrimRegex = "^[%s]*(.-)[%s]*$"
-- Some fields may have unnecessary whitespace between words.
local stripExtraSpaceRegex = "[ \t]+"

-- Other assorted formats for things, including the actual chat messages generated for auction calling.
local lotListFormat = "%d: %s"
local wordsRegex = "[a-zA-Z ]+"
local goingOnceMessage = "%s going once!"
local goingTwiceMessage = "%s going twice!"
local soldMessage = "SOLD to %s for %s! Congrats! Please MAIL your winning bid to @AKTT-auction as soon as possible so we can get your item(s) sent out promptly!"
local lastCallMessage = "%s is the current top bid, any other bids?"
local lastCallEstimatedMessage = "%s is the current top bid, estimated value is %s, any other bids?"
local currentLotMessage = "==== Lot #%d: %s ===="
local startingBidMessage = "<<< Starting bid for this lot: %s >>>"
local startingBidFlashMessage = "FLASH LOT! Estimated value: %s. Wait for the GO, and you have 30 SECONDS to bid. Highest bid when I say STOP gets the lot!"
-- held temporarily for if I decide to try to parse bids directly from the chat window.
-- local AuctionHelperBuffer = nil
-- local copyBufferList = {}

 
-- Add-on name for registering events
AuctionHelper.name = "AuctionHelper"

-- Updates the summary text section of the window to match current lot values.
local function updateWindowFields()
  AuctionHelperControlWindowLotNumLabel:SetText(string.format("#%d", currentIndex))
  AuctionHelperControlWindowLotNameLabel:SetText(AuctionHelperData[currentIndex].title)
  AuctionHelperControlWindowEstimatedLabel:SetText(AuctionHelperData[currentIndex].estimated)
  AuctionHelperControlWindowMinimumLabel:SetText(AuctionHelperData[currentIndex].start)
  AuctionHelperControlWindowCurrentBidderLabel:SetText(AuctionHelperData[currentIndex].winner)
  AuctionHelperControlWindowCurrentBidLabel:SetText(AuctionHelperData[currentIndex].winbid)
end

-- if a new lot is selected via a means other than the pull-down menu (like using a chat command),
-- update the selected item in the pull-down menu to match.
local function updateSelectMenu()
  AuctionHelperControlWindowLotList.m_comboBox:SelectItem(AuctionHelperControlWindowLotList.m_comboBox:GetItems()[currentIndex])
end

-- Change the current lot to the lot at the index specified.
local function changeLot(newLotNumber)
  if (AuctionHelperData[newLotNumber] ~= nil) then
    currentIndex = newLotNumber
    AuctionHelper.savedVariables.currentIndex = currentIndex
    updateWindowFields()
  else
    d("ERROR: chosen lot number doesn't exist")
  end
end

-- Set the value of the starting bid for the current lot.
local function setNewStartingBid(num)
  AuctionHelperData[currentIndex].start = num
  AuctionHelper.savedVariables.AuctionHelperData[currentIndex].start = num
  updateWindowFields()
end

-- Set the value of the estimated value for the current lot.
local function setNewEstimatedValue(num)
  AuctionHelperData[currentIndex].estimated = num
  AuctionHelper.savedVariables.AuctionHelperData[currentIndex].start = num
  updateWindowFields()
end

-- When the current high bid is changed via a method other than the text field (such as by chat command),
-- update the text field to match.
local function updateBidTextField()
  AuctionHelperControlWindowCurrentBidBoxTextField:SetText(AuctionHelperData[currentIndex].winbid)
end

-- When the current high bid is changed via a method other than the text field (such as by chat command),
-- update the text field to match.
local function updateBidderTextField()
  AuctionHelperControlWindowBidderBoxTextField:SetText(AuctionHelperData[currentIndex].winner)
end

local function fireSelectionChanged(theNewLot)
  if (AuctionHelperData[theNewLot] == nil) then
    return
  end
  changeLot(theNewLot)
  updateBidTextField()
  updateBidderTextField()
end

-- Sets the winner for the current lot and updated the control window fields
local function setCurrentWinner(rawName, fromTextField)
  if (rawName ~= AuctionHelperData[currentIndex].winner) then
    AuctionHelperData[currentIndex].winner = rawName
    AuctionHelper.savedVariables.AuctionHelperData[currentIndex].winner = rawName
    d(string.format("-- Current High Bidder set to %s --", rawName))
    updateWindowFields()
    if (not fromTextField) then
      updateBidderTextField()
    end
  end
end

local function setCurrentHighBid(value, fromTextField)
  if (value ~= AuctionHelperData[currentIndex].winbid) then
    AuctionHelperData[currentIndex].winbid = value
    AuctionHelper.savedVariables.AuctionHelperData[currentIndex].winbid = value
    updateWindowFields()
    if (not fromTextField) then
      updateBidTextField()
    end
  end
end

local function selectLotItem(theNewLot)
  if (theNewLot == nil) then
    return
  end
  d(string.format("item selected: %s", theNewLot.title))
  changeLot(theNewLot.index)
  updateSelectMenu()
end

-- Adds a context menu option to usernames in chat that populates the winner field
-- in the control window so you don't have to type it out.
function SetWinnerContextMenu(playerData, rawName)
  AddCustomMenuItem("Set Current Winner", function() setCurrentWinner(rawName, false) end)  
  ShowMenu()
end

-- Restores the last used data on login or reload
local function RestoreSavedLotData()
  AuctionHelperControlWindowLotList.m_comboBox:ClearItems()
  local ind = 1
  while AuctionHelperData[ind] do
    local tmpIndx = ind
    local itemEntry = ZO_ComboBox:CreateItemEntry(string.format(lotListFormat, ind, AuctionHelperData[ind].title), function() fireSelectionChanged(tmpIndx) end )
    AuctionHelperControlWindowLotList.m_comboBox:AddItem(itemEntry)
    ind = ind + 1
  end
  selectLotItem(AuctionHelperData[currentIndex])
  updateBidTextField()
  AuctionHelperControlWindowBidderBoxTextField:SetText(AuctionHelperData[currentIndex].winner)
end

function HandleUpdateClicked(self, useItems)
  d(useItems)
  if useItems then
    AuctionHelperDataField_OnTextChanged_WithItems (self)
  else
    AuctionHelperDataField_OnTextChanged (self)
  end
end

-- Triggered from the Update button, reloads the data pasted from the CSV file
function AuctionHelperDataField_OnTextChanged (self)
  s = AuctionHelperDataWindowBody1Field:GetText()
  if (string.len(s) < 1) then
    return
  end

  AuctionHelperData = {}
  AuctionHelperControlWindowLotList.m_comboBox:ClearItems()
  
  for index, title, est, st in string.gmatch( s, csvRegex ) do
      local inum = tonumber(index)
      AuctionHelperData[inum] = {index = 0, title="", estimated="", start="", winner="", winbid="" }
      -- trim edges and Reduce extra whitespace

      AuctionHelperData[inum].index = inum
      AuctionHelperData[inum].title = string.gsub(string.match(title, stringTrimRegex), stripExtraSpaceRegex, " ")
      AuctionHelperData[inum].estimated = string.match(est, stringTrimRegex)
      AuctionHelperData[inum].start = string.match(st, stringTrimRegex)
      AuctionHelperData[inum].winner = ""
      AuctionHelperData[inum].winbid = ""
      
      local itemEntry = ZO_ComboBox:CreateItemEntry(string.format(lotListFormat, inum, title), function() fireSelectionChanged(inum) end )
      AuctionHelperControlWindowLotList.m_comboBox:AddItem(itemEntry)
  end
  selectLotItem(AuctionHelperData[1])
  AuctionHelper.savedVariables.AuctionHelperData = AuctionHelperData
end

function AuctionHelperDataField_OnTextChanged_WithItems (self)
  s = AuctionHelperDataWindowBody1Field:GetText()
  if (string.len(s) < 1) then
    return
  end

  AuctionHelperData = {}
  AuctionHelperControlWindowLotList.m_comboBox:ClearItems()
  
  for index, title, est, st, f, g, h, i, j, k, l, m, n in string.gmatch( s, csvRegexWithItems ) do
      local inum = tonumber(index)
      AuctionHelperData[inum] = {index = 0, title="", estimated="", start="", winner="", winbid="", items={}}
      -- trim edges and Reduce extra whitespace

      AuctionHelperData[inum].index = inum
      AuctionHelperData[inum].title = string.gsub(string.match(title, stringTrimRegex), stripExtraSpaceRegex, " ")
      AuctionHelperData[inum].estimated = string.match(est, stringTrimRegex)
      AuctionHelperData[inum].start = string.match(st, stringTrimRegex)
      AuctionHelperData[inum].winner = ""
      AuctionHelperData[inum].winbid = ""
      -- for itemIndex = 1, 9 do
        AuctionHelperData[inum].items[1] = string.match(f, stringTrimRegex)
      -- end
      AuctionHelperData[inum].items[2] = string.match(g, stringTrimRegex)
      AuctionHelperData[inum].items[3] = string.match(h, stringTrimRegex)
      AuctionHelperData[inum].items[4] = string.match(i, stringTrimRegex)
      AuctionHelperData[inum].items[5] = string.match(j, stringTrimRegex)
      AuctionHelperData[inum].items[6] = string.match(k, stringTrimRegex)
      AuctionHelperData[inum].items[7] = string.match(l, stringTrimRegex)
      AuctionHelperData[inum].items[8] = string.match(m, stringTrimRegex)
      AuctionHelperData[inum].items[9] = string.match(n, stringTrimRegex)
      
      local itemEntry = ZO_ComboBox:CreateItemEntry(string.format(lotListFormat, inum, title), function() fireSelectionChanged(inum) end )
      AuctionHelperControlWindowLotList.m_comboBox:AddItem(itemEntry)
  end
  selectLotItem(AuctionHelperData[1])
  AuctionHelper.savedVariables.AuctionHelperData = AuctionHelperData
end

function HandleNextButton()
  local newIndex = currentIndex + 1
  if (AuctionHelperData[newIndex] ~= nil) then
    changeLot(newIndex)
    updateSelectMenu()
  end
end

-- Used to change the color of non-numeric labels to red,
-- and numeric labels to green.
function LabelUpdate(label)
  if (string.match(label:GetText(), wordsRegex)) then
    label:SetColor(1, 0.6, 0.6, 1)
  else
    label:SetColor(0.7, 1, 0.7, 1)
  end
end

function updateHighBidFromField(field)
  local newText = field:GetText()
  if (newText ~= AuctionHelperData[currentIndex].winbid) then
    setCurrentHighBid(newText, true)
  end
end

function updateBidderFromField(field)
  local newText = field:GetText()
  if (newText ~= AuctionHelperData[currentIndex].bidder) then
    setCurrentWinner(newText, true)
  end
end

function stageGoingOnce()
  StartChatInput(string.format(goingOnceMessage, AuctionHelperData[currentIndex].winbid))
end

function stageGoingTwice()
  StartChatInput(string.format(goingTwiceMessage, AuctionHelperData[currentIndex].winbid))
end

function stageSoldMessage()
  StartChatInput(string.format(soldMessage, AuctionHelperData[currentIndex].winner, AuctionHelperData[currentIndex].winbid))
end

function stageNewLot()
  StartChatInput(string.format(currentLotMessage, currentIndex, AuctionHelperData[currentIndex].title))
end

function stageStartingBid()
  if (string.lower(AuctionHelperData[currentIndex].start) == "flash") then
    StartChatInput(string.format(startingBidFlashMessage, AuctionHelperData[currentIndex].estimated))
  else
    StartChatInput(string.format(startingBidMessage, AuctionHelperData[currentIndex].start))
  end
end

function stageLastCallWithEstimated()
  StartChatInput(string.format(lastCallEstimatedMessage, AuctionHelperData[currentIndex].winbid, AuctionHelperData[currentIndex].estimated))
end

function stageLastCall()
  StartChatInput(string.format(lastCallMessage, AuctionHelperData[currentIndex].winbid))
end

function AuctionHelper:ConsoleCommands()

    SLASH_COMMANDS["/a"] = function(param)

        local argNum = 0
        local value = ""
        local estimated = ""
        local user = ""
        local command = ""

        for w in string.gmatch(param,"%w+") do
          argNum = argNum + 1
          if argNum == 1 then command = w end
          if argNum == 2 then user = w end
          if argNum == 3 then value = w end
          if argNum == 4 then estimated = w end
        end
          command = string.lower(command)
          if command == "help" then
            d("-- Auction Helper commands --")
            d("/a                        Show or hide the data reader window")
            d("/a b  [bid]               Set the current high bid to [bid]")
            d("/a go [lot #]             Stage up the lot text for the lot number specified")
            d("/a go next                Stage up the lot text for the lot number following the previous one")
            d("/a sb                     Stage up minimum bid text for the current lot")
            d("/a sb [bid]               Stage up minimum bid text in the specified amount")
            d("/a lc                     Stage up last call text at the current bid amount")
            d("/a lc [bid]               Stage up last call text at the bid amount specified")
            d("/a lc [bid] [estimated]   Stage up the last call text with the estimated value nudge")
            d("/a g1                     Stage up the Going Once! text at the current bid")
            d("/a g1 [bid]               Stage up the Going Once! text at the bid specified")
            d("/a g2                     Stage up the Going Twice! text at the current bid")
            d("/a g2 [bid]               Stage up the Going Twice! text at the bid specified")
            d("/a sold                   Stage up the SOLD message using the current lead bidder and amount")
          elseif command == "lc" then
            if (string.len(user) <= 0) then
              stageLastCall()
            else
              if (string.len(value) > 0) then
                estimated = value
              end
              value = user
              setCurrentHighBid(value)
              if (string.len(estimated) > 0) then
                setNewEstimatedValue(estimated)
                stageLastCallWithEstimated()
              else
                stageLastCall()
              end
            end
          elseif command == "b" then
            setCurrentHighBid(user, false)
            updateBidTextField()
          elseif command == "g1" then
            if (string.len(user) > 0) then
              setCurrentHighBid(user, false)
              updateBidTextField()
            end
            stageGoingOnce()
          elseif command == "g2" then
            if (string.len(user) > 0) then
              setCurrentHighBid(user, false)
              updateBidTextField()
            end
            stageGoingTwice()
          elseif command == "sold" then
            stageSoldMessage()
          elseif command == "" then
            AuctionHelperDataWindow:SetHidden(false)
            AuctionHelperControlWindow:SetHidden(false)
          elseif command == "go" then
            if (string.len(user) > 0) then
              if (string.lower(user) == "next") then
                changeLot(currentIndex + 1)
                updateSelectMenu()
              else
                local newIndex = tonumber(user)
                if (newIndex > 0) then
                  changeLot(newIndex)
                  updateSelectMenu()
                end
              end
              if (AuctionHelperData[currentIndex] ~= nil) then
                stageNewLot()
              else
                d("reached the end")
              end
            end
          elseif command == "sb" then
            if (string.len(user) > 0) then
              setNewStartingBid(user)
            end
            stageStartingBid()
          end
    end
end

-- local function CreateCopyBuffer(buffer)
--   local copyBuffer = CircularBuffer:New(buffer:GetMaxHistoryLines())
--   table.insert(copyBufferList, copyBuffer)
--   return #copyBufferList
-- end

-- Load add-on resources
function AuctionHelper.OnAddOnLoaded(event, addonName)
  if addonName == AuctionHelper.name then
    AuctionHelper:Initialize()
  end
end

-- Initialize function
function AuctionHelper:Initialize()
  AuctionHelper.savedVariables = ZO_SavedVars:NewAccountWide("AuctionHelperVars", AuctionHelper.variableVersion, nil, AuctionHelper.Default)
  AuctionHelperData = AuctionHelper.savedVariables.AuctionHelperData
  d(AuctionHelper.savedVariables.AuctionHelperData)
  currentIndex = AuctionHelper.savedVariables.currentIndex
  AuctionHelper.ConsoleCommands()
  AuctionHelperDataWindow:SetHidden(true)
  AuctionHelperControlWindow:SetHidden(true)
  RestoreSavedLotData()
  AuctionHelperBuffer = AuctionHelper.CircularBuffer

  -- local AddWindow_Orig = SharedChatContainer.AddWindow
  -- SharedChatContainer.AddWindow = function(...)
  --     local window = AddWindow_Orig(...)
  --     local buffer = window.buffer

  --     -- we cannot access the messages in the native chat buffer object, so we have to save them separately ourselves.
  --     local copyBufferIndex = CreateCopyBuffer(buffer)

  --     local AddMessage_Orig = buffer.AddMessage
  --     buffer.AddMessage = function(self, message, ...)
  --       AddMessage_Orig(self, message, ...)
  --     end

  --     return window
  -- end

  EVENT_MANAGER:UnregisterForEvent(AuctionHelper.name, EVENT_ADD_ON_LOADED)
end

-- maybe can remove?
-- AuctionHelper.copyBufferList = copyBufferList

-- Finally, we'll register our event handler function to be called when the proper event occurs.
EVENT_MANAGER:RegisterForEvent(AuctionHelper.name, EVENT_ADD_ON_LOADED, AuctionHelper.OnAddOnLoaded)
SecurePostHook(SharedChatSystem, "ShowPlayerContextMenu", SetWinnerContextMenu)

  