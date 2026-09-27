-- LIT Admin: single client executor script. Run while playing; no Studio installation.
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer or LocalPlayer.UserId ~= 1286354240 then return end
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local VirtualUser = game:GetService("VirtualUser")

-- Load IY
pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))() end)

-- Load Obsidian UI
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

-- The game's BombReplicator sometimes passes an incomplete payload.
-- Guard it only when this executor shares the client's ModuleScript cache.
task.spawn(function()
    local moduleScript = ReplicatedStorage:FindFirstChild("ExplosionMaker")
    if not moduleScript then return end
    local success, maker = pcall(require, moduleScript)
    if not success or type(maker) ~= "table" or type(maker.RequirementsToExplode) ~= "function"
        or maker._LITGuarded then return end
    maker._LITGuarded = true
    local original = maker.RequirementsToExplode
    maker.RequirementsToExplode = function(payload, ...)
        if type(payload) ~= "table" or typeof(payload.Hitbox) ~= "Instance" then return end
        return original(payload, ...)
    end
end)


local Options = Library.Options
local Toggles = Library.Toggles
Library.ForceCheckbox = false



local Window = Library:CreateWindow({
    Title = "LIT hub",
    Footer = "Locked In Twin",
    NotifySide = "Right",
    ShowCustomCursor = false,
})

local Tabs = {
    Main        = Window:AddTab(" Home", "house"),
    Defense     = Window:AddTab(" Invincibility", "shield"),
    Target      = Window:AddTab(" Attack", "sword"),
    Grab        = Window:AddTab(" Grab", "hand"),
    Player      = Window:AddTab(" Myself", "user"),
    Misc        = Window:AddTab(" Misc", "layers"),
    Fun         = Window:AddTab(" Troll", "smile"),
    Extras      = Window:AddTab(" Extra", "star"),
    Keybinds    = Window:AddTab(" Keybind", "keyboard"),
    Auras       = Window:AddTab(" Auras", "sparkles"),
    ["UI Settings"] = Window:AddTab(" Panel Settings", "settings")
}

-- Hide tab titles
task.spawn(function()
    task.wait(0.6)
    for name, tab in pairs(Tabs) do
        pcall(function()
            local title = tab.Container.Parent:FindFirstChild("Title")
            if title then
                title.Visible = false
                title.Text = ""
                title.Size = UDim2.new(0,0,0,0)
            end
        end)
    end
end)


local function notify(title, content, duration)
    Library:Notify({
        Title = title or "Notification",
        Description = content or "",
        Time = duration or 5,
    })
end


local function sendHubLoadedMessage()
    local message = " owner version loaded "
    local sent = false
    pcall(function()
        local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        if chatEvents then
            local say = chatEvents:FindFirstChild("SayMessageRequest")
            if say and typeof(say.FireServer) == "function" then
                say:FireServer(message, "All")
                sent = true
            end
        end
    end)
    if not sent then
        pcall(function()
            StarterGui:SetCore("ChatMakeSystemMessage", {
                Text = message;
                Color = Color3.fromRGB(255, 170, 0);
                Font = Enum.Font.SourceSansBold;
                FontSize = Enum.FontSize.Size18;
            })
        end)
    end
end

task.spawn(function()
    task.wait(1)
    sendHubLoadedMessage()
end)


-- Anti Paint keeps the game's instances intact and changes only local touch state.
local paintPartsBackup = {}
local paintConnections = {}
local function hidePaintTouch(part)
    if part:IsA("BasePart") and part.Name == "PaintPlayerPart" then
        if paintPartsBackup[part] == nil then paintPartsBackup[part] = part.CanTouch end
        part.CanTouch = false
    end
end
local function deleteAllPaintParts()
    for _, object in ipairs(Workspace:GetDescendants()) do hidePaintTouch(object) end
end
local function restorePaintParts()
    for part, original in pairs(paintPartsBackup) do
        if part.Parent then part.CanTouch = original end
        paintPartsBackup[part] = nil
    end
end
local function watchNewPaintParts()
    table.insert(paintConnections, Workspace.DescendantAdded:Connect(function(object)
        task.defer(function() if object.Parent then hidePaintTouch(object) end end)
    end))
end
local function disconnectWatchers()
    for _, connection in ipairs(paintConnections) do connection:Disconnect() end
    table.clear(paintConnections)
end

local function setTouchQuery(state)
    local char = Workspace:FindFirstChild(LocalPlayer.Name)
    if not char then return end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Part") or v:IsA("BasePart") then
            v.CanTouch = state
            v.CanQuery = state
        end
    end
end


local antiGucciConnection
local antiGucciLastRemote = 0
local safePosition
local restoreFrames = 0

local function spawnBlobman()
    local args = {
        [1] = "CreatureBlobman",
        [2] = CFrame.new(0, 5000000, 0),
        [3] = Vector3.new(0, 60, 0)
    }
    pcall(function()
        ReplicatedStorage.MenuToys.SpawnToyRemoteFunction:InvokeServer(unpack(args))
    end)
    local folder = Workspace:WaitForChild(LocalPlayer.Name .. "SpawnedInToys", 5)
    if folder and folder:FindFirstChild("CreatureBlobman") then
        local blob = folder.CreatureBlobman
        if blob:FindFirstChild("Head") then
            blob.Head.CFrame = CFrame.new(0, 50000, 0)
            blob.Head.Anchored = true
        end
        notify("Success", "Blobman Spawned!", 3)
    end
end

local function startAntiGucci()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")
    safePosition = rootPart.Position
    local folder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    local blob = folder and folder:FindFirstChild("CreatureBlobman")
    local seat = blob and blob:FindFirstChild("VehicleSeat")
    
    if not blob then
        spawnBlobman()
        task.wait(1)
        folder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
        blob = folder and folder:FindFirstChild("CreatureBlobman")
        seat = blob and blob:FindFirstChild("VehicleSeat")
    end
    
    if seat and seat:IsA("VehicleSeat") then
        rootPart.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
        seat:Sit(humanoid)
    end
    
    humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
        if humanoid.Jump and humanoid.Sit then
            restoreFrames = 15
            safePosition = rootPart.Position
        end
    end)
    
    if antiGucciConnection then antiGucciConnection:Disconnect() end
    
    antiGucciConnection = RunService.Heartbeat:Connect(function()
        if not rootPart or not humanoid then return end
        if os.clock() - antiGucciLastRemote >= 0.35 then
            antiGucciLastRemote = os.clock()
            pcall(function() ReplicatedStorage.CharacterEvents.RagdollRemote:FireServer(rootPart, 0) end)
        end
        if restoreFrames > 0 then
            rootPart.CFrame = CFrame.new(safePosition)
            restoreFrames = restoreFrames - 1
        end
    end)
    
    task.spawn(function()
        while humanoid.Sit do task.wait(1) end
        task.wait(0.5)
        rootPart.CFrame = CFrame.new(safePosition)
    end)
end

local function stopAntiGucci()
    if antiGucciConnection then
        antiGucciConnection:Disconnect()
        antiGucciConnection = nil
    end
    local blobFolder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    if blobFolder and blobFolder:FindFirstChild("CreatureBlobman") then
        blobFolder.CreatureBlobman:Destroy()
    end
end


local antiGucciConnectionTrain
local antiGucciTrainLastRemote = 0
local safePositionTrain
local restoreFramesTrain = 0

local function startAntiGucciTrain()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")
    safePositionTrain = rootPart.Position
    
    local folder = workspace.Map.AlwaysHereTweenedObjects
    local train = folder and folder:FindFirstChild("Train")
    local seat
    
    if train then
        for _, d in ipairs(train:GetDescendants()) do
            if d:IsA("Seat") then
                seat = d
                break
            end
        end
    end
    
    if seat then
        rootPart.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
        seat:Sit(humanoid)
    end
    
    humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
        if humanoid.Jump and humanoid.Sit then
            restoreFramesTrain = 15
            safePositionTrain = rootPart.Position
        end
    end)
    
    if antiGucciConnectionTrain then antiGucciConnectionTrain:Disconnect() end
    
    antiGucciConnectionTrain = RunService.Heartbeat:Connect(function()
        if not rootPart or not humanoid then return end
        if os.clock() - antiGucciTrainLastRemote >= 0.35 then
            antiGucciTrainLastRemote = os.clock()
            pcall(function() ReplicatedStorage.CharacterEvents.RagdollRemote:FireServer(rootPart, 0) end)
        end
        if restoreFramesTrain > 0 then
            rootPart.CFrame = CFrame.new(safePositionTrain)
            restoreFramesTrain = restoreFramesTrain - 1
        end
    end)
    
    task.spawn(function()
        while humanoid.Sit do task.wait(1) end
        task.wait(0.5)
        rootPart.CFrame = CFrame.new(safePositionTrain)
    end)
end

local function stopAntiGucciTrain()
    if antiGucciConnectionTrain then
        antiGucciConnectionTrain:Disconnect()
        antiGucciConnectionTrain = nil
    end
    local trainFolder = workspace.Map.AlwaysHereTweenedObjects
    if trainFolder and trainFolder:FindFirstChild("Train") then
        -- ResetPlayer function would be defined elsewhere
    end
end


local DefenseGroup = Tabs.Defense:AddLeftGroupbox(" Defense Main")
local DefenseExtra = Tabs.Defense:AddRightGroupbox(" Extra Defense")

-- Anti Grab: one connection, bounded remote calls, no character anchoring.
local antiGrabEnabled = false
local antiGrabConnection
local lastStruggle = 0
local lastVelocityStop = 0
local antiGrabElapsed = 0

local function antiGrabStep(dt)
    antiGrabElapsed += dt
    if antiGrabElapsed < 0.15 then return end
    antiGrabElapsed = 0
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local held = LocalPlayer:FindFirstChild("IsHeld")
    if not humanoid or not held or not held:IsA("BoolValue") or not held.Value then return end

    local now = os.clock()
    if now - lastStruggle >= (_G.LITAntiGrabDelay or 0.4) then
        lastStruggle = now
        local events = ReplicatedStorage:FindFirstChild("CharacterEvents")
        local struggle = events and events:FindFirstChild("Struggle")
        if struggle then pcall(function() struggle:FireServer(LocalPlayer) end) end
    end
    if now - lastVelocityStop >= 1 then
        lastVelocityStop = now
        local events = ReplicatedStorage:FindFirstChild("GameCorrectionEvents")
        local stopVelocity = events and events:FindFirstChild("StopAllVelocity")
        if stopVelocity then pcall(function() stopVelocity:FireServer() end) end
    end
    humanoid.PlatformStand = false
    local seat = humanoid.SeatPart
    if seat and seat.Parent and seat.Parent.Name ~= "CreatureBlobman" then
        humanoid.Sit = false
    end
end

DefenseGroup:AddToggle("AntiGrabBest", {
    Text = " Anti Grab",
    Default = false,
    Callback = function(value)
        antiGrabEnabled = value
        if antiGrabConnection then antiGrabConnection:Disconnect(); antiGrabConnection = nil end
        if value then
            antiGrabConnection = RunService.Heartbeat:Connect(function(dt)
                if antiGrabEnabled then antiGrabStep(dt) end
            end)
        end
    end,
})

-- Anti Blobman: reversible local touch filter; no detector destruction.
local antiBlobmanEnabled = false
local antiBlobmanConnection
local blobTouchBackup = {}

local function updateBlobDetector(object)
    if not object:IsA("BasePart") or not object.Parent
        or object.Parent.Name ~= "CreatureBlobman"
        or not string.find(object.Name, "Detector", 1, true) then return end
    if antiBlobmanEnabled then
        if blobTouchBackup[object] == nil then blobTouchBackup[object] = object.CanTouch end
        object.CanTouch = false
    elseif blobTouchBackup[object] ~= nil then
        object.CanTouch = blobTouchBackup[object]
        blobTouchBackup[object] = nil
    end
end

DefenseGroup:AddToggle("AntiBlobmanToggle", {
    Text = " Anti Blobman",
    Default = false,
    Callback = function(on)
        antiBlobmanEnabled = on
        if antiBlobmanConnection then antiBlobmanConnection:Disconnect(); antiBlobmanConnection = nil end
        if on then
            for _, object in ipairs(Workspace:GetDescendants()) do updateBlobDetector(object) end
            antiBlobmanConnection = Workspace.DescendantAdded:Connect(function(object)
                task.defer(function() if antiBlobmanEnabled then updateBlobDetector(object) end end)
            end)
        else
            for object in pairs(blobTouchBackup) do updateBlobDetector(object) end
        end
    end,
})

-- Anti-Explosion
local antiExplodeT = false
local connection

local function antiExplodeF()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:WaitForChild("HumanoidRootPart")
    local hum = char:WaitForChild("Humanoid")
    if connection then connection:Disconnect() end
    
    connection = workspace.ChildAdded:Connect(function(model)
        if model:IsA("BasePart") and model.Name == "Part" and antiExplodeT then
            task.wait()
            if not hrp or not hrp.Parent then return end
            local mag = (model.Position - hrp.Position).Magnitude
            if mag <= 20 then
                hrp.Anchored = true
                if char:FindFirstChild("Right Arm") and char["Right Arm"]:FindFirstChild("RagdollLimbPart") then
                    char["Right Arm"].RagdollLimbPart.CanCollide = false
                end
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                hum.PlatformStand = false
                hum.Sit = false
                task.wait(0.1)
                hrp.Anchored = false
            end
        end
    end)
end

DefenseGroup:AddToggle("AntiExplosionToggle", {
    Text = " Anti Explosion",
    Default = false,
    Callback = function(on)
        antiExplodeT = on
        if on then antiExplodeF() elseif connection then connection:Disconnect() end
    end
})

-- Anti-Burn
local hookBurnConn

local function hookBurn(char)
    local hum = char:WaitForChild("Humanoid")
    local hrp = char:WaitForChild("HumanoidRootPart")
    char.PrimaryPart = hrp
    if hookBurnConn then hookBurnConn:Disconnect() end
    
    hookBurnConn = hum.FireDebounce.Changed:Connect(function(isBurning)
        if isBurning then
            local me = char
            local oldCF = hrp.CFrame
            local plots = workspace:FindFirstChild("Plots")
            if plots and plots:FindFirstChild("Plot2") then
                local plot2 = plots.Plot2
                local barrier = plot2:FindFirstChild("Barrier")
                local pb = barrier and barrier:FindFirstChild("PlotBarrier")
                if pb and pb:IsA("BasePart") then
                    local safeCF = pb.CFrame * CFrame.new(0, 6, 0)
                    me:SetPrimaryPartCFrame(safeCF)
                    task.wait()
                    
                    local firePart = me:FindFirstChild("FirePlayerPart", true)
                    if firePart then
                        for _, obj in ipairs(firePart:GetChildren()) do
                            if obj:IsA("Sound") then obj:Stop() end
                            if obj:IsA("Light") or obj:IsA("ParticleEmitter") then obj.Enabled = false end
                        end
                        if firePart:FindFirstChild("CanBurn") then
                            firePart.CanBurn.Value = false
                        end
                        if hum:FindFirstChild("FireDebounce") then
                            hum.FireDebounce.Value = false
                        end
                    end
                    task.wait()
                    if me and me.PrimaryPart then
                        me:SetPrimaryPartCFrame(oldCF)
                    end
                end
            end
        end
    end)
end

DefenseGroup:AddToggle("AntiBurnToggle", {
    Text = " Anti Burn",
    Default = false,
    Callback = function(on)
        if on then hookBurn(LocalPlayer.Character) elseif hookBurnConn then hookBurnConn:Disconnect() end
    end
})

-- Anti-Void
local antiVoidConn
local VOID_THRESHOLD = -50
local SAFE_HEIGHT = 100

DefenseGroup:AddToggle("AntiVoidToggle", {
    Text = " Anti Void",
    Default = false,
    Callback = function(on)
        if on then
            if antiVoidConn then antiVoidConn:Disconnect() end
            antiVoidConn = RunService.Heartbeat:Connect(function()
                local char = LocalPlayer.Character
                if char and char.PrimaryPart then
                    local pos = char.PrimaryPart.Position
                    if pos.Y < VOID_THRESHOLD then
                        local safePos = Vector3.new(pos.X, pos.Y + SAFE_HEIGHT, pos.Z)
                        char:SetPrimaryPartCFrame(CFrame.new(safePos))
                        char.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
                    end
                end
            end)
        else
            if antiVoidConn then
                antiVoidConn:Disconnect()
                antiVoidConn = nil
            end
        end
    end
})

-- Anti-Sticky
local antiStickyT = false

DefenseGroup:AddToggle("AntiStickyToggle", {
    Text = " Anti Sticky",
    Default = false,
    Callback = function(Value)
        antiStickyT = Value
        if LocalPlayer.PlayerScripts:FindFirstChild("StickyPartsTouchDetection") then
            LocalPlayer.PlayerScripts.StickyPartsTouchDetection.Disabled = Value
        end
    end,
})

-- Anti Lag hides beams locally. Deleting replicated remotes breaks game scripts.
local antiLagEnabled = false
local antiLagConnection
local beamBackup = {}
local function updateLagBeam(object)
    if not object:IsA("Beam") then return end
    if antiLagEnabled then
        if beamBackup[object] == nil then beamBackup[object] = object.Enabled end
        object.Enabled = false
    elseif beamBackup[object] ~= nil then
        if object.Parent then object.Enabled = beamBackup[object] end
        beamBackup[object] = nil
    end
end

DefenseGroup:AddToggle("AntiLagToggle", {
    Text = " Anti Lag",
    Default = false,
    Callback = function(value)
        antiLagEnabled = value
        if antiLagConnection then antiLagConnection:Disconnect(); antiLagConnection = nil end
        if value then
            for _, object in ipairs(Workspace:GetDescendants()) do updateLagBeam(object) end
            antiLagConnection = Workspace.DescendantAdded:Connect(function(object)
                task.defer(function() if antiLagEnabled then updateLagBeam(object) end end)
            end)
        else
            for object in pairs(beamBackup) do updateLagBeam(object) end
        end
    end,
})

-- Anti-Paint
DefenseExtra:AddToggle("PaintDeleteToggle", {
    Text = " Anti Paint",
    Default = false,
    Callback = function(state)
        if state then
            deleteAllPaintParts()
            watchNewPaintParts()
        else
            restorePaintParts()
            disconnectWatchers()
        end
    end
})

-- Auto Gucci (Blobman)
local autoGucciActive = false

DefenseExtra:AddToggle("AutoGucciToggle", {
    Text = " Anti Gucci (Blobman)",
    Default = false,
    Callback = function(Value)
        autoGucciActive = Value
        if Value then
            startAntiGucci()
            notify("system", "auto gucci active (monitoring)", 3)
            task.spawn(function()
                while autoGucciActive do
                    local toysFolder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                    local blobExists = toysFolder and toysFolder:FindFirstChild("CreatureBlobman")
                    if not blobExists then
                        stopAntiGucci()
                        spawnBlobman()
                        notify("System", "blobman lost", 3)
                        local retries = 0
                        repeat
                            task.wait(0.2)
                            retries = retries + 1
                            toysFolder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                        until (toysFolder and toysFolder:FindFirstChild("CreatureBlobman")) or retries > 25 or not autoGucciActive
                        if autoGucciActive and toysFolder and toysFolder:FindFirstChild("CreatureBlobman") then
                            startAntiGucci()
                            notify("System", "blobman restored.", 3)
                        end
                    end
                    task.wait(0.5)
                end
            end)
        else
            autoGucciActive = false
            stopAntiGucci()
            notify("System", "auto gucci disabled.", 3)
        end
    end
})

-- Auto Gucci (Train)
local autoGucciActiveTrain = false

DefenseExtra:AddToggle("AutoGucciTrainToggle", {
    Text = " Anti Gucci (Train)",
    Default = false,
    Callback = function(Value)
        autoGucciActiveTrain = Value
        if Value then
            startAntiGucciTrain()
            notify("system", "Gucci active (monitoring)", 3)
            task.spawn(function()
                while autoGucciActiveTrain do
                    local trainFolder = workspace.Map.AlwaysHereTweenedObjects
                    local trainExists = trainFolder and trainFolder:FindFirstChild("Train")
                    if not trainExists then
                        stopAntiGucciTrain()
                        notify("System", "Train lost", 3)
                        local retries = 0
                        repeat
                            task.wait(0.2)
                            retries = retries + 1
                            trainFolder = workspace.Map.AlwaysHereTweenedObjects
                        until (trainFolder and trainFolder:FindFirstChild("Train")) or retries > 25 or not autoGucciActiveTrain
                        if autoGucciActiveTrain and trainFolder and trainFolder:FindFirstChild("Train") then
                            startAntiGucciTrain()
                            notify("System", "Train restored.", 3)
                        end
                    end
                    task.wait(0.5)
                end
            end)
        else
            autoGucciActiveTrain = false
            stopAntiGucciTrain()
            notify("System", "Gucci disabled.", 3)
        end
    end
})

-- Toy List for Anti-Input Lag
local ToyList = {
    ["Coconut"]     = "FoodCoconut",
    ["Banana"]      = "FoodBanana",
    ["Fries"]       = "FoodFrenchFries",
    ["MeatStick"]   = "FoodMeatStick",
    ["Poop"]        = "PoopPile",
    ["Donut"]       = "FoodDonut",
    ["Cake"]        = "FoodCakePink",
    ["Burger"]      = "FoodHamburger",
    ["Pizza"]       = "FoodPizzaCheese",
    ["Hotdog"]      = "FoodHotdog",
    ["Mushroom"]    = "FoodMushroomPoison",
    ["Banjo"]       = "InstrumentGuitarBanjo",
    ["Violin"]      = "InstrumentGuitarViolin",
    ["Ukulele"]     = "InstrumentGuitarUkulele",
    ["Sax"]         = "InstrumentWoodwindSaxophone",
    ["Vuvuzela"]    = "InstrumentBrassVuvuzela",
    ["Bongos"]      = "InstrumentDrumBongos",
    ["Mic"]         = "InstrumentVoiceMicrophone",
    ["Pepperoni"]   = "FoodPizzaPepperoni",
    ["Piano"]       = "InstrumentPianoMelodica",
    ["Bread"]       = "FoodBread",
    ["Egg"]         = "FoodDippyEgg",
    ["Mayo"]        = "FoodMayonnaise",
    ["WhiteMug"]    = "CupMugWhite",
    ["Ocarina"]     = "InstrumentWoodwindOcarina",
    ["SparklePoop"] = "PoopPileSparkle",
    ["BrownMug"]    = "CupMugBrown",
    ["Trumpet"]     = "InstrumentBrassTrumpet",
    ["Snare"]       = "InstrumentDrumSnare",
}

local DropdownValues = {}
for shortName, _ in pairs(ToyList) do
    table.insert(DropdownValues, shortName)
end
table.sort(DropdownValues)

local SelectedToy = ToyList[DropdownValues[1]]

DefenseExtra:AddDropdown("AntiInputLagToy", {
    Text = " Input Lag Item",
    Values = DropdownValues,
    Default = 1,
    Callback = function(Value)
        SelectedToy = ToyList[Value]
    end
})

-- Anti-Input Lag
DefenseExtra:AddToggle("AntiInputLag", {
    Text = " Anti Input Lag",
    Default = false,
    Callback = function(Value)
        _G.AntiInputLag = Value
        if Value then
            task.spawn(function()
                local plr = Players.LocalPlayer
                local char = plr.Character or plr.CharacterAdded:Wait()
                local hrp = char:WaitForChild("HumanoidRootPart")
                local SpawnRemote = ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("SpawnToyRemoteFunction")
                
                while _G.AntiInputLag do
                    local toysFolder = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                    if not toysFolder then task.wait() continue end
                    
                    local toy = toysFolder:FindFirstChild(SelectedToy)
                    if not toy then
                        pcall(function()
                            SpawnRemote:InvokeServer(SelectedToy, hrp.CFrame * CFrame.new(0, 5, 0), Vector3.zero)
                        end)
                        local t0 = tick()
                        repeat
                            task.wait(0.35)
                            toysFolder = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                            toy = toysFolder and toysFolder:FindFirstChild(SelectedToy)
                        until toy or tick() - t0 > 1 or not _G.AntiInputLag
                    end
                    
                    if toy and toy.Parent then
                        local holdPart = toy:FindFirstChild("HoldPart")
                        if holdPart then
                            local holdingPlayer = holdPart:FindFirstChild("HoldingPlayer")
                            holdingPlayer = holdingPlayer and holdingPlayer.Value
                            if holdingPlayer and holdingPlayer ~= plr then
                                pcall(function()
                                    holdPart.DropItemRemoteFunction:InvokeServer(toy, hrp.CFrame * CFrame.new(0, 2000, 0), Vector3.zero)
                                end)
                                toy:Destroy()
                            else
                                pcall(function() holdPart.HoldItemRemoteFunction:InvokeServer(toy, char) end)
                                task.wait()
                                pcall(function() holdPart.DropItemRemoteFunction:InvokeServer(toy, hrp.CFrame * CFrame.new(0, 2000, 0), Vector3.zero) end)
                                task.wait()
                            end
                        end
                    end
                    task.wait(0.35)
                end
            end)
        end
    end
})

-- Shuriken Anti-Kick
local tpActive = false

DefenseExtra:AddToggle("ShurikenAntiKick", {
    Text = " Anti Kick",
    Default = false,
    Callback = function(Value)
        _G.ShurikenAntiKick = Value
        
        local function ClearKunai()
            local plr = Players.LocalPlayer
            local inv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
            local destroyrem = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")
            if inv and destroyrem then
                for _, v in pairs(inv:GetChildren()) do
                    if v.Name == "AntiKick" or v.Name == "NinjaShuriken" then
                        pcall(function() destroyrem:FireServer(v) end)
                    end
                end
            end
        end
        
        if Value then
            task.spawn(function()
                local plr = Players.LocalPlayer
                local setOwner = ReplicatedStorage:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
                local stickyEvent = ReplicatedStorage:WaitForChild("PlayerEvents"):WaitForChild("StickyPartEvent")
                local spawnRemote = ReplicatedStorage.MenuToys.SpawnToyRemoteFunction
                local destroyrem = ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("DestroyToy")
                local canSpawn = plr:WaitForChild("CanSpawnToy")
                
                local function getHRP()
                    if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                        return plr.Character.HumanoidRootPart
                    else
                        return plr.CharacterAdded:Wait():WaitForChild("HumanoidRootPart")
                    end
                end
                
                local function CheckForHome()
                    if not workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then
                        return false
                    end
                    for _, v in pairs(workspace.Plots:GetChildren()) do
                        local sign = v:FindFirstChild("PlotSign")
                        local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
                        if owners then
                            for _, b in pairs(owners:GetChildren()) do
                                if b.Value == plr.Name then
                                    local folder = workspace.PlotItems:FindFirstChild(v.Name)
                                    if folder then return true, folder end
                                end
                            end
                        end
                    end
                    return false
                end
                
                local function StickKunai(kunai)
                    if not kunai or not kunai:FindFirstChild("StickyPart") then return end
                    local currentHRP = getHRP()
                    if not currentHRP then return end
                    
                    if kunai:FindFirstChild("SoundPart") then
                        if not kunai.SoundPart:FindFirstChild("PartOwner") or kunai.SoundPart.PartOwner.Value ~= plr.Name then
                            setOwner:FireServer(kunai.SoundPart, kunai.SoundPart.CFrame)
                        end
                    end
                    
                    local firePart = currentHRP:FindFirstChild("FirePlayerPart") or currentHRP:WaitForChild("FirePlayerPart", 5)
                    if firePart then
                        stickyEvent:FireServer(kunai.StickyPart, firePart, CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), math.rad(90)))
                    end
                    
                    for _, obj in pairs(kunai:GetChildren()) do
                        if obj.Name == "Pyramid" then
                            obj.CanTouch = false
                            obj.CanCollide = false
                            obj.CanQuery = false
                            obj.Transparency = 0
                            if not obj:FindFirstChild("Highlight") then
                                Instance.new("Highlight", obj).FillColor = Color3.fromRGB(0, 0, 0)
                            end
                        elseif obj.Name == "Main" then
                            obj.CanTouch = false
                            obj.CanCollide = false
                            obj.CanQuery = false
                            obj.Transparency = 0
                            if not obj:FindFirstChild("Highlight") then
                                Instance.new("Highlight", obj).FillColor = Color3.fromRGB(255, 255, 255)
                            end
                        elseif obj:IsA("BasePart") then
                            obj.CanTouch = false
                            obj.CanCollide = false
                            obj.CanQuery = false
                            obj.Transparency = 1
                        end
                    end
                end
                
                local function SpawnToy(name)
                    local t = tick()
                    while not canSpawn.Value do
                        if not _G.ShurikenAntiKick or tick() - t > 5 then return nil end
                        task.wait(0.1)
                    end
                    local currentHRP = getHRP()
                    if currentHRP then
                        task.spawn(function()
                            pcall(function()
                                spawnRemote:InvokeServer(name, currentHRP.CFrame * CFrame.new(0, 12, 20), Vector3.zero)
                            end)
                        end)
                    end
                    local boolik, house = CheckForHome()
                    local inv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                    if boolik and house then
                        return house:WaitForChild(name, 2)
                    elseif not workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) and inv then
                        return inv:WaitForChild(name, 2)
                    end
                    return nil
                end
                
                while _G.ShurikenAntiKick do
                    task.wait(0.005)
                    if not plr.Character or not plr.Character:FindFirstChild("Humanoid") or plr.Character.Humanoid.Health <= 0 then
                        continue
                    end
                    
                    local inv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                    local kunai = inv and inv:FindFirstChild("NinjaShuriken")
                    
                    if workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then
                        local boolik, house = CheckForHome()
                        if boolik and house and workspace.Plots:FindFirstChild(house.Name) then
                            local sign = workspace.Plots[house.Name]:FindFirstChild("PlotSign")
                            if sign and sign.ThisPlotsOwners.Value.TimeRemainingNum.Value > 89 then
                                kunai = SpawnToy("NinjaShuriken")
                                if kunai == nil then continue end
                                kunai.Name = "AntiKick"
                                StickKunai(kunai)
                            end
                        end
                    end
                    
                    if not kunai then
                        if workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then continue end
                        kunai = SpawnToy("NinjaShuriken")
                        if kunai == nil then continue end
                        kunai.Name = "AntiKick"
                        if not kunai then continue end
                    end
                    
                    repeat
                        if kunai and kunai:FindFirstChild("StickyPart") and kunai.StickyPart.CanTouch == true then
                            StickKunai(kunai)
                            kunai.Name = "AntiKick"
                        end
                        task.wait(0.1)
                    until not kunai or not _G.ShurikenAntiKick or not kunai:FindFirstChild("StickyPart") or kunai.StickyPart.CanTouch == false or not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") or not kunai:FindFirstChild("StickyPart") or (plr.Character.HumanoidRootPart.Position - kunai.StickyPart.Position).Magnitude >= 20
                    
                    if not kunai or not kunai:FindFirstChild("StickyPart") or not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") or (plr.Character.HumanoidRootPart.Position - kunai.StickyPart.Position).Magnitude >= 20 then
                        ClearKunai()
                    end
                    
                    pcall(function()
                        repeat
                            task.wait(0.05)
                        until not _G.ShurikenAntiKick or not plr.Character or not plr.Character:FindFirstChild("Humanoid") or not kunai or not kunai:FindFirstChild("StickyPart") or not kunai.StickyPart:FindFirstChild("StickyWeld") or not kunai.StickyPart.StickyWeld.Part1
                        if not kunai or not kunai:FindFirstChild("StickyPart") or (plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health <= 0) or not kunai["StickyPart"]:FindFirstChild("StickyWeld").Part1 then
                            ClearKunai()
                        end
                    end)
                end
            end)
        else
            _G.ShurikenAntiKick = false
            ClearKunai()
        end
    end
})

-- Loop TP
DefenseExtra:AddToggle("LoopTP", {
    Text = " Loop TP",
    Default = false,
    Callback = function(Value)
        tpActive = Value
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local hrp = char:WaitForChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        if Value then
            if hum then hum.PlatformStand = true end
            task.spawn(function()
                while tpActive and hrp do
                    local x = math.random(-500, 500)
                    local y = math.random(30, 480)
                    local z = math.random(-500, 500)
                    hrp.CFrame = CFrame.new(x, y, z)
                    task.wait(0.03)
                end
            end)
        else
            if hum then hum.PlatformStand = false end
        end
    end,
})



-- Extra invincibility controls from the reference panel.
local extraAntis = Tabs.Defense:AddLeftGroupbox("More Antis")
local defenseMisc = Tabs.Defense:AddRightGroupbox("Miscellaneous")
local defenseConfig = Tabs.Defense:AddRightGroupbox("Config")

local touchFilters = { AntiSnowball = false, AntiBanana = false, AntiPoison = false }
local touchBackup = {}
local function shouldFilterTouch(part)
    if not part:IsA("BasePart") then return false end
    local name = string.lower(part.Name .. " " .. (part.Parent and part.Parent.Name or ""))
    return touchFilters.AntiSnowball and string.find(name, "snowball", 1, true)
        or touchFilters.AntiBanana and string.find(name, "banana", 1, true)
        or touchFilters.AntiPoison and (string.find(name, "poison", 1, true)
            or string.find(name, "mushroom", 1, true))
end
local function refreshTouchPart(part)
    if not part:IsA("BasePart") then return end
    if shouldFilterTouch(part) then
        if touchBackup[part] == nil then touchBackup[part] = part.CanTouch end
        part.CanTouch = false
    elseif touchBackup[part] ~= nil then
        if part.Parent then part.CanTouch = touchBackup[part] end
        touchBackup[part] = nil
    end
end
local function refreshTouchFilters()
    for _, object in ipairs(Workspace:GetDescendants()) do refreshTouchPart(object) end
end
Workspace.DescendantAdded:Connect(function(object)
    task.defer(function() if object.Parent then refreshTouchPart(object) end end)
end)
for _, entry in ipairs({
    { "AntiSnowball", "Anti Snowball" },
    { "AntiBanana", "Anti Banana" },
    { "AntiPoison", "Anti Poison" },
}) do
    extraAntis:AddToggle(entry[1], {
        Text = entry[2], Default = false,
        Callback = function(value)
            touchFilters[entry[1]] = value
            refreshTouchFilters()
        end,
    })
end

local gucciChoice = "Blobman"
extraAntis:AddDropdown("GucciType", {
    Text = "GUCCI Type", Values = { "Blobman", "Train" }, Default = "Blobman",
    Callback = function(value)
        gucciChoice = value
        if Toggles.GucciAntiGrab and Toggles.GucciAntiGrab.Value then
            if Toggles.AutoGucciToggle then
                Toggles.AutoGucciToggle:SetValue(value == "Blobman")
            end
            if Toggles.AutoGucciTrainToggle then
                Toggles.AutoGucciTrainToggle:SetValue(value == "Train")
            end
        end
    end,
})
extraAntis:AddToggle("GucciAntiGrab", {
    Text = "[GUCCI] Anti Grab", Default = false,
    Callback = function(value)
        if Toggles.AutoGucciToggle then
            Toggles.AutoGucciToggle:SetValue(value and gucciChoice == "Blobman")
        end
        if Toggles.AutoGucciTrainToggle then
            Toggles.AutoGucciTrainToggle:SetValue(value and gucciChoice == "Train")
        end
    end,
})

local antiNetOwnerEnabled = false
local antiNetOwnerType = "On grab"
extraAntis:AddToggle("AntiNetworkOwnership", {
    Text = "Anti Network Ownership", Default = false,
    Callback = function(value) antiNetOwnerEnabled = value end,
})

local pcldAntiKickEnabled = false
local pcldHookInstalled = false
extraAntis:AddToggle("BreakPCLDAntiKick", {
    Text = "[Break PCLD] Anti Kick", Default = false,
    Callback = function(value)
        pcldAntiKickEnabled = value
        if value and not pcldHookInstalled then
            if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function"
                or type(newcclosure) ~= "function" then
                notify("Anti Kick", "This executor has no namecall hook.", 4)
                return
            end
            local previous
            local success = pcall(function()
                previous = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                    if pcldAntiKickEnabled and self == LocalPlayer and getnamecallmethod() == "Kick" then
                        return nil
                    end
                    return previous(self, ...)
                end))
            end)
            pcldHookInstalled = success
            if not success then notify("Anti Kick", "Could not install the client hook.", 4) end
        end
    end,
})

local antiInvisEnabled = false
local transparencyBackup = {}
local transparencyConnections = {}
local function stopAntiInvis()
    for _, connection in ipairs(transparencyConnections) do connection:Disconnect() end
    table.clear(transparencyConnections)
    for part, original in pairs(transparencyBackup) do
        if part.Parent then part.Transparency = original end
    end
    table.clear(transparencyBackup)
end
local function watchTransparency(part)
    if not part:IsA("BasePart") or part.Name == "HumanoidRootPart"
        or transparencyBackup[part] ~= nil then return end
    transparencyBackup[part] = part.Transparency
    table.insert(transparencyConnections, part:GetPropertyChangedSignal("Transparency"):Connect(function()
        if antiInvisEnabled and part.Parent and part.Transparency > transparencyBackup[part] then
            part.Transparency = transparencyBackup[part]
        end
    end))
end
local function startAntiInvis()
    stopAntiInvis()
    if not antiInvisEnabled then return end
    local character = LocalPlayer.Character
    if not character then return end
    for _, object in ipairs(character:GetDescendants()) do watchTransparency(object) end
    table.insert(transparencyConnections, character.DescendantAdded:Connect(function(object)
        task.defer(function() if antiInvisEnabled then watchTransparency(object) end end)
    end))
end
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.3)
    if antiInvisEnabled then startAntiInvis() end
end)
extraAntis:AddToggle("AntiInvis", {
    Text = "Anti Invis", Default = false,
    Callback = function(value)
        antiInvisEnabled = value
        startAntiInvis()
    end,
})

defenseMisc:AddToggle("DisableVoid", {
    Text = "Disable Void", Default = false,
    Callback = function(value)
        if Toggles.AntiVoidToggle then Toggles.AntiVoidToggle:SetValue(value) end
    end,
})
local waterWalkEnabled = false
local waterPlatform
defenseMisc:AddToggle("WaterWalk", {
    Text = "Water Walk", Default = false,
    Callback = function(value)
        waterWalkEnabled = value
        if not value and waterPlatform then waterPlatform:Destroy(); waterPlatform = nil end
    end,
})

local barrierEnabled = false
local barrierBackup = {}
local function refreshBarrier(part)
    if not part:IsA("BasePart") or not string.find(string.lower(part.Name), "barrier", 1, true) then return end
    if barrierEnabled then
        if barrierBackup[part] == nil then barrierBackup[part] = part.CanCollide end
        part.CanCollide = false
    elseif barrierBackup[part] ~= nil then
        if part.Parent then part.CanCollide = barrierBackup[part] end
        barrierBackup[part] = nil
    end
end
defenseMisc:AddToggle("NoclipBarrier", {
    Text = "Noclip Barrier", Default = false,
    Callback = function(value)
        barrierEnabled = value
        for _, object in ipairs(Workspace:GetDescendants()) do refreshBarrier(object) end
    end,
})
Workspace.DescendantAdded:Connect(function(object)
    task.defer(function() if barrierEnabled and object.Parent then refreshBarrier(object) end end)
end)

local antiFlingEnabled = false
local flingBackup = {}
defenseMisc:AddToggle("AntiFlingObjects", {
    Text = "Anti-Fling [Objects Noclip]", Default = false,
    Callback = function(value) antiFlingEnabled = value end,
})

_G.LITKickDelay = 0.4
_G.LITAntiGrabDelay = 0.4
local autoLagEnabled = false
local autoLeaveEnabled = false
local autoLagThreshold = 20
local autoLagOwnsToggle = false
local lowFpsTime = 0
defenseConfig:AddSlider("AntiLagSensitivity", {
    Text = "Auto Anti-Lag Sensitivity", Default = 20,
    Min = 5, Max = 60, Rounding = 0, Suffix = " FPS",
    Callback = function(value) autoLagThreshold = value end,
})
defenseConfig:AddToggle("DefenseAutoAntiLag", {
    Text = "Auto Anti Lag", Default = false,
    Callback = function(value) autoLagEnabled = value end,
})
defenseConfig:AddToggle("AutoLeave", {
    Text = "Auto Leave", Default = false,
    Callback = function(value) autoLeaveEnabled = value end,
})
defenseConfig:AddDropdown("AntiGrabType", {
    Text = "Anti-Grab Type", Values = { "Normal", "Strong" }, Default = "Normal",
    Callback = function(value)
        _G.LITAntiGrabDelay = value == "Strong" and 0.2 or 0.4
    end,
})
defenseConfig:AddDropdown("AntiNetOwnerType", {
    Text = "Anti Net-Owner Type", Values = { "On grab", "Off" }, Default = "On grab",
    Callback = function(value) antiNetOwnerType = value end,
})
defenseConfig:AddSlider("GrabDropDelay", {
    Text = "Grab & Drop Delay", Default = 0.4,
    Min = 0.2, Max = 1.5, Rounding = 2, Suffix = " s",
    Callback = function(value) _G.LITKickDelay = value end,
})

local miscElapsed = 0
local miscFrames = 0
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.MaxParts = 64
RunService.Heartbeat:Connect(function(dt)
    miscElapsed += dt
    miscFrames += 1
    if miscElapsed < 0.25 then return end
    local sample = miscElapsed
    local fps = miscFrames / sample
    miscElapsed, miscFrames = 0, 0
    if autoLagEnabled and fps < autoLagThreshold then
        lowFpsTime += sample
    else
        lowFpsTime = math.max(0, lowFpsTime - sample)
    end
    if autoLagEnabled and lowFpsTime >= 2 and not autoLagOwnsToggle then
        if Toggles.AntiLagToggle and not Toggles.AntiLagToggle.Value then
            Toggles.AntiLagToggle:SetValue(true)
            autoLagOwnsToggle = true
        end
    elseif (not autoLagEnabled or lowFpsTime < 0.5) and autoLagOwnsToggle then
        if Toggles.AntiLagToggle then Toggles.AntiLagToggle:SetValue(false) end
        autoLagOwnsToggle = false
    end
    if autoLeaveEnabled and lowFpsTime >= 15 then
        LocalPlayer:Kick("Auto Leave: sustained low frame rate")
    end
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if antiNetOwnerEnabled and antiNetOwnerType == "On grab" and humanoid and root then
        local held = LocalPlayer:FindFirstChild("IsHeld")
        if held and held:IsA("BoolValue") and held.Value then
            humanoid.PlatformStand = false
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end
    if waterWalkEnabled and humanoid and root
        and humanoid:GetState() == Enum.HumanoidStateType.Swimming then
        if not waterPlatform then
            waterPlatform = Instance.new("Part")
            waterPlatform.Name = "LITWaterWalkPlatform"
            waterPlatform.Size = Vector3.new(8, 0.5, 8)
            waterPlatform.Transparency = 1
            waterPlatform.CanTouch = false
            waterPlatform.Anchored = true
            waterPlatform.Parent = Workspace
        end
        waterPlatform.CFrame = CFrame.new(root.Position.X, root.Position.Y - 3, root.Position.Z)
    elseif waterPlatform then
        waterPlatform:Destroy()
        waterPlatform = nil
    end
    local now = os.clock()
    for part, record in pairs(flingBackup) do
        if not antiFlingEnabled or now >= record.expires then
            if part.Parent then part.CanCollide = record.original end
            flingBackup[part] = nil
        end
    end
    if antiFlingEnabled and root then
        overlap.FilterDescendantsInstances = { character }
        for _, part in ipairs(Workspace:GetPartBoundsInRadius(root.Position, 12, overlap)) do
            if part:IsA("BasePart") and not part.Anchored
                and part.AssemblyLinearVelocity.Magnitude > 120 then
                if not flingBackup[part] then
                    flingBackup[part] = { original = part.CanCollide, expires = now + 1 }
                else
                    flingBackup[part].expires = now + 1
                end
                part.CanCollide = false
            end
        end
    end
end)

local TargetGroup = Tabs.Target:AddLeftGroupbox(" Target Interaction")
local BlobGroup = Tabs.Target:AddRightGroupbox(" Blobman Kick")
local WhitelistGroup = Tabs.Target:AddRightGroupbox(" Whitelist")

local selectedKickPlayer = nil
local kickLoopEnabled = false
local kickLoopConnection = nil
local savedKickPos = nil
local currentKickTargetChar = nil

local function getPlayerList()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            table.insert(list, plr.DisplayName .. " (" .. plr.Name .. ")")
        end
    end
    return list
end

local function getPlayerFromSelection(selection)
    if not selection then return nil end
    local username = selection:match("%((.-)%)")
    if username then return Players:FindFirstChild(username) end
    return nil
end

TargetGroup:AddDropdown("KickPlayerDropdown", {
    Values = getPlayerList(),
    Default = 1,
    Multi = false,
    Text = " Select Player for Kick",
    Callback = function(Value)
        selectedKickPlayer = getPlayerFromSelection(Value)
    end,
})

TargetGroup:AddButton({
    Text = " Refresh Player List",
    Func = function()
        Options.KickPlayerDropdown:SetValues(getPlayerList())
        Options.KickPlayerDropdown:SetValue(nil)
        selectedKickPlayer = nil
    end
})

-- Non-blob kick sequence: separate state and a bounded request rate.
local nonBlobKickEnabled = false
local nonBlobKickGeneration = 0
TargetGroup:AddToggle("LoopKickGrabToggle", {
    Text = " Kick (Spam Grab)",
    Default = false,
    Callback = function(on)
        nonBlobKickEnabled = on
        nonBlobKickGeneration += 1
        local generation = nonBlobKickGeneration
        if not on then return end
        if not selectedKickPlayer then
            notify("Kick", "Select a target first.", 3)
            Toggles.LoopKickGrabToggle:SetValue(false)
            return
        end
        task.spawn(function()
            local events = ReplicatedStorage:FindFirstChild("GrabEvents")
            if not events then
                notify("Kick", "GrabEvents is missing.", 3)
                Toggles.LoopKickGrabToggle:SetValue(false)
                return
            end
            local character = LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if not root then Toggles.LoopKickGrabToggle:SetValue(false); return end
            local returnCFrame = root.CFrame
            while nonBlobKickEnabled and generation == nonBlobKickGeneration do
                local target = selectedKickPlayer
                local targetCharacter = target and target.Character
                local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
                local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
                if not target or not target.Parent then break end
                if LocalPlayer.Character ~= character then break end
                if targetRoot and targetHumanoid and targetHumanoid.Health > 0 then
                    local nearTarget = targetRoot.CFrame * CFrame.new(0, 0, 2)
                    root.CFrame = nearTarget
                    root.AssemblyLinearVelocity = Vector3.zero
                    pcall(function()
                        events.SetNetworkOwner:FireServer(targetRoot, nearTarget)
                        events.CreateGrabLine:FireServer(targetRoot, Vector3.zero, targetRoot.Position, false)
                    end)
                    task.wait(0.09)
                    if not nonBlobKickEnabled or generation ~= nonBlobKickGeneration then break end
                    root.CFrame = returnCFrame
                    local lockCFrame = returnCFrame * CFrame.new(0, 12, 0)
                    targetRoot.CFrame = lockCFrame
                    pcall(function()
                        events.SetNetworkOwner:FireServer(targetRoot, lockCFrame)
                        events.DestroyGrabLine:FireServer(targetRoot)
                    end)
                end
                task.wait(math.max(0.2, _G.LITKickDelay or 0.4))
            end
            if root.Parent then root.CFrame = returnCFrame end
            if generation == nonBlobKickGeneration then
                nonBlobKickEnabled = false
                Toggles.LoopKickGrabToggle:SetValue(false)
            end
        end)
    end,
})

-- Bring All (Grab)
local bringAllEnabled = false

TargetGroup:AddToggle("BringAllGrabToggle", {
    Text = " Bring All ",
    Default = false,
    Callback = function(on)
        bringAllEnabled = on
        if not on then return end
        
        task.spawn(function()
            for loopCount = 1, 2 do
                if not bringAllEnabled then break end
                for _, target in ipairs(Players:GetPlayers()) do
                    if not bringAllEnabled then break end
                    if Toggles.WhitelistFriendsToggle and Toggles.WhitelistFriendsToggle.Value and LocalPlayer:IsFriendsWith(target.UserId) then
                        continue
                    end
                    if target ~= LocalPlayer and target.Character and target.Character:FindFirstChild("HumanoidRootPart") and target.Character:FindFirstChild("Humanoid") and target.Character.Humanoid.Health > 0 and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local tRoot = target.Character.HumanoidRootPart
                        local myRoot = LocalPlayer.Character.HumanoidRootPart
                        local savedPos = myRoot.CFrame
                        
                        myRoot.CFrame = tRoot.CFrame
                        myRoot.Velocity = Vector3.zero
                        task.wait(0.20)
                        
                        pcall(function()
                            target.Character.Humanoid.PlatformStand = true
                            target.Character.Humanoid.Sit = true
                            ReplicatedStorage.GrabEvents.SetNetworkOwner:FireServer(tRoot, myRoot.CFrame)
                            ReplicatedStorage.GrabEvents.CreateGrabLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false)
                        end)
                        
                        task.wait(0.20)
                        myRoot.CFrame = savedPos
                        myRoot.Velocity = Vector3.zero
                        tRoot.CFrame = savedPos * CFrame.new(0, 0, -5)
                        tRoot.AssemblyLinearVelocity = Vector3.zero
                        tRoot.AssemblyAngularVelocity = Vector3.zero
                        tRoot.Velocity = Vector3.zero
                        tRoot.RotVelocity = Vector3.zero
                        
                        pcall(function()
                            ReplicatedStorage.GrabEvents.DestroyGrabLine:FireServer(tRoot)
                            target.Character.Humanoid.PlatformStand = false
                            target.Character.Humanoid.Sit = false
                            ReplicatedStorage.GrabEvents.SetNetworkOwner:FireServer(tRoot, tRoot.CFrame)
                        end)
                        task.wait(0.15)
                    end
                end
            end
            bringAllEnabled = false
            if Toggles and Toggles.BringAllGrabToggle then
                Toggles.BringAllGrabToggle:SetValue(false)
            end
        end)
    end
})

-- Bring All to Poison
TargetGroup:AddToggle("BringAllToPosGrabToggle", {
    Text = " Bring All to Poison ",
    Default = false,
    Callback = function(on)
        bringAllEnabled = on
        if not on then return end
        
        task.spawn(function()
            for loopCount = 1, 2 do
                if not bringAllEnabled then break end
                for _, target in ipairs(Players:GetPlayers()) do
                    if not bringAllEnabled then break end
                    if Toggles.WhitelistFriendsToggle and Toggles.WhitelistFriendsToggle.Value and LocalPlayer:IsFriendsWith(target.UserId) then
                        continue
                    end
                    if target ~= LocalPlayer and target.Character and target.Character:FindFirstChild("HumanoidRootPart") and target.Character:FindFirstChild("Humanoid") and target.Character.Humanoid.Health > 0 and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local tRoot = target.Character.HumanoidRootPart
                        local myRoot = LocalPlayer.Character.HumanoidRootPart
                        local savedPos = myRoot.CFrame
                        
                        myRoot.CFrame = tRoot.CFrame
                        myRoot.Velocity = Vector3.zero
                        task.wait(0.20)
                        
                        pcall(function()
                            target.Character.Humanoid.PlatformStand = true
                            target.Character.Humanoid.Sit = true
                            ReplicatedStorage.GrabEvents.SetNetworkOwner:FireServer(tRoot, myRoot.CFrame)
                            ReplicatedStorage.GrabEvents.CreateGrabLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false)
                        end)
                        
                        task.wait(0.20)
                        myRoot.CFrame = CFrame.new(64.55, -43.63, 268.75)
                        myRoot.Velocity = Vector3.zero
                        tRoot.CFrame = CFrame.new(64.55, -43.63, 268.75)
                        tRoot.AssemblyLinearVelocity = Vector3.zero
                        tRoot.AssemblyAngularVelocity = Vector3.zero
                        tRoot.Velocity = Vector3.zero
                        tRoot.RotVelocity = Vector3.zero
                        
                        pcall(function()
                            ReplicatedStorage.GrabEvents.DestroyGrabLine:FireServer(tRoot)
                            target.Character.Humanoid.PlatformStand = false
                            target.Character.Humanoid.Sit = false
                            ReplicatedStorage.GrabEvents.SetNetworkOwner:FireServer(tRoot, tRoot.CFrame)
                        end)
                        task.wait(0.15)
                        myRoot.CFrame = savedPos
                        myRoot.Velocity = Vector3.zero
                        task.wait(0.05)
                    end
                end
            end
            bringAllEnabled = false
            if Toggles and Toggles.BringAllToPosGrabToggle then
                Toggles.BringAllToPosGrabToggle:SetValue(false)
            end
        end)
    end
})

-- Bring All to Farm
TargetGroup:AddToggle("BringAllToFarmGrabToggle", {
    Text = " Bring All to Farm ",
    Default = false,
    Callback = function(on)
        bringAllEnabled = on
        if not on then return end
        
        task.spawn(function()
            for loopCount = 1, 2 do
                if not bringAllEnabled then break end
                for _, target in ipairs(Players:GetPlayers()) do
                    if not bringAllEnabled then break end
                    if Toggles.WhitelistFriendsToggle and Toggles.WhitelistFriendsToggle.Value and LocalPlayer:IsFriendsWith(target.UserId) then
                        continue
                    end
                    if target ~= LocalPlayer and target.Character and target.Character:FindFirstChild("HumanoidRootPart") and target.Character:FindFirstChild("Humanoid") and target.Character.Humanoid.Health > 0 and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local tRoot = target.Character.HumanoidRootPart
                        local myRoot = LocalPlayer.Character.HumanoidRootPart
                        local savedPos = myRoot.CFrame
                        
                        myRoot.CFrame = tRoot.CFrame
                        myRoot.Velocity = Vector3.zero
                        task.wait(0.20)
                        
                        pcall(function()
                            target.Character.Humanoid.PlatformStand = true
                            target.Character.Humanoid.Sit = true
                            ReplicatedStorage.GrabEvents.SetNetworkOwner:FireServer(tRoot, myRoot.CFrame)
                            ReplicatedStorage.GrabEvents.CreateGrabLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false)
                        end)
                        
                        task.wait(0.20)
                        myRoot.CFrame = CFrame.new(-88.66, 233.31, -302.70)
                        myRoot.Velocity = Vector3.zero
                        tRoot.CFrame = CFrame.new(-88.66, 233.31, -302.70)
                        tRoot.AssemblyLinearVelocity = Vector3.zero
                        tRoot.AssemblyAngularVelocity = Vector3.zero
                        tRoot.Velocity = Vector3.zero
                        tRoot.RotVelocity = Vector3.zero
                        
                        pcall(function()
                            ReplicatedStorage.GrabEvents.DestroyGrabLine:FireServer(tRoot)
                            target.Character.Humanoid.PlatformStand = false
                            target.Character.Humanoid.Sit = false
                            ReplicatedStorage.GrabEvents.SetNetworkOwner:FireServer(tRoot, tRoot.CFrame)
                        end)
                        task.wait(0.15)
                        myRoot.CFrame = savedPos
                        myRoot.Velocity = Vector3.zero
                        task.wait(0.05)
                    end
                end
            end
            bringAllEnabled = false
            if Toggles and Toggles.BringAllToFarmGrabToggle then
                Toggles.BringAllToFarmGrabToggle:SetValue(false)
            end
        end)
    end
})

-- Bring All to Water
TargetGroup:AddToggle("BringAllToNewPosGrabToggle", {
    Text = " Bring All to Water ",
    Default = false,
    Callback = function(on)
        bringAllEnabled = on
        if not on then return end
        
        task.spawn(function()
            for loopCount = 1, 2 do
                if not bringAllEnabled then break end
                for _, target in ipairs(Players:GetPlayers()) do
                    if not bringAllEnabled then break end
                    if Toggles.WhitelistFriendsToggle and Toggles.WhitelistFriendsToggle.Value and LocalPlayer:IsFriendsWith(target.UserId) then
                        continue
                    end
                    if target ~= LocalPlayer and target.Character and target.Character:FindFirstChild("HumanoidRootPart") and target.Character:FindFirstChild("Humanoid") and target.Character.Humanoid.Health > 0 and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local tRoot = target.Character.HumanoidRootPart
                        local myRoot = LocalPlayer.Character.HumanoidRootPart
                        local savedPos = myRoot.CFrame
                        
                        myRoot.CFrame = tRoot.CFrame
                        myRoot.Velocity = Vector3.zero
                        task.wait(0.20)
                        
                        pcall(function()
                            target.Character.Humanoid.PlatformStand = true
                            target.Character.Humanoid.Sit = true
                            ReplicatedStorage.GrabEvents.SetNetworkOwner:FireServer(tRoot, myRoot.CFrame)
                            ReplicatedStorage.GrabEvents.CreateGrabLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false)
                        end)
                        
                        task.wait(0.20)
                        myRoot.CFrame = CFrame.new(573.75, 2.72, 583.14)
                        myRoot.Velocity = Vector3.zero
                        tRoot.CFrame = CFrame.new(573.75, 2.72, 583.14)
                        tRoot.AssemblyLinearVelocity = Vector3.zero
                        tRoot.AssemblyAngularVelocity = Vector3.zero
                        tRoot.Velocity = Vector3.zero
                        tRoot.RotVelocity = Vector3.zero
                        
                        pcall(function()
                            ReplicatedStorage.GrabEvents.DestroyGrabLine:FireServer(tRoot)
                            target.Character.Humanoid.PlatformStand = false
                            target.Character.Humanoid.Sit = false
                            ReplicatedStorage.GrabEvents.SetNetworkOwner:FireServer(tRoot, tRoot.CFrame)
                        end)
                        task.wait(0.15)
                        myRoot.CFrame = savedPos
                        myRoot.Velocity = Vector3.zero
                        task.wait(0.05)
                    end
                end
            end
            bringAllEnabled = false
            if Toggles and Toggles.BringAllToNewPosGrabToggle then
                Toggles.BringAllToNewPosGrabToggle:SetValue(false)
            end
        end)
    end
})

-- Whitelist Friends
TargetGroup:AddToggle("WhitelistFriendsToggle", {
    Text = " Whitelist Friends",
    Default = false,
    Callback = function(on) end
})

-- Auto Seat Blobman: define the worker before the toggle callback captures it.
local autoSitBlobEnabled = false
local autoSitWorkerRunning = false
local function autoSitLoop()
    if autoSitWorkerRunning then return end
    autoSitWorkerRunning = true
    while autoSitBlobEnabled do
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if root and humanoid and not humanoid.SeatPart then
            local folder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
            local blob = folder and folder:FindFirstChild("CreatureBlobman")
            if not blob then
                local remote = ReplicatedStorage:FindFirstChild("MenuToys")
                remote = remote and remote:FindFirstChild("SpawnToyRemoteFunction")
                if remote then pcall(function()
                    remote:InvokeServer("CreatureBlobman", root.CFrame, Vector3.zero)
                end) end
                folder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                blob = folder and folder:FindFirstChild("CreatureBlobman")
            end
            local seat = blob and blob:FindFirstChild("VehicleSeat")
            if seat and (seat:IsA("Seat") or seat:IsA("VehicleSeat")) then
                root.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
                pcall(function() seat:Sit(humanoid) end)
            end
        end
        task.wait(0.75)
    end
    autoSitWorkerRunning = false
end

local AutoSitGroup = Tabs.Target:AddRightGroupbox("Auto Sit")
AutoSitGroup:AddToggle("AutoSitBlob", {
    Text = "Auto Seat Blobman",
    Default = false,
    Callback = function(value)
        autoSitBlobEnabled = value
        if value then task.spawn(autoSitLoop) end
    end,
})

-- Snowball loop can be turned off and limits remote invokes.
local ragdollSnowballEnabled = false
local ragdollSnowballGeneration = 0
TargetGroup:AddToggle("RagdollSnowballKick", {
    Text = " Ragdoll Snowball",
    Default = false,
    Callback = function(on)
        ragdollSnowballEnabled = on
        ragdollSnowballGeneration += 1
        local generation = ragdollSnowballGeneration
        if not on then return end
        task.spawn(function()
            local menuToys = ReplicatedStorage:FindFirstChild("MenuToys")
            local spawnRemote = menuToys and menuToys:FindFirstChild("SpawnToyRemoteFunction")
            if not spawnRemote then
                Toggles.RagdollSnowballKick:SetValue(false)
                return
            end
            while ragdollSnowballEnabled and generation == ragdollSnowballGeneration do
                local target = selectedKickPlayer
                local character = target and target.Character
                local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
                if torso then
                    pcall(function()
                        spawnRemote:InvokeServer("BallSnowball", torso.CFrame, Vector3.zero)
                    end)
                    local folder = Workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                    if folder then
                        for _, snowball in ipairs(folder:GetChildren()) do
                            if snowball.Name == "BallSnowball" then
                                local part = snowball.PrimaryPart or snowball:FindFirstChildWhichIsA("BasePart")
                                if part then part.CFrame = torso.CFrame end
                            end
                        end
                    end
                end
                task.wait(0.5)
            end
        end)
    end,
})

-- Blob kick sequence: no per-frame remote loop and no shared kick flag.
local blobKickEnabled = false
local blobKickGeneration = 0
local autoResumeKick = false
BlobGroup:AddToggle("LoopKickToggle", {
    Text = " Loop Kick (Grab + Blob)",
    Default = false,
    Callback = function(on)
        blobKickEnabled = on
        blobKickGeneration += 1
        local generation = blobKickGeneration
        if not on then return end
        local target = selectedKickPlayer
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local seat = humanoid and humanoid.SeatPart
        if not target or not seat or not seat.Parent or seat.Parent.Name ~= "CreatureBlobman" then
            notify("Blob kick", "Select a target and sit in your Blobman first.", 4)
            Toggles.LoopKickToggle:SetValue(false)
            return
        end
        task.spawn(function()
            local events = ReplicatedStorage:FindFirstChild("GrabEvents")
            local blob = seat.Parent
            local blobRoot = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
            local blobScript = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
            local grabRemote = blobScript and blobScript:FindFirstChild("CreatureGrab")
            local dropRemote = blobScript and blobScript:FindFirstChild("CreatureDrop")
            local detector = blob:FindFirstChild("RightDetector")
            if not events or not blobRoot or not grabRemote or not detector then
                notify("Blob kick", "Blobman grab controls are missing.", 4)
                Toggles.LoopKickToggle:SetValue(false)
                return
            end
            local returnCFrame = blobRoot.CFrame
            while blobKickEnabled and generation == blobKickGeneration do
                local activeTarget = selectedKickPlayer
                local targetCharacter = activeTarget and activeTarget.Character
                local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
                local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
                if not activeTarget or not activeTarget.Parent or humanoid.SeatPart ~= seat then break end
                if targetRoot and targetHumanoid and targetHumanoid.Health > 0 then
                    blobRoot.CFrame = targetRoot.CFrame
                    blobRoot.AssemblyLinearVelocity = Vector3.zero
                    local weld = detector:FindFirstChild("RightWeld") or detector:FindFirstChildWhichIsA("Weld")
                    pcall(function()
                        grabRemote:FireServer(detector, targetRoot, weld)
                        events.SetNetworkOwner:FireServer(targetRoot, blobRoot.CFrame)
                    end)
                    task.wait(0.1)
                    if not blobKickEnabled or generation ~= blobKickGeneration then break end
                    blobRoot.CFrame = returnCFrame
                    local lockCFrame = returnCFrame * CFrame.new(0, 20, 0)
                    targetRoot.CFrame = lockCFrame
                    pcall(function()
                        if dropRemote and weld then dropRemote:FireServer(weld) end
                        events.SetNetworkOwner:FireServer(targetRoot, lockCFrame)
                        events.DestroyGrabLine:FireServer(targetRoot)
                    end)
                end
                task.wait(math.max(0.2, _G.LITKickDelay or 0.45))
            end
            if blobRoot.Parent then
                blobRoot.CFrame = returnCFrame
                blobRoot.AssemblyLinearVelocity = Vector3.zero
            end
            if generation == blobKickGeneration then
                blobKickEnabled = false
                Toggles.LoopKickToggle:SetValue(false)
            end
        end)
    end,
})

-- Auto Resume Kick on Character Added
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if autoResumeKick and selectedKickPlayer then
        if Toggles.LoopKickToggle then Toggles.LoopKickToggle:SetValue(true) end
    end
end)

-- Fling
local playerFlingActive = false
local flingBAV = nil
local originalPos = nil

TargetGroup:AddToggle("PlayerFlingBtn", {
    Text = " Fling",
    Default = false,
    Callback = function(on)
        playerFlingActive = on
        if on then
            if not selectedKickPlayer then
                notify("System", "Select target first!", 3)
                Toggles.PlayerFlingBtn:SetValue(false)
                return
            end
            
            local MyChar = LocalPlayer.Character
            local MyRoot = MyChar and MyChar:FindFirstChild("HumanoidRootPart")
            if MyRoot then originalPos = MyRoot.CFrame end
            
            notify("Maestro", "Fling Mode Activated.", 3)
            
            task.spawn(function()
                while playerFlingActive do
                    local target = selectedKickPlayer
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    local hum = char and char:FindFirstChild("Humanoid")
                    
                    if not hrp or not hum then
                        task.wait(0.5)
                        continue
                    end
                    
                    if target and target.Parent then
                        local tChar = target.Character
                        local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                        local tHum = tChar and tChar:FindFirstChild("Humanoid")
                        
                        if tRoot and tHum and tHum.Health > 0 then
                            if not flingBAV or flingBAV.Parent ~= hrp then
                                if flingBAV then flingBAV:Destroy() end
                                flingBAV = Instance.new("BodyAngularVelocity")
                                flingBAV.Name = "MaestroSpin"
                                flingBAV.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                                flingBAV.AngularVelocity = Vector3.new(0, 10000, 0)
                                flingBAV.P = 10000
                                flingBAV.Parent = hrp
                            end
                            
                            for _, part in pairs(char:GetDescendants()) do
                                if part:IsA("BasePart") then part.CanCollide = false end
                            end
                            
                            local loop = RunService.Heartbeat:Connect(function()
                                if not playerFlingActive or not tRoot or not tRoot.Parent then return end
                                hrp.CFrame = tRoot.CFrame
                                hrp.Velocity = Vector3.zero
                            end)
                            
                            local startTime = tick()
                            while tick() - startTime < 1.5 do
                                if not playerFlingActive or not tRoot.Parent then break end
                                task.wait(0.1)
                            end
                            
                            if loop then loop:Disconnect() end
                        else
                            task.wait(0.2)
                        end
                    else
                        playerFlingActive = false
                        Toggles.PlayerFlingBtn:SetValue(false)
                    end
                    task.wait(0.1)
                end
                
                if flingBAV then
                    flingBAV:Destroy()
                    flingBAV = nil
                end
                
                local char = LocalPlayer.Character
                if char then
                    for _, part in pairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = true end
                    end
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.RotVelocity = Vector3.zero
                        hrp.Velocity = Vector3.zero
                        if originalPos then hrp.CFrame = originalPos end
                    end
                end
            end)
        else
            playerFlingActive = false
            if flingBAV then
                flingBAV:Destroy()
                flingBAV = nil
            end
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.RotVelocity = Vector3.zero
                hrp.Velocity = Vector3.zero
            end
        end
    end
})

-- Auto Sit Blobman (Key T)
_G.AutoSitBlobT = true

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.T and _G.AutoSitBlobT then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        if not hrp or not hum then return end
        
        local folderName = LocalPlayer.Name .. "SpawnedInToys"
        local folder = workspace:FindFirstChild(folderName)
        local blob = folder and folder:FindFirstChild("CreatureBlobman")
        
        if not blob then
            task.spawn(function()
                pcall(function()
                    ReplicatedStorage.MenuToys.SpawnToyRemoteFunction:InvokeServer("CreatureBlobman", hrp.CFrame, Vector3.zero)
                end)
            end)
            if not folder then folder = workspace:WaitForChild(folderName, 5) end
            if folder then blob = folder:WaitForChild("CreatureBlobman", 5) end
        end
        
        if blob then
            local seat = blob:WaitForChild("VehicleSeat", 5)
            if seat then
                local t = tick()
                repeat
                    if not hum.SeatPart then
                        hrp.CFrame = seat.CFrame + Vector3.new(0, 1, 0)
                        hrp.Velocity = Vector3.zero
                        seat:Sit(hum)
                    end
                    RunService.Heartbeat:Wait()
                until hum.SeatPart == seat or tick() - t > 1.5
            end
        end
    end
end)

-- Blob Fly Variables
local blobMasterSwitch = true
local blobFlyActive = false
local bvInstance = nil
local bgInstance = nil
local blobFlySpeed = 100

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.R then
        if blobMasterSwitch then
            blobFlyActive = not blobFlyActive
            if not blobFlyActive then
                if bvInstance then
                    bvInstance:Destroy()
                    bvInstance = nil
                end
                if bgInstance then
                    bgInstance:Destroy()
                    bgInstance = nil
                end
            end
        end
    end
end)

local function GetBlobRoot()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if hum and hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman" then
        return hum.SeatPart.Parent:FindFirstChild("HumanoidRootPart") or hum.SeatPart.Parent.PrimaryPart
    end
    local folder = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
    if folder then
        local blob = folder:FindFirstChild("CreatureBlobman")
        if blob then return blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart end
    end
    return nil
end

RunService.Heartbeat:Connect(function()
    if not blobFlyActive or not blobMasterSwitch then
        if bvInstance then
            bvInstance:Destroy()
            bvInstance = nil
        end
        if bgInstance then
            bgInstance:Destroy()
            bgInstance = nil
        end
        return
    end
    
    local root = GetBlobRoot()
    if root then
        if not root:FindFirstChild("BlobFlyVelocity") then
            bvInstance = Instance.new("BodyVelocity")
            bvInstance.Name = "BlobFlyVelocity"
            bvInstance.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bvInstance.P = 10000
            bvInstance.Parent = root
        else
            bvInstance = root.BlobFlyVelocity
        end
        
        if not root:FindFirstChild("BlobFlyGyro") then
            bgInstance = Instance.new("BodyGyro")
            bgInstance.Name = "BlobFlyGyro"
            bgInstance.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bgInstance.P = 20000
            bgInstance.D = 100
            bgInstance.Parent = root
        else
            bgInstance = root.BlobFlyGyro
        end
        
        local cam = workspace.CurrentCamera
        local moveDir = Vector3.zero
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end
        
        if bvInstance then bvInstance.Velocity = moveDir * blobFlySpeed end
        if bgInstance then bgInstance.CFrame = cam.CFrame end
    else
        if bvInstance then
            bvInstance:Destroy()
            bvInstance = nil
        end
        if bgInstance then
            bgInstance:Destroy()
            bgInstance = nil
        end
    end
end)

-- Destroy Gucci (Sit)
local DestroyTargetGucciActive = false

BlobGroup:AddToggle("DestroyTargetGucci", {
    Text = " Destroy Gucci (Sit)",
    Default = false,
    Callback = function(Value)
        DestroyTargetGucciActive = Value
        if Value then
            if not selectedKickPlayer then
                notify("Error", "No target selected!", 3)
                Toggles.DestroyTargetGucci:SetValue(false)
                return
            end
            
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then return end
            
            local SafeSpot = root.CFrame
            local folderName = selectedKickPlayer.Name .. "SpawnedInToys"
            notify("System", "Searching for toys in " .. folderName, 3)
            
            task.spawn(function()
                while DestroyTargetGucciActive do
                    if not selectedKickPlayer or not selectedKickPlayer.Parent then
                        notify("System", "Target left the game!", 3)
                        DestroyTargetGucciActive = false
                        Toggles.DestroyTargetGucci:SetValue(false)
                        break
                    end
                    
                    local toysFolder = workspace:FindFirstChild(folderName)
                    if toysFolder then
                        for _, obj in ipairs(toysFolder:GetChildren()) do
                            if not DestroyTargetGucciActive then break end
                            if obj.Name == "CreatureBlobman" then
                                local seat = obj:FindFirstChild("VehicleSeat") or obj:FindFirstChildWhichIsA("VehicleSeat", true)
                                if seat then
                                    local myChar = LocalPlayer.Character
                                    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                                    local myHum = myChar and myChar:FindFirstChild("Humanoid")
                                    
                                    if myRoot and myHum and myHum.SeatPart ~= seat then
                                        local magnetConnection = RunService.Stepped:Connect(function()
                                            if myRoot and seat then
                                                myRoot.CFrame = seat.CFrame
                                                myRoot.Velocity = Vector3.zero
                                                if obj.PrimaryPart then
                                                    obj.PrimaryPart.Velocity = Vector3.zero
                                                    obj.PrimaryPart.RotVelocity = Vector3.zero
                                                end
                                            end
                                        end)
                                        
                                        local sitStart = tick()
                                        while tick() - sitStart < 1 do
                                            if not DestroyTargetGucciActive then break end
                                            if myHum.SeatPart == seat then break end
                                            seat:Sit(myHum)
                                            task.wait()
                                        end
                                        
                                        if magnetConnection then magnetConnection:Disconnect() end
                                        
                                        if myHum.SeatPart == seat then
                                            task.wait(0.3)
                                            myHum.Sit = false
                                            myHum.Jump = true
                                            task.wait(0.05)
                                            myRoot.CFrame = SafeSpot
                                            myRoot.Velocity = Vector3.zero
                                            notify("Success", "Gucci removed from target!", 1)
                                            task.wait(0.5)
                                        else
                                            myRoot.CFrame = SafeSpot
                                        end
                                    end
                                end
                            end
                        end
                    end
                    task.wait(1)
                end
            end)
        else
            DestroyTargetGucciActive = false
            notify("System", "Destroy Gucci disabled.", 2)
        end
    end
})

-- Bring Player Function
local WaterPos = CFrame.new(635.33, -54.51, 299.99)

local function BringPlayer(target, customPos)
    if not target then return end
    
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local seat = hum and hum.SeatPart
    if not seat or seat.Parent.Name ~= "CreatureBlobman" then return end
    
    local blob = seat.Parent
    local blobRoot = blob:FindFirstChild("HumanoidRootPart")
    local scriptObj = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
    if not blobRoot or not scriptObj then return end
    
    local CG = scriptObj:FindFirstChild("CreatureGrab")
    local CD = scriptObj:FindFirstChild("CreatureDrop")
    local R_Det = blob:FindFirstChild("RightDetector")
    local R_Weld = R_Det and (R_Det:FindFirstChild("RightWeld") or R_Det:FindFirstChildWhichIsA("Weld"))
    
    local tChar = target.Character
    local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
    if not tRoot then return end
    
    local home = blobRoot.CFrame
    blobRoot.CFrame = tRoot.CFrame
    blobRoot.Velocity = Vector3.zero
    blobRoot.RotVelocity = Vector3.zero
    task.wait(0.25)
    
    pcall(function() CG:FireServer(R_Det, tRoot, R_Weld) end)
    task.wait(0.4)
    
    blobRoot.CFrame = home
    blobRoot.Velocity = Vector3.zero
    blobRoot.RotVelocity = Vector3.zero
    task.wait(0.05)
    
    for i = 1, 8 do
        local weld = R_Det:FindFirstChild("RightWeld") or R_Det:FindFirstChildWhichIsA("Weld")
        if weld then pcall(function() CD:FireServer(weld) end) end
        task.wait(0.03)
    end
    
    task.wait(0.1)
    local finalPos = customPos or (home * CFrame.new(0, 3, 0))
    
    for i = 1, 12 do
        if tRoot then
            tRoot.CFrame = finalPos
            tRoot.Velocity = Vector3.zero
            tRoot.RotVelocity = Vector3.zero
        end
        task.wait(0.03)
    end
end

-- Bring Button
BlobGroup:AddButton({
    Text = " Bring",
    Func = function()
        if not selectedKickPlayer then return end
        
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local seat = hum and hum.SeatPart
        if not seat or seat.Parent.Name ~= "CreatureBlobman" then return end
        
        local blob = seat.Parent
        local blobRoot = blob:FindFirstChild("HumanoidRootPart")
        local scriptObj = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
        if not blobRoot or not scriptObj then return end
        
        local CG = scriptObj:FindFirstChild("CreatureGrab")
        local CD = scriptObj:FindFirstChild("CreatureDrop")
        local R_Det = blob:FindFirstChild("RightDetector")
        local R_Weld = R_Det and R_Det:FindFirstChild("RightWeld")
        
        local tChar = selectedKickPlayer.Character
        local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
        if not tRoot then return end
        
        local home = blobRoot.CFrame
        blobRoot.CFrame = tRoot.CFrame
        blobRoot.Velocity = Vector3.new()
        blobRoot.RotVelocity = Vector3.new()
        task.wait(0.3)
        
        pcall(function() CG:FireServer(R_Det, tRoot, R_Weld) end)
        task.wait(0.5)
        
        blobRoot.CFrame = home
        blobRoot.Velocity = Vector3.new()
        blobRoot.RotVelocity = Vector3.new()
        task.wait(0.05)
        
        for i = 1, 12 do
            tRoot.CFrame = home * CFrame.new(0, 3, 0)
            tRoot.Velocity = Vector3.new()
            tRoot.RotVelocity = Vector3.new()
            task.wait(0.03)
        end
        
        for i = 1, 8 do
            local weld = R_Det:FindFirstChild("RightWeld")
            if weld then pcall(function() CD:FireServer(weld) end) end
            task.wait(0.03)
        end
    end
})

-- Bring All Button
BlobGroup:AddButton({
    Text = " Bring All",
    Func = function()
        local myPlayer = LocalPlayer
        local char = myPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local seat = hum and hum.SeatPart
        
        if not seat or seat.Parent.Name ~= "CreatureBlobman" then
            notify("Error", "You must be sitting in Blobman!", 3)
            return
        end
        
        local blob = seat.Parent
        local blobRoot = blob:FindFirstChild("HumanoidRootPart")
        local scriptObj = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
        if not blobRoot or not scriptObj then return end
        
        local CG = scriptObj:FindFirstChild("CreatureGrab")
        local CD = scriptObj:FindFirstChild("CreatureDrop")
        local R_Det = blob:FindFirstChild("RightDetector")
        local R_Weld = R_Det and R_Det:FindFirstChild("RightWeld")
        
        if not CG or not CD or not R_Det then return end
        
        local home = blobRoot.CFrame
        local dropPosition = home * CFrame.new(0, 3, -6)
        local brought = 0
        
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= myPlayer and plr.Character then
                local tChar = plr.Character
                local tRoot = tChar:FindFirstChild("HumanoidRootPart")
                local tHum = tChar:FindFirstChild("Humanoid")
                
                if tRoot and tHum and tHum.Health > 0 then
                    brought = brought + 1
                    blobRoot.CFrame = tRoot.CFrame
                    blobRoot.AssemblyLinearVelocity = Vector3.zero
                    blobRoot.AssemblyAngularVelocity = Vector3.zero
                    task.wait(0.25)
                    
                    pcall(function() CG:FireServer(R_Det, tRoot, R_Weld) end)
                    task.wait(0.35)
                    
                    blobRoot.CFrame = home
                    blobRoot.AssemblyLinearVelocity = Vector3.zero
                    blobRoot.AssemblyAngularVelocity = Vector3.zero
                    task.wait(0.05)
                    
                    for i = 1, 12 do
                        if not tRoot or not tRoot.Parent then break end
                        tRoot.CFrame = dropPosition
                        tRoot.AssemblyLinearVelocity = Vector3.zero
                        tRoot.AssemblyAngularVelocity = Vector3.zero
                        tRoot.Velocity = Vector3.zero
                        task.wait(0.02)
                    end
                    
                    for i = 1, 6 do
                        local weld = R_Det:FindFirstChild("RightWeld") or R_Det:FindFirstChildWhichIsA("Weld")
                        if weld then pcall(function() CD:FireServer(weld) end) end
                        if tRoot then
                            tRoot.AssemblyLinearVelocity = Vector3.zero
                            tRoot.AssemblyAngularVelocity = Vector3.zero
                        end
                        task.wait(0.03)
                    end
                    
                    if tRoot then
                        tRoot.AssemblyLinearVelocity = Vector3.zero
                        tRoot.AssemblyAngularVelocity = Vector3.zero
                        tRoot.Velocity = Vector3.zero
                    end
                    task.wait(0.1)
                end
            end
        end
        
        blobRoot.CFrame = home
        blobRoot.AssemblyLinearVelocity = Vector3.zero
        blobRoot.AssemblyAngularVelocity = Vector3.zero
        notify("Bring All", "Brought " .. brought .. " players safely!", 4)
    end
})

-- Remove Anti-Input Lag Items
local AllowedItems = {
    FoodHamburger = true, FoodCoconut = true, FoodPizzaCheese = true, FoodPizzaPepperoni = true,
    FoodHotdog = true, FoodMushroomPoison = true, FoodBread = true, FoodDippyEgg = true,
    FoodMayonnaise = true, FoodFrenchFries = true, FoodMeatStick = true, FoodDonut = true,
    FoodCakePink = true, InstrumentGuitarBanjo = true, InstrumentGuitarViolin = true,
    InstrumentGuitarUkulele = true, InstrumentWoodwindSaxophone = true, InstrumentWoodwindOcarina = true,
    InstrumentBrassVuvuzelaQwizik = true, InstrumentBrassTrumpet = true, InstrumentDrumBongos = true,
    InstrumentDrumSnare = true, InstrumentPianoMelodica = true, InstrumentVoiceMicrophone = true,
    CupMugWhite = true, CupMugBrown = true, PoopPile = true, PoopPileSparkle = true,
}

local antiAntiLagEnabled = false

TargetGroup:AddToggle("Remove AntiInputLag", {
    Text = " Remove Anti Input Lag",
    Default = false,
    Callback = function(on)
        antiAntiLagEnabled = on
        if not on then
            antiAntiLagEnabled = false
            return
        end
        
        task.spawn(function()
            local char = LocalPlayer.Character
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            
            local items = {}
            for _, v in ipairs(workspace:GetDescendants()) do
                if AllowedItems[v.Name] and v:IsA("Model") and v:FindFirstChild("HoldPart") then
                    items[#items + 1] = v
                end
            end
            
            workspace.DescendantAdded:Connect(function(obj)
                if AllowedItems[obj.Name] and obj:IsA("Model") then
                    task.spawn(function()
                        local hp = obj:WaitForChild("HoldPart", 3)
                        if hp then items[#items + 1] = obj end
                    end)
                end
            end)
            
            while antiAntiLagEnabled do
                for i = #items, 1, -1 do
                    local b = items[i]
                    if not b or not b.Parent or not b:FindFirstChild("HoldPart") then
                        table.remove(items, i)
                    else
                        local hp = b.HoldPart
                        pcall(function() hp.HoldItemRemoteFunction:InvokeServer(b, char) end)
                        task.wait()
                        pcall(function()
                            hp.DropItemRemoteFunction:InvokeServer(b, CFrame.new(hrp.Position + Vector3.new(0, -2000, 0)), Vector3.zero)
                        end)
                    end
                end
                task.wait()
            end
        end)
    end
})

-- Whitelist Group
WhitelistGroup:AddDropdown("MultiWhitelist", {
    Values = getPlayerList(),
    Default = {},
    Multi = true,
    Text = " Whitelist People",
})

WhitelistGroup:AddButton({
    Text = " Refresh List",
    Func = function()
        Options.MultiWhitelist:SetValues(getPlayerList())
    end
})

-- Target Joined Notify
local notifyActive = false
local notifyConnection = nil

WhitelistGroup:AddToggle("JoinedNotifyBtn", {
    Text = " Target Joined Notify",
    Default = false,
    Callback = function(on)
        notifyActive = on
        if on then
            notify("Radar", "Tracking enabled...", 3)
            if notifyConnection then notifyConnection:Disconnect() end
            
            notifyConnection = Players.PlayerAdded:Connect(function(newPlayer)
                if not notifyActive then return end
                
                local detected = false
                local reason = ""
                local whitelistTable = Options.MultiWhitelist.Value
                
                for nameString, isSelected in pairs(whitelistTable) do
                    if isSelected then
                        local actualName = nameString:match("%((.-)%)")
                        if actualName == newPlayer.Name then
                            detected = true
                            reason = "[Whitelist]"
                            break
                        end
                    end
                end
                
                if not detected and Options.KickPlayerDropdown and Options.KickPlayerDropdown.Value then
                    local selection = Options.KickPlayerDropdown.Value
                    local selectedName = selection:match("%((.-)%)")
                    if selectedName and selectedName == newPlayer.Name then
                        detected = true
                        reason = "[Main Target]"
                    end
                end
                
                if detected then
                    notify("Detected", reason .. " detected: " .. newPlayer.Name, 8)
                    local sound = Instance.new("Sound", workspace)
                    sound.SoundId = "rbxassetid://4590662766"
                    sound.Volume = 2
                    sound:Play()
                    game:GetService("Debris"):AddItem(sound, 3)
                end
            end)
        else
            if notifyConnection then
                notifyConnection:Disconnect()
                notifyConnection = nil
            end
            notify("Radar", "Tracking Disabled", 2)
        end
    end
})


local GrabGroup = Tabs.Grab:AddLeftGroupbox(" Grab Actions & Customization")

_G.GoxConfig = _G.GoxConfig or {}
_G.GoxConfig.GrabSettings = {
    SpinSpeed = 100,
    SpinActive = false,
    RagdollActive = false,
    KickActive = false,
    ThrowEnabled = false,
    KillEnabled = false,
    Strength = 750
}

GrabGroup:AddSlider("SpinSpeedSlider", {
    Text = " Spin Speed",
    Default = 100,
    Min = 0,
    Max = 10000,
    Rounding = 0,
    Callback = function(v) _G.GoxConfig.GrabSettings.SpinSpeed = v end
})

GrabGroup:AddSlider("ThrowPowerSlider", {
    Text = " Throw Power",
    Default = 750,
    Min = 1,
    Max = 20000,
    Rounding = 0,
    Callback = function(v) _G.GoxConfig.GrabSettings.Strength = v end
})

GrabGroup:AddToggle("SpinGrab", {Text = " Spin Grab", Callback = function(v) _G.GoxConfig.GrabSettings.SpinActive = v end})
GrabGroup:AddToggle("RagdollGrab", {Text = " Ragdoll Grab", Callback = function(v) _G.GoxConfig.GrabSettings.RagdollActive = v end})
GrabGroup:AddToggle("KickGrab", {Text = " Kick Grab", Callback = function(v) _G.GoxConfig.GrabSettings.KickActive = v end})
GrabGroup:AddToggle("ThrowStrengthToggle", {Text = " Throw Strength", Callback = function(v) _G.GoxConfig.GrabSettings.ThrowEnabled = v end})
GrabGroup:AddToggle("KillGrabToggle", {Text = " Kill Grab", Callback = function(v) _G.GoxConfig.GrabSettings.KillEnabled = v end})

workspace.ChildAdded:Connect(function(model)
    if model.Name == "GrabParts" then
        task.wait(0.1)
        local grabPart = model:FindFirstChild("GrabPart")
        if not grabPart or not grabPart:FindFirstChild("WeldConstraint") then return end
        local part1 = grabPart.WeldConstraint.Part1
        if not part1 then return end
        
        task.spawn(function()
            while model.Parent and _G.GoxConfig.GrabSettings.SpinActive do
                part1.AssemblyAngularVelocity = Vector3.new(0, _G.GoxConfig.GrabSettings.SpinSpeed, 0)
                task.wait()
            end
        end)
        
        if _G.GoxConfig.GrabSettings.KillEnabled then
            if part1.Parent and part1.Parent ~= LocalPlayer.Character then
                local hum = part1.Parent:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum.Health = 0; part1.Parent:BreakJoints() end) end
            end
        end
        
        if _G.GoxConfig.GrabSettings.ThrowEnabled then
            local vel = Instance.new("BodyVelocity", part1)
            model.AncestryChanged:Connect(function()
                if not model:IsDescendantOf(workspace) then
                    if UserInputService:GetLastInputType() == Enum.UserInputType.MouseButton2 then
                        vel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                        vel.Velocity = workspace.CurrentCamera.CFrame.LookVector * _G.GoxConfig.GrabSettings.Strength
                        game:GetService("Debris"):AddItem(vel, 1)
                    else
                        vel:Destroy()
                    end
                end
            end)
        end
    end
end)


if not _G.GoxConfig then
    _G.GoxConfig = { HexColor = "#FFFFFF", Cpu = 24, GpuTemp = 52, CpuTemp = 49 }
end

_G.GoxConfig.NoclipActive = false

if not _G.GoxConfig.NoclipConnection then
    _G.GoxConfig.NoclipConnection = RunService.Stepped:Connect(function()
        if _G.GoxConfig.NoclipActive then
            local character = LocalPlayer.Character
            if character then
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end
    end)
end


local PlayerView = Tabs.Player:AddLeftGroupbox(" View & Movement")
local PlayerESP = Tabs.Player:AddRightGroupbox(" ESP")
local PlayerPerf = Tabs.Player:AddRightGroupbox(" Performance")

-- Third Person
local function enableThirdPerson()
    LocalPlayer.CameraMode = Enum.CameraMode.Classic
    Camera.CameraType = Enum.CameraType.Custom
    Camera.CameraSubject = LocalPlayer.Character:WaitForChild("Humanoid")
    LocalPlayer.CameraMaxZoomDistance = 16456456546
    LocalPlayer.CameraMinZoomDistance = 0.5
end

local function disableThirdPerson()
    LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
    Camera.CameraType = Enum.CameraType.Custom
    Camera.CameraSubject = LocalPlayer.Character:WaitForChild("Humanoid")
    LocalPlayer.CameraMaxZoomDistance = 0
    LocalPlayer.CameraMinZoomDistance = 0
end

PlayerView:AddToggle("ThirdPersonToggle", {
    Text = " 3rd Person View",
    Default = false,
    Callback = function(Value)
        if Value then enableThirdPerson() else disableThirdPerson() end
    end
})

-- Spin Character
local spinningConnection
local spinSpeed = 5

PlayerView:AddToggle("SpinToggle", {
    Text = " Spin Character",
    Default = false,
    Callback = function(Value)
        if Value then
            spinningConnection = RunService.Heartbeat:Connect(function()
                local character = LocalPlayer.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if root then
                    root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(spinSpeed), 0)
                end
            end)
        else
            if spinningConnection then
                spinningConnection:Disconnect()
                spinningConnection = nil
            end
        end
    end
})

PlayerView:AddSlider("SpinSpeed", {
    Text = " Spin Speed",
    Default = 5,
    Min = 1,
    Max = 50,
    Rounding = 0,
    Callback = function(Value) spinSpeed = Value end
})

-- Infinite Jump
local infJump = false

PlayerView:AddToggle("infJumpToggle", {
    Text = " Infinite Jump",
    Default = false,
    Callback = function(Value) infJump = Value end
})

PlayerView:AddToggle("NoclipToggle", {
    Text = " Noclip",
    Default = false,
    Callback = function(Value) _G.GoxConfig.NoclipActive = Value end
})

-- Speed Hack
local currentWalkSpeed = 16
local defaultWalkSpeed = 16

PlayerView:AddToggle("SpeedToggle", {
    Text = " Speed Hack",
    Default = false,
    Callback = function(state)
        if state then
            task.spawn(function()
                while Toggles.SpeedToggle.Value do
                    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if hum then hum.WalkSpeed = currentWalkSpeed end
                    task.wait(0.05)
                end
            end)
        else
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = defaultWalkSpeed end
        end
    end
})

PlayerView:AddSlider("SpeedSlider", {
    Text = " Walk Speed",
    Default = 16,
    Min = 16,
    Max = 300,
    Rounding = 0,
    Suffix = " speed/s",
    Callback = function(value)
        currentWalkSpeed = value
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and Toggles.SpeedToggle.Value then hum.WalkSpeed = value end
    end
})

PlayerView:AddSlider("JumpPowerSlider", {
    Text = " Jump Power",
    Default = 50,
    Min = 50,
    Max = 350,
    Rounding = 0,
    Callback = function(value)
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = value end
    end
})

UserInputService.JumpRequest:Connect(function()
    if infJump then
        local character = LocalPlayer.Character
        if character and character:FindFirstChildOfClass("Humanoid") then
            character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)


ESP_Config = ESP_Config or {
    Size = 100,
    Transparency = 0,
    HighlightESP = false,
    HighlightColorR = 255,
    HighlightColorG = 0,
    HighlightColorB = 0
}

ESPFolder = ESPFolder or {}
HighlightFolder = HighlightFolder or {}
PlayerConnections = PlayerConnections or {}

function RemoveHighlight(plr)
    if HighlightFolder[plr] then
        pcall(function() HighlightFolder[plr]:Destroy() end)
        HighlightFolder[plr] = nil
    end
end

function ApplyHighlight(plr)
    if not ESP_Config.HighlightESP or plr == LocalPlayer then return end
    local char = plr.Character
    if not char then return end
    
    RemoveHighlight(plr)
    local highlight = Instance.new("Highlight")
    highlight.Name = "WallESP"
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = Color3.fromRGB(ESP_Config.HighlightColorR, ESP_Config.HighlightColorG, ESP_Config.HighlightColorB)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.45
    highlight.OutlineTransparency = 0
    highlight.Adornee = char
    highlight.Parent = char
    HighlightFolder[plr] = highlight
end

function RefreshHighlightColors()
    for plr, highlight in pairs(HighlightFolder) do
        if highlight and highlight.Parent then
            highlight.FillColor = Color3.fromRGB(ESP_Config.HighlightColorR, ESP_Config.HighlightColorG, ESP_Config.HighlightColorB)
        end
    end
end

function RefreshLiveESP()
    for _, billboard in pairs(ESPFolder) do
        if billboard and billboard.Parent then
            billboard.Size = UDim2.new(0, ESP_Config.Size, 0, 40)
            local container = billboard:FindFirstChild("Container")
            if container then
                local avatar = container:FindFirstChild("Avatar")
                if avatar then avatar.ImageTransparency = ESP_Config.Transparency end
                local nameLabel = container:FindFirstChild("NameLabel")
                if nameLabel then
                    nameLabel.TextTransparency = ESP_Config.Transparency
                    nameLabel.TextStrokeTransparency = math.clamp(ESP_Config.Transparency + 0.4, 0, 1)
                end
                local distLabel = container:FindFirstChild("DistLabel")
                if distLabel then distLabel.TextTransparency = ESP_Config.Transparency end
            end
        end
    end
end

function CreateESP(plr)
    if plr == LocalPlayer then return end
    
    local function CharacterAdded(char)
        local hrp = char:WaitForChild("HumanoidRootPart", 15)
        if not hrp then return end
        task.wait(0.2)
        
        if hrp:FindFirstChild("PlayerESP") then hrp.PlayerESP:Destroy() end
        if ESPFolder[plr] then pcall(function() ESPFolder[plr]:Destroy() end) end
        if ESP_Config.HighlightESP then ApplyHighlight(plr) end
        
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "PlayerESP"
        billboard.Adornee = hrp
        billboard.Size = UDim2.new(0, ESP_Config.Size, 0, 40)
        billboard.StudsOffset = Vector3.new(0, 3.5, 0)
        billboard.AlwaysOnTop = true
        billboard.LightInfluence = 0
        billboard.Parent = hrp
        
        local container = Instance.new("Frame")
        container.Name = "Container"
        container.Size = UDim2.new(1, 0, 1, 0)
        container.BackgroundTransparency = 1
        container.Parent = billboard
        
        local avatar = Instance.new("ImageLabel")
        avatar.Name = "Avatar"
        avatar.Size = UDim2.new(0, 30, 0, 30)
        avatar.Position = UDim2.new(0, 0, 0.5, -15)
        avatar.BackgroundTransparency = 1
        avatar.ImageTransparency = ESP_Config.Transparency
        pcall(function()
            avatar.Image = Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        end)
        avatar.Parent = container
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.Size = UDim2.new(1, -35, 0, 16)
        nameLabel.Position = UDim2.new(0, 35, 0, 2)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = plr.Name
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextTransparency = ESP_Config.Transparency
        nameLabel.TextStrokeTransparency = math.clamp(ESP_Config.Transparency + 0.4, 0, 1)
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextScaled = true
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.Parent = container
        
        local distLabel = Instance.new("TextLabel")
        distLabel.Name = "DistLabel"
        distLabel.Size = UDim2.new(1, -35, 0, 12)
        distLabel.Position = UDim2.new(0, 35, 0, 18)
        distLabel.BackgroundTransparency = 1
        distLabel.Text = "0 studs"
        distLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        distLabel.TextTransparency = ESP_Config.Transparency
        distLabel.TextXAlignment = Enum.TextXAlignment.Left
        distLabel.TextScaled = true
        distLabel.Font = Enum.Font.Gotham
        distLabel.Parent = container
        
        ESPFolder[plr] = billboard
        
        task.spawn(function()
            while billboard and billboard.Parent and char and char.Parent do
                local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if myRoot and hrp.Parent then
                    local dist = (myRoot.Position - hrp.Position).Magnitude
                    distLabel.Text = string.format("%.0f studs", dist)
                else
                    break
                end
                task.wait(0.4)
            end
            if ESPFolder[plr] == billboard then ESPFolder[plr] = nil end
        end)
    end
    
    table.insert(PlayerConnections, plr.CharacterAdded:Connect(CharacterAdded))
    table.insert(PlayerConnections, plr.CharacterRemoving:Connect(function()
        if ESPFolder[plr] then
            pcall(function() ESPFolder[plr]:Destroy() end)
            ESPFolder[plr] = nil
        end
        RemoveHighlight(plr)
    end))
    
    if plr.Character then task.spawn(CharacterAdded, plr.Character) end
end

PlayerESP:AddSlider("ESPSize", {
    Text = " ESP Size",
    Min = 50,
    Max = 150,
    Default = ESP_Config.Size,
    Callback = function(Value) ESP_Config.Size = Value; RefreshLiveESP() end
})

PlayerESP:AddSlider("ESPTransparency", {
    Text = " ESP Transparency",
    Min = 0,
    Max = 1,
    Default = ESP_Config.Transparency,
    DecimalPlaces = 2,
    Callback = function(Value) ESP_Config.Transparency = Value; RefreshLiveESP() end
})

PlayerESP:AddSlider("HighlightRed", {
    Text = " Highlight Red",
    Min = 0,
    Max = 255,
    Default = ESP_Config.HighlightColorR,
    Callback = function(Value) ESP_Config.HighlightColorR = Value; RefreshHighlightColors() end
})

PlayerESP:AddSlider("HighlightGreen", {
    Text = " Highlight Green",
    Min = 0,
    Max = 255,
    Default = ESP_Config.HighlightColorG,
    Callback = function(Value) ESP_Config.HighlightColorG = Value; RefreshHighlightColors() end
})

PlayerESP:AddSlider("HighlightBlue", {
    Text = " Highlight Blue",
    Min = 0,
    Max = 255,
    Default = ESP_Config.HighlightColorB,
    Callback = function(Value) ESP_Config.HighlightColorB = Value; RefreshHighlightColors() end
})

PlayerESP:AddToggle("HighlightESP", {
    Text = " Wall Highlight ESP",
    Default = false,
    Callback = function(Value)
        ESP_Config.HighlightESP = Value
        if Value then
            for _, plr in pairs(Players:GetPlayers()) do ApplyHighlight(plr) end
        else
            for plr in pairs(HighlightFolder) do RemoveHighlight(plr) end
        end
    end
})

PlayerESP:AddToggle("PlayerESP", {
    Text = " Player ESP",
    Default = false,
    Callback = function(Value)
        if Value then
            for _, plr in pairs(Players:GetPlayers()) do CreateESP(plr) end
            table.insert(PlayerConnections, Players.PlayerAdded:Connect(CreateESP))
            table.insert(PlayerConnections, Players.PlayerRemoving:Connect(function(plr)
                if ESPFolder[plr] then
                    pcall(function() ESPFolder[plr]:Destroy() end)
                    ESPFolder[plr] = nil
                end
                RemoveHighlight(plr)
            end))
        else
            for _, conn in pairs(PlayerConnections) do conn:Disconnect() end
            PlayerConnections = {}
            for _, esp in pairs(ESPFolder) do pcall(function() esp:Destroy() end) end
            for _, plr in pairs(Players:GetPlayers()) do
                RemoveHighlight(plr)
                if plr.Character then
                    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and hrp:FindFirstChild("PlayerESP") then hrp.PlayerESP:Destroy() end
                end
            end
            ESPFolder = {}
        end
    end
})


local oldProperties = {}
local isBoosted = false

local function applyAndSave(obj, props)
    if not oldProperties[obj] then
        oldProperties[obj] = {}
        for propName, _ in pairs(props) do
            oldProperties[obj][propName] = obj[propName]
        end
    end
    for propName, newValue in pairs(props) do
        obj[propName] = newValue
    end
end

PlayerPerf:AddButton({
    Text = " Toggle FPS Boost",
    Func = function()
        if not isBoosted then
            applyAndSave(Lighting, {
                GlobalShadows = false,
                FogEnd = 9e9,
                Brightness = 2,
                Technology = Enum.Technology.Compatibility
            })
            
            for _, effect in pairs(Lighting:GetChildren()) do
                if effect:IsA("PostEffect") or effect:IsA("BloomEffect") or effect:IsA("BlurEffect") or effect:IsA("SunRaysEffect") or effect:IsA("ColorCorrectionEffect") then
                    applyAndSave(effect, { Enabled = false })
                end
            end
            
            local descendants = Workspace:GetDescendants()
            for i = 1, #descendants do
                local v = descendants[i]
                if v:IsA("BasePart") and not v:IsDescendantOf(Players) then
                    applyAndSave(v, { Material = Enum.Material.Plastic, Reflectance = 0, CastShadow = false })
                elseif v:IsA("Texture") or v:IsA("Decal") then
                    applyAndSave(v, { Transparency = 1 })
                elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                    applyAndSave(v, { Enabled = false })
                elseif v:IsA("Explosion") then
                    applyAndSave(v, { Visible = false })
                end
            end
            
            for _, plr in pairs(Players:GetPlayers()) do
                if plr.Character then
                    for _, part in pairs(plr.Character:GetDescendants()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                            applyAndSave(part, { Material = Enum.Material.Plastic, Reflectance = 0, CastShadow = false })
                        elseif part:IsA("ShirtGraphic") or part:IsA("Decal") then
                            applyAndSave(part, { Transparency = 1 })
                        end
                    end
                end
            end
            isBoosted = true
            print("FPS Boost enabled!")
        else
            for obj, props in pairs(oldProperties) do
                if obj and obj.Parent then
                    for propName, originalValue in pairs(props) do
                        pcall(function() obj[propName] = originalValue end)
                    end
                end
            end
            oldProperties = {}
            isBoosted = false
            print("FPS Boost disabled!")
        end
    end
})

PlayerPerf:AddButton({
    Text = " Delete FPS Boost",
    Func = function()
        for obj, props in pairs(oldProperties) do
            if typeof(obj) == "Instance" and obj.Parent then
                for prop, value in pairs(props) do obj[prop] = value end
            elseif obj == "Lighting" then
                for prop, value in pairs(props) do Lighting[prop] = value end
            end
        end
        oldProperties = {}
    end
})


local MiscGroup = Tabs.Misc:AddLeftGroupbox(" misc ")

-- Water Parts for later use
local waterParts = {}
task.spawn(function()
    if workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("AlwaysHereTweenedObjects") then
        local oceanModel = workspace.Map.AlwaysHereTweenedObjects.Ocean.Object.ObjectModel
        for _, v in pairs(oceanModel:GetChildren()) do
            if v:IsA("Part") or v:IsA("UnionOperation") or v:IsA("BasePart") or v:IsA("MeshPart") then
                table.insert(waterParts, { part = v, originalCollide = v.CanCollide })
            end
        end
    end
end)

-- No Barrier Collision
MiscGroup:AddToggle("NoBarrierCollision", {
    Text = " Ignore House Barriers",
    Default = false,
    Callback = function(Value)
        local plots = workspace:FindFirstChild("Plots")
        if not plots then return end
        for _, plot in ipairs(plots:GetChildren()) do
            local barrier = plot:FindFirstChild("Barrier")
            if barrier then
                for _, obj in ipairs(barrier:GetDescendants()) do
                    if obj:IsA("BasePart") then obj.CanCollide = not Value end
                end
            end
        end
    end
})

-- Packet Lag
local PacketSpamAmount = 100

MiscGroup:AddSlider("PacketAmountSlider", {
    Text = " Packet Lag Amount",
    Default = 100,
    Min = 10,
    Max = 5000,
    Rounding = 0,
    Callback = function(Value) PacketSpamAmount = Value end
})

MiscGroup:AddToggle("PacketLagToggle", {
    Text = " Packet Lag",
    Default = false,
    Callback = function(Value)
        _G.PacketLagActive = Value
        if Value then
            task.spawn(function()
                local GE = ReplicatedStorage:WaitForChild("GrabEvents")
                local Remote = GE:FindFirstChild("ExtendGrabLine") or GE:FindFirstChild("CreateGrabLine")
                if not Remote then return end
                
                while _G.PacketLagActive do
                    pcall(function()
                        for i = 1, 25 do
                            Remote:FireServer(
                                string.rep("LAGGGGGGG", 5000),
                                Vector3.new(math.huge, math.huge, math.huge),
                                CFrame.new(math.huge, math.huge, math.huge),
                                table.create(5000, "X")
                            )
                        end
                    end)
                    task.wait()
                end
            end)
        else
            _G.PacketLagActive = false
        end
    end
})

-- Auto Reset
local autoResetEnabled = false

MiscGroup:AddToggle("AutoResetToggle", {
    Text = " Auto Reset",
    Default = false,
    Callback = function(on)
        autoResetEnabled = on
        if not on then
            autoResetEnabled = false
            return
        end
        
        task.spawn(function()
            while autoResetEnabled do
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChild("Humanoid")
                if hum and hum.Health > 0 then hum.Health = 0 end
                task.wait(0.5)
            end
        end)
    end
})

-- FOV Slider
MiscGroup:AddSlider("FOVSlider", {
    Text = " fov",
    Default = 90,
    Min = 1,
    Max = 120,
    Rounding = 0,
    Suffix = "°",
    Callback = function(value) workspace.CurrentCamera.FieldOfView = value end
})


local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox(" Menu")

MenuGroup:AddButton(" Unload Script", function() Library:Unload() end)
MenuGroup:AddLabel(" Menu Keybind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "Menu Keybind"
})

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("ok hub")
SaveManager:SetFolder("ok hub/configs")
SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])

-- Friend Join Notify
Players.PlayerAdded:Connect(function(plr)
    if plr:IsFriendsWith(LocalPlayer.UserId) then
        notify("Friend Joined", plr.Name .. " joined the game!", 5)
    end
end)


local FanGroup = Tabs.Fun:AddLeftGroupbox(" Troll")

-- Black Hole Kick Detection
local variants = {
    "BlackHole", "Black_Hole", "Blackhole", "Black-Hole", "BHole", "BH",
    "VoidHole", "Void", "VoidSphere", "DarkHole", "DarkSphere", "DarkOrb",
    "GravityHole", "GravityOrb", "SpaceHole", "SpaceOrb", "Singularity",
    "SingularityOrb", "EventHorizon", "BlackSphere", "Anomaly", "AnomalyHole",
    "SupermassiveHole", "QuantumHole"
}

local function playKickSound()
    local s = Instance.new("Sound")
    s.SoundId = ""
    s.Volume = 5
    s.PlayOnRemove = true
    s.Parent = SoundService
    s:Destroy()
end

local function notifyKick(displayName, username)
    Library:Notify({
        Title = "nice",
        Description = displayName .. " (" .. username .. ") has been kicked",
        Time = 6,
    })
end

local function getClosestPlayer(pos)
    local closestPlr = nil
    local closestDist = math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (hrp.Position - pos).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestPlr = plr
                end
            end
        end
    end
    return closestPlr
end

Workspace.ChildAdded:Connect(function(obj)
    if obj.Name == "BlackHoleKick" or obj.Name == "BlackHoleDetected" then
        task.wait(0.05)
        local pos
        if obj:IsA("BasePart") then
            pos = obj.Position
        elseif obj:IsA("Model") and obj.PrimaryPart then
            pos = obj.PrimaryPart.Position
        end
        if not pos then return end
        
        local plr = getClosestPlayer(pos)
        if not plr then return end
        
        playKickSound()
        notifyKick(plr.DisplayName, plr.Name)
    end
end)

-- Jerk Off Animation
local playJerkOffActive = false
local jerkOffAnimTrack = nil
local jerkOffAnimId = "rbxassetid://168268306"
local selectedKey = Enum.KeyCode.Q
local jerkSpeed = 1

local function startJerkOff()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end
    
    local anim = Instance.new("Animation")
    anim.AnimationId = jerkOffAnimId
    jerkOffAnimTrack = animator:LoadAnimation(anim)
    jerkOffAnimTrack.Priority = Enum.AnimationPriority.Action
    jerkOffAnimTrack:Play()
    jerkOffAnimTrack:AdjustSpeed(jerkSpeed)
    
    task.spawn(function()
        while playJerkOffActive do
            task.wait(0.1)
            if jerkOffAnimTrack and jerkOffAnimTrack.IsPlaying then
                jerkOffAnimTrack.TimePosition = 0.3
                jerkOffAnimTrack:AdjustSpeed(jerkSpeed)
            end
        end
    end)
end

local function stopJerkOff()
    if jerkOffAnimTrack then
        jerkOffAnimTrack:Stop()
        jerkOffAnimTrack = nil
    end
end

FanGroup:AddToggle("JerkOffToggle", {
    Text = " Jerk Off ",
    Default = false,
    Callback = function(on)
        playJerkOffActive = on
        if on then startJerkOff() else stopJerkOff() end
    end
})

FanGroup:AddSlider("JerkSpeed", {
    Text = " Animation Speed",
    Default = 1,
    Min = 0.1,
    Max = 5,
    Rounding = 1,
    Callback = function(v)
        jerkSpeed = v
        if jerkOffAnimTrack then jerkOffAnimTrack:AdjustSpeed(jerkSpeed) end
    end
})

FanGroup:AddDropdown("JerkKey", {
    Text = " Toggle Key",
    Values = { "Q", "E", "R", "T" },
    Default = 1,
    Callback = function(v) selectedKey = Enum.KeyCode[v] end
})

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == selectedKey then
        playJerkOffActive = not playJerkOffActive
        if playJerkOffActive then startJerkOff() else stopJerkOff() end
    end
end)



local AurasGroup = Tabs.Auras:AddLeftGroupbox(" Auras")

-- Remove Anti-Kick Aura
local removeAntiKickAuraActive = false
local removeAntiKickAuraConnection = nil
local removeAntiKickRadius = 15
local useWhitelistRemoveAntiKick = true

AurasGroup:AddDropdown("RemoveAntiKickAuraRadiusDropdown", {
    Text = " Anti Kick Aura Radius",
    Values = { "10", "12", "14", "16", "18", "20" },
    Default = "15",
    Callback = function(value) removeAntiKickRadius = tonumber(value) end
})

AurasGroup:AddToggle("RemoveAntiKickAuraWhitelistToggle", {
    Text = " Use Whitelist (Friends)",
    Default = true,
    Callback = function(on) useWhitelistRemoveAntiKick = on end
})

AurasGroup:AddToggle("RemoveAntiKickAuraToggle", {
    Text = " Remove Anti Kick Aura",
    Default = false,
    Callback = function(on)
        removeAntiKickAuraActive = on
        if not on then
            if removeAntiKickAuraConnection then
                removeAntiKickAuraConnection:Disconnect()
                removeAntiKickAuraConnection = nil
            end
            return
        end
        
        task.spawn(function()
            local GrabEvents = ReplicatedStorage:WaitForChild("GrabEvents")
            local SetNetOwner = GrabEvents:WaitForChild("SetNetworkOwner")
            
            removeAntiKickAuraConnection = RunService.Heartbeat:Connect(function()
                local myChar = LocalPlayer.Character
                local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if not myRoot then return end
                
                for _, target in ipairs(Players:GetPlayers()) do
                    if target ~= LocalPlayer then
                        local tChar = target.Character
                        local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                        if not tRoot then continue end
                        
                        if useWhitelistRemoveAntiKick and LocalPlayer:IsFriendsWith(target.UserId) then
                            continue
                        end
                        
                        if (tRoot.Position - myRoot.Position).Magnitude <= removeAntiKickRadius then
                            local spawned = workspace:FindFirstChild(target.Name .. "SpawnedInToys")
                            if spawned then
                                for _, toyName in ipairs({ "NinjaKunai", "NinjaShuriken", "AntiKick" }) do
                                    local toy = spawned:FindFirstChild(toyName)
                                    if toy then
                                        local part = toy:FindFirstChild("SoundPart")
                                        if part then
                                            pcall(function() SetNetOwner:FireServer(part, part.CFrame) end)
                                            if part:FindFirstChild("PartOwner") and part.PartOwner.Value == LocalPlayer.Name then
                                                part.CFrame = CFrame.new(0, 1000, 0)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end)
    end
})

-- Dual Hand Kick Aura
local dualKickAuraEnabled = false
local dualKickAuraRadius = 20
local dualKickAuraWhitelist = true
local dualKickAuraConn

local function canKick(plr)
    if not dualKickAuraWhitelist then return true end
    return not LocalPlayer:IsFriendsWith(plr.UserId)
end

AurasGroup:AddDropdown("DualKickAuraRadius", {
    Text = " Dual Kick Aura Radius",
    Values = { "10", "20", "30", "40", "50" },
    Default = "20",
    Callback = function(v) dualKickAuraRadius = tonumber(v) end
})

AurasGroup:AddToggle("DualKickAuraWhitelist", {
    Text = " Whitelist Friends",
    Default = true,
    Callback = function(v) dualKickAuraWhitelist = v end
})

AurasGroup:AddToggle("DualHandKickAura", {
    Text = " Dual Hand Kick Aura",
    Default = false,
    Callback = function(on)
        dualKickAuraEnabled = on
        if dualKickAuraConn then
            dualKickAuraConn:Disconnect()
            dualKickAuraConn = nil
        end
        if not on then return end
        
        local tickLimiter = 0
        dualKickAuraConn = RunService.Heartbeat:Connect(function()
            if tick() - tickLimiter < 0.12 then return end
            tickLimiter = tick()
            
            local myChar = LocalPlayer.Character
            local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
            local seat = hum and hum.SeatPart
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not (seat and myRoot) then return end
            
            local seatParent = seat.Parent
            local scriptFolder = seatParent and seatParent:FindFirstChild("BlobmanSeatAndOwnerScript")
            local grab = scriptFolder and scriptFolder:FindFirstChild("CreatureGrab")
            local drop = scriptFolder and scriptFolder:FindFirstChild("CreatureDrop")
            local leftDet = seatParent:FindFirstChild("LeftDetector")
            local rightDet = seatParent:FindFirstChild("RightDetector")
            local leftWeld = leftDet and leftDet:FindFirstChild("LeftWeld")
            local rightWeld = rightDet and rightDet:FindFirstChild("RightWeld")
            
            if not (grab and drop and leftDet and rightDet and leftWeld and rightWeld) then return end
            
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character and canKick(plr) then
                    local char = plr.Character
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local hum2 = char:FindFirstChildOfClass("Humanoid")
                    if hrp and hum2 and hum2.Health > 0 then
                        local dist = (hrp.Position - myRoot.Position).Magnitude
                        if dist <= dualKickAuraRadius then
                            pcall(function()
                                grab:FireServer(leftDet, hrp, leftWeld)
                                task.wait(0.04)
                                drop:FireServer(leftWeld, hrp)
                                grab:FireServer(rightDet, hrp, rightWeld)
                                task.wait(0.04)
                                drop:FireServer(rightWeld, hrp)
                                grab:FireServer(leftDet, hrp, leftWeld)
                                grab:FireServer(rightDet, hrp, rightWeld)
                                task.wait(0.03)
                                drop:FireServer(leftWeld, hrp)
                                drop:FireServer(rightWeld, hrp)
                            end)
                        end
                    end
                end
            end
        end)
    end
})

-- Kick Aura 1 Hand
local kickAura1Enabled = false
local kickAura1Radius = 20
local kickAura1Whitelist = true
local kickAura1Conn

AurasGroup:AddDropdown("KickAura1Radius", {
    Text = " Kick Aura 1 Hand Radius",
    Values = { "10", "20", "30", "40", "50" },
    Default = "20",
    Callback = function(v) kickAura1Radius = tonumber(v) end
})

AurasGroup:AddToggle("KickAura1Whitelist", {
    Text = " Whitelist Friends",
    Default = kickAura1Whitelist,
    Callback = function(v) kickAura1Whitelist = v end
})

AurasGroup:AddToggle("KickAura1Toggle", {
    Text = " Kick Aura 1 Hand (Grab + Blob)",
    Default = kickAura1Enabled,
    Callback = function(on)
        kickAura1Enabled = on
        if kickAura1Conn then
            kickAura1Conn:Disconnect()
            kickAura1Conn = nil
        end
        if not on then return end
        
        kickAura1Conn = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChild("Humanoid")
            local seat = hum and hum.SeatPart
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not (seat and root) then return end
            
            local blob = seat.Parent
            local blobRoot = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
            local scriptObj = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
            local CG = scriptObj and scriptObj:FindFirstChild("CreatureGrab")
            local CD = scriptObj and scriptObj:FindFirstChild("CreatureDrop")
            local R_Det = blob:FindFirstChild("RightDetector")
            local R_Weld = R_Det and (R_Det:FindFirstChild("RightWeld") or R_Det:FindFirstChildWhichIsA("Weld"))
            
            if not (CG and CD and R_Det and R_Weld and blobRoot) then return end
            
            local packetTimer = 0
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character and (not kickAura1Whitelist or not LocalPlayer:IsFriendsWith(plr.UserId)) then
                    local tChar = plr.Character
                    local tRoot = tChar:FindFirstChild("HumanoidRootPart")
                    local tHum = tChar:FindFirstChild("Humanoid")
                    if tRoot and tHum and tHum.Health > 0 then
                        local dist = (tRoot.Position - root.Position).Magnitude
                        if dist <= kickAura1Radius then
                            pcall(function()
                                if tick() - packetTimer > 0.05 then
                                    packetTimer = tick()
                                    local weld = R_Det:FindFirstChild("RightWeld") or R_Det:FindFirstChildWhichIsA("Weld")
                                    if weld then
                                        CD:FireServer(weld)
                                        CG:FireServer(R_Det, tRoot, R_Weld)
                                    end
                                end
                            end)
                        end
                    end
                end
            end
        end)
    end
})


local KeybindsGroup = Tabs.Keybinds:AddLeftGroupbox(" Keybinds")
local AnimGroup = Tabs.Fun:AddLeftGroupbox(" Animations")
local animEnabled = false
local currentTrack = nil
local selectedAnimName = "Crazy"
local selectedAnimKey = Enum.KeyCode.Q

local Animations = {
    ["Crazy"] = "rbxassetid://248263260",
    ["Insane"] = "rbxassetid://35654637",
    ["Collapse"] = "rbxassetid://35154961",
    ["Zombie"] = "rbxassetid://33796059",
}

local function playAnimation()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end
    
    if currentTrack then
        currentTrack:Stop()
        currentTrack = nil
    end
    
    local anim = Instance.new("Animation")
    anim.AnimationId = Animations[selectedAnimName]
    currentTrack = animator:LoadAnimation(anim)
    currentTrack.Priority = Enum.AnimationPriority.Action
    currentTrack.Looped = true
    currentTrack:Play()
    
    task.spawn(function()
        while animEnabled and currentTrack do
            if currentTrack.TimePosition > 0.9 then
                currentTrack.TimePosition = 0.3
            end
            task.wait(0.05)
        end
    end)
end

local function stopAnimation()
    if currentTrack then
        currentTrack:Stop()
        currentTrack = nil
    end
end

AnimGroup:AddToggle("AnimToggle", {
    Text = " Play Animation",
    Default = false,
    Callback = function(on)
        animEnabled = on
        if on then playAnimation() else stopAnimation() end
    end
})

AnimGroup:AddDropdown("AnimSelect", {
    Text = " Select Animation",
    Values = { "Crazy", "Insane", "Collapse", "Zombie" },
    Default = 1,
    Callback = function(v)
        selectedAnimName = v
        if animEnabled then playAnimation() end
    end
})

AnimGroup:AddDropdown("AnimKeybind", {
    Text = " Toggle Key",
    Values = { "Q", "E", "R", "T", "F", "Z", "X", "C" },
    Default = 1,
    Callback = function(v) selectedAnimKey = Enum.KeyCode[v] end
})

-- Sit on Nearest Blobman
local function getNearestBlobman(maxDist)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local nearest, dist = nil, maxDist or 50
    for _, model in ipairs(workspace:GetDescendants()) do
        if model:IsA("Model") and model.Name == "CreatureBlobman" then
            local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
            if root then
                local d = (root.Position - hrp.Position).Magnitude
                if d < dist then
                    dist = d
                    nearest = model
                end
            end
        end
    end
    return nearest
end

local function SitOnBlobman()
    local char = LocalPlayer.Character
    if not char then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end
    if hum.SeatPart then return end
    
    local blob = getNearestBlobman(40)
    if not blob then
        warn("Blobman not found nearby")
        return
    end
    
    local seat = blob:FindFirstChildWhichIsA("Seat", true) or blob:FindFirstChildWhichIsA("VehicleSeat", true)
    if not seat then
        warn("Blobman seat not found")
        return
    end
    
    hrp.CFrame = seat.CFrame * CFrame.new(0, 1.2, -1)
    task.wait(0.05)
    pcall(function() seat:Sit(hum) end)
end

-- Keybind for Sit on Blobman
KeybindsGroup:AddLabel(" Blobman"):AddKeyPicker("SitBlobmanKey", {
    Default = "Z",
    Text = "Sit on nearest Blob",
    NoUI = false,
    Callback = function() SitOnBlobman() end
})

-- Follow & Stare
AnimGroup:AddToggle("FollowStare", {
    Text = "👀 Follow & Stare",
    Default = false,
    Callback = function(on)
        local follow = on
        task.spawn(function()
            while follow do
                local target = Players:GetPlayers()[math.random(#Players:GetPlayers())]
                if target ~= LocalPlayer and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    local hrp = LocalPlayer.Character.HumanoidRootPart
                    local thrp = target.Character.HumanoidRootPart
                    hrp.CFrame = CFrame.new(thrp.Position + thrp.CFrame.LookVector * -2, thrp.Position)
                end
                task.wait(0.3)
            end
        end)
    end
})

-- Fake Death
AnimGroup:AddToggle("FakeDeathToggle", {
    Text = " Fake Death",
    Default = false,
    Callback = function(on)
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        
        if on then
            hum:ChangeState(Enum.HumanoidStateType.Physics)
            hum.PlatformStand = true
        else
            hum.PlatformStand = false
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end
})

-- Fake Lag
local fakeLagConn
AnimGroup:AddToggle("FakeLagToggle", {
    Text = " Fake Lag",
    Default = false,
    Callback = function(on)
        if fakeLagConn then
            fakeLagConn:Disconnect()
            fakeLagConn = nil
        end
        if not on then return end
        
        fakeLagConn = RunService.Heartbeat:Connect(function()
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not root then return end
            if math.random(1, 5) == 1 then
                root.CFrame = root.CFrame * CFrame.new(math.random(-2, 2) / 10, 0, math.random(-2, 2) / 10)
            end
        end)
    end
})

-- Bang Player Animation
local playBangActive = false
local bangAnimTrack = nil
local bangAnimId = "rbxassetid://148840371"
local bangSpeed = 1
local selectedBangPlayer = ""

local playerNames = {}
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then table.insert(playerNames, p.Name) end
end
if #playerNames == 0 then table.insert(playerNames, "No Players") end

FanGroup:AddDropdown("BangPlayerDropdown", {
    Text = " Select Player",
    Values = playerNames,
    Default = 1,
    Callback = function(v) selectedBangPlayer = v end
})

FanGroup:AddSlider("BangSpeedSlider", {
    Text = " Bang Speed",
    Default = 1,
    Min = 0.1,
    Max = 5,
    Rounding = 1,
    Callback = function(v)
        bangSpeed = v
        if bangAnimTrack then bangAnimTrack:AdjustSpeed(v) end
    end
})

local function startBang()
    if selectedBangPlayer == "" or selectedBangPlayer == "No Players" then
        if notify then notify("Error", "Select a player first!", 3) end
        return nil
    end
    
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return nil end
    
    local target = Players:FindFirstChild(selectedBangPlayer)
    if not target then return nil end
    
    local tChar = target.Character
    local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
    if not tRoot then return nil end
    
    local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
    local anim = Instance.new("Animation")
    anim.AnimationId = bangAnimId
    
    if bangAnimTrack then bangAnimTrack:Stop() end
    bangAnimTrack = animator:LoadAnimation(anim)
    bangAnimTrack.Priority = Enum.AnimationPriority.Action
    bangAnimTrack.Looped = true
    bangAnimTrack:Play()
    bangAnimTrack:AdjustSpeed(bangSpeed)
    
    local followConn = RunService.RenderStepped:Connect(function()
        if not playBangActive or not root or not tRoot then return end
        root.CFrame = tRoot.CFrame * CFrame.new(0, 0, 0.75)
    end)
    return followConn
end

local followConnection = nil

FanGroup:AddToggle("BangToggle", {
    Text = " Bang Player",
    Default = false,
    Callback = function(on)
        playBangActive = on
        if on then
            if followConnection then followConnection:Disconnect() end
            followConnection = startBang()
        else
            if bangAnimTrack then
                bangAnimTrack:Stop()
                bangAnimTrack = nil
            end
            if followConnection then
                followConnection:Disconnect()
                followConnection = nil
            end
        end
    end
})

-- Stick Shuriken to UFO
FanGroup:AddToggle("UFOShurikenStick", {
    Text = " Stick Shuriken to ufo",
    Default = false,
    Callback = function(state)
        if not state then return end
        
        local StickyEvent = ReplicatedStorage:WaitForChild("PlayerEvents"):WaitForChild("StickyPartEvent")
        local SpawnRemote = ReplicatedStorage.MenuToys:WaitForChild("SpawnToyRemoteFunction")
        local CanSpawn = LocalPlayer:WaitForChild("CanSpawnToy")
        local ToysFolder = workspace:WaitForChild(LocalPlayer.Name .. "SpawnedInToys")
        
        local UFOs = {
            workspace.Map.AlwaysHereTweenedObjects:FindFirstChild("InnerUFO"),
            workspace.Map.AlwaysHereTweenedObjects:FindFirstChild("OuterUFO")
        }
        
        local function getHRP()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                return LocalPlayer.Character.HumanoidRootPart
            end
            return LocalPlayer.CharacterAdded:Wait():WaitForChild("HumanoidRootPart")
        end
        
        task.spawn(function()
            for i = 1, 12 do
                local t = tick()
                while not CanSpawn.Value do
                    if tick() - t > 5 then break end
                    task.wait(0.1)
                end
                local hrp = getHRP()
                if hrp then
                    pcall(function()
                        SpawnRemote:InvokeServer("NinjaShuriken", hrp.CFrame * CFrame.new(0, 10, 15), Vector3.new())
                    end)
                end
                task.wait(0.15)
            end
            
            task.wait(1)
            for _, Toy in ipairs(ToysFolder:GetChildren()) do
                if Toy.Name == "NinjaShuriken" and Toy:FindFirstChild("StickyPart") then
                    for _, UFO in ipairs(UFOs) do
                        if UFO and UFO:FindFirstChild("Object") and UFO.Object:FindFirstChild("ObjectModel") and UFO.Object.ObjectModel:FindFirstChild("Body") then
                            StickyEvent:FireServer(Toy.StickyPart, UFO.Object.ObjectModel.Body, CFrame.new())
                            local follow = UFO.Object:FindFirstChild("FollowThisPart")
                            if follow then
                                if follow:FindFirstChild("AlignOrientation") then
                                    follow.AlignOrientation.Enabled = false
                                end
                                if follow:FindFirstChild("AlignPosition") then
                                    follow.AlignPosition.Enabled = false
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
})

-- MassLess Grab
GrabGroup:AddToggle("MassLessGrabToggle", {
    Text = " MassLess Grab",
    Default = false,
    Callback = function(Value)
        _G.MassLessGrab = Value
        if not _G.MassLessGrab then
            if _G.MLConn then
                _G.MLConn:Disconnect()
                _G.MLConn = nil
            end
            return
        end
        
        if _G.MLConn then _G.MLConn:Disconnect() end
        _G.MLSense = _G.MLSense or 200
        
        _G.MLConn = RunService.Heartbeat:Connect(function()
            if not _G.MassLessGrab then return end
            local gp = workspace:FindFirstChild("GrabParts")
            if not gp then return end
            local dp = gp:FindFirstChild("DragPart")
            if not dp then return end
            
            local ap = dp:FindFirstChild("AlignPosition")
            local ao = dp:FindFirstChild("AlignOrientation")
            
            if ap then
                ap.Responsiveness = _G.MLSense
                ap.MaxForce = math.huge
                ap.MaxVelocity = math.huge
            end
            if ao then
                ao.Responsiveness = _G.MLSense
                ao.MaxTorque = math.huge
            end
        end)
    end
})



function SetupStatsAndLogs(Tab)
    local Groups = { Stats = Tab:AddRightGroupbox(" Stats") }
    local L = {
        PlayTime = Groups.Stats:AddLabel(" Playtime: 00:00:00"),
        FPS = Groups.Stats:AddLabel(" FPS: 0"),
        Ping = Groups.Stats:AddLabel(" Ping: 0 ms"),
        RAM = Groups.Stats:AddLabel(" RAM: 0 MB"),
        Players = Groups.Stats:AddLabel(" Players: 0"),
        Time = Groups.Stats:AddLabel(" Time: 00:00:00"),
        ServerAge = Groups.Stats:AddLabel(" Server Age: 00:00:00"),
        AccAge = Groups.Stats:AddLabel(" Acc Age: 0 days")
    }
    
    local LogsGroup = Tabs.Main:AddRightGroupbox("")
    LogsGroup:AddButton({
        Text = " Copy: no",
        Func = function()
            setclipboard("no")
            if Library and Library.Notify then
                Library:Notify({ Text = "!", Time = 2 })
            end
        end
    })
    LogsGroup:AddLabel(" ")
    LogsGroup:AddLabel("")
    LogsGroup:AddLabel(" Latest Updates:")
    LogsGroup:AddLabel("• 2026.06.08 - MORE UPDATE SOON!")
    LogsGroup:AddLabel("• 2026.06.08 - Added to maintab discord copy link button")
    LogsGroup:AddLabel("• 2026.06.08 - Added Whitelist to bring position function in attacktab")
    LogsGroup:AddLabel("• 2026.06.08 - FeedBack got Updated Minimal")
    LogsGroup:AddLabel("• 2026.06.08 - Bring Functions fixed")
    LogsGroup:AddLabel("• 2026.06.08 - Bring to farm added")
    LogsGroup:AddLabel("• 2026.06.08 - Minimal UI update")
    LogsGroup:AddLabel("• 2026.06.08 - More Sparkler Function added")
    LogsGroup:AddLabel("• 2026.06.08 - Spam Grab updated")
    
    task.spawn(function()
        local JoinTime = os.time()
        while task.wait(1) do
            local elapsed = os.time() - JoinTime
            local dgt = math.floor(workspace.DistributedGameTime)
            L.PlayTime:SetText(string.format("⏱️ Playtime: %02d:%02d:%02d", math.floor(elapsed/3600), math.floor((elapsed%3600)/60), elapsed%60))
            L.FPS:SetText(" FPS: " .. math.floor(workspace:GetRealPhysicsFPS()))
            L.Ping:SetText(" Ping: " .. math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) .. " ms")
            L.RAM:SetText(" RAM: " .. math.floor(Stats:GetTotalMemoryUsageMb()) .. " MB")
            L.Players:SetText(" Players: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers)
            L.Time:SetText(" Time: " .. os.date("%X"))
            L.ServerAge:SetText(" Server Age: " .. string.format("%02d:%02d:%02d", math.floor(dgt/3600), math.floor((dgt%3600)/60), dgt%60))
            L.AccAge:SetText(" Acc Age: " .. LocalPlayer.AccountAge .. " days")
        end
    end)
end

SetupStatsAndLogs(Tabs.Main)



_G.GoxConfig = _G.GoxConfig or {}
_G.GoxConfig.FullBrightActive = false
_G.GoxConfig.AntiAfkActive = false
_G.GoxConfig.AntiReportActive = false
_G.GoxConfig.AutoAntiLagActive = false
_G.GoxConfig.Lines = 0
_G.GoxConfig.Lagger = nil
_G.GoxConfig.Connections = _G.GoxConfig.Connections or {}

_G.GoxConfig.DoServerHop = function()
    pcall(function()
        local Servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        for _, server in pairs(Servers.data) do
            if server.playing < server.maxPlayers and server.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                break
            end
        end
    end)
end

-- Full Bright Loop
task.spawn(function()
    while task.wait(1) do
        if _G.GoxConfig.FullBrightActive then
            pcall(function()
                Lighting.Brightness = 2
                Lighting.ClockTime = 14
                Lighting.FogEnd = 999999
                Lighting.GlobalShadows = false
                Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            end)
        end
    end
end)

-- Anti-AFK
if not _G.GoxConfig.AntiAfkConnected then
    _G.GoxConfig.AntiAfkConnected = true
    pcall(function()
        LocalPlayer.Idled:Connect(function()
            if _G.GoxConfig.AntiAfkActive then
                VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            end
        end)
    end)
end

-- Anti-Report
if not _G.GoxConfig.AntiReportConnected then
    _G.GoxConfig.AntiReportConnected = true
    local function setupPlayer(p)
        p.Chatted:Connect(function(msg)
            if p ~= LocalPlayer and _G.GoxConfig.AntiReportActive and string.find(string.lower(msg), "report") then
                _G.GoxConfig.DoServerHop()
            end
        end)
    end
    table.foreach(Players:GetPlayers(), function(_, p) setupPlayer(p) end)
    Players.PlayerAdded:Connect(setupPlayer)
end

-- Descendant Added Monitor
if not _G.GoxConfig.DescendantAddedConnected then
    _G.GoxConfig.DescendantAddedConnected = true
    workspace.DescendantAdded:Connect(function(d)
        if d.Name == "GrabBeam" then
            _G.GoxConfig.Lines = _G.GoxConfig.Lines + 1
            pcall(function() _G.GoxConfig.Lagger = d.Parent.Parent.Parent end)
        end
    end)
end

-- Extras Groups
_G.GoxConfig.ExtrasVisuals = Tabs.Extras:AddLeftGroupbox("🎨 Visual Hacks")
_G.GoxConfig.ExtrasProtection = Tabs.Extras:AddRightGroupbox("🛡️ Safety & Automation")
_G.GoxConfig.ExtrasCharacter = Tabs.Extras:AddRightGroupbox("👤 Character Exploits")

_G.GoxConfig.ExtrasVisuals:AddToggle("FullBrightToggle", {
    Text = " Full Bright & No Fog",
    Default = false,
    Callback = function(Value)
        _G.GoxConfig.FullBrightActive = Value
        if not Value then
            pcall(function()
                Lighting.Brightness = 1
                Lighting.ClockTime = 12
                Lighting.FogEnd = 1000
                Lighting.GlobalShadows = true
                Lighting.Ambient = Color3.fromRGB(128, 128, 128)
            end)
        end
    end
})

_G.GoxConfig.ExtrasProtection:AddToggle("AntiAfkToggle", {
    Text = " Anti-AFK ",
    Default = false,
    Callback = function(Value) _G.GoxConfig.AntiAfkActive = Value end
})

_G.GoxConfig.ExtrasProtection:AddToggle("AntiReportToggle", {
    Text = " Anti-Report  Admin Detect",
    Default = false,
    Callback = function(Value) _G.GoxConfig.AntiReportActive = Value end
})

_G.GoxConfig.ExtrasProtection:AddToggle("AutoAntiLag", {
    Text = " Auto Anti Lag",
    Default = false,
    Callback = function(v)
        _G.GoxConfig.AutoAntiLagActive = v
        if v then
            task.spawn(function()
                while _G.GoxConfig.AutoAntiLagActive and task.wait() do
                    if _G.GoxConfig.Lines > 100 then
                        pcall(function()
                            if LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts") and LocalPlayer.PlayerScripts:FindFirstChild("CharacterAndBeamMove") then
                                LocalPlayer.PlayerScripts.CharacterAndBeamMove.Enabled = false
                            end
                            local laggerName = (_G.GoxConfig.Lagger and _G.GoxConfig.Lagger.Name) or "Someone"
                            Library:Notify({
                                Title = "Auto Anti Lag Notify",
                                Description = laggerName .. " Lagged Server",
                                Time = 6.5,
                            })
                        end)
                        _G.GoxConfig.Lines = 0
                    end
                end
            end)
        else
            pcall(function()
                if LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts") and LocalPlayer.PlayerScripts:FindFirstChild("CharacterAndBeamMove") then
                    LocalPlayer.PlayerScripts.CharacterAndBeamMove.Enabled = true
                end
            end)
        end
    end
})

_G.GoxConfig.ExtrasCharacter:AddButton(" Delete Legs", function()
    pcall(function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("Left Leg") and char:FindFirstChild("Right Leg") and char:FindFirstChild("Torso") then
            _G.GoxConfig.LL = char:FindFirstChild("Left Leg")
            _G.GoxConfig.RL = char:FindFirstChild("Right Leg")
            _G.GoxConfig.VoidHeight = workspace.FallenPartsDestroyHeight
            _G.GoxConfig.SavedPos = char.Torso.CFrame
            workspace.FallenPartsDestroyHeight = -100
            
            if CE and CE:FindFirstChild("RagdollRemote") then
                CE.RagdollRemote:FireServer(char.HumanoidRootPart, 2)
            end
            
            task.wait(0.5)
            if _G.GoxConfig.RL then _G.GoxConfig.RL.CFrame = CFrame.new(0, -10000, 0) end
            if _G.GoxConfig.LL then _G.GoxConfig.LL.CFrame = CFrame.new(0, -10000, 0) end
            task.wait(0.3)
            if char:FindFirstChild("Torso") then char.Torso.CFrame = CFrame.new(0, -9970, 0) end
            task.wait(0.5)
            if char:FindFirstChild("Torso") and _G.GoxConfig.SavedPos then char.Torso.CFrame = _G.GoxConfig.SavedPos end
            task.wait(0.5)
            workspace.FallenPartsDestroyHeight = _G.GoxConfig.VoidHeight
            
            task.spawn(function()
                while char and char.Parent and not char:FindFirstChild("Left Leg") and not char:FindFirstChild("Right Leg") and task.wait() do
                    pcall(function()
                        if LocalPlayer.PlayerGui.ControlsGui.PCFrame.Stand.Visible == false then
                            char.Humanoid.HipHeight = 2
                        else
                            char.Humanoid.HipHeight = 0
                        end
                    end)
                end
            end)
        end
    end)
end)


_G.GoxConfig.AutoFarmCoins = false
_G.GoxConfig.TP_Priority = 0
_G.GoxConfig.SavedPositionInSpin = nil

local workspaceService = Workspace
local setNetworkOwnerEvent = ReplicatedStorage:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")

_G.GoxConfig.GetPlayerCharacter = function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChildOfClass("Humanoid") then
        return char
    end
    return nil
end

_G.GoxConfig.LookAt = function(startPosition, targetPosition)
    local directionVector = (targetPosition - startPosition).Unit
    local rightVector = directionVector:Cross(Vector3.new(0, 1, 0))
    local upVector = rightVector:Cross(directionVector)
    return CFrame.fromMatrix(startPosition, rightVector, upVector)
end

_G.GoxConfig.SNOWship = function(targetPart)
    if not targetPart then return end
    local char = _G.GoxConfig.GetPlayerCharacter()
    if char and char:FindFirstChild("HumanoidRootPart") then
        local dist = (char.HumanoidRootPart.Position - targetPart.Position).Magnitude
        if dist <= 30 then
            setNetworkOwnerEvent:FireServer(targetPart, _G.GoxConfig.LookAt(char.HumanoidRootPart.Position, targetPart.Position))
        end
    end
end

_G.GoxConfig.ChangeActivityPriority = function(p)
    if _G.GoxConfig.TP_Priority <= p then
        _G.GoxConfig.TP_Priority = p
        return true
    end
    if p == 0 then
        _G.GoxConfig.TP_Priority = p
        return true
    end
    return false
end

_G.GoxConfig.TeleportPlayer = function(cframeOffset, tp)
    if (tp == nil and 0 or tp) ~= _G.GoxConfig.TP_Priority then return end
    local char = _G.GoxConfig.GetPlayerCharacter()
    if not char then return end
    local hrp = char.HumanoidRootPart
    local hum = char:FindFirstChildOfClass("Humanoid")
    hrp.CFrame = hrp.CFrame.Rotation + cframeOffset.Position
    if hum and (not hum.SeatPart or tostring(hum.SeatPart.Parent) ~= "CreatureBlobman") then
        hum.Sit = false
    end
end

_G.GoxConfig.AreAllSlotsNeon = function()
    for _, slot in pairs(workspaceService.Slots:GetChildren()) do
        local lightBall = slot:FindFirstChild("SlotHandle", true) and slot.SlotHandle:FindFirstChild("LightBall")
        if lightBall and lightBall.Material ~= Enum.Material.Neon then return false end
    end
    return true
end

_G.GoxConfig.SaveCharacterPosition = function(loc)
    local char = _G.GoxConfig.GetPlayerCharacter()
    if loc == "Spin" and char and char:FindFirstChild("HumanoidRootPart") then
        _G.GoxConfig.SavedPositionInSpin = char.HumanoidRootPart.CFrame
    end
end

_G.GoxConfig.TeleportToLocation = function(loc)
    local char = _G.GoxConfig.GetPlayerCharacter()
    if loc == "Spin" and char and char:FindFirstChild("HumanoidRootPart") and _G.GoxConfig.SavedPositionInSpin then
        char.HumanoidRootPart.CFrame = _G.GoxConfig.SavedPositionInSpin
    end
end

CoinFarmGroup = Tabs.Extras:AddRightGroupbox(" Coin Farm")
CoinFarmGroup:AddLabel(" Auto Spin (Slots)")
local TimeRemainingLabel = CoinFarmGroup:AddLabel(" Time Remaining: 0:00")
local CoinsWonLabel = CoinFarmGroup:AddLabel(" Coins Won: 0")

CoinFarmGroup:AddToggle("AutoSpinToggle", {
    Text = " Auto-Spin",
    Default = false,
    Callback = function(Value)
        _G.GoxConfig.AutoFarmCoins = Value
        if Value then
            task.spawn(function()
                while _G.GoxConfig.AutoFarmCoins do
                    if _G.GoxConfig.AreAllSlotsNeon() and _G.GoxConfig.ChangeActivityPriority(5) then
                        _G.GoxConfig.SaveCharacterPosition("Spin")
                        local slotHandle = nil
                        local teleportTask = task.spawn(function()
                            while true do
                                if slotHandle then
                                    _G.GoxConfig.TeleportPlayer(slotHandle.CFrame + Vector3.new(0, 5, 0), 5)
                                    task.wait(0.2)
                                    _G.GoxConfig.SNOWship(slotHandle)
                                end
                                task.wait()
                            end
                        end)
                        
                        for _, slot in pairs(workspaceService.Slots:GetChildren()) do
                            slotHandle = slot:FindFirstChild("SlotHandle", true) and slot.SlotHandle:FindFirstChild("Handle")
                            if slotHandle then
                                slotHandle.CanCollide = false
                                for _ = 1, 5 do task.wait(0.2) end
                                slotHandle.CanCollide = true
                                if not _G.GoxConfig.AreAllSlotsNeon() then break end
                            end
                        end
                        
                        task.cancel(teleportTask)
                        _G.GoxConfig.ChangeActivityPriority(0)
                        _G.GoxConfig.TeleportToLocation("Spin")
                    end
                    task.wait(5)
                end
            end)
        end
    end
})


local PlayerViewGroup = Tabs.Player:AddLeftGroupbox(" Player View")
local blobSpeedValue = 100
local blobFlySpeed = 100
local autoBlobReseat = false
local blobFlyEnabled = false
local bodyGyro = nil
local bodyVelocity = nil

PlayerViewGroup:AddSlider("BlobSpeedSlider", {
    Text = " Blobman Speed",
    Default = 100,
    Min = 0,
    Max = 300,
    Rounding = 0,
    Callback = function(Value) blobSpeedValue = Value end
})

PlayerViewGroup:AddSlider("BlobFlySpeedSlider", {
    Text = " Blob Fly Speed",
    Default = 100,
    Min = 0,
    Max = 500,
    Rounding = 0,
    Callback = function(Value) blobFlySpeed = Value end
})

PlayerViewGroup:AddToggle("AutoBlobsit", {
    Text = " Auto Blob sit",
    Default = false,
    Callback = function(v) autoBlobsit = v end
})

PlayerViewGroup:AddToggle("BlobFlyToggle", {
    Text = " Blob Fly",
    Default = false,
    Callback = function(v) blobFlyEnabled = v end
})

-- Blob Movement Loop
task.spawn(function()
    while task.wait(0.1) do
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then continue end
        
        local seat = hum.SeatPart
        if seat and seat.Parent and seat.Parent.Name == "CreatureBlobman" then
            local blob = seat.Parent
            local blobHum = blob:FindFirstChildWhichIsA("Humanoid")
            local blobRoot = blob:FindFirstChild("HumanoidRootPart")
            
            if blobHum then blobHum.WalkSpeed = blobSpeedValue end
            
            if blobFlyEnabled and blobRoot and blobHum then
                blobHum.PlatformStand = true
                
                if not bodyGyro or bodyGyro.Parent ~= blobRoot then
                    bodyGyro = Instance.new("BodyGyro")
                    bodyGyro.P = 90000
                    bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                    bodyGyro.Parent = blobRoot
                end
                
                if not bodyVelocity or bodyVelocity.Parent ~= blobRoot then
                    bodyVelocity = Instance.new("BodyVelocity")
                    bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                    bodyVelocity.Parent = blobRoot
                end
                
                local moveDirection = Vector3.zero
                local cam = workspace.CurrentCamera
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection += cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection -= cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection -= cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection += cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDirection += Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDirection -= Vector3.new(0, 1, 0) end
                
                bodyGyro.CFrame = cam.CFrame
                if moveDirection.Magnitude > 0 then
                    bodyVelocity.Velocity = moveDirection.Unit * blobFlySpeed
                else
                    bodyVelocity.Velocity = Vector3.zero
                end
            else
                if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
                if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
                if blobHum then blobHum.PlatformStand = false end
            end
        else
            if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
            if bodyVelocity then bodyVelocity:Destroy(); bodyVelocity = nil end
        end
        
        -- Auto Blob Reseat
        if autoBlobReseat and not hum.SeatPart then
            local folder = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
            if folder then
                local blob = folder:FindFirstChild("CreatureBlobman")
                if blob then
                    local blobSeat = blob:FindFirstChild("VehicleSeat") or blob:FindFirstChildWhichIsA("Seat")
                    if blobSeat then
                        local t = tick()
                        repeat
                            if hum.SeatPart == blobSeat then break end
                            hrp.CFrame = blobSeat.CFrame + Vector3.new(0, 1, 0)
                            hrp.Velocity = Vector3.zero
                            pcall(function() blobSeat:Sit(hum) end)
                            RunService.Heartbeat:Wait()
                        until hum.SeatPart == blobSeat or tick() - t > 1.5
                    end
                end
            end
        end
    end
end)


_G.FZ = _G.FZ or {}
_G.FZ.SkyPresets = {
    ["Default"] =     {Time = "14:00:00", Brightness = 2,   Ambient = Color3.fromRGB(140,140,140), Fog = 100000, Shadows = true},
    ["Night"] =       {Time = "00:30:00", Brightness = 0.4, Ambient = Color3.fromRGB(10,10,30),   Fog = 800,    Shadows = false},
    ["Midnight"] =    {Time = "23:45:00", Brightness = 0.25, Ambient = Color3.fromRGB(5,5,25),     Fog = 600,    Shadows = false},
    ["Sunset"] =      {Time = "18:20:00", Brightness = 1.1, Ambient = Color3.fromRGB(255,140,80), Fog = 1400,   Shadows = true},
    ["Purple Haze"] = {Time = "20:30:00", Brightness = 0.9, Ambient = Color3.fromRGB(100,30,150), Fog = 950,    Shadows = true}
}
_G.FZ.CurrentSky = "Default"

_G.FZ.SkyGroup = Tabs.Player:AddLeftGroupbox("🌌 Sky Changer")
_G.FZ.SkyGroup:AddDropdown("SkyDropdown", {
    Text = " Select Sky",
    Values = {"Default", "Night", "Midnight", "Sunset", "Purple Haze"},
    Default = 1,
    Callback = function(Value)
        _G.FZ.CurrentSky = Value
        local s = _G.FZ.SkyPresets[Value]
        Lighting.TimeOfDay = s.Time
        Lighting.Brightness = s.Brightness
        Lighting.Ambient = s.Ambient
        Lighting.FogEnd = 1000000
        Lighting.GlobalShadows = s.Shadows
    end
})

Lighting:GetPropertyChangedSignal("TimeOfDay"):Connect(function()
    if _G.FZ.CurrentSky ~= "Default" then
        local s = _G.FZ.SkyPresets[_G.FZ.CurrentSky]
        if Lighting.TimeOfDay ~= s.Time then Lighting.TimeOfDay = s.Time end
        Lighting.FogEnd = 1000000
    end
end)

_G.FZ.SkyGroup:AddButton({
    Text = " Reset to Default",
    Func = function()
        _G.FZ.CurrentSky = "Default"
        local s = _G.FZ.SkyPresets["Default"]
        Lighting.TimeOfDay = s.Time
        Lighting.Brightness = s.Brightness
        Lighting.Ambient = s.Ambient
        Lighting.FogEnd = 1000000
        Lighting.GlobalShadows = s.Shadows
    end
})

-- Ultra Graphics Preset
local originalSettings = nil
_G.FZ.SkyGroup:AddButton({
    Text = "Graphics",
    Func = function()
        local Terrain = workspace.Terrain
        if not originalSettings then
            originalSettings = {
                Brightness = Lighting.Brightness,
                GlobalShadows = Lighting.GlobalShadows,
                FogEnd = Lighting.FogEnd,
                Ambient = Lighting.Ambient,
                EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
                EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
                ShadowSoftness = Lighting.ShadowSoftness,
                Technology = Lighting.Technology,
                WaterWaveSize = Terrain.WaterWaveSize,
                WaterWaveSpeed = Terrain.WaterWaveSpeed,
                WaterReflectance = Terrain.WaterReflectance,
                WaterTransparency = Terrain.WaterTransparency,
            }
        end
        
        pcall(function() Lighting.Technology = Enum.Technology.Future end)
        Lighting.Brightness = 3.0
        Lighting.GlobalShadows = true
        Lighting.ShadowSoftness = 0.2
        Lighting.FogEnd = 999999
        Lighting.Ambient = Color3.fromRGB(140, 140, 140)
        Lighting.EnvironmentDiffuseScale = 1
        Lighting.EnvironmentSpecularScale = 1
        
        Terrain.WaterWaveSize = 0.2
        Terrain.WaterWaveSpeed = 10
        Terrain.WaterReflectance = 1
        Terrain.WaterTransparency = 0.5
        
        local bloom = Lighting:FindFirstChild("UltraBloom") or Instance.new("BloomEffect")
        bloom.Name = "UltraBloom"
        bloom.Intensity = 1.5
        bloom.Size = 30
        bloom.Threshold = 0.9
        bloom.Parent = Lighting
        
        local cc = Lighting:FindFirstChild("UltraCC") or Instance.new("ColorCorrectionEffect")
        cc.Name = "UltraCC"
        cc.Saturation = 0.35
        cc.Contrast = 0.2
        cc.Parent = Lighting
        
        local sunRays = Lighting:FindFirstChild("UltraSunRays") or Instance.new("SunRaysEffect")
        sunRays.Name = "UltraSunRays"
        sunRays.Intensity = 0.25
        sunRays.Spread = 0.6
        sunRays.Parent = Lighting
        
        print(" Ultra Graphics Activated!")
    end
})

_G.FZ.SkyGroup:AddButton({
    Text = " Reset Graphs",
    Func = function()
        if not originalSettings then
            print("Graphics are already at default!")
            return
        end
        
        local Terrain = workspace.Terrain
        Lighting.Brightness = originalSettings.Brightness
        Lighting.GlobalShadows = originalSettings.GlobalShadows
        Lighting.FogEnd = originalSettings.FogEnd
        Lighting.Ambient = originalSettings.Ambient
        Lighting.EnvironmentDiffuseScale = originalSettings.EnvironmentDiffuseScale
        Lighting.EnvironmentSpecularScale = originalSettings.EnvironmentSpecularScale
        Lighting.ShadowSoftness = originalSettings.ShadowSoftness
        pcall(function() Lighting.Technology = originalSettings.Technology end)
        
        Terrain.WaterWaveSize = originalSettings.WaterWaveSize
        Terrain.WaterWaveSpeed = originalSettings.WaterWaveSpeed
        Terrain.WaterReflectance = originalSettings.WaterReflectance
        Terrain.WaterTransparency = originalSettings.WaterTransparency
        
        if Lighting:FindFirstChild("UltraBloom") then Lighting.UltraBloom:Destroy() end
        if Lighting:FindFirstChild("UltraCC") then Lighting.UltraCC:Destroy() end
        if Lighting:FindFirstChild("UltraSunRays") then Lighting.UltraSunRays:Destroy() end
        
        originalSettings = nil
    end
})



local ProfileGroup = Tabs.Main:AddLeftGroupbox(" Profile")
ProfileGroup:AddLabel(" User: " .. LocalPlayer.Name)
ProfileGroup:AddLabel(" Display Name: " .. LocalPlayer.DisplayName)
ProfileGroup:AddLabel(" User ID: " .. LocalPlayer.UserId)



notify("sigma", " Script loaded successfully! ", 3)
