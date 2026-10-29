-- KindMops Blox Hub V1 | original implementation
-- Executor Luau | no HTTP loaders, webhooks, telemetry, or HWID collection
local Players = game:GetService('Players')
local TweenService = game:GetService('TweenService')
local RunService = game:GetService('RunService')
local UIS = game:GetService('UserInputService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local LP = Players.LocalPlayer
local env = (type(getgenv) == 'function' and getgenv()) or _G
if type(env.KindMopsHubStop) == 'function' then pcall(env.KindMopsHubStop) end
local CFG = {
    Title = 'KINDMOPS | BLOX HUB V1',
    UpdateSeconds = 0.25,
    MoveSpeed = 190,
    MoveHeight = 14,
    TargetRange = 1200,
    Accent = Color3.fromRGB(143, 163, 65),
    Background = Color3.fromRGB(20, 23, 20),
    Panel = Color3.fromRGB(35, 40, 34),
    Text = Color3.fromRGB(240, 243, 232),
    PlaceIds = { [2753915549]='Sea 1', [4442272183]='Sea 2', [7449423635]='Sea 3' }
}
local Flags = { ESP=false, EnemyESP=false, AutoEquip=false, AutoStats=false, AutoApproach=false }
local alive, minimized = true, false
local connections, highlights, tween = {}, {}, nil
local selectedTool, selectedStat = nil, 'Melee'
local guiParent = LP:WaitForChild('PlayerGui')
if type(gethui)=='function' then local ok, result=pcall(gethui); if ok and typeof(result)=='Instance' then guiParent=result end end
local gui = Instance.new('ScreenGui')
gui.Name='KindMops_BloxHub'; gui.ResetOnSpawn=false; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=guiParent
local function make(class, props, parent)
    local obj=Instance.new(class)
    for k,v in pairs(props or {}) do obj[k]=v end
    obj.Parent=parent
    return obj
end
local function corner(obj, r) make('UICorner',{CornerRadius=UDim.new(0,r or 8)},obj) end
local function bind(signal, callback) local c=signal:Connect(callback); table.insert(connections,c); return c end
local main=make('Frame',{Size=UDim2.fromOffset(430,350),Position=UDim2.new(.5,-215,.5,-175),BackgroundColor3=CFG.Background,BorderSizePixel=0,Active=true},gui)
corner(main,12)
make('UIStroke',{Color=CFG.Accent,Transparency=.3,Thickness=1.5},main)
local header=make('Frame',{Size=UDim2.new(1,0,0,46),BackgroundColor3=CFG.Panel,BorderSizePixel=0},main); corner(header,12)
make('TextLabel',{Size=UDim2.new(1,-110,1,0),Position=UDim2.fromOffset(14,0),BackgroundTransparency=1,Text=CFG.Title,TextColor3=CFG.Accent,TextSize=15,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},header)
local function headerButton(label,x)
 local b=make('TextButton',{Size=UDim2.fromOffset(30,28),Position=UDim2.new(1,x,0,9),Text=label,Font=Enum.Font.GothamBold,TextColor3=CFG.Text,BackgroundColor3=CFG.Background,TextSize=15},header); corner(b,6); return b
end
local minBtn=headerButton('−',-72)
local closeBtn=headerButton('×',-36)
local tabs=make('Frame',{Position=UDim2.fromOffset(10,55),Size=UDim2.new(1,-20,0,32),BackgroundTransparency=1},main)
make('UIListLayout',{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,7)},tabs)
local panel=make('ScrollingFrame',{Position=UDim2.fromOffset(10,95),Size=UDim2.new(1,-20,1,-125),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.fromOffset(0,0)},main)
local footer=make('TextLabel',{Position=UDim2.new(0,10,1,-23),Size=UDim2.new(1,-20,0,17),BackgroundTransparency=1,TextColor3=Color3.fromRGB(170,180,162),TextSize=11,Text='',TextXAlignment=Enum.TextXAlignment.Left},main)
local pages, tabButtons={},{}
for _,name in ipairs({'MAIN','VISUALS','MOVEMENT','CONFIG'}) do
 local b=make('TextButton',{Size=UDim2.fromOffset(95,32),Text=name,BackgroundColor3=CFG.Panel,TextColor3=CFG.Text,TextSize=12,Font=Enum.Font.GothamBold},tabs); corner(b,7); tabButtons[name]=b
 local page=make('Frame',{Name=name,Size=UDim2.new(1,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Visible=false},panel)
 make('UIListLayout',{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder},page)
 pages[name]=page
end
local function showTab(name)
 for n,p in pairs(pages) do p.Visible=n==name; tabButtons[n].BackgroundColor3=n==name and CFG.Accent or CFG.Panel; tabButtons[n].TextColor3=n==name and CFG.Background or CFG.Text end
 panel.CanvasPosition=Vector2.zero
end
for name,b in pairs(tabButtons) do bind(b.MouseButton1Click,function() showTab(name) end) end
local function addButton(page,text,callback)
 local b=make('TextButton',{Size=UDim2.new(1,-4,0,36),BackgroundColor3=CFG.Panel,TextColor3=CFG.Text,Text=text,TextSize=13,Font=Enum.Font.GothamMedium},pages[page]); corner(b,7)
 bind(b.MouseButton1Click,function() if alive then callback(b) end end)
 return b
end
local function addToggle(page,text,key)
 local b=addButton(page,text..' : OFF',function(btn)
  Flags[key]=not Flags[key]; btn.Text=text..(Flags[key] and ' : ON' or ' : OFF')
  if key=='ESP' or key=='EnemyESP' then if not Flags[key] then for _,h in pairs(highlights) do if h then h:Destroy() end end; table.clear(highlights) end end
  if key=='AutoApproach' and not Flags[key] and tween then tween:Cancel(); tween=nil end
 end)
 return b
end
local function getRoot()
 local c=LP.Character
 return c and c:FindFirstChild('HumanoidRootPart')
end
local function nearestEnemy()
 local folder=workspace:FindFirstChild('Enemies'); local root=getRoot()
 if not folder or not root then return nil end
 local best,dist=nil,CFG.TargetRange
 for _,mob in ipairs(folder:GetChildren()) do
  local hum=mob:FindFirstChildOfClass('Humanoid'); local part=mob:FindFirstChild('HumanoidRootPart')
  if hum and part and hum.Health>0 then
   local d=(part.Position-root.Position).Magnitude
   if d<dist then best=mob; dist=d end
  end
 end
 return best,dist
end
local function equipSelected()
 if not selectedTool then return end
 local c=LP.Character; local hum=c and c:FindFirstChildOfClass('Humanoid')
 local bag=LP:FindFirstChild('Backpack'); local tool=bag and bag:FindFirstChild(selectedTool)
 if hum and tool and tool:IsA('Tool') then hum:EquipTool(tool) end
end
local status=addButton('MAIN','Nearest enemy: scanning...',function(b)
 local mob,dist=nearestEnemy(); b.Text=mob and string.format('%s | %.0f studs',mob.Name,dist) or 'No nearby enemy'
end)
addToggle('MAIN','Auto equip selected weapon','AutoEquip')
addButton('MAIN','Choose weapon: tap to cycle',function(b)
 local options={}; local bag=LP:FindFirstChild('Backpack')
 for _,folder in ipairs({bag,LP.Character}) do
  if folder then for _,obj in ipairs(folder:GetChildren()) do if obj:IsA('Tool') and not table.find(options,obj.Name) then table.insert(options,obj.Name) end end end
 end
 table.sort(options)
 if #options==0 then b.Text='No weapons in Backpack/Character'; return end
 local index=table.find(options,selectedTool) or 0
 selectedTool=options[(index % #options)+1]
 b.Text='Weapon: '..selectedTool
 equipSelected()
end)
addToggle('MAIN','Auto spend available stat points','AutoStats')
addButton('MAIN','Stat type: Melee',function(b)
 local stats={'Melee','Defense','Sword','Gun','Demon Fruit'}
 selectedStat=stats[((table.find(stats,selectedStat) or 0)%#stats)+1]
 b.Text='Stat type: '..selectedStat
end)
addToggle('VISUALS','Player highlight','ESP')
addToggle('VISUALS','Enemy highlight','EnemyESP')
local coords=addButton('VISUALS','Position: loading...',function(b)
 local r=getRoot(); b.Text=r and tostring(r.Position) or 'Character unavailable'
end)
addToggle('MOVEMENT','Approach nearest enemy','AutoApproach')
addButton('MOVEMENT','Stop moving',function()
 Flags.AutoApproach=false; if tween then tween:Cancel(); tween=nil end
end)
addButton('CONFIG','Print configuration',function()
 for k,v in pairs(Flags) do print('[KindMops]',k,v) end
 print('[KindMops] Weapon:',selectedTool,'Stat:',selectedStat)
end)
addButton('CONFIG','Reset toggles',function()
 for k in pairs(Flags) do Flags[k]=false end
 for _,h in pairs(highlights) do if h then h:Destroy() end end; table.clear(highlights)
 if tween then tween:Cancel(); tween=nil end
 for _,b in ipairs(pages.MAIN:GetChildren()) do if b:IsA('TextButton') and b.Text:find(' : ON',1,true) then b.Text=b.Text:gsub(' : ON',' : OFF') end end
 for _,p in pairs(pages) do for _,b in ipairs(p:GetChildren()) do if b:IsA('TextButton') then b.Text=b.Text:gsub(' : ON',' : OFF') end end end
end)
local function updateHighlights()
 local seen={}
 local function scan(models,on,skipLocal)
  if not models or not on then return end
  for _,model in ipairs(models) do
   if model:IsA('Model') and (not skipLocal or model~=LP.Character) then
    local h=model:FindFirstChildOfClass('Humanoid')
    if h and h.Health>0 then
     seen[model]=true
     if not highlights[model] then
      local hi=make('Highlight',{Adornee=model,FillTransparency=.8,OutlineTransparency=0,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,FillColor=CFG.Accent,OutlineColor=CFG.Accent},gui)
      highlights[model]=hi
     end
    end
   end
  end
 end
 if Flags.ESP then for _,p in ipairs(Players:GetPlayers()) do if p~=LP and p.Character then scan({p.Character},true,false) end end end
 local enemies=workspace:FindFirstChild('Enemies')
 scan(enemies and enemies:GetChildren(),Flags.EnemyESP,true)
 for model,hi in pairs(highlights) do if not seen[model] or not model.Parent then hi:Destroy(); highlights[model]=nil end end
end
local function approach()
 local r=getRoot(); local mob=nearestEnemy(); local target=mob and mob:FindFirstChild('HumanoidRootPart')
 if not r or not target then return end
 local destination=target.Position+Vector3.new(0,CFG.MoveHeight,0)
 local d=(r.Position-destination).Magnitude
 if d<8 then return end
 if tween then tween:Cancel() end
 tween=TweenService:Create(r,TweenInfo.new(math.max(.1,d/CFG.MoveSpeed),Enum.EasingStyle.Linear),{CFrame=CFrame.new(destination)})
 tween:Play()
end
local last,statLast,moveLast=0,0,0
bind(RunService.Heartbeat,function(dt)
 if not alive then return end
 last=last+dt; statLast=statLast+dt; moveLast=moveLast+dt
 if last>=CFG.UpdateSeconds then
  last=0
  updateHighlights()
  local r=getRoot(); coords.Text=r and string.format('Position: %.0f, %.0f, %.0f',r.Position.X,r.Position.Y,r.Position.Z) or 'Position: unavailable'
  local mob,d=nearestEnemy(); status.Text=mob and string.format('Nearest enemy: %s (%.0f)',mob.Name,d) or 'Nearest enemy: none'
  if Flags.AutoEquip then pcall(equipSelected) end
  footer.Text=(CFG.PlaceIds[game.PlaceId] or 'Unknown sea')..' | '..(LP.Name or '')..' | F4: menu'
 end
 if statLast>=1.5 then
  statLast=0
  if Flags.AutoStats then
   local data=LP:FindFirstChild('Data'); local pts=data and data:FindFirstChild('Points')
   local remotes=ReplicatedStorage:FindFirstChild('Remotes'); local rf=remotes and remotes:FindFirstChild('CommF_')
   if pts and pts.Value>0 and rf and rf:IsA('RemoteFunction') then
    pcall(function() rf:InvokeServer('AddPoint',selectedStat,1) end)
   end
  end
 end
 if moveLast>=.8 then
  moveLast=0
  if Flags.AutoApproach then pcall(approach) end
 end
end)
local dragging, dragStart, frameStart=false,nil,nil
bind(header.InputBegan,function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
  dragging=true; dragStart=input.Position; frameStart=main.Position
 end
end)
bind(UIS.InputChanged,function(input)
 if dragging and dragStart and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
  local d=input.Position-dragStart
  main.Position=UDim2.new(frameStart.X.Scale,frameStart.X.Offset+d.X,frameStart.Y.Scale,frameStart.Y.Offset+d.Y)
 end
end)
bind(UIS.InputEnded,function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)
bind(UIS.InputBegan,function(input,processed)
 if not processed and input.KeyCode==Enum.KeyCode.F4 then main.Visible=not main.Visible end
end)
bind(minBtn.MouseButton1Click,function()
 minimized=not minimized
 main.Size=minimized and UDim2.fromOffset(430,46) or UDim2.fromOffset(430,350)
 tabs.Visible=not minimized; panel.Visible=not minimized; footer.Visible=not minimized
 minBtn.Text=minimized and '+' or '−'
end)
local function stop()
 if not alive then return end
 alive=false
 if tween then tween:Cancel() end
 for _,conn in ipairs(connections) do conn:Disconnect() end
 for _,h in pairs(highlights) do if h then h:Destroy() end end
 gui:Destroy()
 if env.KindMopsHubStop==stop then env.KindMopsHubStop=nil end
end
env.KindMopsHubStop=stop
bind(closeBtn.MouseButton1Click,stop)
showTab('MAIN')
print('[KindMops Blox Hub V1] loaded: F4 toggle; close to unload')
