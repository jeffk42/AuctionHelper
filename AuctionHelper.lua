-- First, we create a namespace for our addon by declaring a top-level table that will hold everything else.
AuctionHelper = {}
local AuctionHelperData = {}
local currentIndex = 0
local currentBid = ""
local currentWinner = ""
local currentEstimate = ""
 
-- This isn't strictly necessary, but we'll use this string later when registering events.
-- Better to define it in a single place rather than retyping the same string.
AuctionHelper.name = "AuctionHelper"
 
-- Next we create a function that will initialize our addon
function AuctionHelper:Initialize()
  -- ...but we don't have anything to initialize yet. We'll come back to this.
  AuctionHelper.ConsoleCommands()
  AuctionHelperDataWindow:SetHidden(false)
  -- ScrollListExampleMainWindow:SetText("the message")
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
  currentWinner = rawName
  d(string.format("-- Current High Bidder set to %s --", rawName))
end

local function MyShowPlayerContextMenu(playerData, rawName)
  AddCustomMenuItem("Set Current Winner", function() setCurrentWinner(rawName) end)
  AddCustomMenuItem("Sold To " .. rawName, function() handleSoldBid(rawName) end)
  
  ShowMenu()
end

function AuctionHelperDataField_OnTextChanged (self)
  AuctionHelperData = {}
  s = AuctionHelperDataWindowBody1Field:GetText()
  for index, title, est, st in string.gmatch( s, "^(%d+),(.-),[\"\$]*(.-)[\"]*,\"\$.-\",\"\$(.-)\",.-[\n]" ) do
      inum = tonumber(index)
      AuctionHelperData[inum] = {title="", estimated="", start=""}
      -- Trim the edges of the title
      title = string.match(title, "^[%s]*(.-)[%s]*$")
      -- Reduce extra whitespace
      title = string.gsub(title, "[ \t]+", " ")
      AuctionHelperData[inum].title = title
      AuctionHelperData[inum].estimated = est
      AuctionHelperData[inum].start = st
  end
  
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
            d("/a                  Show or hide the data reader window")
            d("/a lc [bid] [estimated]  Print the last call for bids. Estimated value is optional")
            d("/a g1 [bid]                 [bid] going once!")
            d("/a g2 [bid]                 [bid] going twice!")
            d("/a sold [user] [bid]        Print SOLD message")
          elseif command == "lc" then
            if (string.len(user) <= 0) then
              d('not enough parameters. input ignored.')
            else
              if (string.len(value) > 0) then
                estimated = value
                currentEstimate = estimated
              end
              value = user
              currentBid = value
              if (string.len(estimated) > 0) then
                StartChatInput(string.format("%s is the current top bid, estimated value is %s, any other bids?", value, estimated))
              else
                StartChatInput(string.format("%s is the current top bid, any other bids?", value))
              end
            end
          elseif command == "b" then
            currentBid = user
            d(string.format("-- Current top bid set to %s --", currentBid));
          elseif command == "g1" then
            -- value = user
            StartChatInput(string.format("%s going once!", currentBid))
          elseif command == "g2" then
            value = user
            StartChatInput(string.format("%s going twice!", currentBid))
          elseif command == "sold" then
            StartChatInput(string.format("SOLD to %s for %s! Congrats! Please MAIL your winning bid to @AKTT-auction as soon as possible so we can get your item(s) sent out promptly!", currentWinner, currentBid))
          elseif command == "" then
            AuctionHelperDataWindow:SetHidden(false)
          elseif command == "go" then
            if (string.len(user) > 0) then
              if (string.lower(user) == "next") then
                currentIndex = currentIndex + 1
              else
                local newIndex = tonumber(user)
                if (newIndex > 0) then
                  currentIndex = newIndex
                end
              end
              if (AuctionHelperData[currentIndex] ~= nil) then
                d(string.format("==== Lot #%d: %s ====", currentIndex, AuctionHelperData[currentIndex].title))
              else
                d("reached the end")
              end
            end
          elseif command == "sb" then
            local bid = ""
            if (string.len(user) > 0) then
              bid = user
            else
              bid = AuctionHelperData[currentIndex].start
            end
            d(string.format("<<< Starting bid for this lot: %s >>>", bid))
          end
    end
end

-- Finally, we'll register our event handler function to be called when the proper event occurs.
EVENT_MANAGER:RegisterForEvent(AuctionHelper.name, EVENT_ADD_ON_LOADED, AuctionHelper.OnAddOnLoaded)
SecurePostHook(SharedChatSystem, "ShowPlayerContextMenu", MyShowPlayerContextMenu)




-- test window
  
  -- function SLE.MouseEnter(control)
  --   SLE.UnitList:Row_OnMouseEnter(control)
  -- end
  
  -- function SLE.MouseExit(control)
  --   SLE.UnitList:Row_OnMouseExit(control)
  -- end
  
  -- function SLE.MouseUp(control, button, upInside)
  --   local cd = control.data
  --   d(table.concat( { cd.name, cd.race, cd.class, cd.zone }, " "))
  -- end
  
--  function SLE.TrackUnit()
--    local targetName = GetUnitName("reticleover")
--    if targetName == "" then return end
--    local targetRace = GetUnitRace("reticleover")
--    local targetClass = GetUnitClass("reticleover")
--    local targetZone = GetUnitZone("reticleover")
--    SLE.units[targetName] = {race=tagetRace, class=targetClass, zone=targetZone}
--    SLE.UnitList:Refresh()
--  end
  
  -- do all this when the addon is loaded
  -- function .Init(eventCode, addOnName)
  --   if addOnName ~= "AuctionHelper" then return end
  
    -- Event Registration
    -- EVENT_MANAGER:RegisterForEvent("SLE_RETICLE_TARGET_CHANGED", EVENT_RETICLE_TARGET_CHANGED, SLE.TrackUnit)
  
    -- SLE.UnitList = UnitList:New()
    -- local playerName = GetUnitName("player")
    -- local playerRace = GetUnitRace("player")
    -- local playerClass = GetUnitClass("player")
    -- local playerZone = GetUnitZone("player")
    -- SLE.units[playerName] = {race=playerRace, class=playerClass, zone=playerZone}
    -- SLE.UnitList:Refresh()
  
    
  -- end
  
  -- EVENT_MANAGER:RegisterForEvent("SLE_Init", EVENT_ADD_ON_LOADED , SLE.Init)

  