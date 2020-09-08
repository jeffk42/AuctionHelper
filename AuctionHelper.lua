-- First, we create a namespace for our addon by declaring a top-level table that will hold everything else.
AuctionHelper = {}
local AuctionHelperData = {}
local currentIndex = 0
 
-- Add-on name for registering events
AuctionHelper.name = "AuctionHelper"
 
-- Initialize function
function AuctionHelper:Initialize()
  AuctionHelper.ConsoleCommands()
  AuctionHelperDataWindow:SetHidden(true)
  AuctionHelperControlWindow:SetHidden(true)
end
 
-- Then we create an event handler function which will be called when the "addon loaded" event
-- occurs. We'll use this to initialize our addon after all of its resources are fully loaded.
function AuctionHelper.OnAddOnLoaded(event, addonName)
  -- The event fires each time *any* addon loads - but we only care about when our own addon loads.
  if addonName == AuctionHelper.name then
    AuctionHelper:Initialize()
  end
end

local function handleSoldBid(rawName)
  StartChatInput(string.format("SOLD to %s for %s! Congrats! Please MAIL your winning bid to @AKTT-auction as soon as possible so we can get your item(s) sent out promptly!", rawName, currentBid))
end

local function setCurrentWinner(rawName)
  AuctionHelperData[currentIndex].winner = rawName
  d(string.format("-- Current High Bidder set to %s --", rawName))
  updateWindowFields()
end

local function MyShowPlayerContextMenu(playerData, rawName)
  AddCustomMenuItem("Set Current Winner", function() setCurrentWinner(rawName) end)
  AddCustomMenuItem("Sold To " .. rawName, function() handleSoldBid(rawName) end)
  
  ShowMenu()
end

function AuctionHelperDataField_OnTextChanged (self)
  d("text changed")
  AuctionHelperData = {}
  AuctionHelperControlWindowLotList.m_comboBox:ClearItems()
  d("items cleared")
  s = AuctionHelperDataWindowBody1Field:GetText()
  d("text received")
  for index, title, est, st in string.gmatch( s, "^(%d+),(.-),[\"\$]*(.-)[\"]*,\"\$.-\",[\"\$]*(.-[,%d]*)[\"]*,.-[\n]" ) do
      d(string.format("Generating Lot #%s...", index))
      local inum = tonumber(index)
      AuctionHelperData[inum] = {index = 0, title="", estimated="", start="", winner="", winbid=""}
      -- Trim the edges of the title
      title = string.match(title, "^[%s]*(.-)[%s]*$")
      est = string.match(est, "^[%s]*(.-)[%s]*$")
      st = string.match(st, "^[%s]*(.-)[%s]*$")
      -- Reduce extra whitespace
      title = string.gsub(title, "[ \t]+", " ")
      AuctionHelperData[inum].index = inum
      AuctionHelperData[inum].title = title
      AuctionHelperData[inum].estimated = est
      AuctionHelperData[inum].start = st
      AuctionHelperData[inum].winner = ""
      AuctionHelperData[inum].winbid = ""
      local itemEntry = ZO_ComboBox:CreateItemEntry(string.format("%d: %s", inum, title), function() fireSelectionChanged(AuctionHelperData[inum]) end )
      AuctionHelperControlWindowLotList.m_comboBox:AddItem(itemEntry)
  end
  selectLotItem(AuctionHelperData[1])
end

function fireSelectionChanged(item)
  changeLot(item.index)
  updateWindowFields()
end

function selectLotItem(item)
  d(string.format("item selected: %s", item.title))
  changeLot(item.index)
  updateWindowFields()
  AuctionHelperControlWindowLotList.m_comboBox:SelectItem(AuctionHelperControlWindowLotList.m_comboBox:GetItems()[currentIndex])
end

function changeLot(newLotNumber)
  if (AuctionHelperData[newLotNumber] ~= nil) then
    currentIndex = newLotNumber
  else
    d("ERROR: chosen lot number doesn't exist")
  end
end

function updateWindowFields()
  AuctionHelperControlWindowLotNumLabel:SetText(string.format("Lot #%d", currentIndex))
  AuctionHelperControlWindowLotNameLabel:SetText(string.format("Title: %s", AuctionHelperData[currentIndex].title))
  AuctionHelperControlWindowEstimatedLabel:SetText(string.format("Estimated Value: %s", AuctionHelperData[currentIndex].estimated))
  AuctionHelperControlWindowMinimumLabel:SetText(string.format("Starting Bid: %s",AuctionHelperData[currentIndex].start))
  AuctionHelperControlWindowCurrentBidderLabel:SetText(string.format("Current High Bidder: %s",AuctionHelperData[currentIndex].winner))
  AuctionHelperControlWindowCurrentBidLabel:SetText(string.format("Current High Bid: %s",AuctionHelperData[currentIndex].winbid))
end

function setCurrentHighBid(value)
  AuctionHelperData[currentIndex].winbid = value
  updateWindowFields()
  d(string.format("-- Current top bid set to %s --", AuctionHelperData[currentIndex].winbid))
end

function stageGoingOnce()
  StartChatInput(string.format("%s going once!", AuctionHelperData[currentIndex].winbid))
end

function stageGoingTwice()
  StartChatInput(string.format("%s going twice!", AuctionHelperData[currentIndex].winbid))
end

function stageSoldMessage()
  StartChatInput(string.format("SOLD to %s for %s! Congrats! Please MAIL your winning bid to @AKTT-auction as soon as possible so we can get your item(s) sent out promptly!", AuctionHelperData[currentIndex].winner, AuctionHelperData[currentIndex].winbid))
end

function stageNewLot()
  StartChatInput(string.format("==== Lot #%d: %s ====", currentIndex, AuctionHelperData[currentIndex].title))
end

function stageStartingBid()
  if (string.lower(AuctionHelperData[currentIndex].start) == "flash") then
    StartChatInput(string.format("FLASH LOT! Estimated value: %s. Wait for the GO, and you have 30 SECONDS to bid. Highest bid when I say STOP gets the lot!", AuctionHelperData[currentIndex].estimated))
  else
    StartChatInput(string.format("<<< Starting bid for this lot: %s >>>", AuctionHelperData[currentIndex].start))
  end
end

function setNewStartingBid(num)
  AuctionHelperData[currentIndex].start = num
  updateWindowFields()
end

function setNewEstimatedValue(num)
  AuctionHelperData[currentIndex].estimated = num
  updateWindowFields()
end

function stageLastCallWithEstimated()
  StartChatInput(string.format("%s is the current top bid, estimated value is %s, any other bids?", AuctionHelperData[currentIndex].winbid, AuctionHelperData[currentIndex].estimated))
end

function stageLastCall()
  StartChatInput(string.format("%s is the current top bid, any other bids?", AuctionHelperData[currentIndex].winbid))
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
            setCurrentHighBid(user)
          elseif command == "g1" then
            if (string.len(user) > 0) then
              setCurrentHighBid(user)
            end
            stageGoingOnce()
          elseif command == "g2" then
            if (string.len(user) > 0) then
              setCurrentHighBid(user)
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
              else
                local newIndex = tonumber(user)
                if (newIndex > 0) then
                  changeLot(newIndex)
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

-- Finally, we'll register our event handler function to be called when the proper event occurs.
EVENT_MANAGER:RegisterForEvent(AuctionHelper.name, EVENT_ADD_ON_LOADED, AuctionHelper.OnAddOnLoaded)
SecurePostHook(SharedChatSystem, "ShowPlayerContextMenu", MyShowPlayerContextMenu)

  