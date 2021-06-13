--[=[
  Adapted from Kali's adaptation of kaiUI's info here display
  Mostly just shoved into an independent table and its own adjustable container
  for people to move around and adjust as they see fit
  I added player output to the top, and alphabetizing the display within the
  console, whether it's all the items individually or the collapsed and sorted
  version added by Kali's adjustments.
--]=]
-- BEGIN CONFIG
-- max number of items before we collapse the list
local maxSize = 33
-- font size for the info window
local fontSize = 10
-- automatically set wrapwidth?
local autoWrap = true
-- if autoWrap = false, how many characters should we wrap at?
local wrapAt = 40
-- display current players in the room at the top?
local showPlayers = true

-- END CONFIG
local timerRunning, writeTimer
demonIH = demonIH or {}
demonIH.itemsHere = demonIH.itemsHere or {}
demonIH.itemsSorted = demonIH.itemsSorted or {}
local infoColors = {
  t = "<DarkGoldenrod>",
  m = "<chartreuse>",
  mx = "<chartreuse>",
  mh = "<OrangeRed>",
  c = "<LightSkyBlue>",
  none = "<LightGoldenrod>",
  et = "<DarkGoldenrod>",
  mt = "<DarkGoldenrod>",
  cm = "<LightSkyBlue>",
}
local sortOrder = {"c", "none", "mx","mh", "m", "mt", "cm", "t", "et", "ct", "md", "mdt"}
local function sortFunc(t,a,b)
  local aname = t[a].name or ""
  local bname = t[b].name or ""
  aname = aname:lower()
  bname = bname:lower()
  if aname == bname then
    local aid = tonumber(t[a].id) or 0
    local bid = tonumber(t[b].id) or 0
    return aid < bid
  end
  return aname < bname
end
local containerConfig = {
  name = "demonIHContainer",
  x = 0,
  y = 275,
  height = 625,
  width = 400,
  titleText = ""
}

local defaultConsoleConfig = {
  name = "demonIHConsole",
  autoWrap = autoWrap,
  wrapAt = wrapAt,
  x = 0,
  y = 0,
  width = "100%",
  height = "95%",
  color = "black",
  fontSize = fontSize,
}

demonIH.container = demonIH.container or Adjustable.Container:new(containerConfig)
demonIH.console = demonIH.console or Geyser.MiniConsole:new(defaultConsoleConfig, demonIH.container)
local function printLine(number, name, attrib, spacing)
  local color = infoColors[attrib] or "<LightGoldenrod>"
  local echoString =
    string.rep(" ", spacing - #("" .. number)) ..
    "<LightYellow>[" ..
    color ..
    number ..
    color ..
    "<LightYellow>] " ..
    color ..
    name
  demonIH.console:cecho("\n" .. echoString)
end

local function addNDB(txt)
  local format = "<cyan>"
  local names = ndb.findnames(txt)
  if not names then return txt end
  local done = {}
  for _,name in pairs(names) do
    if not done[name] then
      local color = ndb.getcolor(name) or "<white>"
      if color == "" then -- they're a rogue, most likely, since the ndb has the name but returned "" as the color
        debugc("InfoHere window got '' from ndb.getcolor for " .. name .. ". We are assuming they are rogue and looking up the correct color in ndb.conf or mm.conf. If it can't find either it will fallback to white")
        color = ndb.roguescolor or mm.conf.roguescolor
        color = color or "<white>"
      end
      txt = txt:gsub(name, color .. name .. format)
      done[name] = true
    end
  end
  return txt
end
 
local function sortItems()
  demonIH.itemsSorted = {}
  for _, attrib in pairs(sortOrder) do
    demonIH.itemsSorted[attrib] = {}
  end
  for k, item in pairs(demonIH.itemsHere) do
    local attrib = item.attrib or "none"
    if not table.contains(sortOrder, attrib) then
      display(attrib)
    else
      demonIH.itemsSorted[attrib][item.name] = (demonIH.itemsSorted[attrib][item.name] or 0) + 1
    end
  end
end

function demonIH.writeItemsHere()
  if not timerRunning then
    timerRunning = true
    if writeTimer then
      killTimer(writeTimer)
    end
    writeTimer =
      tempTimer(
        0,
        function()
          timerRunning = false
          demonIH.writeItems2()
        end
      )
  end
end

function demonIH.writeItems2()
  demonIH.console:clear()
  local players = {}
  if showPlayers then
    local myname = gmcp.Char.Name.name
    for _,char in ipairs(gmcp.Room.Players) do
      if char.name ~= myname then
        players[#players + 1] = char.name
      end
    end
    table.sort(players)
    demonIH.console:cecho("<cyan>Players:\n")
    local playerString = " <cyan>None"
    if #players > 0 then
      playerString = " <cyan>" .. table.concat(players, "<white>,<cyan>") .. "<reset>"
      if ndb then playerString = addNDB(playerString) end
    end
    demonIH.console:cecho(playerString .. "\n")
  end
  demonIH.console:cecho("\n<yellow>Mobs & Items:")
  if #demonIH.itemsHere > maxSize then
    for _, attrib in ipairs(sortOrder) do
      for name, number in spairs(demonIH.itemsSorted[attrib]) do
        printLine(number, name, attrib, 3)
      end
    end
  else
    for _, item in spairs(demonIH.itemsHere, sortFunc) do
      printLine(item.id, item.name, item.attrib, 6)
    end
  end
end

function demonIH.onItemsList()
  if gmcp.Char.Items.List.location ~= "room" then
    return
  end
  demonIH.itemsHere = table.deepcopy(gmcp.Char.Items.List.items)
  if #demonIH.itemsHere > maxSize then
    sortItems()
  else
    demonIH.itemsSorted = nil
  end
  demonIH.writeItemsHere()
end

function demonIH.onItemsUpdate()
  if gmcp.Char.Items.Update.location ~= "room" then
    return
  end
  for index, item in pairs(demonIH.itemsHere) do
    if item.id == gmcp.Char.Items.Update.item.id then
      demonIH.itemsHere[index] = gmcp.Char.Items.Update.item
      if #demonIH.itemsHere > maxSize then
        sortItems()
      end
      demonIH.writeItemsHere()
      return
    end
  end
end

function demonIH.onItemsAdd()
  if gmcp.Char.Items.Add.location ~= "room" then
    return
  end
  local item = gmcp.Char.Items.Add.item
  table.insert(demonIH.itemsHere, item)
  if #demonIH.itemsHere > maxSize then
    if not demonIH.itemsSorted then
      sortItems()
    end
    demonIH.itemsSorted[item.attrib][item.name] = (demonIH.itemsSorted[item.attrib][item.name] or 0) + 1
    demonIH.writeItemsHere()
  else
    printLine(item.id, item.name, item.attrib, 6)
  end
end

function demonIH.onItemsRemove()
  if gmcp.Char.Items.Remove.location ~= "room" then
    return
  end
  local item = gmcp.Char.Items.Remove.item
  for index, item2 in pairs(demonIH.itemsHere) do
    if item2.id == item.id then
      table.remove(demonIH.itemsHere, index)
      demonIH.writeItemsHere()
      if demonIH.itemsSorted and demonIH.itemsSorted[item.attrib] then
        demonIH.itemsSorted[item.attrib][item.name] =
          (demonIH.itemsSorted[item.attrib][item.name] or 0) - 1
        if demonIH.itemsSorted[item.attrib][item.name] <= 0 then
          demonIH.itemsSorted[item.attrib][item.name] = nil
        end
      end
      return
    end
  end
end
demonIH.eventHandlers = demonIH.eventHandlers or {}
for _,handlerID in pairs(demonIH.eventHandlers) do
  killAnonymousEventHandler(handlerID)
end
demonIH.eventHandlers.list = registerAnonymousEventHandler("gmcp.Char.Items.List", "demonIH.onItemsList")
demonIH.eventHandlers.remove = registerAnonymousEventHandler("gmcp.Char.Items.Remove", "demonIH.onItemsRemove")
demonIH.eventHandlers.add = registerAnonymousEventHandler("gmcp.Char.Items.Add", "demonIH.onItemsAdd")
demonIH.eventHandlers.update = registerAnonymousEventHandler("gmcp.Char.Items.Update", "demonIH.onItemsUpdate")
