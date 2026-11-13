local games = {}
local filtered = {}
local searchText = ""
local loading = false
local errorMsg = ""
local scanCounter = 0
local building = false
local initOk = true
local selectedIndex = 0

local PAGE_SIZE = 12
local curPage = 1
local SPINE_W = 48
local CASE_H = 260
local CASE_W = 120

local steamCoverDir = ""
local heroicCoverDir = ""
local ok1, err1 = pcall(function()
  local xdgCache = noctalia.getenv("XDG_CACHE_HOME")
  local home = noctalia.getenv("HOME")
  local cacheBase
  if xdgCache and #xdgCache > 0 then
    cacheBase = xdgCache .. "/gamelauncher"
  elseif home and #home > 0 then
    cacheBase = home .. "/.cache/gamelauncher"
  else
    cacheBase = "/tmp/gamelauncher"
  end
  steamCoverDir = cacheBase .. "/steam"
  heroicCoverDir = cacheBase .. "/heroic"
  local ok, err = noctalia.mkdirAll(steamCoverDir)
  if not ok then noctalia.log("failed to create steam cover dir: " .. (err or "unknown")) end
  ok, err = noctalia.mkdirAll(heroicCoverDir)
  if not ok then noctalia.log("failed to create heroic cover dir: " .. (err or "unknown")) end
end)
if not ok1 then
  initOk = false
  noctalia.log("init error: " .. tostring(err1))
end

local binary = noctalia.pluginDir() .. "/gamelauncher"
local cSource = noctalia.pluginDir() .. "/gamelauncher.c"
local cReaderSource = noctalia.pluginDir() .. "/sqlite_reader.c"

local function buildCommand()
  return "cc -o " .. binary .. " " .. cSource .. " " .. cReaderSource
end

local buildTagFile
do
  local ok, dir = pcall(noctalia.pluginDataDir)
  if ok and dir then buildTagFile = dir .. "/build_command" end
end

local function binaryReady()
  if not noctalia.fileExists(binary) then return false end
  if not buildTagFile then return true end
  if noctalia.readFile(buildTagFile) ~= buildCommand() then
    noctalia.removeFile(binary)
    return false
  end
  return true
end

local function markBuilt()
  if buildTagFile then noctalia.writeFile(buildTagFile, buildCommand()) end
end

local function shellQuote(s)
  return '"' .. tostring(s):gsub('[\\$"`]', '\\%0') .. '"'
end

local function homeDir()
  local h = noctalia.getenv("HOME")
  if h and #h > 0 then return h end
  return "/home/" .. (noctalia.getenv("USER") or "user")
end

local function isValidProtocol(cmd)
  local protocols = { "steam://", "lutris:", "heroic://", "desktop://" }
  for _, p in ipairs(protocols) do
    if cmd:sub(1, #p) == p then
      local rest = cmd:sub(#p + 1)
      if rest:match("^[%w_%-%.%/]+$") then return true end
    end
  end
  return false
end

local function isRunnerEnabled(runner)
  local ok, val = pcall(noctalia.getConfig, runner .. "_enabled")
  if not ok then return true end
  if val == nil then return true end
  return val == true or val == "true"
end

local function filterByRunner(g)
  return isRunnerEnabled(g.runner)
end

local function launchGame(id)
  for _, g in ipairs(filtered) do
    if g.id == id and g.run_command and #g.run_command > 0 and isValidProtocol(g.run_command) then
      if g.run_command:sub(1, 10) == "desktop://" then
        noctalia.runAsync("gio launch " .. shellQuote(g.run_command:sub(11)))
      else
        noctalia.runAsync('xdg-open "' .. g.run_command .. '"')
      end
      onClose()
      return
    end
  end
end

local function filterGames(text)
  local pool = {}
  for _, g in ipairs(games) do
    if filterByRunner(g) then table.insert(pool, g) end
  end
  if text == "" then
    filtered = pool
    return
  end
  local lower = text:lower()
  local result = {}
  for _, g in ipairs(pool) do
    if g.name:lower():find(lower, 1, true) or g.runner:lower():find(lower, 1, true) then
      table.insert(result, g)
    end
  end
  filtered = result
end

local function clampNum(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function totalPages()
  return math.max(1, math.ceil(#filtered / PAGE_SIZE))
end

local function clampPage()
  curPage = clampNum(curPage, 1, totalPages())
end

local function ensureSelVisible()
  if #filtered == 0 then
    curPage = 1
    return
  end
  if selectedIndex < 0 then selectedIndex = 0 end
  if selectedIndex >= #filtered then selectedIndex = #filtered - 1 end
  curPage = math.floor(selectedIndex / PAGE_SIZE) + 1
end

local function launchSelected()
  if #filtered > 0 and selectedIndex >= 0 and selectedIndex < #filtered then
    launchGame(filtered[selectedIndex + 1].id)
  end
end

local function isImageFile(path)
  return noctalia.fileExists(path)
end

local function fetchSteamStoreCover(g, dest, cb)
  noctalia.http({ url = "https://store.steampowered.com/api/appdetails?appids=" .. g.id }, function(res2)
    pcall(function()
      if res2.ok and res2.status == 200 then
        local ok2, data2 = pcall(noctalia.json.decode, res2.body)
        if ok2 and data2 then
          local appData = data2[g.id]
          if appData and appData.data and appData.data.header_image then
            noctalia.download(appData.data.header_image, dest, function(ok3)
              pcall(function() if ok3 then g.cover = dest; render() end end)
            end)
            return
          end
        end
      end
    end)
  end)
end

local function fetchSteampoacherCover(g, dest, fallback)
  noctalia.http({ url = "https://steam-asset-proxy.steampoacher.workers.dev?appid=" .. g.id }, function(res)
    pcall(function()
      if res.ok and res.status == 200 then
        local ok, data = pcall(noctalia.json.decode, res.body)
        if ok and data and data.response and data.response.store_items then
          local item = data.response.store_items[1]
          if item and item.assets then
            local assets = item.assets
            local filename = assets.library_capsule_2x or assets.library_capsule or assets.header
            local fmt = assets.asset_url_format
            if filename and fmt then
              local placeholder = "${FILENAME}"
              local pos = fmt:find(placeholder, 1, true)
              local cdnUrl
              if pos then
                local prefix = fmt:sub(1, pos - 1)
                local suffix = fmt:sub(pos + #placeholder)
                cdnUrl = "https://shared.steamstatic.com/store_item_assets/" .. prefix .. filename .. suffix
              else
                cdnUrl = "https://shared.steamstatic.com/store_item_assets/" .. fmt .. "/" .. filename
              end
              noctalia.download(cdnUrl, dest, function(ok2)
                pcall(function()
                  if ok2 then g.cover = dest; render() return end
                  fallback()
                end)
              end)
              return
            end
          end
        end
      end
      pcall(function() fallback() end)
    end)
  end)
end

local function downloadSteamCover(g)
  local ok, err = pcall(function()
    if g.cover and #g.cover > 0 then return end
    local dest = steamCoverDir .. "/" .. g.id .. ".jpg"
    if isImageFile(dest) then
      g.cover = dest
      return
    end
    local steampoacherEnabled = false
    local okc, val = pcall(noctalia.getConfig, "steampoacher_enabled")
    if okc then
      steampoacherEnabled = val == true or val == "true"
    end
    if steampoacherEnabled then
      fetchSteampoacherCover(g, dest, function()
        fetchSteamStoreCover(g, dest)
      end)
    else
      fetchSteamStoreCover(g, dest)
    end
  end)
  if not ok then
    noctalia.log("downloadSteamCover error: " .. tostring(err))
  end
end

local function downloadHeroicCover(g)
  local ok, err = pcall(function()
    if g.cover and #g.cover > 0 then return end
    if not g.cover_url or #g.cover_url == 0 then return end
    local dest = heroicCoverDir .. "/" .. g.id .. ".jpg"
    if isImageFile(dest) then
      g.cover = dest
      return
    end
    noctalia.download(g.cover_url, dest, function(ok2)
      pcall(function()
        if ok2 then g.cover = dest; render() end
      end)
    end)
  end)
  if not ok then
    noctalia.log("downloadHeroicCover error: " .. tostring(err))
  end
end

local function fetchMissingCovers()
  for _, g in ipairs(games) do
    if g.runner == "steam" then
      downloadSteamCover(g)
    elseif g.runner == "heroic" then
      downloadHeroicCover(g)
    end
  end
end

local DESKTOP_GAMES = {
  "stellar-blade-gamescope",
  "mortal-kombat-1-gamescope",
  "gears-e-day-gamescope",
  "league-of-legends",
  "mortal-shell-2-gamescope",
  "ctr-nitro-fueled",
  "infamous-second-son",
  "hookshot",
}

local function parseDesktopEntry(id)
  local path = homeDir() .. "/.local/share/applications/" .. id .. ".desktop"
  if not noctalia.fileExists(path) then return nil end
  local text = noctalia.readFile(path)
  if not text or #text == 0 then return nil end

  local inGroup, name, icon, typ, cats, hidden = false, nil, nil, nil, nil, false
  for line in text:gmatch("[^\n]+") do
    if line:sub(1, 1) == "[" then
      inGroup = (line:match("^%[Desktop Entry%]") ~= nil)
    elseif inGroup then
      local k, v = line:match("^([%w%-]+)=(.*)$")
      if k then
        if k == "Name" and not name then
          name = v
        elseif k == "Icon" then
          icon = v
        elseif k == "Type" then
          typ = v
        elseif k == "Categories" then
          cats = v
        elseif k == "Hidden" or k == "NoDisplay" then
          if v:lower() == "true" then hidden = true end
        end
      end
    end
  end

  if hidden or typ ~= "Application" then return nil end
  if not name or name == "" then return nil end
  if cats and not cats:lower():find("game", 1, true) then return nil end

  local custom = homeDir() .. "/.local/share/noctalia/game-covers/" .. id .. ".jpg"
  local cover = (icon and noctalia.fileExists(icon)) and icon or ""
  if noctalia.fileExists(custom) then cover = custom end

  return {
    id = id,
    name = name,
    runner = "desktop",
    cover = cover,
    cover_url = "",
    run_command = "desktop://" .. path,
    slug = "",
  }
end

local function appendDesktopGames()
  for _, id in ipairs(DESKTOP_GAMES) do
    local entry = parseDesktopEntry(id)
    if entry then
      local duplicate = false
      for _, g in ipairs(games) do
        if g.id == entry.id or g.name == entry.name then
          duplicate = true
          break
        end
      end
      if not duplicate then table.insert(games, entry) end
    end
  end
end

local runnerMeta = {
  steam = { glyph = "brand-steam", color = "#66c0f4" },
  lutris = { glyph = "device-gamepad", color = "#ff6600" },
  heroic = { glyph = "app-window", color = "#a78bfa" },
  desktop = { glyph = "grid-dots", color = "#34d399" },
}

local function renderHeader()
  return ui.row({ align = "center", gap = 8 }, {
    ui.label({ text = "Games", fontSize = 18, fontWeight = "bold", flexGrow = 1 }),
    ui.label({ text = "(" .. #games .. ")", color = "on_surface_variant", fontSize = 12 }),
    ui.button({ glyph = "reload", variant = "ghost", onClick = "onRescan", tooltip = "Rescan" }),
    ui.button({ glyph = "close", variant = "ghost", onClick = "onClose" }),
  })
end

local function renderSearchBar()
  return ui.row({ align = "center", gap = 8 }, {
    ui.input({ key = "search_" .. scanCounter, placeholder = "Search games…", onChange = "onSearch", onSubmit = "onSubmitSearch", value = searchText, flexGrow = 1, focus = true }),
    ui.button({ glyph = "filter", variant = "ghost", visible = false }),
  })
end

local function renderStatus()
  if loading then
    return ui.row({ align = "center", justify = "center", flexGrow = 1 }, {
      ui.label({ text = "Scanning for games…", color = "on_surface_variant" }),
    })
  end
  if errorMsg ~= "" then
    return ui.column({ align = "center", justify = "center", flexGrow = 1, gap = 12 }, {
      ui.glyph({ name = "alert-circle", size = 40, color = "error" }),
      ui.label({ text = errorMsg, color = "error", maxWidth = 400, textAlign = "center" }),
      ui.button({ text = "Retry", variant = "primary", onClick = "onRescan" }),
    })
  end
  if #filtered == 0 then
    return ui.row({ align = "center", justify = "center", flexGrow = 1 }, {
      ui.label({
        text = #games == 0 and "No games found. Click the reload button to scan." or "No games match your search.",
        color = "on_surface_variant",
      }),
    })
  end
  return nil
end

local function renderGameSpine(g, index)
  local meta = runnerMeta[g.runner] or { glyph = "app-window", color = "on_surface_variant" }
  local isSelected = (index - 1) == selectedIndex
  
  local cp = (g.cover and #g.cover > 0) and g.cover or nil
  if not cp then
    if g.runner == "steam" then
      cp = steamCoverDir .. "/" .. g.id .. ".jpg"
    elseif g.runner == "heroic" then
      cp = heroicCoverDir .. "/" .. g.id .. ".jpg"
    end
  end
  
  local coverWidget
  if cp and noctalia.fileExists(cp) then
    coverWidget = ui.image({ 
      path = cp, 
      width = CASE_W - 16, 
      height = CASE_H - 100, 
      radius = 4, 
      fit = "cover" 
    })
  else
    coverWidget = ui.box({ 
      width = CASE_W - 16, 
      height = CASE_H - 100, 
      radius = 4, 
      fill = "surface_variant" 
    })
  end

  -- Título en el lomo (vertical)
  local spineLabel = ui.label({ 
    text = g.name, 
    fontWeight = "bold", 
    fontSize = 9, 
    maxLines = 1, 
    textAlign = "center",
    color = isSelected and "primary" or "on_surface",
    width = CASE_H - 40,
  })

  local runnerBadge = ui.row({ align = "center", gap = 3 }, {
    ui.glyph({ name = meta.glyph, size = 9, color = meta.color }),
    ui.label({ text = g.runner, fontSize = 8, color = "on_surface_variant" }),
  })

  local playBtn = ui.button({
    text = "",
    glyph = isSelected and "pause" or "play_arrow",
    variant = isSelected and "primary" or "ghost",
    size = 28,
    onClick = function() launchGame(g.id) end,
    tooltip = isSelected and "Playing..." or "Launch",
  })

  -- Contenido del lomo: carátula arriba, badge + play abajo, título en el lado
  local spineContent = ui.row({ align = "center", gap = 6 }, {
    -- Lado izquierdo: título vertical (el lomo)
    ui.box({ 
      width = 28, 
      height = CASE_H - 40, 
      radius = 2, 
      fill = isSelected and "primary" or "outline_variant",
      padding = 4,
    }, { 
      ui.label({ 
        text = g.name, 
        fontWeight = "bold", 
        fontSize = 9, 
        color = isSelected and "on_primary" or "on_surface_variant",
        maxLines = 1,
        textAlign = "center",
      }) 
    }),
    -- Centro: carátula + controles
    ui.column({ align = "center", gap = 6 }, {
      ui.box({ flexGrow = 1 }),
      coverWidget,
      runnerBadge,
      ui.box({ height = 4 }),
      playBtn,
      ui.box({ height = 8 }),
    }),
  })

  local bgFill = isSelected and "primary_container" or "surface"
  local borderColor = isSelected and "primary" or "outline_variant"
  local borderWidth = isSelected and 2 or 1

  return ui.box({
    key = g.id .. "_" .. index,
    width = CASE_W,
    height = CASE_H,
    radius = 8,
    padding = 6,
    gap = 4,
    align = "center",
    fill = bgFill,
    borderWidth = borderWidth,
    borderColor = borderColor,
    onClick = function() 
      selectedIndex = index - 1
      render()
    end,
  }, { spineContent })
end

local function renderShelf()
  clampPage()
  local spines = {}
  local startIdx = (curPage - 1) * PAGE_SIZE + 1
  local endIdx = math.min(startIdx + PAGE_SIZE - 1, #filtered)
  
  for i = startIdx, endIdx do
    table.insert(spines, renderGameSpine(filtered[i], i))
  end
  
  if #spines == 0 then return {} end
  
  local shelfRow = ui.row({ 
    align = "center", 
    justify = "center", 
    gap = 6, 
    flexGrow = 1,
    flexWrap = "nowrap",
  }, spines)
  
  -- Estantería de cristal: fondo semitransparente + baldas
  return ui.box({
    fill = "surface",
    padding = 16,
    radius = 16,
    gap = 16,
  }, {
    -- Balda superior (cristal)
    ui.box({ 
      height = 4, 
      radius = 2, 
      fill = "outline",
    }),
    -- Hilera de juegos
    shelfRow,
    -- Balda inferior (cristal)
    ui.box({ 
      height = 4, 
      radius = 2, 
      fill = "outline",
    }),
  })
end

local function renderBody(content)
  if loading then
    return ui.label({ text = "Scanning for games…", color = "on_surface_variant" })
  end
  if errorMsg ~= "" then
    return ui.column({ align = "center", justify = "center", gap = 12 }, {
      ui.glyph({ name = "alert-circle", size = 40, color = "error" }),
      ui.label({ text = errorMsg, color = "error", maxWidth = 400, textAlign = "center" }),
      ui.button({ text = "Retry", variant = "primary", onClick = "onRescan" }),
    })
  end
  if #filtered == 0 then
    return ui.label({
      text = #games == 0 and "No games found. Click the reload button to scan." or "No games match your search.",
      color = "on_surface_variant",
    })
  end
  return content
end

local function computeLayout()
  PAGE_SIZE = 10
  CASE_H = 260
  CASE_W = 120
  local h = outputLogicalHeight()
  if h then
    local caseH = clampNum(math.floor((h - 200) / 1.2 - 40), 200, 320)
    CASE_H = caseH
    CASE_W = math.floor(caseH * 0.46)
  end
end

local function outputLogicalHeight()
  local ok, outs = pcall(noctalia.outputs)
  if not (ok and type(outs) == "table" and #outs > 0) then return nil end
  local target = outs[1]
  local okf, focused = pcall(noctalia.focusedOutputName)
  if okf and focused then
    for _, o in ipairs(outs) do
      if type(o) == "table" and o.name == focused then
        target = o
        break
      end
    end
  end
  if type(target) ~= "table" or type(target.height) ~= "number" then return nil end
  local scale = (type(target.scale) == "number" and target.scale > 0) and target.scale or 1
  return target.height / scale
end

local function render()
  local ok, err = pcall(function()
    local okm, modem = pcall(noctalia.getConfig, "panel_mode")
    if okm and modem == "original" then
      panel.close()
      return
    end
    computeLayout()
    local body = renderBody(renderShelf())
    panel.render(ui.column({ flexGrow = 1, gap = 0, align = "stretch" }, {
      ui.column({ gap = 8, paddingH = 16, paddingV = 16 }, {
        renderHeader(),
        renderSearchBar(),
      }),
      ui.separator({ thickness = 1, color = "surface_variant" }),
      ui.box({ 
        flexGrow = 1, 
        fill = "surface", 
        padding = 16,
        radius = 12,
      }, { body }),
    }))
  end)
  if not ok then
    noctalia.log("render error: " .. tostring(err))
  end
end

local function buildBinary()
  if building then return end
  building = true
  loading = true
  errorMsg = ""
  render()
  local cmd = buildCommand()
  local ok = noctalia.runAsync(cmd, function(res)
    building = false
    if res.exitCode == 0 then
      loading = false
      markBuilt()
      scanGames()
    else
      loading = false
      errorMsg = "Failed to build gamelauncher. Install gcc. (exit " .. (res.exitCode or "?") .. ")"
      noctalia.log("build failed (cmd: " .. cmd .. "): " .. (res.stderr or "no stderr"))
      render()
    end
  end)
  if not ok then
    building = false
    loading = false
    errorMsg = "Failed to start build process"
    render()
  end
end

function scanGames()
  if loading or building then return end
  if not binaryReady() then
    buildBinary()
    return
  end
  loading = true
  errorMsg = ""
  scanCounter = scanCounter + 1
  searchText = ""
  render()
  local flags = ""
  if isRunnerEnabled("steam") then flags = flags .. " --steam" end
  if isRunnerEnabled("lutris") then flags = flags .. " --lutris" end
  if isRunnerEnabled("heroic") then flags = flags .. " --heroic" end
  local ok = noctalia.runAsync(binary .. flags .. " --force", function(res)
    local ok3, err3 = pcall(function()
      loading = false
      if res.exitCode == 0 and res.stdout and #res.stdout > 0 then
        local parsed, err2 = noctalia.json.decode(res.stdout)
        if parsed then
          games = parsed
          pcall(appendDesktopGames)
          pcall(noctalia.state.set, "games", games)
          fetchMissingCovers()
        else
          errorMsg = "Failed to parse game list: " .. (err2 or "unknown error")
          noctalia.log("parse error on stdout: " .. res.stdout:sub(1, 200))
          games = {}
        end
      else
        errorMsg = "Game scan failed (exit " .. (res.exitCode or "?") .. ")"
        if res.stderr and #res.stderr > 0 then
          errorMsg = errorMsg .. ": " .. res.stderr:sub(1, 200)
        end
        games = {}
      end
      selectedIndex = 0
      curPage = 1
      filterGames(searchText)
    end)
    if not ok3 then
      loading = false
      errorMsg = "Scan error: " .. tostring(err3)
      games = {}
      filtered = games
      selectedIndex = 0
      curPage = 1
      noctalia.log("scan callback error: " .. tostring(err3))
    end
    render()
  end)
  if not ok then
    loading = false
    errorMsg = "Failed to start game scan"
    render()
  end
end

function onOpen(context)
  local ok, mode = pcall(noctalia.getConfig, "panel_mode")
  if ok and mode == "original" then
    if noctalia.state.get("o_open") == true then
      noctalia.state.set("o_open", false)
      panel.close()
      return
    end
    panel.close()
    noctalia.togglePanel("alexander/game-launcher:original")
    return
  end
  noctalia.state.set("o_open", false)
  computeLayout()
  selectedIndex = 0
  curPage = 1
  filterGames(searchText)
  render()
  scanGames()
end

function onClose()
  panel.close()
end

function onRescan()
  scanGames()
end

function onSearch(value)
  searchText = value or ""
  selectedIndex = 0
  curPage = 1
  filterGames(searchText)
  render()
end

function onKey(chord, pressed)
  if not pressed then return end
  if chord == "Left" then
    if #filtered > 0 then
      selectedIndex = selectedIndex - 1
      if selectedIndex < 0 then selectedIndex = 0 end
      ensureSelVisible()
      render()
    end
  elseif chord == "Right" then
    if #filtered > 0 then
      selectedIndex = selectedIndex + 1
      if selectedIndex >= #filtered then selectedIndex = 0 end
      ensureSelVisible()
      render()
    end
  elseif chord == "Return" then
    launchSelected()
  elseif chord == "PageUp" then
    curPage = curPage - 1
    clampPage()
    selectedIndex = (curPage - 1) * PAGE_SIZE
    ensureSelVisible()
    render()
  elseif chord == "PageDown" then
    curPage = curPage + 1
    clampPage()
    selectedIndex = (curPage - 1) * PAGE_SIZE
    ensureSelVisible()
    render()
  end
end

function onSubmitSearch()
  launchSelected()
end