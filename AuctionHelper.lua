-- First, we create a namespace for our addon by declaring a top-level table that will hold everything else.
AuctionHelper = {}
 
-- This isn't strictly necessary, but we'll use this string later when registering events.
-- Better to define it in a single place rather than retyping the same string.
AuctionHelper.name = "AuctionHelper"
 
-- Next we create a function that will initialize our addon
function AuctionHelper:Initialize()
  -- ...but we don't have anything to initialize yet. We'll come back to this.
  AuctionHelper.ConsoleCommands()
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
  StartChatInput(string.format("SOLD to %s for MONEY! Congrats!", rawName))
end

local function MyShowPlayerContextMenu(playerDatas, rawName)
  AddCustomMenuItem("Sold To " .. rawName, function() handleSoldBid(rawName) end)
  ShowMenu()
end



function AuctionHelper:ConsoleCommands()

    SLASH_COMMANDS["/auc"] = function(param)

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
            d("/auc                  Show or hide the window. <not implemented>")
            d("/auc call [bid] [estimated]  Print the last call for bids. Estimated value is optional")
            d("/auc g1 [bid]                 [bid] going once!")
            d("/auc g2 [bid]                 [bid] going twice!")
            d("/auc sold [user] [bid]        Print SOLD message")
          elseif command == "call" then
            if (string.len(user) <= 0) then
              d("Input ignored, not enough parameters")
            else
              if (string.len(value) > 0) then
                estimated = value
              end
              value = user
              if (string.len(estimated) > 0) then
                StartChatInput(string.format("%s is the current top bid, estimated value is %s, any other bids?", value, estimated))
              else
                StartChatInput(string.format("%s is the current top bid, any other bids?", value))
              end
            end
          elseif command == "g1" then
            value = user
            StartChatInput(string.format("%s going once!", value))
          elseif command == "g2" then
            value = user
            StartChatInput(string.format("%s going twice!", value))
          elseif command == "sold" then
            StartChatInput(string.format("SOLD to %s for %s! Congrats!", value))
          end
    end
end

-- Finally, we'll register our event handler function to be called when the proper event occurs.
EVENT_MANAGER:RegisterForEvent(AuctionHelper.name, EVENT_ADD_ON_LOADED, AuctionHelper.OnAddOnLoaded)
SecurePostHook(SharedChatSystem, "ShowPlayerContextMenu", MyShowPlayerContextMenu)