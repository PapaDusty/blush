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
local function new(class, props, parent)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then
                pcall(function() inst[k] = v end)
            end
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

local FONT_MED    = Enum.Font.GothamMedium
local FONT_SEMI   = Enum.Font.GothamSemibold
local FONT_BOLD   = Enum.Font.GothamBold

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
    -- >>> put your own ids here <<<
    home      = "",
    settings  = "",
    search    = "",
    chevron   = "",
    check     = "",
    user      = "",
    sparkle   = "",
    sliders   = "",
    shield    = "",
    dot       = "",
}
Library.Icons = Icons

-- swap this for a real soft-shadow 9-slice if you have one
local SHADOW_IMAGE = ""

local function resolveIcon(def)
    if type(def) == "string" then
        local id = Icons[def] or def
        if type(id) ~= "string" or id == "" then return nil end
        return { Image = id }
    elseif type(def) == "table" then
        if def.Image and def.Image ~= "" then return def end
        return nil
    end
    return nil
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
            Image = resolved.Image,
            ImageColor3 = color,
            ScaleType = Enum.ScaleType.Fit,
            ImageRectOffset = resolved.ImageRectOffset,
            ImageRectSize = resolved.ImageRectSize,
            ZIndex = holder.ZIndex,
        }, holder)
    else
        local ring = new("Frame", {
            Name = "IconRing",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(0.7, 0.7),
            BackgroundTransparency = 1,
            ZIndex = holder.ZIndex,
        }, holder)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
        new("UIStroke", { Color = color, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, ring)
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

do
    local parent = getHiddenUI()
    if not parent then
        parent = tryCall(function() return game:GetService("CoreGui") end)
    end
    local placed = false
    if parent then
        placed = pcall(function() gui.Parent = parent end)
        if not placed or not gui.Parent then placed = false end
    end
    if not placed then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    protectGui(gui)
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
    Size = UDim2.new(0, 270, 0, 0),
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
function Library:Notify(opts)
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
    new("UICorner", { CornerRadius = UDim.new(0, 9) }, card)
    local stroke = new("UIStroke", {
        Color = Theme.Divider, Transparency = 0.92, Thickness = 1,
    }, card)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
    }, card)
    new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, card)

    local titleLbl = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16),
        Font = FONT_SEMI, TextSize = 12, TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Text = opts.Title or "notice",
        LayoutOrder = 1, ZIndex = 802,
    }, card)

    local contentLbl = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Font = FONT_MED, TextSize = 11,
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
    table.insert(host.Card._rows, row)
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
        control:SetVisible(Library.Flags[depFlag] == depValue)
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
        Size = UDim2.new(1, 0, 0, 24),
    }, host.RowsFrame)
    markRow(host, row, opts.Name)

    local btn = new("TextButton", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        Text = "", AutoButtonColor = false,
    }, row)

    local box = new("Frame", {
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.new(0, 0, 0.5, -8),
        BackgroundColor3 = Theme.Input,
    }, row)
    new("UICorner", { CornerRadius = UDim.new(0, 4) }, box)

    local check = new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        Font = FONT_BOLD, TextSize = 12, Text = "✓",
        TextColor3 = Color3.new(1, 1, 1), TextTransparency = 1,
    }, box)

    local labelColor = opts.Danger and Theme.Danger or Theme.Text
    local label = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 24, 0, 0),
        Size = UDim2.new(1, -24, 1, 0),
        Font = FONT_MED, TextSize = 13, TextColor3 = labelColor,
        TextXAlignment = Enum.TextXAlignment.Left, Text = opts.Name or "Toggle",
    }, row)

    local labelW = textWidth(label.Text, 13, FONT_MED)

    if opts.Badge then
        local txt = string.upper(opts.Badge)
        local bw = textWidth(txt, 9, FONT_BOLD) + 12
        local badge = new("Frame", {
            Position = UDim2.new(0, 24 + labelW + 8, 0.5, -8),
            Size = UDim2.fromOffset(bw, 16),
            BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.75,
        }, row)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, badge)
        new("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
            Font = FONT_BOLD, TextSize = 9, TextColor3 = Color3.new(1, 1, 1), Text = txt,
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
            Size = UDim2.fromOffset(0, 20),
            AutomaticSize = Enum.AutomaticSize.X,
        }, row)

        local chip = new("TextButton", {
            BackgroundColor3 = Theme.Input,
            AutoButtonColor = false,
            Size = UDim2.fromOffset(0, 20),
            Text = "", TextSize = 11, Font = FONT_MED,
            TextColor3 = Theme.Muted,
        }, chipHolder)
        new("UICorner", { CornerRadius = UDim.new(0, 4) }, chip)

        local bindKey, bindName = nil, nil
        local listening = false
        local listenConn

        local function chipRender()
            if listening then
                chip.Text = "..."
                chip.TextColor3 = Theme.Accent
                chip.Size = UDim2.fromOffset(textWidth("...", 11, FONT_MED) + 14, 20)
            else
                chip.Text = bindName or "none"
                chip.TextColor3 = Theme.Muted
                chip.Size = UDim2.fromOffset(textWidth(chip.Text, 11, FONT_MED) + 14, 20)
            end
        end

        local function stopListening()
            listening = false
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

        if type(opts.Keybind) == "EnumItem" then
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
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38),
    }, host.RowsFrame)
    markRow(host, row, opts.Name)

    local label = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, -70, 0, 18), Font = FONT_MED, TextSize = 12,
        TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
        Text = opts.Name or "Slider",
    }, row)

    local valueLbl = new("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 70, 0, 18),
        Font = FONT_MED, TextSize = 11, TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Right, Text = "",
    }, row)

    local hit = new("TextButton", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 20),
        Size = UDim2.new(1, 0, 0, 14), Text = "", AutoButtonColor = false,
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
        Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.new(1, 1, 1),
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
            tween(thumb, { Size = UDim2.fromOffset(14, 14) }, 0.1)
        end
    end)
    connect(hit.MouseEnter, function()
        tween(thumb, { Size = UDim2.fromOffset(14, 14) }, 0.12)
    end)
    connect(hit.MouseLeave, function()
        if not dragging then tween(thumb, { Size = UDim2.fromOffset(12, 12) }, 0.12) end
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
                tween(thumb, { Size = UDim2.fromOffset(12, 12) }, 0.12)
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

    local row = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    }, host.RowsFrame)
    new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, row)
    markRow(host, row, opts.Name)

    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
        Font = FONT_MED, TextSize = 11, TextColor3 = Theme.Muted,
        TextXAlignment = Enum.TextXAlignment.Left, Text = opts.Name or "Dropdown",
        LayoutOrder = 1,
    }, row)

    local box = new("TextButton", {
        BackgroundColor3 = Theme.Input, Size = UDim2.new(1, 0, 0, 28),
        AutoButtonColor = false, Text = "", LayoutOrder = 2,
    }, row)
    new("UICorner", { CornerRadius = UDim.new(0, 7) }, box)

    local selLbl = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -34, 1, 0), Font = FONT_MED, TextSize = 12,
        TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = "",
    }, box)

    local chev = makeIcon(box, "chevron", 12, Theme.Muted, UDim2.new(1, -18, 0.5, -6))

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

    local function closeList()
        if catcher then catcher:Destroy(); catcher = nil end
        if listHolder then listHolder:Destroy(); listHolder = nil end
    end

    local function openList()
        if listHolder then closeList(); return end

        catcher = new("TextButton", {
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
            Text = "", AutoButtonColor = false, ZIndex = 501,
        }, overlayLayer)
        connect(catcher.MouseButton1Click, closeList)

        local rowH = 24
        local listH = math.min(#options * rowH + 8, 180)

        local absPos = box.AbsolutePosition
        local absSize = box.AbsoluteSize
        local screenH = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 720

        local y = absPos.Y + absSize.Y + 4
        if y + listH > screenH - 8 then
            y = absPos.Y - listH - 4
        end

        listHolder = new("Frame", {
            BackgroundColor3 = Theme.Card, Position = UDim2.fromOffset(absPos.X, y),
            Size = UDim2.fromOffset(absSize.X, listH), ZIndex = 502,
        }, overlayLayer)
        new("UICorner", { CornerRadius = UDim.new(0, 7) }, listHolder)
        new("UIStroke", { Color = Theme.Divider, Transparency = 0.9, Thickness = 1 }, listHolder)
        new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, listHolder)

        local scroll = new("ScrollingFrame", {
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
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

            local lbl = new("TextLabel", {
                BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0),
                Size = UDim2.new(1, -20, 1, 0), Font = FONT_MED, TextSize = 12,
                TextColor3 = isSel and Theme.Accent or Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left, Text = optStr, ZIndex = 505,
            }, item)

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
                    closeList()
                    openList()
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

    connect(box.MouseButton1Click, openList)

    function control:Set(v)
        value = v
        if multi and type(value) ~= "table" then value = {} end
        render()
        Library:_setFlag(flag, value)
    end
    function control:Get() return value end
    function control:SetVisible(v)
        row.Visible = v and true or false
        if not row.Visible then closeList() end
    end

    render()
    applyDepends(control, opts)
    return control
end

-- --------------------------------------------------------------- KEYBIND ----
local function createKeybindRow(host, opts)
    opts = opts or {}
    local flag = opts.Flag or opts.Name

    local row = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24),
    }, host.RowsFrame)
    markRow(host, row, opts.Name)

    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -70, 1, 0),
        Font = FONT_MED, TextSize = 13, TextColor3 = opts.Danger and Theme.Danger or Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Text = opts.Name or "Keybind",
    }, row)

    local chip = new("TextButton", {
        BackgroundColor3 = Theme.Input, AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(40, 20), Text = "", Font = FONT_MED, TextSize = 11,
        TextColor3 = Theme.Muted,
    }, row)
    new("UICorner", { CornerRadius = UDim.new(0, 4) }, chip)

    local control = { Frame = row, Flag = flag }
    local bindKey, bindName, listening, listenConn

    local function render()
        if listening then
            chip.Text = "..."
            chip.TextColor3 = Theme.Accent
            chip.Size = UDim2.fromOffset(textWidth("...", 11, FONT_MED) + 14, 20)
        else
            chip.Text = bindName or "none"
            chip.TextColor3 = Theme.Muted
            chip.Size = UDim2.fromOffset(textWidth(chip.Text, 11, FONT_MED) + 14, 20)
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

    if type(opts.Default) == "EnumItem" then
        bindKey, bindName = opts.Default, opts.Default.Name
    elseif type(opts.Default) == "string" then
        bindName = opts.Default
    end
    render()

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
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28),
    }, host.RowsFrame)
    markRow(host, row, opts.Name)

    local btn = new("TextButton", {
        BackgroundColor3 = Theme.Input, Size = UDim2.fromScale(1, 1),
        AutoButtonColor = false, Text = "", TextSize = 12, Font = FONT_MED,
        TextColor3 = Theme.Text,
    }, row)
    new("UICorner", { CornerRadius = UDim.new(0, 7) }, btn)
    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        Font = FONT_MED, TextSize = 12,
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
        AutomaticSize = Enum.AutomaticSize.Y, Font = FONT_MED, TextSize = 11,
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
        Size = UDim2.new(0, 0, 0, 32),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Card,
        ZIndex = 400,
    }, gui)
    new("UICorner", { CornerRadius = UDim.new(0, 8) }, infoBar)
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
    local function addLabel(key, color)
        order = order + 1
        local lbl = new("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 32),
            AutomaticSize = Enum.AutomaticSize.X, Font = FONT_SEMI, TextSize = 11,
            TextColor3 = color, Text = "", LayoutOrder = order, ZIndex = 401,
        }, infoBar)
        infoLabels[key] = lbl
        return lbl
    end
    local function addDivider()
        order = order + 1
        new("Frame", {
            BackgroundColor3 = Theme.Divider, BackgroundTransparency = 0.9,
            Size = UDim2.fromOffset(1, 12), LayoutOrder = order, ZIndex = 401,
        }, infoBar)
    end

    addLabel("brand", Theme.Accent)
    addDivider()
    addLabel("user", Theme.Muted)
    addDivider()
    addLabel("fps", Theme.Muted)
    addDivider()
    addLabel("ping", Theme.Muted)
    addDivider()
    addLabel("clock", Theme.Muted)

    onAccentChange(function(c)
        if infoLabels.brand then infoLabels.brand.TextColor3 = c end
    end)
end

local function buildBindsPanel()
    if bindsPanel then return end
    bindsPanel = new("Frame", {
        Name = "BindsPanel",
        Position = UDim2.new(0, 12, 0, 12),
        Size = UDim2.new(0, 200, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Card,
        BackgroundTransparency = 1,
        ZIndex = 400,
    }, gui)
    new("UICorner", { CornerRadius = UDim.new(0, 9) }, bindsPanel)
    new("UIStroke", { Color = Theme.Divider, Transparency = 0.94, Thickness = 1 }, bindsPanel)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
    }, bindsPanel)

    local list = new("UIListLayout", {
        Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
    }, bindsPanel)

    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16),
        Font = FONT_SEMI, TextSize = 12, TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, Text = "active binds", LayoutOrder = 1,
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
end

function Library:_refreshBinds()
    if not bindsPanel or not Library._showBinds then return end
    buildBindsPanel()

    local entries = {}
    for _, e in ipairs(self._bindEntries) do
        local keyName = e.getKeyName and e.getKeyName()
        local enabled = e.getEnabled and e.getEnabled()
        if keyName and enabled then
            table.insert(entries, { name = e.name, key = keyName })
        end
    end

    for _, ch in ipairs(bindsRowsHolder:GetChildren()) do
        if ch:IsA("Frame") then ch:Destroy() end
    end

    for i, e in ipairs(entries) do
        local r = new("Frame", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = i,
        }, bindsRowsHolder)
        new("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(0.6, 0, 1, 0),
            Font = FONT_MED, TextSize = 11, TextColor3 = Theme.Muted,
            TextXAlignment = Enum.TextXAlignment.Left, Text = e.name,
        }, r)
        new("TextLabel", {
            BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.4, 0, 1, 0),
            Font = FONT_MED, TextSize = 11, TextColor3 = Theme.Muted,
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

    task.spawn(function()
        while Library._alive do
            if Library._showInfo and infoLabels.brand then
                infoLabels.brand.Text = (Library._brandName or "library") .. "."
                infoLabels.user.Text  = string.lower(LocalPlayer.Name)
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

    local winSize = opts.Size or Vector2.new(680, 470)

    local holder = new("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(winSize.X, winSize.Y),
        BackgroundTransparency = 1,
        ZIndex = 2,
    }, gui)
    new("UISizeConstraint", { MinSize = Vector2.new(520, 340), MaxSize = Vector2.new(1400, 900) }, holder)

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
    new("UICorner", { CornerRadius = UDim.new(0, 12) }, main)

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
        Size = UDim2.new(0, 170, 1, 0),
        BackgroundColor3 = Theme.Sidebar,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, main)
    new("UICorner", { CornerRadius = UDim.new(0, 12) }, sidebar)

    local brand = new("Frame", {
        Name = "Brand",
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundTransparency = 1,
        ZIndex = 4,
    }, sidebar)

    local logo = makeIcon(brand, opts.Logo, 30, Theme.Accent, UDim2.fromOffset(12, 8))
    logo.ZIndex = 5
    -- logo as a rounded square plate for the default icon
    local logoBg = new("Frame", {
        Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(12, 8),
        BackgroundColor3 = Theme.Card, ZIndex = 4,
    }, brand)
    new("UICorner", { CornerRadius = UDim.new(0, 7) }, logoBg)
    logo.Position = UDim2.fromOffset(19, 15)
    logo.Size = UDim2.fromOffset(16, 16)
    logo.ZIndex = 5

    local brandNameLbl = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 50, 0, 9),
        Size = UDim2.new(1, -56, 0, 18), Font = FONT_BOLD, TextSize = 15,
        TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
        Text = brandName .. ".", ZIndex = 5,
    }, brand)
    accent(brandNameLbl, "TextColor3")

    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 50, 0, 25),
        Size = UDim2.new(1, -56, 0, 14), Font = FONT_MED, TextSize = 11,
        TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left,
        Text = opts.Subtitle or "v1.0.0", ZIndex = 5,
    }, brand)

    -- nav --------------------------------------------------------------------
    local nav = new("ScrollingFrame", {
        Name = "Nav",
        Position = UDim2.new(0, 0, 0, 50),
        Size = UDim2.new(1, 0, 1, -104),
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
        Size = UDim2.new(1, 0, 0, 54),
        BackgroundTransparency = 1,
        ZIndex = 4,
    }, sidebar)

    new("Frame", {
        BackgroundColor3 = Theme.Divider, BackgroundTransparency = 0.9,
        Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -24, 0, 1),
        ZIndex = 4,
    }, footer)

    local avatar = new("ImageLabel", {
        BackgroundColor3 = Theme.Input, Position = UDim2.fromOffset(12, 11),
        Size = UDim2.fromOffset(32, 32), Image = "", ZIndex = 5,
    }, footer)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, avatar)

    local maskedName = string.sub(LocalPlayer.Name, 1, 2)
        .. string.rep("*", math.max(3, #LocalPlayer.Name - 2))

    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 52, 0, 11),
        Size = UDim2.new(1, -58, 0, 16), Font = FONT_SEMI, TextSize = 12,
        TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
        Text = maskedName, ZIndex = 5,
    }, footer)

    local sessionLbl = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 52, 0, 27),
        Size = UDim2.new(1, -58, 0, 14), Font = FONT_MED, TextSize = 11,
        TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left,
        Text = "session ", ZIndex = 5,
    }, footer)
    local sessionVal = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 52 + 42, 0, 27),
        Size = UDim2.new(1, -100, 0, 14), Font = FONT_SEMI, TextSize = 11,
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
        Position = UDim2.new(0, 170, 0, 0),
        Size = UDim2.new(1, -170, 1, 0),
        BackgroundTransparency = 1,
        ZIndex = 3,
    }, main)

    local header = new("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 54),
        BackgroundTransparency = 1,
        ZIndex = 4,
    }, content)

    local headerTitle = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(0, 220, 1, 0), Font = FONT_MED, TextSize = 15,
        TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
        Text = "home", ZIndex = 5,
    }, header)

    local searchBox = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.fromOffset(150, 28), BackgroundColor3 = Theme.Input, ZIndex = 5,
    }, header)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, searchBox)
    local searchIcon = makeIcon(searchBox, "search", 13, Theme.Muted, UDim2.new(0, 10, 0.5, -6))

    local searchInput = new("TextBox", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 30, 0, 0),
        Size = UDim2.new(1, -38, 1, 0), Font = FONT_MED, TextSize = 12,
        TextColor3 = Theme.Text, PlaceholderText = "search...",
        PlaceholderColor3 = Theme.Hint, Text = "", ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
    }, searchBox)

    local pageHolder = new("Frame", {
        Name = "PageHolder",
        Position = UDim2.new(0, 0, 0, 54),
        Size = UDim2.new(1, 0, 1, -54),
        BackgroundTransparency = 1,
        ZIndex = 3,
    }, content)

    -- drag / resize ----------------------------------------------------------
    local function makeDraggable(target, moveTarget)
        local dragging, startMouse, startPos = false, nil, nil
        connect(target.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                startMouse = input.Position
                startPos = moveTarget.Position
            end
        end)
        connect(UserInputService.InputChanged, function(input)
            if not dragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                local d = input.Position - startMouse
                moveTarget.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y
                )
            end
        end)
        connect(UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end
    makeDraggable(header, holder)
    makeDraggable(headerTitle, holder)
    makeDraggable(brand, holder)
    makeDraggable(brandNameLbl, holder)

    -- resize grip
    local grip = new("TextButton", {
        AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -6),
        Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, ZIndex = 6,
    }, main)
    for i = 1, 3 do
        new("Frame", {
            BackgroundColor3 = Theme.Muted, BackgroundTransparency = 0.5,
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -(i - 1) * 4, 1, 0),
            Size = UDim2.fromOffset(1, 2 + (i - 1) * 4),
            ZIndex = 6,
        }, grip)
    end
    do
        local resizing, startMouse, startSize = false, nil, nil
        connect(grip.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                resizing = true
                startMouse = input.Position
                startSize = holder.AbsoluteSize
            end
        end)
        connect(UserInputService.InputChanged, function(input)
            if not resizing then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                local d = input.Position - startMouse
                holder.Size = UDim2.fromOffset(
                    math.clamp(startSize.X + d.X, 520, 1400),
                    math.clamp(startSize.Y + d.Y, 340, 900)
                )
            end
        end)
        connect(UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
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
    end

    function Window:_buildSwitcher(tab)
        clearSwitcher()
        if #tab.Pages <= 1 then return end

        local holderFrame = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.fromOffset(0, 28),
            BackgroundColor3 = Theme.Input,
            ZIndex = 5,
        }, header)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, holderFrame)
        Window._switcher = holderFrame

        local pill = new("Frame", {
            BackgroundColor3 = Theme.Card, Size = UDim2.fromOffset(0, 22),
            Position = UDim2.fromOffset(3, 3), ZIndex = 6,
        }, holderFrame)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)

        local segs = {}
        for i, page in ipairs(tab.Pages) do
            local seg = new("Frame", {
                BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 3),
                Size = UDim2.fromOffset(26, 22), ZIndex = 7,
            }, holderFrame)
            local btn = new("TextButton", {
                BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
                Text = "", AutoButtonColor = false, ZIndex = 9,
            }, seg)
            local ic = makeIcon(seg, page.Icon, 14, Theme.Muted, UDim2.fromOffset(6, 4), nil, 8)
            local lbl = new("TextLabel", {
                BackgroundTransparency = 1, Position = UDim2.fromOffset(26, 0),
                Size = UDim2.fromOffset(textWidth(page.Name, 12, FONT_MED) + 4, 22),
                Font = FONT_MED, TextSize = 12, TextColor3 = Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left, Text = page.Name,
                Visible = false, ZIndex = 8,
            }, seg)
            segs[i] = { Frame = seg, Icon = ic, Label = lbl, Page = page, TextW = textWidth(page.Name, 12, FONT_MED) }
            connect(btn.MouseButton1Click, function()
                Window:SelectPage(tab, page)
            end)
        end

        local current = tab.ActivePage or tab.Pages[1]
        local function layout(animate)
            local x = 3
            local selIdx = 1
            for i, s in ipairs(segs) do
                local selected = (s.Page == current)
                if selected then selIdx = i end
                local w = selected and (8 + 14 + 6 + s.TextW + 12) or 26
                s.Label.Visible = selected
                s.Icon.Position = UDim2.fromOffset(selected and 8 or 6, 4)
                s.Frame.Position = UDim2.fromOffset(x, 3)
                s.Frame.Size = UDim2.fromOffset(w, 22)
                setIconColor(s.Icon, selected and Theme.Accent or Theme.Muted)
                s.Label.TextColor3 = selected and Theme.Text or Theme.Muted
                x = x + w + 2
            end
            holderFrame.Size = UDim2.fromOffset(x + 1, 28)
            local sel = segs[selIdx]
            if sel then
                if animate then
                    tween(pill, { Position = sel.Frame.Position, Size = sel.Frame.Size }, 0.16)
                else
                    pill.Position = sel.Frame.Position
                    pill.Size = sel.Frame.Size
                end
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
            if p.Frame then p.Frame.Visible = (p == page) end
        end
        if Window._switcherLayout then
            Window._switcherLayout(true)
        end
        -- re-apply active state on switcher
        if Window._switcher then
            Window:_buildSwitcher(tab)
        end
        Window:ApplyFilter(Window.SearchInput.Text)
    end

    function Window:SelectTab(tab)
        Window.ActiveTab = tab
        for _, t in ipairs(Window.Tabs) do
            t:SetActive(t == tab)
        end
        headerTitle.Text = tab.Name
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

    -- public window methods --------------------------------------------------
    function Window:AddSection(name)
        local section = {
            Name = name or "Section",
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

        local groupLayout = new("UIListLayout", {
            Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder,
        }, group)

        local label = new("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18),
            Font = FONT_MED, TextSize = 10, TextColor3 = Theme.Hint,
            TextXAlignment = Enum.TextXAlignment.Left, Text = section.Name,
            LayoutOrder = 1, ZIndex = 4,
        }, group)
        new("UIPadding", { PaddingLeft = UDim.new(0, 6) }, label)

        local itemsHolder = new("Frame", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, ZIndex = 4,
        }, group)
        new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, itemsHolder)

        -- tree guide
        local guide = new("Frame", {
            BackgroundColor3 = Theme.Muted, BackgroundTransparency = 0.7,
            Position = UDim2.new(0, 4, 0, 8), Size = UDim2.new(0, 1, 1, -16),
            ZIndex = 4,
        }, itemsHolder)

        section._holder = itemsHolder
        section._guide = guide
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
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34),
        ZIndex = 5,
    }, self._holder)

    local elbow = new("Frame", {
        BackgroundColor3 = Theme.Hint, BackgroundTransparency = 0.55,
        Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.fromOffset(9, 1),
        ZIndex = 5,
    }, item)
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, elbow)

    local highlight = new("Frame", {
        BackgroundColor3 = Theme.Card, BackgroundTransparency = 1,
        Position = UDim2.new(0, 14, 0.5, -15),
        Size = UDim2.new(1, -16, 0, 30), ZIndex = 5,
    }, item)
    new("UICorner", { CornerRadius = UDim.new(0, 8) }, highlight)

    local btn = new("TextButton", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        Text = "", AutoButtonColor = false, ZIndex = 8,
    }, item)

    local icon = makeIcon(item, tab.Icon, 16, Theme.Muted, UDim2.new(0, 22, 0.5, -8), nil, 7)
    local label = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 44, 0, 0),
        Size = UDim2.new(1, -50, 1, 0), Font = FONT_MED, TextSize = 13,
        TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Left,
        Text = tab.Name, ZIndex = 7,
    }, item)

    tab.Button = item
    tab.Highlight = highlight
    tab.Elbow = elbow
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

    function tab:SetActive(active)
        tween(highlight, { BackgroundTransparency = active and 0 or 1 }, 0.15)
        tween(label, { TextColor3 = active and Theme.Text or Theme.Muted }, 0.15)
        tweenIconColor(icon, active and Theme.Text or Theme.Muted, 0.15)
        elbow.BackgroundColor3 = active and Theme.Accent or Theme.Hint
        elbow.BackgroundTransparency = active and 0 or 0.55
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

    local scroll = new("ScrollingFrame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = Theme.Muted,
        ScrollBarImageTransparency = 0.6,
        Visible = false,
        ZIndex = 4,
    }, window.PageHolder)
    page.Frame = scroll

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
        local narrow = scroll.AbsoluteSize.X < 480
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
    new("UICorner", { CornerRadius = UDim.new(0, 10) }, frame)

    local body = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 5,
    }, frame)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
    }, body)
    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, body)

    -- header
    local headerRow = new("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20),
        LayoutOrder = 1, ZIndex = 6,
    }, body)
    local headerBtn = new("TextButton", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        Text = "", AutoButtonColor = false, ZIndex = 6,
    }, headerRow)

    local hIcon = makeIcon(headerRow, opts.Icon, 16, Theme.Accent, UDim2.new(0, 0, 0.5, -8), nil, 7)
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 24, 0, 0),
        Size = UDim2.new(1, -46, 1, 0), Font = FONT_SEMI, TextSize = 13,
        TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
        Text = opts.Name or "Card", ZIndex = 7,
    }, headerRow)

    local chevron = makeIcon(headerRow, "chevron", 14, Theme.Muted,
        UDim2.new(1, -7, 0.5, 0), Vector2.new(0.5, 0.5), 7)

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
            tween(wrapper, { Size = UDim2.new(1, 0, 0, target) }, 0.18)
        end
        tween(chevron, { Rotation = state and -90 or 0 }, 0.18)
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
                r.Visible = true
            end
            frame.Visible = true
            return
        end

        local cardMatches = tostring(self.Name):lower():find(query, 1, true) ~= nil
        local anyVisible = false
        for _, r in ipairs(self._rows) do
            local rowName = tostring(r:GetAttribute("RowName") or ""):lower()
            local match = cardMatches or rowName:find(query, 1, true) ~= nil
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
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24),
            LayoutOrder = 1, ZIndex = 7,
        }, wrapper)
        new("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder,
        }, strip)

        local underline = new("Frame", {
            BackgroundColor3 = Theme.Accent, Size = UDim2.fromOffset(0, 2),
            Position = UDim2.fromOffset(0, 22), ZIndex = 8,
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
            local x = t.Label.AbsolutePosition.X - strip.AbsolutePosition.X
            tween(underline, {
                Position = UDim2.fromOffset(x, 22),
                Size = UDim2.fromOffset(t.Label.AbsoluteSize.X, 2),
            }, 0.15)
        end

        for i, nm in ipairs(names) do
            local lbl = new("TextButton", {
                BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 24),
                AutomaticSize = Enum.AutomaticSize.X,
                Font = FONT_MED, TextSize = 12,
                TextColor3 = (i == 1) and Theme.Text or Theme.Muted,
                Text = tostring(nm), LayoutOrder = i, ZIndex = 8,
                AutoButtonColor = false,
            }, strip)
            tabs[i] = { Label = lbl }

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
        return table.unpack and table.unpack(hosts) or unpack(hosts)
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
        TextSize = 16,
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
