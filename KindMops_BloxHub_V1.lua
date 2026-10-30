-- KindMops Blox Hub V1 | Auto attack + level/sea auto quest
-- Uses game-provided quest/NPC data; unknown schemas are reported in the menu.
-- Auto attack uses normal Tool activation; skill-only weapons need manual skills.
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
    Title = 'KINDMOPS | V1.2 QUEST FIX',
    UpdateSeconds = 0.25,
    MoveSpeed = 190,
    MoveHeight = 14,
    TargetRange = 1200,
    AttackSeconds = 0.4,
    AttackRange = 12,
    QuestRetrySeconds = 5,
    Accent = Color3.fromRGB(143, 163, 65),
    Background = Color3.fromRGB(20, 23, 20),
    Panel = Color3.fromRGB(35, 40, 34),
    Text = Color3.fromRGB(240, 243, 232),
    PlaceIds = {
        [2753915549]='Sea 1', [85211729168715]='Sea 1',
        [113741252407134]='Sea 1', [114279672983750]='Sea 1',
        [4442272183]='Sea 2', [79091703265657]='Sea 2',
        [7449423635]='Sea 3', [100117331123089]='Sea 3'
    }
}
local Flags = { ESP=false, EnemyESP=false, AutoEquip=false, AutoStats=false, AutoApproach=false, AutoAttack=false, AutoQuest=false }
local alive, minimized = true, false
local connections, highlights, tween = {}, {}, nil
local selectedTool, selectedStat = nil, 'Melee'
local statRequestInFlight = false
local toggleButtons = {}
local questChoice, questReady = nil, false
local questMessage = 'Quest: OFF'
local attackMessage = 'Attack: OFF'
local pendingQuest, ownedQuestSignature = nil, nil
local restartQuestRequested, restartWaitingAt = false, nil
local lastQuestAttempt = -math.huge
local automationGeneration = 0
local lastActivatedTool = nil
local function stopMovement()
 if tween then tween:Cancel(); tween=nil end
end
local function releaseAttack()
 local tool=lastActivatedTool; lastActivatedTool=nil
 if tool then pcall(function() tool:Deactivate() end) end
end
local function setFlag(key,value)
 Flags[key]=value
 local entry=toggleButtons[key]
 if entry then entry.Button.Text=entry.Label..(value and ' : ON' or ' : OFF') end
 if key=='AutoQuest' then
  automationGeneration=automationGeneration+1
  questChoice=nil; questReady=false
  pendingQuest=nil; ownedQuestSignature=nil; restartQuestRequested=false; restartWaitingAt=nil
  questMessage=value and 'Quest: reading game data...' or 'Quest: OFF'
  stopMovement(); releaseAttack()
 elseif key=='AutoApproach' and not value then stopMovement()
 elseif key=='AutoAttack' and not value then releaseAttack() end
end
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
  setFlag(key,not Flags[key])
  if key=='ESP' or key=='EnemyESP' then if not Flags[key] then for _,h in pairs(highlights) do if h then h:Destroy() end end; table.clear(highlights) end end
  -- Movement and attack cleanup is handled by setFlag.
 end)
 toggleButtons[key]={Button=b,Label=text}
 return b
end
local function getRoot()
 local c=LP.Character
 return c and c:FindFirstChild('HumanoidRootPart')
end
local function cleanEnemyName(name)
 return (name:gsub('%s*%[Lv%.?%s*%d+%]', ''):gsub('%s*%[Boss%]', ''):gsub('^%s+', ''):gsub('%s+$', ''))
end
local function nearestEnemy()
 local folder=workspace:FindFirstChild('Enemies'); local root=getRoot()
 if not folder or not root then return nil end
 if Flags.AutoQuest and (not questReady or not questChoice) then return nil end
 local best,dist=nil,(Flags.AutoQuest and math.huge or CFG.TargetRange)
 for _,mob in ipairs(folder:GetChildren()) do
  local hum=mob:FindFirstChildOfClass('Humanoid'); local part=mob:FindFirstChild('HumanoidRootPart')
  if hum and part and hum.Health>0 and (not Flags.AutoQuest or cleanEnemyName(mob.Name)==questChoice.Enemy) then
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
addToggle('MAIN','Auto attack (equipped weapon)','AutoAttack')
addToggle('MAIN','Auto quest (level + sea)','AutoQuest')
addButton('MAIN','Auto farm: start / stop',function()
 local enabled=not (Flags.AutoQuest and Flags.AutoAttack and Flags.AutoApproach and Flags.AutoEquip)
 setFlag('AutoEquip',enabled); setFlag('AutoAttack',enabled)
 setFlag('AutoApproach',enabled); setFlag('AutoQuest',enabled)
end)
local questStatus=addButton('MAIN','Quest: OFF',function(b) b.Text=questMessage end)
questStatus.Size=UDim2.new(1,-4,0,54); questStatus.TextWrapped=true
local attackStatus=addButton('MAIN','Attack: OFF',function(b) b.Text=attackMessage end)
attackStatus.Size=UDim2.new(1,-4,0,54); attackStatus.TextWrapped=true
addButton('MAIN','Restart level quest (clears current progress)',function()
 if not Flags.AutoQuest then setFlag('AutoQuest',true) end
 restartQuestRequested=true
 questReady=false; stopMovement(); releaseAttack()
 questMessage='Quest: restarting current level quest...'
end)
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
local approachToggle=addToggle('MOVEMENT','Approach nearest enemy','AutoApproach')
addButton('MOVEMENT','Stop moving',function()
 setFlag('AutoQuest',false)
 setFlag('AutoApproach',false)
 setFlag('AutoAttack',false)
end)
addButton('CONFIG','Print configuration',function()
 for k,v in pairs(Flags) do print('[KindMops]',k,v) end
 print('[KindMops] Weapon:',selectedTool,'Stat:',selectedStat)
end)
addButton('CONFIG','Reset toggles',function()
 for k in pairs(Flags) do setFlag(k,false) end
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
-- Quest data stays local to the game. No downloaded code or static quest map.
local questCatalog, catalogAt = nil, -math.huge
local blockedQuests={BartiloQuest=true, CitizenQuest=true}
local seaBounds={['Sea 1']={0,700}, ['Sea 2']={700,1500}, ['Sea 3']={1500,math.huge}}
local function asPosition(value)
 if typeof(value)=='Vector3' then return value end
 if typeof(value)=='CFrame' then return value.Position end
end
local function questNPC(npcs,id,level)
 local fallback, matches=nil,0
 for _,npc in pairs(npcs) do
  if type(npc)=='table' then
   local position=asPosition(npc.Position)
   if position then
    for _,value in pairs(npc) do
     if value==id then return position end
    end
    if type(npc.Levels)=='table' then
     for _,required in pairs(npc.Levels) do
      if tonumber(required)==level then fallback=position; matches=matches+1; break end
     end
    end
   end
  end
 end
 -- Never guess between NPCs sharing a requirement.
 if matches==1 then return fallback end
end
local function loadQuestCatalog()
 if questCatalog then return questCatalog end
 if os.clock()-catalogAt<5 then return nil end
 catalogAt=os.clock()
 local bounds=seaBounds[CFG.PlaceIds[game.PlaceId]]
 if not bounds then questMessage='Quest: unsupported Sea / PlaceId'; return nil end
 local questsModule=ReplicatedStorage:FindFirstChild('Quests')
 local guideModule=ReplicatedStorage:FindFirstChild('GuideModule')
 if not questsModule or not guideModule then questMessage='Quest: game modules unavailable'; return nil end
 local okQ,quests=pcall(require,questsModule)
 local okG,guide=pcall(require,guideModule)
 if not alive or not Flags.AutoQuest then return nil end
 local npcs=okG and type(guide)=='table' and type(guide.Data)=='table' and guide.Data.NPCList
 if not okQ or type(quests)~='table' or type(npcs)~='table' then
  questMessage='Quest: cannot read quest/NPC data'; return nil
 end
 local list={}
 for id,missions in pairs(quests) do
  if type(id)=='string' and type(missions)=='table' and not blockedQuests[id] then
   for index,mission in pairs(missions) do
    if type(index)=='number' and type(mission)=='table' then
     local level=tonumber(mission.LevelReq)
     local enemy,count,taskCount=nil,nil,0
     if type(mission.Task)=='table' then
      for name,amount in pairs(mission.Task) do
       taskCount=taskCount+1; enemy=name; count=tonumber(amount)
      end
     end
     -- Repeatable single-enemy missions only; avoid bosses and story objectives.
     if level and level>=bounds[1] and level<bounds[2] and taskCount==1
       and type(enemy)=='string' and count and count>1 then
      local position=questNPC(npcs,id,level)
      if position then
       table.insert(list,{Id=id,Index=index,Level=level,Enemy=cleanEnemyName(enemy),Position=position})
      end
     end
    end
   end
  end
 end
 table.sort(list,function(a,b)
  if a.Level~=b.Level then return a.Level>b.Level end
  if a.Id~=b.Id then return a.Id<b.Id end
  return a.Index<b.Index
 end)
 if #list==0 then questMessage='Quest: no supported missions in this Sea'; return nil end
 questCatalog=list
 return list
end
local function playerLevel()
 local data=LP:FindFirstChild('Data'); local level=data and data:FindFirstChild('Level')
 return level and tonumber(level.Value)
end
local function readQuestPanel()
 local playerGui=LP:FindFirstChild('PlayerGui')
 local mainGui=playerGui and playerGui:FindFirstChild('Main')
 local panelGui=mainGui and mainGui:FindFirstChild('Quest')
 if not panelGui or not panelGui:IsA('GuiObject') then return nil,'' end
 if not panelGui.Visible then return false,'' end
 local container=panelGui:FindFirstChild('Container')
 local heading=container and container:FindFirstChild('QuestTitle')
 local title=heading and heading:FindFirstChild('Title')
 if title and (title:IsA('TextLabel') or title:IsA('TextButton')) then return true,title.Text end
 return true,''
end
local function titleMatches(title,quest)
 return title:lower():find(quest.Enemy:lower(),1,true)~=nil
end
local function questSignature(title)
 -- The objective text stays the same as translated progress counters change.
 return (title:gsub('%b<>',''):gsub('%d+',''):gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$',''))
end
local function ownedQuestMatches(title)
 if not questChoice or ownedQuestSignature==nil then return false end
 local signature=questSignature(title)
 if signature=='' then return false end
 if ownedQuestSignature=='' then ownedQuestSignature=signature end
 return signature==ownedQuestSignature
end
local function adoptPendingQuest(title,generation)
 if pendingQuest and pendingQuest.Generation==generation and os.clock()-pendingQuest.At<=15 then
  questChoice=pendingQuest.Choice
  ownedQuestSignature=questSignature(title)
  pendingQuest=nil
  return true
 end
 return false
end
local function chooseQuest(list,level,title)
 local team=LP.Team and LP.Team.Name or ''
 for _,entry in ipairs(list) do
  local teamAllowed=(entry.Id~='MarineQuest' or team=='Marines')
     and (entry.Id~='BanditQuest1' or team~='Marines')
  if entry.Level<=level and teamAllowed and (not title or titleMatches(title,entry)) then return entry end
 end
end
local function livingRoot()
 local c=LP.Character; local h=c and c:FindFirstChildOfClass('Humanoid')
 if h and h.Health>0 then return getRoot() end
end
local function moveTo(position,stopDistance,lookAt)
 local root=livingRoot()
 if not root then stopMovement(); return false end
 local distance=(root.Position-position).Magnitude
 if distance<=stopDistance then
  stopMovement()
  if lookAt and (root.Position-lookAt).Magnitude>.1 then root.CFrame=CFrame.lookAt(root.Position,lookAt) end
  return true
 end
 stopMovement()
 local goal=CFrame.new(position)
 if lookAt and (position-lookAt).Magnitude>.1 then goal=CFrame.lookAt(position,lookAt) end
 tween=TweenService:Create(root,TweenInfo.new(math.max(.1,distance/CFG.MoveSpeed),Enum.EasingStyle.Linear),{CFrame=goal})
 tween:Play()
 return false
end
local function findSpawn(enemy)
 local root=getRoot(); if not root then return nil end
 local origin=workspace:FindFirstChild('_WorldOrigin')
 local folders={}
 local spawns=origin and origin:FindFirstChild('EnemySpawns')
 if spawns then table.insert(folders,spawns) end
 local replicated=ReplicatedStorage:FindFirstChild('FortBuilderReplicatedSpawnPositionsFolder')
 if replicated then table.insert(folders,replicated) end
 local best,bestDistance=nil,math.huge
 for _,folder in ipairs(folders) do
  for _,point in ipairs(folder:GetDescendants()) do
   if cleanEnemyName(point.Name)==enemy then
    local position=nil
    if point:IsA('BasePart') then position=point.Position
    elseif point:IsA('CFrameValue') or point:IsA('Vector3Value') then position=asPosition(point.Value)
    elseif point:IsA('Model') then position=point:GetPivot().Position end
    if position then
     local distance=(root.Position-position).Magnitude
     if distance<bestDistance then best=position; bestDistance=distance end
    end
   end
  end
 end
 return best
end
local function approach()
 local root=livingRoot(); local enemy=nearestEnemy()
 local target=enemy and enemy:FindFirstChild('HumanoidRootPart')
 if not root or not target then stopMovement(); return false end
 local height=Flags.AutoAttack and 3 or CFG.MoveHeight
 moveTo(target.Position+Vector3.new(0,height,0),2,target.Position)
 return true
end
local function ensureWeapon()
 local c=LP.Character; if not c then return nil end
 if selectedTool then
  equipSelected()
  local chosen=c:FindFirstChild(selectedTool)
  return chosen and chosen:IsA('Tool') and chosen or nil
 end
 -- Only auto-select melee/swords. Do not activate arbitrary backpack tools.
 for _,tool in ipairs(c:GetChildren()) do
  if tool:IsA('Tool') and (tool.ToolTip=='Melee' or tool.ToolTip=='Sword') then return tool end
 end
 local bag=LP:FindFirstChild('Backpack'); local hum=c:FindFirstChildOfClass('Humanoid')
 if bag and hum then
  for _,tool in ipairs(bag:GetChildren()) do
   if tool:IsA('Tool') and (tool.ToolTip=='Melee' or tool.ToolTip=='Sword') then hum:EquipTool(tool); return tool end
  end
 end
end
local function attack()
 releaseAttack()
 if not alive or not Flags.AutoAttack then attackMessage='Attack: OFF'; return end
 if not livingRoot() then attackMessage='Attack: waiting for character'; return end
 if Flags.AutoQuest then
  local visible,title=readQuestPanel()
  if not visible or not questReady or not questChoice then
   attackMessage='Attack: waiting for quest / target'; return
  end
  if not ownedQuestMatches(title) and not titleMatches(title,questChoice) then
   attackMessage='Attack: quest not recognized; use Restart level quest'; return
  end
 end
 local enemy,distance=nearestEnemy()
 if not enemy then
  attackMessage='Attack: no loaded '..(questChoice and questChoice.Enemy or 'enemy'); return
 end
 if distance>CFG.AttackRange then
  attackMessage=string.format('Attack: %s is %.0f studs away%s',enemy.Name,distance,Flags.AutoApproach and '' or '; turn on Approach')
  return
 end
 local tool=ensureWeapon()
 if not tool then attackMessage='Attack: choose a melee weapon or sword'; return end
 if not tool.Enabled then attackMessage='Attack: weapon cooldown'; return end
 lastActivatedTool=tool
 tool:Activate()
 attackMessage='Attack: activating '..tool.Name..' on '..enemy.Name
end
local function updateQuest(generation)
 questReady=false
 if not livingRoot() then stopMovement(); questMessage='Quest: waiting for character'; return end
 local list=loadQuestCatalog()
 if not alive or not Flags.AutoQuest or generation~=automationGeneration then return end
 if not list then stopMovement(); return end
 local level=playerLevel()
 if not level then stopMovement(); questMessage='Quest: waiting for level'; return end
 local visible,title=readQuestPanel()
 if visible==nil then stopMovement(); questMessage='Quest: panel unavailable'; return end
 if restartQuestRequested then
  restartQuestRequested=false; questChoice=nil; pendingQuest=nil; ownedQuestSignature=nil
  stopMovement(); releaseAttack()
  if visible then
   local remotes=ReplicatedStorage:FindFirstChild('Remotes')
   local remote=remotes and remotes:FindFirstChild('CommF_')
   if not remote or not remote:IsA('RemoteFunction') then questMessage='Quest: restart remote unavailable'; return end
   restartWaitingAt=os.clock()
   local ok=pcall(function() remote:InvokeServer('AbandonQuest') end)
   if not alive or not Flags.AutoQuest or generation~=automationGeneration then return end
   if not ok then restartWaitingAt=nil; questMessage='Quest: restart failed; press Restart again' end
   return
  end
 end
 if restartWaitingAt then
  if not visible then restartWaitingAt=nil; lastQuestAttempt=-math.huge
  elseif os.clock()-restartWaitingAt<5 then questMessage='Quest: waiting for old quest to close'; return
  else restartWaitingAt=nil; questMessage='Quest: restart not confirmed; press Restart again'; return end
 end
 if visible then
  adoptPendingQuest(title,generation)
  if not ownedQuestMatches(title) and (not questChoice or not titleMatches(title,questChoice)) then
   ownedQuestSignature=nil
   questChoice=chooseQuest(list,level,title)
  end
  if not questChoice then
   stopMovement(); questMessage='Quest: cannot identify existing quest. Press Restart level quest.'; return
  end
  questReady=true
  questMessage=string.format('%s | Lv.%d | %s',CFG.PlaceIds[game.PlaceId],level,questChoice.Enemy)
  if Flags.AutoApproach then
   if not approach() then
    local spawnPosition=findSpawn(questChoice.Enemy)
    if spawnPosition then moveTo(spawnPosition+Vector3.new(0,3,0),5)
    else questMessage='Quest accepted: '..questChoice.Enemy..'; no enemy/spawn loaded. Move toward the enemy area.' end
   end
  end
  return
 end
 ownedQuestSignature=nil
 questChoice=chooseQuest(list,level)
 if not questChoice then stopMovement(); questMessage='Quest: no eligible mission at this level'; return end
 questMessage=string.format('Quest: %s (Lv.%d) - going to NPC',questChoice.Enemy,questChoice.Level)
 if not moveTo(questChoice.Position,4) then return end
 if os.clock()-lastQuestAttempt<CFG.QuestRetrySeconds then questMessage='Quest: waiting for acceptance'; return end
 local remotes=ReplicatedStorage:FindFirstChild('Remotes')
 local remote=remotes and remotes:FindFirstChild('CommF_')
 if not remote or not remote:IsA('RemoteFunction') then questMessage='Quest: server remote unavailable'; return end
 lastQuestAttempt=os.clock()
 local requestChoice=questChoice
 pendingQuest={Choice=requestChoice,Generation=generation,At=os.clock()}
 local ok=pcall(function() remote:InvokeServer('StartQuest',requestChoice.Id,requestChoice.Index) end)
 if not alive or not Flags.AutoQuest or generation~=automationGeneration then return end
 if not ok then pendingQuest=nil end
 questMessage=ok and 'Quest: waiting for acceptance' or 'Quest: request failed; retrying'
end
-- A single worker owns quest requests. A slow server cannot enqueue duplicates.
local questWorkerBusy=false
local questElapsed,attackElapsed=0,0
bind(RunService.Heartbeat,function(dt)
 if not alive then return end
 questElapsed=questElapsed+dt; attackElapsed=attackElapsed+dt
 if attackElapsed>=CFG.AttackSeconds then
  attackElapsed=0
  local ok,err=pcall(attack)
  if not ok then releaseAttack(); attackMessage='Attack error: '..tostring(err) end
 end
 if questElapsed>=.5 then
  questElapsed=0
  if Flags.AutoQuest and not questWorkerBusy then
   questWorkerBusy=true
   local generation=automationGeneration
   task.spawn(function()
    local ok,err=pcall(function()
     if alive and Flags.AutoQuest and generation==automationGeneration then updateQuest(generation) end
    end)
    questWorkerBusy=false
    if not ok and alive and Flags.AutoQuest and generation==automationGeneration then
     questReady=false; stopMovement(); questMessage='Quest error: '..tostring(err)
    end
   end)
  end
 end
end)

local last,statLast,moveLast=0,0,0
bind(RunService.Heartbeat,function(dt)
 if not alive then return end
 last=last+dt; statLast=statLast+dt; moveLast=moveLast+dt
 if last>=CFG.UpdateSeconds then
  last=0
  updateHighlights()
  local r=getRoot(); coords.Text=r and string.format('Position: %.0f, %.0f, %.0f',r.Position.X,r.Position.Y,r.Position.Z) or 'Position: unavailable'
  local mob,d=nearestEnemy(); status.Text=mob and string.format('Nearest enemy: %s (%.0f)',mob.Name,d) or 'Nearest enemy: none'
  questStatus.Text=questMessage
  attackStatus.Text=attackMessage
  if Flags.AutoEquip then pcall(equipSelected) end
  footer.Text=(CFG.PlaceIds[game.PlaceId] or 'Unknown sea')..' | '..(LP.Name or '')..' | F4: menu'
 end
 if statLast>=1.5 then
  statLast=0
  if Flags.AutoStats and not statRequestInFlight then
   local data=LP:FindFirstChild('Data'); local pts=data and data:FindFirstChild('Points')
   local remotes=ReplicatedStorage:FindFirstChild('Remotes'); local rf=remotes and remotes:FindFirstChild('CommF_')
   if pts and pts.Value>0 and rf and rf:IsA('RemoteFunction') then
    statRequestInFlight=true
    pcall(function() rf:InvokeServer('AddPoint',selectedStat,1) end)
    statRequestInFlight=false
    -- A pending server response can arrive after the hub has been closed.
    if not alive then return end
   end
  end
 end
 if moveLast>=.8 then
  moveLast=0
  if Flags.AutoApproach and not Flags.AutoQuest then pcall(approach) end
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
 automationGeneration=automationGeneration+1
 stopMovement(); releaseAttack()
 for _,conn in ipairs(connections) do conn:Disconnect() end
 for _,h in pairs(highlights) do if h then h:Destroy() end end
 gui:Destroy()
 if env.KindMopsHubStop==stop then env.KindMopsHubStop=nil end
end
env.KindMopsHubStop=stop
bind(closeBtn.MouseButton1Click,stop)
showTab('MAIN')
print('[KindMops V1.2 Quest Fix] loaded: F4 toggle; close to unload')
