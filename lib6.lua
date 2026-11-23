--!nocheck
--[[ ==========================================================================
     Library.lua — "lowercase dark dashboard" UI library
     Self-contained. Returns the Library table. No demo UI. No prints on load.
     ========================================================================== ]]

local Library = {}
Library.Flags = {}
Library.Version = "1.0.0"

--============================================================================
-- SERVICES / SAFE GLOBALS
--============================================================================
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService      = game:GetService("TextService")
local RunService       = game:GetService("RunService")
local StatsService     = game:GetService("Stats")
local LocalPlayer      = Players.LocalPlayer

local function tryCall(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res end
    return nil
end

local MarketplaceService = tryCall(function() return game:GetService("MarketplaceService") end)
local HttpService        = tryCall(function() return game:GetService("HttpService") end)
local ContentProvider    = tryCall(function() return game:GetService("ContentProvider") end)

-- executor globals, all guarded ------------------------------------------------
local cloneref = (function()
    local f = tryCall(function() return getgenv and getgenv().cloneref end)
    if type(f) == "function" then return f end
    f = tryCall(function() return getfenv().cloneref end)
    if type(f) == "function" then return f end
    return function(o) return o end
end)()

local function protectGui(gui)
    tryCall(function() if type(protect_gui) == "function" then protect_gui(gui) end end)
    tryCall(function() if type(syn) == "table" and type(syn.protect_gui) == "function" then syn.protect_gui(gui) end end)
end

local function getHiddenUI()
    local h = tryCall(function()
        if type(gethui) == "function" then return gethui() end
    end)
    if h then return h end
    return nil
end

--============================================================================
-- SMALL HELPERS
--============================================================================
-- text objects created through new() are registered here so the Text Size
-- setting can retune every label in the menu at once
local TextSizeBindings = {}

-- font-related properties are applied before the text itself so a label never
-- renders a frame in the default (Arial-like) fallback font
local TEXT_PROPS_FIRST = {
    Font = true, TextSize = true, TextColor3 = true,
    RichText = true, TextScaled = true, LineHeight = true,
}

local function new(class, props, parent)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" and TEXT_PROPS_FIRST[k] then
                pcall(function() inst[k] = v end)
            end
        end
        for k, v in pairs(props) do
            if k ~= "Parent" and not TEXT_PROPS_FIRST[k] then
                pcall(function() inst[k] = v end)
            end
        end
        if props.TextSize and (inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox")) then
            table.insert(TextSizeBindings, { inst = inst, base = props.TextSize - (Library._textBoost or 2) })
        end
    end
    if parent then inst.Parent = parent end
    return inst
end

local function tween(inst, props, time, style, dir)
    local t = TweenService:Create(
        inst,
        TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    )
    t:Play()
    return t
end

local function textWidth(text, size, font)
    local ok, v = pcall(function()
        return TextService:GetTextSize(text, size, font, Vector2.new(4000, 200))
    end)
    if ok and v then return v.X end
    return #tostring(text) * (size * 0.55)
end

--============================================================================
-- THEME
--============================================================================
local Theme = {
    Window   = Color3.fromHex("111113"),
    Sidebar  = Color3.fromHex("0c0c0e"),
    Card     = Color3.fromHex("18181b"),
    Input    = Color3.fromHex("202024"),
    Text     = Color3.fromHex("f2f2f4"),
    Muted    = Color3.fromHex("8c8c94"),
    Hint     = Color3.fromHex("5d5d65"),
    Accent   = Color3.fromHex("f5a6c6"),
    Danger   = Color3.fromHex("f0525f"),
    Divider  = Color3.fromRGB(255, 255, 255),
    DividerT = 0.93,
}
Library.Theme = Theme

-- Builder Sans (Roblox's built-in UI font). Enum.Font has no SemiBold weight, so
-- SEMI maps to Bold and BOLD to ExtraBold to keep a visible hierarchy.
local FONT_MED    = Enum.Font.BuilderSansMedium
local FONT_SEMI   = Enum.Font.BuilderSansBold
local FONT_BOLD   = Enum.Font.BuilderSansExtraBold

-- Every text size in the library goes through T(): Library._textBoost grows/shrinks
-- all text at once (changed live by the Text Size slider in the settings).
Library._textBoost = 2
local function T(n) return n + (Library._textBoost or 2) end

--============================================================================
-- ACCENT REGISTRY
--============================================================================
local AccentBindings   = {}   -- {inst=, prop=}
local AccentCallbacks  = {}   -- function(color)

local function accent(inst, prop)
    inst[prop] = Theme.Accent
    table.insert(AccentBindings, {inst = inst, prop = prop})
    return inst
end

local function onAccentChange(fn)
    table.insert(AccentCallbacks, fn)
end

function Library:SetAccent(color)
    Theme.Accent = color
    for i = #AccentBindings, 1, -1 do
        local b = AccentBindings[i]
        if b.inst and b.inst.Parent then
            pcall(function() b.inst[b.prop] = color end)
        else
            table.remove(AccentBindings, i)
        end
    end
    for _, fn in ipairs(AccentCallbacks) do
        pcall(fn, color)
    end
end

-- Theme presets (accent colours). Add your own with Library:AddTheme("name", Color3).
Library.Themes = {
    { Name = "Pastel Pink", Color = Color3.fromHex("f5a6c6") },
    { Name = "Soft Mint",   Color = Color3.fromHex("a6f5cf") },
    { Name = "Sky Blue",    Color = Color3.fromHex("a6c8f5") },
    { Name = "Warm Peach",  Color = Color3.fromHex("f5c9a6") },
    { Name = "Lilac",       Color = Color3.fromHex("c9a6f5") },
}
Library._themeName = "Pastel Pink"

function Library:AddTheme(name, color)
    table.insert(self.Themes, { Name = name, Color = color })
end

function Library:SetTheme(name)
    for _, th in ipairs(self.Themes) do
        if th.Name == name then
            self._themeName = name
            self:SetAccent(th.Color)
            return true
        end
    end
    return false
end

-- Menu scale (1 = normal). Applied to the window through a UIScale.
Library._scale = 1
function Library:SetScale(s)
    s = math.clamp(tonumber(s) or 1, 0.6, 1.6)
    self._scale = s
    if self._scaleObj and self._scaleObj.Parent then
        tween(self._scaleObj, { Scale = s }, 0.18, Enum.EasingStyle.Quint)
    end
end

-- Text size boost (pixels added to every text size). Driven by the Text Size slider.
function Library:SetTextSize(b)
    b = math.clamp(tonumber(b) or 2, 0, 8)
    self._textBoost = b
    for i = #TextSizeBindings, 1, -1 do
        local t = TextSizeBindings[i]
        if t.inst and t.inst.Parent then
            pcall(function() t.inst.TextSize = t.base + b end)
        else
            table.remove(TextSizeBindings, i)
        end
    end
end

--============================================================================
-- CONNECTION REGISTRY
--============================================================================
Library._connections = {}
function Library:_connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(self._connections, c)
    return c
end
local function connect(signal, fn)
    return Library:_connect(signal, fn)
end

--============================================================================
-- FLAGS
--============================================================================
Library._flagListeners = {}

function Library:_onFlag(flag, fn)
    if not flag then return end
    self._flagListeners[flag] = self._flagListeners[flag] or {}
    table.insert(self._flagListeners[flag], fn)
end

function Library:_setFlag(flag, value)
    if not flag then return end
    self.Flags[flag] = value
    local list = self._flagListeners[flag]
    if list then
        for _, fn in ipairs(list) do pcall(fn, value) end
    end
end

--============================================================================
-- ICONS
--  Fill these in with your own ids. Any empty / missing entry falls back to
--  the built-in asset-free ring icon.  Format: "rbxassetid://1234567890"
--============================================================================
local Icons = {
    -- built-in UI icons
    logo      = "rbxassetid://88968374981330",   -- menu logo
    settings  = "rbxassetid://84360896671248",   -- settings gear (next to the search bar)
    arrowDown  = "rbxassetid://118775691894307",  -- unexpanded / collapsed
    arrowUp    = "rbxassetid://136920335013389",  -- expanded
    arrowRight = { "rbxassetid://88968374981330", "rbxassetid://109028225963082" }, -- submenu arrow (asset id, texture id fallback)
    resize     = "rbxassetid://90927792586571",   -- window resize grip

    -- >>> put your own ids here (or pass Icon = "rbxassetid://..." / a number anywhere) <<<
    home      = "",
    search    = "",
    user      = "",
    sparkle   = "",
    sliders   = "",
    shield    = "",
    dot       = "",
}
Library.Icons = Icons

-- swap this for a real soft-shadow 9-slice if you have one
local SHADOW_IMAGE = ""

-- accepts "rbxassetid://123", "123", 123, a name from Library.Icons, or {Image=...}
local function normalizeId(v)
    if type(v) == "number" then return "rbxassetid://" .. tostring(math.floor(v)) end
    if type(v) == "string" then
        if v == "" then return nil end
        if v:match("^%d+$") then return "rbxassetid://" .. v end
        return v
    end
    return nil
end

-- resolves an asset id (image, decal or texture) into a url an ImageLabel can
-- actually display, using the thumbnail api when the executor allows HttpGet
local function fetchThumbnailUrl(num)
    local decoded = tryCall(function()
        return HttpService:JSONDecode(game:HttpGet(
            "https://thumbnails.roblox.com/v1/assets?assetIds=" .. num .. "&size=150x150&format=Png"
        ))
    end)
    if type(decoded) == "table" and decoded.data and decoded.data[1]
        and decoded.data[1].state == "Completed" and type(decoded.data[1].imageUrl) == "string" then
        return decoded.data[1].imageUrl
    end
    return nil
end

local function buildRing(holder, color, zindex)
    local ring = new("Frame", {
        Name = "IconRing",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.7, 0.7),
        BackgroundTransparency = 1,
        ZIndex = zindex or holder.ZIndex,
    }, holder)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
    new("UIStroke", { Color = color, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, ring)
    return ring
end

-- accepts "rbxassetid://123", "123", 123, a name from Library.Icons, {Image=...}
-- or a list of fallback ids (each one is tried until one loads)
local function resolveIcon(def)
    local candidates = {}
    local function push(v)
        local id = normalizeId(v)
        if id then table.insert(candidates, id) end
    end
    if type(def) == "string" then
        local named = Icons[def]
        if type(named) == "table" then
            for _, v in ipairs(named) do push(v) end
        elseif named ~= nil then
            push(named)
        end
        if def:match("^rbxasset") or def:match("^%d+$") then push(def) end
    elseif type(def) == "number" then
        push(def)
    elseif type(def) == "table" then
        if def.Image ~= nil then
            push(def.Image)
        else
            for _, v in ipairs(def) do push(v) end
            if type(def.Fallbacks) == "table" then
                for _, v in ipairs(def.Fallbacks) do push(v) end
            end
        end
    end
    if #candidates == 0 then return nil end
    return { Candidates = candidates }
end

local function makeIcon(parent, def, size, color, position, anchorPoint, zindex)
    local holder = new("Frame", {
        Name = "Icon",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(size, size),
        Position = position or UDim2.fromOffset(0, 0),
        AnchorPoint = anchorPoint or Vector2.new(0, 0),
        ZIndex = zindex or 2,
    }, parent)

    local resolved = resolveIcon(def)
    if resolved then
        local img = new("ImageLabel", {
            Name = "IconImage",
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = resolved.Candidates[1],
            ImageColor3 = color,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = holder.ZIndex,
        }, holder)

        -- make sure the icon can actually be displayed: decal / texture / asset
        -- ids are converted through the thumbnail api, and anything that still
        -- fails falls back to the placeholder ring instead of blank space
        task.spawn(function()
            for _, url in ipairs(resolved.Candidates) do
                local num = tostring(url):match("(%d+)")
                local thumb = num and fetchThumbnailUrl(num) or nil
                if thumb and img.Parent then
                    img.Image = thumb
                    local ring = holder:FindFirstChild("IconRing")
                    if ring then ring:Destroy() end
                    return
                end
            end

            if not ContentProvider or not img.Parent then return end
            local statusById = {}
            local ok = pcall(function()
                ContentProvider:PreloadAsync(resolved.Candidates, function(u, s)
                    local num = tostring(u):match("(%d+)")
                    if num then statusById[num] = s end
                end)
            end)
            if not ok or not img.Parent then return end
            local good, bad = nil, false
            for _, url in ipairs(resolved.Candidates) do
                local num = tostring(url):match("(%d+)")
                local st = num and statusById[num] or nil
                if st == Enum.AssetFetchStatus.Success then
                    good = good or url
                elseif st ~= nil then
                    bad = true
                end
            end
            if good then
                if img.Image ~= good then img.Image = good end
            elseif bad then
                img:Destroy()
                buildRing(holder, color, holder.ZIndex)
            end
        end)
    else
        buildRing(holder, color)
    end
    return holder
end

local function setIconColor(icon, color)
    local img = icon:FindFirstChild("IconImage")
    if img then img.ImageColor3 = color; return end
    local ring = icon:FindFirstChild("IconRing")
    if ring then
        local s = ring:FindFirstChildOfClass("UIStroke")
        if s then s.Color = color end
    end
end

local function tweenIconColor(icon, color, time)
    local img = icon:FindFirstChild("IconImage")
    if img then
        tween(img, { ImageColor3 = color }, time or 0.15)
        return
    end
    setIconColor(icon, color)
end

-- Expand/collapse arrow. Swaps between the arrowDown (closed) and arrowUp (open) icons with a
-- quick cross-fade; if those icons are cleared it falls back to rotating the placeholder ring.
local function makeArrow(parent, size, color, position, anchorPoint, zindex)
    local holder = makeIcon(parent, "arrowDown", size, color, position, anchorPoint, zindex)
    local arrow = { Icon = holder, Open = false }
    local token = 0

    function arrow:Set(open, animate)
        open = open and true or false
        self.Open = open
        token = token + 1
        local mine = token
        local img = holder:FindFirstChild("IconImage")
        local target = resolveIcon(open and "arrowUp" or "arrowDown")
        if img and target then
            if animate == false then
                img.Image = target.Candidates[1]
                return
            end
            tween(img, { ImageTransparency = 1 }, 0.07)
            task.delay(0.07, function()
                if mine ~= token or not img.Parent then return end
                img.Image = target.Candidates[1]
                tween(img, { ImageTransparency = 0 }, 0.1)
            end)
        else
            local rot = open and 180 or 0
            if animate == false then holder.Rotation = rot else tween(holder, { Rotation = rot }, 0.18) end
        end
    end

    function arrow:SetColor(c) setIconColor(holder, c) end
    return arrow
end

--============================================================================
-- SINGLE-INSTANCE SAFETY
--============================================================================
local ENV = (function()
    local g = tryCall(function() return getgenv() end)
    if type(g) == "table" then return g end
    return _G
end)()

if ENV.__LowerCaseDashboard then
    pcall(function() ENV.__LowerCaseDashboard:Unload() end)
end
ENV.__LowerCaseDashboard = Library

--============================================================================
-- ROOT GUI
--============================================================================
local gui = new("ScreenGui", {
    Name = "ui_" .. tostring(math.random(100000, 999999)),
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    DisplayOrder = 2147483000,
})
Library.Gui = gui

-- the menu lives directly in CoreGui (no executor hide/protect wrapper), so it
-- can be found and tweaked at runtime through the executor
do
    local placed = pcall(function()
        gui.Parent = game:GetService("CoreGui")
    end)
    if not placed or not gui.Parent then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

-- pre-warm the Builder Sans font files so text never flashes in the fallback
-- (Arial-like) font when the menu first appears or is toggled back on
do
    local warm = {}
    for _, f in ipairs({ FONT_MED, FONT_SEMI, FONT_BOLD }) do
        table.insert(warm, new("TextLabel", {
            Text = "warmup", Font = f, TextSize = 12,
            Position = UDim2.fromOffset(-200, -200), Size = UDim2.fromOffset(120, 20),
            BackgroundTransparency = 1,
        }, gui))
    end
    for _ = 1, 3 do
        pcall(function() RunService.Heartbeat:Wait() end)
    end
    for _, l in ipairs(warm) do pcall(function() l:Destroy() end) end
end

-- layers
local overlayLayer = new("Frame", {
    Name = "Overlay",
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    ZIndex = 500,
}, gui)

local notifyHolder = new("Frame", {
    Name = "Notifs",
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -16, 1, -16),
    Size = UDim2.new(0, 310, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    ZIndex = 800,
}, gui)
new("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
}, notifyHolder)

Library._alive = true

--============================================================================
-- NOTIFICATIONS
--============================================================================
local notifyOrder = 0
Library._notifyEnabled = true
function Library:SetNotifications(state)
    self._notifyEnabled = state and true or false
end

function Library:Notify(opts)
    if self._notifyEnabled == false then return end
    opts = opts or {}
    notifyOrder = notifyOrder + 1

    local card = new("Frame", {
        Name = "Toast",
        BackgroundColor3 = Theme.Card,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = notifyOrder,
        ZIndex = 801,
    }, notifyHolder)
    new("UICorner", { CornerRadius = UDim.new(0, 12) }, card)
    local stroke = new("UIStroke", {
        Color = Theme.Divider, Transparency = 0.92, Thickness = 1,
    }, card)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
    }, card)
    new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, card)

    local titleLbl = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20),
        Font = FONT_SEMI, TextSize = T(12), TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Text = opts.Title or "notice",
        LayoutOrder = 1, ZIndex = 802,
    }, card)

    local contentLbl = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Font = FONT_MED, TextSize = T(11),
        TextColor3 = Theme.Muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        Text = opts.Content or "", LayoutOrder = 2, ZIndex = 802,
    }, card)

    for _, d in ipairs({ card, titleLbl, contentLbl }) do
        d.BackgroundTransparency = 1
    end

    -- fade in
    local targets = { card, titleLbl, contentLbl }
    card.BackgroundTransparency = 1
    titleLbl.TextTransparency = 1
    contentLbl.TextTransparency = 1
    stroke.Transparency = 1

    tween(card, { BackgroundTransparency = 0 }, 0.15)
    tween(titleLbl, { TextTransparency = 0 }, 0.15)
    tween(contentLbl, { TextTransparency = 0 }, 0.15)
    tween(stroke, { Transparency = 0.92 }, 0.15)

    task.delay(opts.Duration or 4, function()
        if not card or not card.Parent then return end
        tween(card, { BackgroundTransparency = 1 }, 0.2)
        tween(titleLbl, { TextTransparency = 1 }, 0.2)
        tween(contentLbl, { TextTransparency = 1 }, 0.2)
        tween(stroke, { Transparency = 1 }, 0.2)
        task.delay(0.25, function()
            if card then card:Destroy() end
        end)
    end)
end

--============================================================================
-- CONTROL FACTORY (shared by cards and tab-strip containers)
--============================================================================
local ControlMethods = {}

local function markRow(host, row, name)
    row:SetAttribute("RowName", tostring(name or ""))
    -- a card is its own host; tab-strip containers point back at their card via host.Card
    local card = host.Card or host
    table.insert(card._rows, row)
    return row
end

local function applyDepends(control, opts)
    local dep = opts.DependsOn
    if not dep then return end
    local depFlag  = dep.Flag or dep.flag or dep[1]
    local depValue = dep.Value
    if depValue == nil then depValue = dep.value end
    if depValue == nil then depValue = true end
    local function check()
        local show = Library.Flags[depFlag] == depValue
        -- remembered on the row so the search filter doesn't un-hide it
        if control.Frame then control.Frame:SetAttribute("DepHidden", not show) end
        control:SetVisible(show)
    end
    Library:_onFlag(depFlag, check)
    check()
end

-- ---------------------------------------------------------------- TOGGLE ----
local function createToggle(host, opts)
    opts = opts or {}
    local flag = opts.Flag or opts.Name
    local row = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 28),
    }, host.RowsFrame)
    markRow(host, row, opts.Name)

    local btn = new("TextButton", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        Text = "", AutoButtonColor = false,
    }, row)

    local box = new("Frame", {
        Size = UDim2.fromOffset(18, 18),
        Position = opts.CheckboxRight and UDim2.new(1, 0, 0.5, -9) or UDim2.new(0, 0, 0.5, -9),
        AnchorPoint = opts.CheckboxRight and Vector2.new(1, 0.5) or Vector2.new(0, 0.5),
        BackgroundColor3 = Theme.Input,
    }, row)
    new("UICorner", { CornerRadius = UDim.new(0, 7) }, box)

    local check = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        Font = FONT_BOLD, TextSize = T(12), Text = "✓",
        TextColor3 = Color3.new(1, 1, 1), TextTransparency = 1,
    }, box)

    local labelColor = opts.Danger and Theme.Danger or Theme.Text
    local label = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, opts.CheckboxRight and 0 or 28, 0, 0),
        Size = UDim2.new(1, -28, 1, 0),
        Font = FONT_MED, TextSize = T(13), TextColor3 = labelColor,
        TextXAlignment = Enum.TextXAlignment.Left, Text = opts.Name or "Toggle",
    }, row)

    local labelW = textWidth(label.Text, T(13), FONT_MED)

    if opts.Badge then
        local txt = string.upper(opts.Badge)
        local bw = textWidth(txt, T(9), FONT_BOLD) + 12
        local badge = new("Frame", {
            Position = UDim2.new(0, 28 + labelW + 8, 0.5, -9),
            Size = UDim2.fromOffset(bw, 18),
            BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.75,
        }, row)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, badge)
        new("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
            Font = FONT_BOLD, TextSize = T(9), TextColor3 = Color3.new(1, 1, 1), Text = txt,
        }, badge)
        onAccentChange(function(c)
            if badge.Parent then badge.BackgroundColor3 = c end
        end)
    end

    local value = opts.Default == true
    local control = { Frame = row, Flag = flag }

    local keybindObj
    if opts.Keybind ~= nil or opts.Keybind == nil and opts.Name and opts.WithKeybind then
        -- handled below
    end

    local function render(animate)
        local t = animate and 0.12 or 0
        if value then
            tween(box, { BackgroundColor3 = Theme.Accent }, t)
            tween(check, { TextTransparency = 0 }, t)
        else
            tween(box, { BackgroundColor3 = Theme.Input }, t)
            tween(check, { TextTransparency = 1 }, t)
        end
    end

    onAccentChange(function(c)
        if value then
            if box and box.Parent then box.BackgroundColor3 = c end
        end
    end)

    function control:Set(v)
        value = v and true or false
        render(true)
        Library:_setFlag(flag, value)
        if opts.Callback then
            local ok, err = pcall(opts.Callback, value)
            if not ok then warn("[library] toggle callback error: " .. tostring(err)) end
        end
        Library:_refreshBinds()
    end
    function control:Get() return value end
    function control:SetVisible(v) row.Visible = v and true or false end

    connect(btn.MouseButton1Click, function()
        control:Set(not value)
    end)

    -- keybind chip on the toggle row
    if opts.Keybind ~= nil then
        local chipHolder = new("Frame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(0, 22),
            AutomaticSize = Enum.AutomaticSize.X,
        }, row)

        local chip = new("TextButton", {
            BackgroundColor3 = Theme.Input,
            AutoButtonColor = false,
            Size = UDim2.fromOffset(0, 22),
            Text = "", TextSize = T(11), Font = FONT_MED,
            TextColor3 = Theme.Muted,
        }, chipHolder)
        new("UICorner", { CornerRadius = UDim.new(0, 6) }, chip)

        local bindKey, bindName = nil, nil
        local listening = false
        local listenConn
        local lastStop = 0

        local function chipRender()
            if listening then
                chip.Text = "..."
                chip.TextColor3 = Theme.Accent
                chip.Size = UDim2.fromOffset(textWidth("...", T(11), FONT_MED) + 16, 22)
            else
                chip.Text = bindName or "none"
                chip.TextColor3 = Theme.Muted
                chip.Size = UDim2.fromOffset(textWidth(chip.Text, T(11), FONT_MED) + 16, 22)
            end
        end

        local function stopListening()
            listening = false
            lastStop = os.clock()
            if listenConn then
                pcall(function() listenConn:Disconnect() end)
                listenConn = nil
            end
            chipRender()
        end

        local function startListening()
            if listening then return end
            listening = true
            chipRender()
            listenConn = UserInputService.InputBegan:Connect(function(input, gp)
                if not listening then return end
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    if input.KeyCode == Enum.KeyCode.Escape then
                        stopListening()
                        return
                    elseif input.KeyCode == Enum.KeyCode.Backspace then
                        bindKey, bindName = nil, nil
                    else
                        bindKey, bindName = input.KeyCode, input.KeyCode.Name
                    end
                elseif input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.MouseButton2
                    or input.UserInputType == Enum.UserInputType.MouseButton3 then
                    local map = {
                        [Enum.UserInputType.MouseButton1] = { Enum.UserInputType.MouseButton1, "MB1" },
                        [Enum.UserInputType.MouseButton2] = { Enum.UserInputType.MouseButton2, "MB2" },
                        [Enum.UserInputType.MouseButton3] = { Enum.UserInputType.MouseButton3, "MB3" },
                    }
                    local e = map[input.UserInputType]
                    bindKey, bindName = e[1], e[2]
                else
                    return
                end
                stopListening()
                if opts.KeybindCallback then pcall(opts.KeybindCallback, bindKey, bindName) end
                Library:_setFlag((flag or "toggle") .. "_keybind", bindName)
                Library:_refreshBinds()
            end)
            table.insert(Library._connections, listenConn)
        end

        connect(chip.MouseButton1Click, function()
            if listening then stopListening() else startListening() end
        end)

        -- pressing the bound key flips the toggle
        connect(UserInputService.InputBegan, function(input, gp)
            if gp or listening or not bindKey then return end
            if os.clock() - lastStop < 0.15 then return end -- ignore the press that just set the bind
            if input.KeyCode == bindKey or input.UserInputType == bindKey then
                control:Set(not value)
            end
        end)

        if typeof(opts.Keybind) == "EnumItem" then
            bindKey, bindName = opts.Keybind, opts.Keybind.Name
        elseif type(opts.Keybind) == "string" and opts.Keybind ~= "" then
            bindName = opts.Keybind
        end
        chipRender()

        control.Keybind = {
            Get = function() return bindKey end,
            GetName = function() return bindName end,
        }
        Library:_registerBind(flag, opts.Name, function() return bindName end, function() return value end)
    end

    control:Set(value == true and true or false)
    applyDepends(control, opts)
    return control
end

-- ---------------------------------------------------------------- SLIDER ----
local function decimalsFor(step)
    local s = tostring(step)
    local dot = s:find("%.")
    if dot then return #s - dot end
    return 0
end

local function createSlider(host, opts)
    opts = opts or {}
    local flag    = opts.Flag or opts.Name
    local min     = opts.Min or 0
    local max     = opts.Max or 100
    local inc     = opts.Increment or 1
    local suffix  = opts.Suffix or ""
    local decimals = decimalsFor(inc)
    local value   = opts.Default or min

    local row = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46),
    }, host.RowsFrame)
    markRow(host, row, opts.Name)

    local label = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, -64, 0, 22), Font = FONT_MED, TextSize = T(13), -- same size as toggle labels
        TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
        Text = opts.Name or "Slider",
    }, row)

    local valueLbl = new("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 64, 0, 22),
        Font = FONT_MED, TextSize = T(13), TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Right, Text = "",
    }, row)

    local hit = new("TextButton", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 26),
        Size = UDim2.new(1, 0, 0, 16), Text = "", AutoButtonColor = false,
    }, row)

    local track = new("Frame", {
        BackgroundColor3 = Theme.Input, AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 4),
    }, hit)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)

    local fill = new("Frame", {
        BackgroundColor3 = Theme.Accent, Size = UDim2.new(0, 0, 1, 0),
    }, track)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

    local thumb = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.new(1, 1, 1),
    }, track)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, thumb)

    onAccentChange(function(c)
        if fill and fill.Parent then fill.BackgroundColor3 = c end
    end)

    local control = { Frame = row, Flag = flag }

    local function alpha()
        if max == min then return 0 end
        return (value - min) / (max - min)
    end

    local function renderValue()
        local txt
        if decimals > 0 then
            txt = string.format("%." .. decimals .. "f", value) .. suffix
        else
            txt = tostring(math.floor(value + 0.5)) .. suffix
        end
        valueLbl.Text = txt
        tween(fill, { Size = UDim2.new(alpha(), 0, 1, 0) }, 0.08)
        tween(thumb, { Position = UDim2.new(alpha(), 0, 0.5, 0) }, 0.08)
    end

    function control:Set(v, silent)
        v = tonumber(v) or min
        v = math.clamp(v, min, max)
        if inc > 0 then
            v = math.floor(v / inc + 0.5) * inc
        end
        value = v
        renderValue()
        Library:_setFlag(flag, value)
        if not silent and opts.Callback then
            local ok, err = pcall(opts.Callback, value)
            if not ok then warn("[library] slider callback error: " .. tostring(err)) end
        end
    end
    function control:Get() return value end
    function control:SetVisible(v) row.Visible = v and true or false end

    local dragging = false
    local function updateFromX(px)
        local rel = (px - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
        rel = math.clamp(rel, 0, 1)
        control:Set(min + (max - min) * rel)
    end

    connect(hit.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
            tween(thumb, { Size = UDim2.fromOffset(16, 16) }, 0.1)
        end
    end)
    connect(hit.MouseEnter, function()
        tween(thumb, { Size = UDim2.fromOffset(16, 16) }, 0.12)
    end)
    connect(hit.MouseLeave, function()
        if not dragging then tween(thumb, { Size = UDim2.fromOffset(14, 14) }, 0.12) end
    end)
    connect(UserInputService.InputChanged, function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            updateFromX(input.Position.X)
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                tween(thumb, { Size = UDim2.fromOffset(14, 14) }, 0.12)
            end
        end
    end)

    control:Set(value, true)
    applyDepends(control, opts)
    return control
end

-- -------------------------------------------------------------- DROPDOWN ----
local function createDropdown(host, opts)
    opts = opts or {}
    local flag = opts.Flag or opts.Name
    local options = opts.Options or {}
    local multi = opts.Multi == true

    -- the name and the dropdown bar sit on the same row, like a toggle
    local row = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34),
    }, host.RowsFrame)
    markRow(host, row, opts.Name)

    local nameLbl = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0),
        Font = FONT_MED, TextSize = T(13), TextColor3 = Theme.Text, -- same size as toggle labels
        TextXAlignment = Enum.TextXAlignment.Left, Text = opts.Name or "Dropdown",
    }, row)
    local nameW = textWidth(nameLbl.Text, T(13), FONT_MED) + 8
    nameLbl.Size = UDim2.new(0, nameW, 1, 0)

    local box = new("TextButton", {
        BackgroundColor3 = Theme.Input, AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(1, -(nameW + 8), 0, 30),
        AutoButtonColor = false, Text = "",
    }, row)
    new("UICorner", { CornerRadius = UDim.new(0, 10) }, box)

    local selLbl = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -34, 1, 0), Font = FONT_MED, TextSize = T(13),
        TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = "",
    }, box)

    local arrow = makeArrow(box, 16, Theme.Muted, UDim2.new(1, -20, 0.5, 0), Vector2.new(0.5, 0.5), 2)

    local control = { Frame = row, Flag = flag }
    local value = opts.Default
    if multi then
        value = type(value) == "table" and value or {}
    end

    local listHolder, catcher

    local function displayText()
        if multi then
            if #value == 0 then return "none" end
            return table.concat(value, ", ")
        end
        return tostring(value or "none")
    end

    local function render()
        selLbl.Text = displayText()
        selLbl.TextColor3 = (value == nil or (multi and #value == 0)) and Theme.Muted or Theme.Text
    end

    local listW = 0

    local function closeList(instant)
        local lh, ct = listHolder, catcher
        listHolder, catcher = nil, nil
        if ct then ct:Destroy() end
        arrow:Set(false, not instant)
        if lh then
            if instant then
                lh:Destroy()
            else
                -- collapse animation
                tween(lh, { Size = UDim2.fromOffset(listW, 0) }, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                task.delay(0.16, function() if lh then lh:Destroy() end end)
            end
        end
    end

    local function openList(instant)
        if listHolder then closeList(); return end
        arrow:Set(true, not instant)

        catcher = new("TextButton", {
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
            Text = "", AutoButtonColor = false, ZIndex = 501,
        }, overlayLayer)
        connect(catcher.MouseButton1Click, function() closeList() end)

        local scale = Library._scale or 1          -- the list lives outside the window, so it needs the menu scale too
        local rowH = 28
        local listH = math.min(#options * rowH + 8, 200)

        local absPos = box.AbsolutePosition
        local absSize = box.AbsoluteSize
        local screenH = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 720

        local openUp = absPos.Y + absSize.Y + 4 + listH * scale > screenH - 8
        listW = absSize.X / scale

        listHolder = new("Frame", {
            BackgroundColor3 = Theme.Card,
            AnchorPoint = Vector2.new(0, openUp and 1 or 0),
            Position = UDim2.fromOffset(absPos.X, openUp and (absPos.Y - 4) or (absPos.Y + absSize.Y + 4)),
            Size = UDim2.fromOffset(listW, instant and listH or 0),
            ClipsDescendants = true, ZIndex = 502,
        }, overlayLayer)
        new("UIScale", { Scale = scale }, listHolder)
        new("UICorner", { CornerRadius = UDim.new(0, 12) }, listHolder)
        new("UIStroke", { Color = Theme.Divider, Transparency = 0.9, Thickness = 1 }, listHolder)
        new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, listHolder)

        -- expand animation
        if not instant then
            tween(listHolder, { Size = UDim2.fromOffset(listW, listH) }, 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        end

        local scroll = new("ScrollingFrame", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, listH - 8),
            CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.Muted,
            BorderSizePixel = 0, ZIndex = 503,
        }, listHolder)
        new("UIListLayout", { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)

        for i, opt in ipairs(options) do
            local optStr = tostring(opt)
            local isSel = multi and table.find(value, optStr) ~= nil or (not multi and value == opt)

            local item = new("TextButton", {
                BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, rowH),
                Text = "", AutoButtonColor = false, LayoutOrder = i, ZIndex = 504,
            }, scroll)
            item.Size = UDim2.new(1, 0, 0, rowH)

            local lbl = new("TextLabel", {
                BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0),
                Size = UDim2.new(1, -20, 1, 0), Font = FONT_MED, TextSize = T(13),
                TextColor3 = isSel and Theme.Accent or Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left, Text = optStr, ZIndex = 505,
            }, item)
            if not instant then
                -- options fade in one after another
                lbl.TextTransparency = 1
                task.delay(0.03 * i, function()
                    if lbl and lbl.Parent then tween(lbl, { TextTransparency = 0 }, 0.18) end
                end)
            end

            if isSel then accent(lbl, "TextColor3") end

            connect(item.MouseEnter, function()
                tween(item, { BackgroundTransparency = 0.92 }, 0.1)
                item.BackgroundColor3 = Theme.Input
            end)
            connect(item.MouseLeave, function()
                tween(item, { BackgroundTransparency = 1 }, 0.1)
            end)

            connect(item.MouseButton1Click, function()
                if multi then
                    local idx = table.find(value, optStr)
                    if idx then table.remove(value, idx) else table.insert(value, optStr) end
                    render()
                    Library:_setFlag(flag, value)
                    if opts.Callback then pcall(opts.Callback, value) end
                    closeList(true)
                    openList(true)
                else
                    value = opt
                    render()
                    Library:_setFlag(flag, value)
                    if opts.Callback then pcall(opts.Callback, value) end
                    closeList()
                end
            end)
        end
    end

    connect(box.MouseButton1Click, function() openList() end)

    function control:Set(v)
        value = v
        if multi and type(value) ~= "table" then value = {} end
        render()
        Library:_setFlag(flag, value)
    end
    function control:Get() return value end
    function control:SetVisible(v)
        row.Visible = v and true or false
        if not row.Visible then closeList(true) end
    end

    render()
    Library:_setFlag(flag, value)
    applyDepends(control, opts)
    return control
end

-- --------------------------------------------------------------- KEYBIND ----
local function createKeybindRow(host, opts)
    opts = opts or {}
    local flag = opts.Flag or opts.Name

    local row = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28),
    }, host.RowsFrame)
    markRow(host, row, opts.Name)

    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -80, 1, 0),
        Font = FONT_MED, TextSize = T(13), TextColor3 = opts.Danger and Theme.Danger or Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Text = opts.Name or "Keybind",
    }, row)

    local chip = new("TextButton", {
        BackgroundColor3 = Theme.Input, AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(40, 22), Text = "", Font = FONT_MED, TextSize = T(11),
        TextColor3 = Theme.Muted,
    }, row)
    new("UICorner", { CornerRadius = UDim.new(0, 6) }, chip)

    local control = { Frame = row, Flag = flag }
    local bindKey, bindName, listening, listenConn

    local function render()
        if listening then
            chip.Text = "..."
            chip.TextColor3 = Theme.Accent
            chip.Size = UDim2.fromOffset(textWidth("...", T(11), FONT_MED) + 16, 22)
        else
            chip.Text = bindName or "none"
            chip.TextColor3 = Theme.Muted
            chip.Size = UDim2.fromOffset(textWidth(chip.Text, T(11), FONT_MED) + 16, 22)
        end
    end

    local function stop()
        listening = false
        if listenConn then
            pcall(function() listenConn:Disconnect() end)
            listenConn = nil
        end
        render()
    end

    local function start()
        if listening then return end
        listening = true
        render()
        listenConn = UserInputService.InputBegan:Connect(function(input)
            if not listening then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Escape then
                    stop(); return
                elseif input.KeyCode == Enum.KeyCode.Backspace then
                    bindKey, bindName = nil, nil
                else
                    bindKey, bindName = input.KeyCode, input.KeyCode.Name
                end
            elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
                bindKey, bindName = Enum.UserInputType.MouseButton1, "MB1"
            elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
                bindKey, bindName = Enum.UserInputType.MouseButton2, "MB2"
            elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
                bindKey, bindName = Enum.UserInputType.MouseButton3, "MB3"
            else
                return
            end
            stop()
            Library:_setFlag(flag, bindName)
            if opts.Callback then pcall(opts.Callback, bindKey, bindName) end
            Library:_refreshBinds()
        end)
        table.insert(Library._connections, listenConn)
    end

    connect(chip.MouseButton1Click, function()
        if listening then stop() else start() end
    end)

    if typeof(opts.Default) == "EnumItem" then
        bindKey, bindName = opts.Default, opts.Default.Name
    elseif type(opts.Default) == "string" then
        bindName = opts.Default
    end
    render()
    Library:_setFlag(flag, bindName)

    function control:Set(v)
        bindName = v
        render()
        Library:_setFlag(flag, bindName)
    end
    function control:Get() return bindKey end
    function control:GetName() return bindName end
    function control:SetVisible(v) row.Visible = v and true or false end

    applyDepends(control, opts)
    return control
end

-- ---------------------------------------------------------------- BUTTON ----
local function createButton(host, opts)
    opts = opts or {}
    local row = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34),
    }, host.RowsFrame)
    markRow(host, row, opts.Name)

    local btn = new("TextButton", {
        BackgroundColor3 = Theme.Input, Size = UDim2.fromScale(1, 1),
        AutoButtonColor = false, Text = "", TextSize = T(12), Font = FONT_MED,
        TextColor3 = Theme.Text,
    }, row)
    new("UICorner", { CornerRadius = UDim.new(0, 10) }, btn)
    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        Font = FONT_MED, TextSize = T(12),
        TextColor3 = opts.Danger and Theme.Danger or Theme.Text,
        Text = opts.Name or "Button",
    }, btn)

    connect(btn.MouseEnter, function()
        tween(btn, { BackgroundColor3 = Color3.fromRGB(0x2a, 0x2a, 0x2f) }, 0.12)
    end)
    connect(btn.MouseLeave, function()
        tween(btn, { BackgroundColor3 = Theme.Input }, 0.12)
    end)
    connect(btn.MouseButton1Click, function()
        if opts.Callback then
            local ok, err = pcall(opts.Callback)
            if not ok then warn("[library] button error: " .. tostring(err)) end
        end
    end)

    local control = { Frame = row }
    function control:Set() end
    function control:Get() return nil end
    function control:SetVisible(v) row.Visible = v and true or false end
    applyDepends(control, opts)
    return control
end

-- ------------------------------------------------------------------ HINT ----
local function createHint(host, opts)
    opts = opts or {}
    local row = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Font = FONT_MED, TextSize = T(11),
        TextColor3 = Theme.Hint, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, Text = opts.Text or opts.Name or "",
    }, host.RowsFrame)
    markRow(host, row, opts.Name or opts.Text)

    local control = { Frame = row }
    function control:SetVisible(v)
        row.Visible = v and true or false
    end
    function control:Set(t) row.Text = tostring(t) end
    function control:Get() return row.Text end
    applyDepends(control, opts)
    return control
end

ControlMethods.AddToggle   = createToggle
ControlMethods.AddSlider   = createSlider
ControlMethods.AddDropdown = createDropdown
ControlMethods.AddKeybind  = createKeybindRow
ControlMethods.AddButton   = createButton
ControlMethods.AddHint     = createHint

--============================================================================
-- BINDS HUD REGISTRY
--============================================================================
Library._bindEntries = {}
function Library:_registerBind(flag, name, getKeyName, getEnabled)
    if not name then return end
    for _, e in ipairs(self._bindEntries) do
        if e.name == name and e.flag == flag then return end
    end
    table.insert(self._bindEntries, {
        flag = flag, name = name,
        getKeyName = getKeyName, getEnabled = getEnabled,
    })
end

--============================================================================
-- DRAGGING
--============================================================================
-- handle: the GuiObject you press on; target: the GuiObject that moves.
-- clampToScreen keeps the target fully on screen (used for the HUD panels).
local function makeDraggable(handle, target, clampToScreen)
    local dragging, startMouse, startPos, startAbs = false, nil, nil, nil
    local grabOff = Vector2.new(0, 0)
    connect(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startMouse = Vector2.new(input.Position.X, input.Position.Y)
            startPos = target.Position
            startAbs = target.AbsolutePosition
            -- grab offset from the mouse location, so the panel keeps the exact
            -- point you pressed on and never jumps when the drag starts
            local m = tryCall(function() return UserInputService:GetMouseLocation() end)
            if m then grabOff = Vector2.new(m.X - startAbs.X, m.Y - startAbs.Y) end
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            if clampToScreen then
                -- position straight from the mouse + grab offset (both in viewport
                -- space, so no inset mismatch can shift the panel) and clamp against
                -- the real viewport so nothing blocks it from reaching the top
                local m = tryCall(function() return UserInputService:GetMouseLocation() end)
                if not m then return end
                local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or gui.AbsoluteSize
                local size = target.AbsoluteSize
                local ap = target.AnchorPoint
                local nx = math.clamp(m.X - grabOff.X, 0, math.max(0, vp.X - size.X))
                local ny = math.clamp(m.Y - grabOff.Y, 0, math.max(0, vp.Y - size.Y))
                target.Position = UDim2.fromOffset(nx + size.X * ap.X, ny + size.Y * ap.Y)
            else
                local dx = input.Position.X - startMouse.X
                local dy = input.Position.Y - startMouse.Y
                target.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + dx,
                    startPos.Y.Scale, startPos.Y.Offset + dy
                )
            end
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

--============================================================================
-- HUD
--============================================================================
local infoBar, infoLabels = nil, {}
local bindsPanel, bindsRowsHolder = nil, nil
local bindsEmpty = true

local function buildInfoBar()
    if infoBar then return end
    infoBar = new("Frame", {
        Name = "InfoBar",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 14),
        Size = UDim2.new(0, 0, 0, 38),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Card,
        ZIndex = 400,
    }, gui)
    new("UICorner", { CornerRadius = UDim.new(0, 12) }, infoBar)
    new("UIStroke", { Color = Theme.Divider, Transparency = 0.94, Thickness = 1 }, infoBar)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 0), PaddingBottom = UDim.new(0, 0),
    }, infoBar)
    local layout = new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, infoBar)

    local order = 0
    local function addLabel(key, color, font)
        order = order + 1
        local lbl = new("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 38),
            AutomaticSize = Enum.AutomaticSize.X, Font = font or FONT_MED, TextSize = T(12),
            TextColor3 = color, Text = "", LayoutOrder = order, ZIndex = 401,
        }, infoBar)
        infoLabels[key] = lbl
        return lbl
    end
    local function addDivider()
        order = order + 1
        new("Frame", {
            BackgroundColor3 = Theme.Divider, BackgroundTransparency = 0.9,
            Size = UDim2.fromOffset(1, 16), LayoutOrder = order, ZIndex = 401,
        }, infoBar)
    end

    addLabel("brand", Theme.Accent, FONT_SEMI) -- only the watermark is bold
    addDivider()
    addLabel("game", Theme.Muted)
    addDivider()
    addLabel("fps", Theme.Muted)
    addDivider()
    addLabel("ping", Theme.Muted)
    addDivider()
    addLabel("clock", Theme.Muted)

    onAccentChange(function(c)
        if infoLabels.brand then infoLabels.brand.TextColor3 = c end
    end)

    makeDraggable(infoBar, infoBar, true)
end

local function buildBindsPanel()
    if bindsPanel then return end
    bindsPanel = new("Frame", {
        Name = "BindsPanel",
        Position = UDim2.new(0, 12, 0, 12),
        Size = UDim2.new(0, 240, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Card,
        BackgroundTransparency = 1,
        ZIndex = 400,
    }, gui)
    new("UICorner", { CornerRadius = UDim.new(0, 12) }, bindsPanel)
    new("UIStroke", { Color = Theme.Divider, Transparency = 0.94, Thickness = 1 }, bindsPanel)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
    }, bindsPanel)

    local list = new("UIListLayout", {
        Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
    }, bindsPanel)

    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20),
        Font = FONT_SEMI, TextSize = T(12), TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Text = "keybinds", LayoutOrder = 1,
    }, bindsPanel)

    new("Frame", {
        BackgroundColor3 = Theme.Divider, BackgroundTransparency = 0.9,
        Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 2,
    }, bindsPanel)

    bindsRowsHolder = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3,
    }, bindsPanel)
    new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, bindsRowsHolder)

    makeDraggable(bindsPanel, bindsPanel, true)
end

function Library:_refreshBinds()
    if not Library._showBinds then return end
    buildBindsPanel()

    -- every option that has a keybind shows up here, bound or not; the ones
    -- that are currently enabled light up in the accent colour
    local entries = {}
    for _, e in ipairs(self._bindEntries) do
        local keyName = e.getKeyName and e.getKeyName()
        if keyName then
            table.insert(entries, {
                name = e.name,
                key = keyName,
                enabled = (e.getEnabled and e.getEnabled()) == true,
            })
        end
    end

    for _, ch in ipairs(bindsRowsHolder:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end

    for i, e in ipairs(entries) do
        local r = new("Frame", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = i,
        }, bindsRowsHolder)
        new("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(0.6, 0, 1, 0),
            Font = FONT_MED, TextSize = T(11),
            TextColor3 = e.enabled and Theme.Accent or Theme.Muted,
            TextXAlignment = Enum.TextXAlignment.Left, Text = e.name,
        }, r)
        new("TextLabel", {
            BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.4, 0, 1, 0),
            Font = FONT_MED, TextSize = T(11), TextColor3 = Theme.Muted,
            TextXAlignment = Enum.TextXAlignment.Right, Text = "[" .. e.key .. "]",
        }, r)
    end

    local empty = #entries == 0
    if empty ~= bindsEmpty then
        bindsEmpty = empty
        if empty then
            tween(bindsPanel, { BackgroundTransparency = 1 }, 0.18)
        else
            tween(bindsPanel, { BackgroundTransparency = 0 }, 0.18)
        end
    elseif not empty then
        bindsPanel.BackgroundTransparency = 0
    end
end

-- keep the enabled rows in the accent colour when the theme changes
onAccentChange(function()
    if Library._showBinds then Library:_refreshBinds() end
end)

function Library:SetInfoBar(state)
    self._showInfo = state and true or false
    if self._showInfo then buildInfoBar() ; infoBar.Visible = true
    elseif infoBar then infoBar.Visible = false end
end

function Library:SetKeybindList(state)
    self._showBinds = state and true or false
    if self._showBinds then
        buildBindsPanel()
        bindsPanel.Visible = true
        self:_refreshBinds()
    elseif bindsPanel then
        bindsPanel.Visible = false
    end
end

-- HUD update loop ------------------------------------------------------------
do
    local frames, accum, fps = 0, 0, 0
    connect(RunService.RenderStepped, function(dt)
        frames = frames + 1
        accum = accum + dt
        if accum >= 0.5 then
            fps = math.floor(frames / accum + 0.5)
            frames, accum = 0, 0
        end
    end)

    local sessionStart = os.clock()

    -- the info bar shows the name of the game you're in
    local gameName = tryCall(function() return game.Name end) or "game"
    task.spawn(function()
        local info = tryCall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
        if type(info) == "table" and type(info.Name) == "string" and info.Name ~= "" then
            gameName = info.Name
        end
    end)
    local function shortName(n)
        n = tostring(n)
        if (utf8.len(n) or #n) > 28 then
            local cut = utf8.offset(n, 28)
            if cut then return n:sub(1, cut - 1) .. "…" end
        end
        return n
    end

    task.spawn(function()
        while Library._alive do
            if Library._showInfo and infoLabels.brand then
                infoLabels.brand.Text = (Library._brandName or "library") .. "."
                infoLabels.game.Text  = shortName(gameName)
                infoLabels.fps.Text   = "fps " .. tostring(fps)
                local ping = tryCall(function()
                    return math.floor(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue())
                end)
                infoLabels.ping.Text  = "ping " .. tostring(ping or 0)
                local secs = math.floor(os.clock() - sessionStart)
                infoLabels.clock.Text = string.format("%02d:%02d", math.floor(secs / 60), secs % 60)
            end
            task.wait(0.5)
        end
    end)
end

--============================================================================
-- WINDOW
--============================================================================
local WindowMethods = {}
local SectionMethods = {}
local TabMethods = {}
local PageMethods = {}
local CardMethods = {}

local function extend(dest, src)
    for k, v in pairs(src) do dest[k] = v end
    return dest
end

function Library:CreateWindow(opts)
    opts = opts or {}
    local brandName = opts.Title or "library"
    self._brandName = brandName

    local winSize = opts.Size or Vector2.new(840, 560)
    local SIDEBAR_W = 200

    local holder = new("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(winSize.X, winSize.Y),
        BackgroundTransparency = 1,
        ZIndex = 2,
    }, gui)
    new("UISizeConstraint", { MinSize = Vector2.new(640, 420), MaxSize = Vector2.new(1500, 950) }, holder)

    -- glow ------------------------------------------------------------------
    local glow = nil
    if SHADOW_IMAGE ~= "" then
        glow = new("ImageLabel", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, 60, 1, 60),
            Image = SHADOW_IMAGE,
            ImageColor3 = Theme.Accent,
            ImageTransparency = 0.72,
            ScaleType = Enum.ScaleType.Slice,
            SliceCenter = Rect.new(30, 30, 30, 30),
            ZIndex = 1,
        }, holder)
        onAccentChange(function(c) if glow and glow.Parent then glow.ImageColor3 = c end end)
    end

    -- main window ------------------------------------------------------------
    local main = new("CanvasGroup", {
        Name = "Main",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Window,
        GroupTransparency = 0,
        ZIndex = 2,
    }, holder)
    new("UICorner", { CornerRadius = UDim.new(0, 16) }, main)

    if not glow then
        new("UIStroke", {
            Color = Theme.Accent, Transparency = 0.93, Thickness = 1.5,
        }, main)
    end

    local uiScale = new("UIScale", { Scale = 0.97 }, main)
    main.BackgroundTransparency = 0
    main.GroupTransparency = 1
    tween(main, { GroupTransparency = 0 }, 0.18)
    tween(uiScale, { Scale = 1 }, 0.18)

    -- sidebar ----------------------------------------------------------------
    local sidebar = new("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, SIDEBAR_W, 1, 0),
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, main)
    new("UICorner", { CornerRadius = UDim.new(0, 16) }, sidebar)

    local brand = new("Frame", {
        Name = "Brand",
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundTransparency = 1,
        ZIndex = 4,
    }, sidebar)

    -- logo sits on a rounded plate. Default logo is Library.Icons.logo; override with opts.Logo
    -- (an id / number / name) and set opts.LogoTint = false to keep a multi-colour logo untinted.
    local logoTint = opts.LogoTint ~= false
    local logo = makeIcon(brand, opts.Logo or "logo", 24, logoTint and Theme.Accent or Color3.new(1, 1, 1),
        UDim2.fromOffset(17, 16))
    local logoBg = new("Frame", {
        Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(12, 10),
        BackgroundColor3 = Theme.Card, ZIndex = 4,
    }, brand)
    new("UICorner", { CornerRadius = UDim.new(0, 10) }, logoBg)
    logo.ZIndex = 5
    if logoTint then
        onAccentChange(function(c) if logo.Parent then setIconColor(logo, c) end end)
    end

    local brandNameLbl = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 58, 0, 10),
        Size = UDim2.new(1, -64, 0, 22), Font = FONT_BOLD, TextSize = T(15),
        TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
        Text = brandName .. ".", ZIndex = 5,
    }, brand)
    accent(brandNameLbl, "TextColor3")

    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 58, 0, 32),
        Size = UDim2.new(1, -64, 0, 16), Font = FONT_MED, TextSize = T(11),
        TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left,
        Text = opts.Subtitle or "v1.0.0", ZIndex = 5,
    }, brand)

    -- nav --------------------------------------------------------------------
    local nav = new("ScrollingFrame", {
        Name = "Nav",
        Position = UDim2.new(0, 0, 0, 62),
        Size = UDim2.new(1, 0, 1, -126),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 0,
        ZIndex = 4,
    }, sidebar)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 2),
    }, nav)
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, nav)

    -- footer -----------------------------------------------------------------
    local footer = new("Frame", {
        Name = "Footer",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 62),
        BackgroundTransparency = 1,
        ZIndex = 4,
    }, sidebar)

    new("Frame", {
        BackgroundColor3 = Theme.Divider, BackgroundTransparency = 0.9,
        Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -24, 0, 1),
        ZIndex = 4,
    }, footer)

    local avatar = new("ImageLabel", {
        BackgroundColor3 = Theme.Input, Position = UDim2.fromOffset(12, 13),
        Size = UDim2.fromOffset(36, 36), Image = "", ZIndex = 5,
    }, footer)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, avatar)

    -- the full username is shown here (the "Hide Info" setting can hide it)
    local footerNameLbl = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 58, 0, 13),
        Size = UDim2.new(1, -64, 0, 18), Font = FONT_SEMI, TextSize = T(12),
        TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
        Text = LocalPlayer.Name, ZIndex = 5,
    }, footer)
    footerNameLbl.Visible = not Library.Flags["ui_hideinfo"]

    local sessionLbl = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 58, 0, 32),
        Size = UDim2.new(1, -64, 0, 16), Font = FONT_MED, TextSize = T(11),
        TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left,
        Text = "session ", ZIndex = 5,
    }, footer)
    local sessionVal = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 58 + textWidth("session ", T(11), FONT_MED), 0, 32),
        Size = UDim2.new(1, -110, 0, 16), Font = FONT_SEMI, TextSize = T(11),
        TextColor3 = Theme.Accent, TextXAlignment = Enum.TextXAlignment.Left,
        Text = "00:00", ZIndex = 5,
    }, footer)
    accent(sessionVal, "TextColor3")

    task.spawn(function()
        local start = os.clock()
        while Library._alive do
            local s = math.floor(os.clock() - start)
            sessionVal.Text = string.format("%02d:%02d", math.floor(s / 60), s % 60)
            task.wait(0.5)
        end
    end)

    task.spawn(function()
        local ok, img = pcall(function()
            return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if ok and img and avatar and avatar.Parent then
            avatar.Image = img
        end
    end)

    -- content area -----------------------------------------------------------
    local content = new("Frame", {
        Name = "Content",
        Position = UDim2.new(0, SIDEBAR_W, 0, 0),
        Size = UDim2.new(1, -SIDEBAR_W, 1, 0),
        BackgroundTransparency = 1,
        ZIndex = 3,
    }, main)

    local HEADER_H = 60

    local header = new("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, HEADER_H),
        BackgroundTransparency = 1,
        ZIndex = 4,
    }, content)

    local headerTitle = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 18, 0, 0),
        Size = UDim2.new(0, 220, 1, 0), Font = FONT_MED, TextSize = T(15),
        TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
        Text = "home", ZIndex = 5,
    }, header)

    -- settings gear (far right) ------------------------------------------------
    local gearBtn = new("TextButton", {
        Name = "SettingsButton",
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.fromOffset(34, 34), BackgroundColor3 = Theme.Input,
        Text = "", AutoButtonColor = false, ZIndex = 5,
    }, header)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, gearBtn)
    local gearIcon = makeIcon(gearBtn, "settings", 18, Theme.Muted, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), 6)

    -- search box (sits to the left of the gear) --------------------------------
    local searchBox = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -58, 0.5, 0),
        Size = UDim2.fromOffset(164, 34), BackgroundColor3 = Theme.Input, ZIndex = 5,
    }, header)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, searchBox)
    local searchIcon = makeIcon(searchBox, "search", 15, Theme.Muted, UDim2.new(0, 12, 0.5, 0), Vector2.new(0, 0.5))

    local searchInput = new("TextBox", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 36, 0, 0),
        Size = UDim2.new(1, -44, 1, 0), Font = FONT_MED, TextSize = T(12),
        TextColor3 = Theme.Text, PlaceholderText = "search...",
        PlaceholderColor3 = Theme.Hint, Text = "", ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
    }, searchBox)

    local pageHolder = new("Frame", {
        Name = "PageHolder",
        Position = UDim2.new(0, 0, 0, HEADER_H),
        Size = UDim2.new(1, 0, 1, -HEADER_H),
        BackgroundTransparency = 1,
        ZIndex = 3,
    }, content)

    -- menu scale (driven by the settings popup) ----------------------------------
    local scaleObj = new("UIScale", { Scale = Library._scale or 1 }, holder)
    Library._scaleObj = scaleObj

    -- drag / resize ----------------------------------------------------------
    makeDraggable(header, holder)
    makeDraggable(headerTitle, holder)
    makeDraggable(brand, holder)
    makeDraggable(brandNameLbl, holder)

    -- resize grip
    local grip = new("TextButton", {
        AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -4),
        Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, ZIndex = 20,
    }, main)
    local gripIcon = makeIcon(grip, "resize", 14, Theme.Hint, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), 21)
    connect(grip.MouseEnter, function() tweenIconColor(gripIcon, Theme.Accent, 0.12) end)
    connect(grip.MouseLeave, function() tweenIconColor(gripIcon, Theme.Hint, 0.12) end)
    do
        local resizing, startMouse, startSize = false, nil, nil
        connect(grip.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                resizing = true
                startMouse = Vector2.new(input.Position.X, input.Position.Y)
                startSize = holder.AbsoluteSize
            end
        end)
        connect(UserInputService.InputChanged, function(input)
            if not resizing then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                -- AbsoluteSize / mouse deltas are in screen pixels; Size is pre-scale
                local sc = Library._scale or 1
                local dx, dy = input.Position.X - startMouse.X, input.Position.Y - startMouse.Y
                holder.Size = UDim2.fromOffset(
                    math.clamp((startSize.X + dx) / sc, 640, 1500),
                    math.clamp((startSize.Y + dy) / sc, 420, 950)
                )
            end
        end)
        connect(UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                resizing = false
            end
        end)
    end

    -- window object ----------------------------------------------------------
    local Window = extend({
        Holder = holder,
        Main = main,
        Sidebar = sidebar,
        Content = content,
        HeaderTitle = headerTitle,
        SearchInput = searchInput,
        PageHolder = pageHolder,
        Nav = nav,
        Sections = {},
        Tabs = {},
        Pages = {},
        ActiveTab = nil,
        ActivePage = nil,
        ToggleKey = opts.ToggleKey or Enum.KeyCode.RightShift,
        _switcher = nil,
        _navOrder = 0,
    }, WindowMethods)

    -- switcher ---------------------------------------------------------------
    local function clearSwitcher()
        if Window._switcher then
            Window._switcher:Destroy()
            Window._switcher = nil
        end
        Window._switcherLayout = nil
    end

    function Window:_buildSwitcher(tab)
        clearSwitcher()
        if #tab.Pages <= 1 then return end

        local SW_H, SEG_H = 34, 28
        local holderFrame = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.fromOffset(0, SW_H),
            BackgroundColor3 = Theme.Input,
            ZIndex = 5,
        }, header)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, holderFrame)
        Window._switcher = holderFrame

        local pill = new("Frame", {
            BackgroundColor3 = Theme.Card, Size = UDim2.fromOffset(0, SEG_H),
            Position = UDim2.fromOffset(3, 3), ZIndex = 6,
        }, holderFrame)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)

        local segs = {}
        for i, page in ipairs(tab.Pages) do
            local seg = new("Frame", {
                BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 3),
                Size = UDim2.fromOffset(32, SEG_H), ClipsDescendants = true, ZIndex = 7,
            }, holderFrame)
            local btn = new("TextButton", {
                BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
                Text = "", AutoButtonColor = false, ZIndex = 9,
            }, seg)
            local ic = makeIcon(seg, page.Icon, 16, Theme.Muted, UDim2.fromOffset(8, 6), nil, 8)
            local textW = textWidth(page.Name, T(12), FONT_MED)
            local lbl = new("TextLabel", {
                BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 0),
                Size = UDim2.fromOffset(textW + 4, SEG_H),
                Font = FONT_MED, TextSize = T(12), TextColor3 = Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left, Text = page.Name,
                TextTransparency = 1, ZIndex = 8,
            }, seg)
            segs[i] = { Frame = seg, Icon = ic, Label = lbl, Page = page, TextW = textW }
            connect(btn.MouseButton1Click, function()
                Window:SelectPage(tab, page)
            end)
        end

        local current = tab.ActivePage or tab.Pages[1]
        -- layout(animate, page): slides the pill and grows/shrinks the segments
        local function layout(animate, newCurrent)
            if newCurrent then current = newCurrent end
            local t = animate and 0.22 or 0
            local ease = Enum.EasingStyle.Quint
            local x, selPos, selSize = 3, UDim2.fromOffset(3, 3), UDim2.fromOffset(32, SEG_H)
            for _, sg in ipairs(segs) do
                local selected = (sg.Page == current)
                local w = selected and (10 + 16 + 6 + sg.TextW + 14) or 32
                local pos, size = UDim2.fromOffset(x, 3), UDim2.fromOffset(w, SEG_H)
                local iconPos = UDim2.fromOffset(selected and 10 or 8, 6)
                if selected then selPos, selSize = pos, size end
                if animate then
                    tween(sg.Frame, { Position = pos, Size = size }, t, ease)
                    tween(sg.Icon, { Position = iconPos }, t, ease)
                    tween(sg.Label, { TextTransparency = selected and 0 or 1 }, t)
                    tweenIconColor(sg.Icon, selected and Theme.Accent or Theme.Muted, t)
                else
                    sg.Frame.Position, sg.Frame.Size = pos, size
                    sg.Icon.Position = iconPos
                    sg.Label.TextTransparency = selected and 0 or 1
                    setIconColor(sg.Icon, selected and Theme.Accent or Theme.Muted)
                end
                x = x + w + 2
            end
            local total = UDim2.fromOffset(x + 1, SW_H)
            if animate then
                tween(holderFrame, { Size = total }, t, ease)
                tween(pill, { Position = selPos, Size = selSize }, t, ease)
            else
                holderFrame.Size = total
                pill.Position, pill.Size = selPos, selSize
            end
        end

        layout(false)
        Window._switcherLayout = layout
    end

    function Window:SelectPage(tab, page)
        if not page then return end
        tab.ActivePage = page
        Window.ActivePage = page
        for _, p in ipairs(Window.Pages) do
            if p ~= page and p.Frame then p.Frame.Visible = false end
        end
        -- the incoming page fades in and slides up a little
        if page.Frame and not page.Frame.Visible then
            page.Frame.GroupTransparency = 1
            page.Frame.Position = UDim2.fromOffset(0, 16)
            page.Frame.Visible = true
            tween(page.Frame, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, 0.28,
                Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        end
        if Window._switcherLayout then
            Window._switcherLayout(true, page)
        end
        Window:ApplyFilter(Window.SearchInput.Text)
    end

    function Window:SelectTab(tab)
        Window.ActiveTab = tab
        for _, t in ipairs(Window.Tabs) do
            t:SetActive(t == tab)
        end
        if headerTitle.Text ~= tab.Name then
            headerTitle.Text = tab.Name
            headerTitle.TextTransparency = 1
            headerTitle.Position = UDim2.new(0, 30, 0, 0)
            tween(headerTitle, { TextTransparency = 0, Position = UDim2.new(0, 18, 0, 0) }, 0.28, Enum.EasingStyle.Quint)
        end
        Window:_buildSwitcher(tab)
        Window:SelectPage(tab, tab.ActivePage or tab.Pages[1])
    end

    function Window:ApplyFilter(query)
        query = tostring(query or ""):lower()
        local page = Window.ActivePage
        if not page then return end
        for _, card in ipairs(page.Cards) do
            card:ApplyFilter(query)
        end
    end

    connect(searchInput:GetPropertyChangedSignal("Text"), function()
        Window:ApplyFilter(searchInput.Text)
    end)

    -- settings popup (opened by the gear next to the search bar) ----------------
    do
        local isOpen = false
        local POPUP_W, SUB_W = 186, 180

        local catcher = new("TextButton", {
            Name = "SettingsCatcher", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
            Text = "", AutoButtonColor = false, Visible = false, ZIndex = 59,
        }, content)

        local popup = new("CanvasGroup", {
            Name = "Settings",
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, HEADER_H + 4),
            Size = UDim2.new(0, POPUP_W, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.Card, GroupTransparency = 1, Visible = false, ZIndex = 60,
        }, content)
        new("UICorner", { CornerRadius = UDim.new(0, 16) }, popup)
        new("UIStroke", { Color = Theme.Divider, Transparency = 0.9, Thickness = 1 }, popup)
        local popScale = new("UIScale", { Scale = 0.92 }, popup)
        new("UIPadding", {
            PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
        }, popup)
        new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, popup)

        local titleRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1 }, popup)
        local titleIcon = makeIcon(titleRow, "settings", 18, Theme.Accent, UDim2.new(0, 0, 0.5, 0), Vector2.new(0, 0.5))
        onAccentChange(function(c) if titleIcon.Parent then setIconColor(titleIcon, c) end end)
        new("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -28, 1, 0),
            Font = FONT_SEMI, TextSize = T(13), TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left, Text = "customize",
        }, titleRow)
        new("Frame", {
            BackgroundColor3 = Theme.Divider, BackgroundTransparency = 0.9,
            Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 2,
        }, popup)

        local rowsFrame = new("Frame", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3,
        }, popup)
        new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, rowsFrame)

        local host = extend({ RowsFrame = rowsFrame, _rows = {} }, ControlMethods)

        -- submenus: the small boxes that open to the right side of the settings box
        local submenus = {}
        local function closeSubmenus(except)
            for _, sm in ipairs(submenus) do
                if sm ~= except then sm.Close() end
            end
        end

        local function addSubmenu(build)
            local sub = new("CanvasGroup", {
                Name = "SettingsSubmenu",
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -(16 + POPUP_W + 8), 0, HEADER_H + 4),
                Size = UDim2.new(0, SUB_W, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.Card, GroupTransparency = 1, Visible = false, ZIndex = 61,
            }, content)
            new("UICorner", { CornerRadius = UDim.new(0, 16) }, sub)
            new("UIStroke", { Color = Theme.Divider, Transparency = 0.9, Thickness = 1 }, sub)
            new("UIPadding", {
                PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
                PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
            }, sub)
            local subRows = new("Frame", {
                BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
            }, sub)
            new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, subRows)
            local subHost = extend({ RowsFrame = subRows, _rows = {} }, ControlMethods)
            build(subHost)

            local open = false
            local sm = {}
            function sm.Open()
                closeSubmenus(sm)
                open = true
                sub.Visible = true
                sub.GroupTransparency = 1
                tween(sub, { GroupTransparency = 0 }, 0.2, Enum.EasingStyle.Quint)
            end
            function sm.Close()
                if not open then return end
                open = false
                tween(sub, { GroupTransparency = 1 }, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                task.delay(0.17, function()
                    if not open and sub.Parent then sub.Visible = false end
                end)
            end
            function sm.Toggle()
                if open then sm.Close() else sm.Open() end
            end
            function sm.IsOpen() return open end
            return sm
        end

        -- a settings row that opens a submenu: name on the left, right-pointing
        -- arrow on the very right (rotates down while the submenu is open)
        local function addTriggerRow(name, build)
            local row = new("TextButton", {
                BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26),
                Text = "", AutoButtonColor = false,
            }, rowsFrame)
            markRow(host, row, name)
            new("TextLabel", {
                BackgroundTransparency = 1, Size = UDim2.new(1, -24, 1, 0),
                Font = FONT_MED, TextSize = T(13), TextColor3 = Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left, Text = name,
            }, row)
            local arrow = makeIcon(row, "arrowRight", 14, Theme.Muted,
                UDim2.new(1, 0, 0.5, 0), Vector2.new(1, 0.5), 6)
            local sm = addSubmenu(build)
            table.insert(submenus, sm)
            connect(row.MouseButton1Click, function()
                local opening = not sm:IsOpen()
                sm.Toggle()
                tween(arrow, { Rotation = opening and 90 or 0 }, 0.2, Enum.EasingStyle.Quint)
                tweenIconColor(arrow, opening and Theme.Accent or Theme.Muted, 0.15)
            end)
            return sm
        end

        -- Menu → submenu with the scale / text size sliders and a reset button
        local scaleSlider, textSlider
        addTriggerRow("Menu", function(sub)
            scaleSlider = sub:AddSlider({
                Name = "Menu Scale", Min = 0.75, Max = 1.35, Default = Library._scale, Increment = 0.05,
                Suffix = "x", Flag = "ui_scale",
                Callback = function(v) Library:SetScale(v) end,
            })
            textSlider = sub:AddSlider({
                Name = "Text Size", Min = 0, Max = 6, Default = Library._textBoost or 2, Increment = 1,
                Suffix = "pt", Flag = "ui_textsize",
                Callback = function(v) Library:SetTextSize(v) end,
            })
            sub:AddButton({
                Name = "Reset Menu",
                Callback = function()
                    Library:SetScale(1)
                    Library:SetTextSize(2)
                    if scaleSlider then scaleSlider:Set(1, true) end
                    if textSlider then textSlider:Set(2, true) end
                end,
            })
        end)

        local themeNames = {}
        for _, th in ipairs(Library.Themes) do table.insert(themeNames, th.Name) end

        host:AddDropdown({
            Name = "Theme", Options = themeNames, Default = Library._themeName, Flag = "ui_theme",
            Callback = function(v) Library:SetTheme(v) end,
        })

        -- HUD → submenu with the info bar / keybinds list toggles
        addTriggerRow("HUD", function(sub)
            sub:AddToggle({
                Name = "Info Bar", Default = true, Flag = "ui_infobar", CheckboxRight = true,
                Callback = function(v) Library:SetInfoBar(v) end,
            })
            sub:AddToggle({
                Name = "Keybinds List", Default = true, Flag = "ui_keybinds", CheckboxRight = true,
                Callback = function(v) Library:SetKeybindList(v) end,
            })
        end)

        host:AddToggle({
            Name = "Notifications", Default = true, Flag = "ui_notifications", CheckboxRight = true,
            Callback = function(v) Library:SetNotifications(v) end,
        })
        host:AddToggle({
            Name = "Hide Info", Default = false, Flag = "ui_hideinfo", CheckboxRight = true,
            Callback = function(v)
                if footerNameLbl and footerNameLbl.Parent then
                    footerNameLbl.Visible = not v
                end
            end,
        })
        host:AddButton({
            Name = "Unload", Danger = true,
            Callback = function() Library:Unload() end,
        })

        local function setOpen(open)
            open = open and true or false
            if open == isOpen then return end
            isOpen = open
            if open then
                catcher.Visible = true
                popup.Visible = true
                popup.GroupTransparency = 1
                popup.Position = UDim2.new(1, -16, 0, HEADER_H - 6)
                popScale.Scale = 0.9
                tween(popup, { GroupTransparency = 0, Position = UDim2.new(1, -16, 0, HEADER_H + 4) }, 0.24, Enum.EasingStyle.Quint)
                tween(popScale, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
                tween(gearIcon, { Rotation = 90 }, 0.4, Enum.EasingStyle.Quint)
                tweenIconColor(gearIcon, Theme.Accent, 0.15)
            else
                closeSubmenus()
                catcher.Visible = false
                tween(popup, { GroupTransparency = 1, Position = UDim2.new(1, -16, 0, HEADER_H - 6) }, 0.15,
                    Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                tween(popScale, { Scale = 0.94 }, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                tween(gearIcon, { Rotation = 0 }, 0.3, Enum.EasingStyle.Quint)
                tweenIconColor(gearIcon, Theme.Muted, 0.15)
                task.delay(0.17, function()
                    if not isOpen and popup.Parent then popup.Visible = false end
                end)
            end
        end

        connect(gearBtn.MouseButton1Click, function() setOpen(not isOpen) end)
        connect(catcher.MouseButton1Click, function() setOpen(false) end)
        connect(gearBtn.MouseEnter, function() tween(gearBtn, { BackgroundColor3 = Color3.fromRGB(0x2a, 0x2a, 0x2f) }, 0.12) end)
        connect(gearBtn.MouseLeave, function() tween(gearBtn, { BackgroundColor3 = Theme.Input }, 0.12) end)

        Window.Settings = {
            Host = host, Popup = popup, Button = gearBtn,
            Open = function() setOpen(true) end,
            Close = function() setOpen(false) end,
            Toggle = function() setOpen(not isOpen) end,
            IsOpen = function() return isOpen end,
        }
    end

    -- public window methods --------------------------------------------------
    -- AddSection("Name") | AddSection("Name", iconId) | AddSection({ Name = "Name", Icon = iconId })
    function Window:AddSection(nameOrOpts, iconArg)
        local sOpts = type(nameOrOpts) == "table" and nameOrOpts or { Name = nameOrOpts, Icon = iconArg }
        local section = {
            Name = sOpts.Name or "Section",
            Tabs = {},
            Window = Window,
        }
        extend(section, SectionMethods)
        table.insert(Window.Sections, section)

        Window._navOrder = Window._navOrder + 1
        local group = new("Frame", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = Window._navOrder,
            ZIndex = 4,
        }, nav)

        new("UIListLayout", {
            Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder,
        }, group)

        local labelRow = new("Frame", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24),
            LayoutOrder = 1, ZIndex = 4,
        }, group)

        local textX = 6
        if resolveIcon(sOpts.Icon) then
            section.Icon = makeIcon(labelRow, sOpts.Icon, 14, Theme.Hint, UDim2.new(0, 6, 0.5, 0), Vector2.new(0, 0.5), 4)
            textX = 26
        end
        new("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(textX, 0),
            Size = UDim2.new(1, -textX, 1, 0),
            Font = FONT_SEMI, TextSize = T(10), TextColor3 = Theme.Hint,
            TextXAlignment = Enum.TextXAlignment.Left, Text = section.Name,
            ZIndex = 4,
        }, labelRow)

        local itemsHolder = new("Frame", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, ZIndex = 4,
        }, group)
        new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, itemsHolder)

        section._holder = itemsHolder
        return section
    end

    function Window:Toggle()
        if Window._closed then
            Window._closed = false
            holder.Visible = true
            main.GroupTransparency = 1
            uiScale.Scale = 0.97
            tween(main, { GroupTransparency = 0 }, 0.18)
            tween(uiScale, { Scale = 1 }, 0.18)
        else
            Window._closed = true
            if Window.Settings then Window.Settings.Close() end
            tween(main, { GroupTransparency = 1 }, 0.16)
            tween(uiScale, { Scale = 0.97 }, 0.16)
            task.delay(0.18, function()
                if Window._closed then holder.Visible = false end
            end)
        end
    end

    function Window:SetToggleKey(key)
        Window.ToggleKey = key
        Library:SetToggleKey(key)
    end

    Library.Window = Window
    Library._toggleKey = Window.ToggleKey
    Library:_refreshBinds()
    return Window
end

--============================================================================
-- SECTION
--============================================================================
function SectionMethods:AddTab(opts)
    opts = opts or {}
    local window = self.Window
    local tab = {
        Name = opts.Name or "Tab",
        Icon = opts.Icon,
        Pages = {},
        Section = self,
        Window = window,
    }
    extend(tab, TabMethods)
    table.insert(self.Tabs, tab)
    table.insert(window.Tabs, tab)

    local item = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40),
        ZIndex = 5,
    }, self._holder)

    local highlight = new("Frame", {
        BackgroundColor3 = Theme.Card, BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0.5, -18),
        Size = UDim2.new(1, 0, 0, 36), ZIndex = 5,
    }, item)
    new("UICorner", { CornerRadius = UDim.new(0, 12) }, highlight)

    local btn = new("TextButton", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        Text = "", AutoButtonColor = false, ZIndex = 8,
    }, item)

    -- Icon accepts an asset id ("rbxassetid://123", "123", 123), a Library.Icons name, or nothing (placeholder ring)
    local ICON_X, LABEL_X = 12, 42
    local icon = makeIcon(item, tab.Icon, 18, Theme.Muted, UDim2.new(0, ICON_X, 0.5, -9), nil, 7)
    local label = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, LABEL_X, 0, 0),
        Size = UDim2.new(1, -(LABEL_X + 6), 1, 0), Font = FONT_SEMI, TextSize = T(13),
        TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left,
        Text = tab.Name, ZIndex = 7,
    }, item)

    tab.Button = item
    tab.Highlight = highlight
    tab.Icon = icon
    tab.Label = label

    connect(btn.MouseEnter, function()
        if window.ActiveTab ~= tab then
            tween(highlight, { BackgroundTransparency = 0.93 }, 0.12)
        end
    end)
    connect(btn.MouseLeave, function()
        if window.ActiveTab ~= tab then
            tween(highlight, { BackgroundTransparency = 1 }, 0.12)
        end
    end)
    connect(btn.MouseButton1Click, function()
        window:SelectTab(tab)
    end)

    -- selecting a tab: highlight fades in and the icon + label nudge to the right
    function tab:SetActive(active)
        local nudge = active and 4 or 0
        local ease = Enum.EasingStyle.Quint
        tween(highlight, { BackgroundTransparency = active and 0 or 1 }, 0.2)
        tween(label, {
            TextColor3 = active and Theme.Text or Theme.Muted,
            Position = UDim2.new(0, LABEL_X + nudge, 0, 0),
        }, 0.25, ease)
        tween(icon, { Position = UDim2.new(0, ICON_X + nudge, 0.5, -9) }, 0.25, ease)
        tweenIconColor(icon, active and Theme.Text or Theme.Muted, 0.2)
    end

    return tab
end

--============================================================================
-- TAB
--============================================================================
function TabMethods:AddPage(opts)
    opts = opts or {}
    local window = self.Window
    local page = {
        Name = opts.Name or "Page",
        Icon = opts.Icon,
        Tab = self,
        Cards = {},
    }
    extend(page, PageMethods)
    table.insert(self.Pages, page)
    table.insert(window.Pages, page)

    -- the CanvasGroup lets the whole page fade + slide when it is selected (see Window:SelectPage)
    local group = new("CanvasGroup", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        ZIndex = 4,
    }, window.PageHolder)

    local scroll = new("ScrollingFrame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Muted,
        ScrollBarImageTransparency = 0.6,
        ZIndex = 4,
    }, group)
    page.Frame = group
    page.Scroll = scroll

    local col1 = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, 16),
        Size = UDim2.new(0.5, -22, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 4,
    }, scroll)
    new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, col1)

    local col2 = new("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 6, 0, 16),
        Size = UDim2.new(0.5, -22, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 4,
    }, scroll)
    new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, col2)

    page.Col1, page.Col2 = col1, col2

    -- responsive single column
    local function relayout()
        if not scroll.Parent then return end
        local narrow = scroll.AbsoluteSize.X < 520
        if narrow then
            col1.Size = UDim2.new(1, -32, 0, 0)
            col1.Position = UDim2.new(0, 16, 0, 16)
            col2.Visible = false
            for _, card in ipairs(page.Cards) do
                card.Frame.Parent = col1
            end
        else
            col1.Size = UDim2.new(0.5, -22, 0, 0)
            col1.Position = UDim2.new(0, 16, 0, 16)
            col2.Visible = true
            for _, card in ipairs(page.Cards) do
                card.Frame.Parent = (card.Column == 2) and col2 or col1
            end
        end
    end
    connect(scroll:GetPropertyChangedSignal("AbsoluteSize"), relayout)
    page._relayout = relayout

    -- Show something straight away: the first tab with a page gets selected,
    -- and the active tab's page switcher is rebuilt as extra pages arrive.
    if not window.ActiveTab then
        window:SelectTab(self)
    elseif window.ActiveTab == self then
        window:_buildSwitcher(self)
    end

    return page
end

--============================================================================
-- PAGE
--============================================================================
function PageMethods:AddCard(opts)
    opts = opts or {}
    local page = self
    local column = (opts.Column == 2) and 2 or 1

    local frame = new("Frame", {
        BackgroundColor3 = Theme.Card,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = #page.Cards + 1,
        ZIndex = 5,
    }, (column == 2) and page.Col2 or page.Col1)
    new("UICorner", { CornerRadius = UDim.new(0, 14) }, frame)

    local body = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 5,
    }, frame)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14),
        PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14),
    }, body)
    new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, body)

    -- header
    local headerRow = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26),
        LayoutOrder = 1, ZIndex = 6,
    }, body)
    local headerBtn = new("TextButton", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        Text = "", AutoButtonColor = false, ZIndex = 6,
    }, headerRow)

    local hIcon = makeIcon(headerRow, opts.Icon, 18, Theme.Accent, UDim2.new(0, 0, 0.5, -9), nil, 7)
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 28, 0, 0),
        Size = UDim2.new(1, -56, 1, 0), Font = FONT_SEMI, TextSize = T(13),
        TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
        Text = opts.Name or "Card", ZIndex = 7,
    }, headerRow)

    -- expanded = arrowUp, collapsed = arrowDown
    local chevron = makeArrow(headerRow, 16, Theme.Muted, UDim2.new(1, -8, 0.5, 0), Vector2.new(0.5, 0.5), 7)
    chevron:Set(true, false)

    -- divider
    new("Frame", {
        BackgroundColor3 = Theme.Divider, BackgroundTransparency = Theme.DividerT,
        Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 2, ZIndex = 6,
    }, body)

    -- clipping wrapper
    local wrapper = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        ClipsDescendants = true, LayoutOrder = 3, ZIndex = 6,
    }, body)
    local rowsLayout = new("UIListLayout", {
        Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
    }, wrapper)

    local card = extend({
        Frame = frame,
        Body = body,
        RowsFrame = wrapper,
        Column = column,
        Name = opts.Name or "Card",
        Page = page,
        _rows = {},
        Collapsed = false,
    }, CardMethods)
    extend(card, ControlMethods)

    table.insert(page.Cards, card)

    local function updateHeight()
        if card.Collapsed then return end
        wrapper.Size = UDim2.new(1, 0, 0, rowsLayout.AbsoluteContentSize.Y)
    end
    connect(rowsLayout:GetPropertyChangedSignal("AbsoluteContentSize"), updateHeight)
    task.defer(updateHeight)

    local function setCollapsed(state, animate)
        card.Collapsed = state
        local target = state and 0 or rowsLayout.AbsoluteContentSize.Y
        if animate == false then
            wrapper.Size = UDim2.new(1, 0, 0, target)
        else
            tween(wrapper, { Size = UDim2.new(1, 0, 0, target) }, 0.26, Enum.EasingStyle.Quint)
        end
        chevron:Set(not state, animate ~= false)
    end

    connect(headerBtn.MouseButton1Click, function()
        setCollapsed(not card.Collapsed, true)
    end)

    if opts.Collapsed then
        card.Collapsed = true
        task.defer(function() setCollapsed(true, false) end)
    end

    -- filtering
    function card:ApplyFilter(query)
        query = tostring(query or ""):lower()
        if query == "" then
            for _, r in ipairs(self._rows) do
                r.Visible = not r:GetAttribute("DepHidden")
            end
            frame.Visible = true
            return
        end

        local cardMatches = tostring(self.Name):lower():find(query, 1, true) ~= nil
        local anyVisible = false
        for _, r in ipairs(self._rows) do
            local rowName = tostring(r:GetAttribute("RowName") or ""):lower()
            local match = (cardMatches or rowName:find(query, 1, true) ~= nil)
                and not r:GetAttribute("DepHidden")
            r.Visible = match
            if match then anyVisible = true end
        end
        frame.Visible = anyVisible or (#self._rows == 0 and cardMatches)
    end

    -- internal tab strip
    function card:AddTabStrip(stripOpts)
        stripOpts = stripOpts or {}
        local names = stripOpts.Tabs or { "A", "B", "C" }

        local strip = new("Frame", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30),
            LayoutOrder = 1, ZIndex = 7,
        }, wrapper)
        -- labels live in their own row; the underline stays a layout-free sibling
        local stripRow = new("Frame", {
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 7,
        }, strip)
        new("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder,
        }, stripRow)

        local underline = new("Frame", {
            BackgroundColor3 = Theme.Accent, Size = UDim2.fromOffset(0, 2),
            Position = UDim2.fromOffset(0, 28), ZIndex = 8,
        }, strip)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, underline)
        onAccentChange(function(c)
            if underline.Parent then underline.BackgroundColor3 = c end
        end)

        local dividerStrip = new("Frame", {
            BackgroundColor3 = Theme.Divider, BackgroundTransparency = Theme.DividerT,
            Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 2, ZIndex = 6,
        }, wrapper)

        local tabs, containers = {}, {}
        local activeIndex = 1

        local function placeUnderline()
            local t = tabs[activeIndex]
            if not t or not t.Label or not t.Label.Parent then return end
            -- Absolute* values are screen pixels; offsets are pre-UIScale, so divide by the menu scale
            local sc = Library._scale or 1
            local x = (t.Label.AbsolutePosition.X - strip.AbsolutePosition.X) / sc
            tween(underline, {
                Position = UDim2.fromOffset(x, 28),
                Size = UDim2.fromOffset(t.Label.AbsoluteSize.X / sc, 2),
            }, 0.15)
        end

        for i, nm in ipairs(names) do
            local lbl = new("TextButton", {
                BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 30),
                AutomaticSize = Enum.AutomaticSize.X,
                Font = FONT_MED, TextSize = T(12),
                TextColor3 = (i == 1) and Theme.Text or Theme.Muted,
                Text = tostring(nm), LayoutOrder = i, ZIndex = 8,
                AutoButtonColor = false,
            }, stripRow)
            tabs[i] = { Label = lbl }
            -- AutomaticSize resolves a frame later, so re-seat the underline once it does
            connect(lbl:GetPropertyChangedSignal("AbsoluteSize"), function()
                if activeIndex == i then placeUnderline() end
            end)

            local container = new("Frame", {
                BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Visible = (i == 1), LayoutOrder = 2 + i, ZIndex = 6,
            }, wrapper)
            new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, container)
            containers[i] = container

            connect(lbl.MouseButton1Click, function()
                activeIndex = i
                for j, t in ipairs(tabs) do
                    t.Label.TextColor3 = (j == i) and Theme.Text or Theme.Muted
                end
                for j, c in ipairs(containers) do
                    c.Visible = (j == i)
                end
                placeUnderline()
                task.defer(updateHeight)
            end)
        end

        task.defer(placeUnderline)

        local hosts = {}
        for i, c in ipairs(containers) do
            local host = extend({
                RowsFrame = c,
                Card = card,
                Container = c,
            }, ControlMethods)
            hosts[i] = host
        end
        -- NB: must be a bare call. `a and f() or g()` would truncate f() to one value.
        local unpackFn = table.unpack or unpack
        return unpackFn(hosts)
    end

    -- expose helpers
    function card:SetCollapsed(v) setCollapsed(v, true) end

    return card
end

--============================================================================
-- TOGGLE KEY / API
--============================================================================
function Library:SetToggleKey(key)
    self._toggleKey = key
    if self.Window then self.Window.ToggleKey = key end
end

Library._toggleKey = Enum.KeyCode.RightShift

connect(UserInputService.InputBegan, function(input, gameProcessed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local key = Library._toggleKey
    if key and input.KeyCode == key then
        if Library.Window then Library.Window:Toggle() end
    end
end)

--============================================================================
-- TOUCH TOGGLE BUTTON (only visible on touch devices)
--============================================================================
do
    local touchBtn = new("TextButton", {
        Name = "TouchToggle",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 10, 0.5, 0),
        Size = UDim2.fromOffset(34, 34),
        BackgroundColor3 = Theme.Card,
        Text = "≡",
        Font = FONT_BOLD,
        TextSize = T(16),
        TextColor3 = Theme.Text,
        AutoButtonColor = false,
        Visible = false,
        ZIndex = 420,
    }, gui)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, touchBtn)
    new("UIStroke", { Color = Theme.Divider, Transparency = 0.9, Thickness = 1 }, touchBtn)
    Library._touchButton = touchBtn

    local function isTouch()
        local ok = tryCall(function()
            return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
        end)
        return ok == true
    end
    touchBtn.Visible = isTouch()

    connect(UserInputService.LastInputTypeChanged, function(t)
        touchBtn.Visible = (t == Enum.UserInputType.Touch)
    end)

    connect(touchBtn.MouseButton1Click, function()
        if Library.Window then Library.Window:Toggle() end
    end)

    -- draggable
    do
        local dragging, startMouse, startPos = false, nil, nil
        connect(touchBtn.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.Touch
                or input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                startMouse = input.Position
                startPos = touchBtn.Position
            end
        end)
        connect(UserInputService.InputChanged, function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.Touch
                or input.UserInputType == Enum.UserInputType.MouseMovement then
                local d = input.Position - startMouse
                if d.Magnitude > 3 then
                    touchBtn.Position = UDim2.new(
                        startPos.X.Scale, startPos.X.Offset + d.X,
                        startPos.Y.Scale, startPos.Y.Offset + d.Y
                    )
                end
            end
        end)
        connect(UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.Touch
                or input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
    end
end

--============================================================================
-- CONFIG SAVE / LOAD (optional, executor-guarded)
--============================================================================
local function hasFileApi()
    return type(writefile) == "function" and type(isfolder) == "function"
        and type(makefolder) == "function" and type(isfile) == "function"
end

function Library:SaveConfig(name)
    if not hasFileApi() then return false, "no file api" end
    local ok, err = pcall(function()
        if not isfolder("lowercase_ui") then makefolder("lowercase_ui") end
        local data = game:GetService("HttpService"):JSONEncode(self.Flags)
        writefile("lowercase_ui/" .. tostring(name) .. ".json", data)
    end)
    return ok, err
end

function Library:LoadConfig(name)
    if not hasFileApi() or type(readfile) ~= "function" then return false, "no file api" end
    local ok, data = pcall(function()
        return readfile("lowercase_ui/" .. tostring(name) .. ".json")
    end)
    if not ok or not data then return false, "read failed" end
    local ok2, decoded = pcall(function()
        return game:GetService("HttpService"):JSONDecode(data)
    end)
    if not ok2 or type(decoded) ~= "table" then return false, "decode failed" end
    for k, v in pairs(decoded) do
        self:_setFlag(k, v)
    end
    return true
end

--============================================================================
-- UNLOAD
--============================================================================
function Library:Unload()
    if self._unloaded then return end
    self._unloaded = true
    self._alive = false

    for _, c in ipairs(self._connections) do
        pcall(function() c:Disconnect() end)
    end
    self._connections = {}

    pcall(function() if gui then gui:Destroy() end end)
    self.Gui = nil
    self.Window = nil

    if ENV.__LowerCaseDashboard == self then
        ENV.__LowerCaseDashboard = nil
    end
end

return Library
