__VERSION = 1.00

upd = nil
script_name('pie binder')
script_author('vespan')
script_version_number(__VERSION)

libs = {
    ['sampev'] = 'samp.events',
    ['imgui'] = 'imgui',
    ['pie'] = 'imgui_piemenu(for pie binder)',
    ['requests'] = 'requests',
}
for k,v in pairs(libs) do
    if (select(1,pcall(require,v))) == false then
        local f = getWorkingDirectory()..'/__LIBS DOWNLOANDER-pie binder.lua'
        if not doesFileExist(f) then
            downloadUrlToFile('https://raw.githubusercontent.com/v3sp4n/pie-binder/main/downloander.lua',f,function(_,s)
                if s == 58 then
                    for k,v in ipairs(script.list()) do
                        if v.path ~= f then print(v.filename) v:unload() end
                    end
                    script.load(f)
                end
            end)
        end
    else
        _G[k] = require(v)
    end
end 

require 'moonloader'
encoding = require("encoding"); encoding.default = 'CP1251'; u8 = encoding.UTF8  
json = {
    defPath = getWorkingDirectory()..'/config/',
    save = function(t,path) 
        if not path:find('[\\/]') then;  path = json.defPath..path end
        t = (t == nil and {} or (type(t) == 'table' and t or {}))
        local f = io.open(path,'w');    f:write(encodeJson(t) or {});   f:close()
    end,
    load = function(t,path) 
        if not path:find('[\\/]') then;  path = json.defPath..path end
        if not doesFileExist(path) then;    json.save(t,path);  end
        local f = io.open(path,'r+');   local T = decodeJson(f:read('*a')); f:close()
        for def_k, def_v in next, t do;  if T[def_k] == nil then;    T[def_k] = def_v;  json.save(T,path); end end
        return T
    end
}
j = json.load({
	binds = {},
    cmd = {
        target = 'pbst',
        menu = 'pb',
    },
    hk = {
        target = '[]',
    },
    nearPedCarColor = {0.30,0.30,0.30,0.20},


},'pie binder.json')
function s() json.save(j,'pie binder.json') end
window = imgui.ImBool(false)
pie.window = imgui.ImBool(false)

pie.bind = ''
activePieMenu = 0
clockKeyDown = 0
activeMenu = 'binds'

target = {
    select = false,
    marker = nil,
    id = -1,
}

font = renderCreateFont('Arial',10,0x1+0x8)
function main()
    while not isSampAvailable() do wait(0) end
    while not sampIsLocalPlayerSpawned() do wait(0) end

    registerCmds()

    registerHK()

    local res = requests.get('https://raw.githubusercontent.com/v3sp4n/pie-binder/main/updating.lua')
    if res.status_code == 200 then
        local f,err = load('return '..res.text)
        if err == nil and type(f()) == 'table' then
            local t,u = f(),0
            for k,v in pairs(t) do
                if k > thisScript().version_num then
                    u = k
                end
            end
            if u ~= 0 then
                upd = {
                    version = u,
                    log = t[u],
                }
                sampAddChatMessage('{00830C}avaliable update!{cccccc}/'..j.cmd.menu..'-other')
            end
        else
            sampAddChatMessage('{FAD100}error getting an update!{cccccc}#2')
            print(err)
        end
    else
        sampAddChatMessage('{FAD100}error getting an update!{cccccc}#1')
        print(res.text,res.status_code)
    end

    while true do wait(0)
        imgui.Process = window.v or pie.window.v
        tags['myid'] = select(2,sampGetPlayerIdByCharHandle(PLAYER_PED))
        MYPOS = {getCharCoordinates(PLAYER_PED)}
        sw,sh = getScreenResolution()

        if os.clock()-clockKeyDown > 0.1 then
            clockKeyDown = 0xffff
            pie.window.v = false
        end

        local res,but,list,input = sampHasDialogRespond(10)
        if res and but == 1 then
            if #input > 0 then
                local origBind = pie.bind
                local res,err,act = gsubTextByRegulars(origBind,input)
                local bind = workTags(act,true)
                if res and err == nil then
                    send(bind)
                else
                    sampShowDialog(10,'pie binder send param','{C5A209}'..err,'send','cancel',1)
                end
            else
                sampShowDialog(10,'pie binder send param','','send','cancel',1)
            end
        end

        if target.id ~= -1 then
            local res,h = sampGetCharHandleBySampPlayerId(target.id)
            if res then
                local x,y,z = getCharCoordinates(h)
                removeUser3dMarker(target.marker)
                target.marker = createUser3dMarker(x, y, z + 3, 4)
            else
                removeUser3dMarker(target.marker)
                target.marker = nil
            end
            if not sampIsPlayerConnected(target.id) then
                sampAddChatMessage(('{AB000C} %s target disconnected'):format(target.id))
                target.id = -1
                removeUser3dMarker(target.marker)
                target.marker = nil
            end
        end
        tags['target'] = target.id

        local color = ('0x%02x%02x%02x%02x'):format(j.nearPedCarColor[4]*255,j.nearPedCarColor[1]*255,j.nearPedCarColor[2]*255,j.nearPedCarColor[3]*255)
        if getNearPedOnScreen() ~= -1 then
            local r,handle = sampGetCharHandleBySampPlayerId(getNearPedOnScreen())
            local x,y,z = getCharCoordinates(handle)
            local _,x,y,z = convert3DCoordsToScreenEx(x,y,z)
            local text = 'near ped'
            renderFontDrawText(font,text,x-renderGetFontDrawTextLength(font,text)/2,y,color)
        end
        if getNearCarOnScreen() ~= -1 then
            local r,handle = sampGetCarHandleBySampVehicleId(getNearCarOnScreen())
            local x,y,z = getCarCoordinates(handle)
            local _,x,y,z = convert3DCoordsToScreenEx(x,y,z)
            local text = 'near car'
            renderFontDrawText(font,text,x-renderGetFontDrawTextLength(font,text)/2,y,color)
        end

        if target.select then
            local sx, sy = getCursorPos()
            if sx >= 0 and sy >= 0 and sx < sw and sy < sh then
                local posX, posY, posZ = convertScreenCoordsToWorld3D(sx, sy, 700.0) 
                local camX, camY, camZ = getActiveCameraCoordinates() 
                local result, colpoint = processLineOfSight(camX, camY, camZ, posX, posY, posZ, true, true, true, true, false, false, false)
                if isKeyJustPressed(VK_LBUTTON) or isKeyJustPressed(VK_RBUTTON) then
                    if colpoint ~= nil and (colpoint.entityType == 2 or colpoint.entityType == 3)  then
                        local id = -1
                        if colpoint.entityType == 2 then
                            local veh = getVehiclePointerHandle(colpoint.entity)
                            if isCarOnScreen(veh) then
                                for k,v in ipairs(getAllChars()) do
                                    if isCharInCar(v,veh) then
                                        id = select(2,sampGetPlayerIdByCharHandle(v))
                                    end
                                end
                            end
                        else
                            local ped = getCharPointerHandle(colpoint.entity)
                            if ped ~= playerPed then
                                id = select(2,sampGetPlayerIdByCharHandle(ped))
                            end
                        end
                        setTarget(id)
                        if target.id == -1 then setTarget(id) end
                    end
                    target.select = false
                    showCursor(false,false)
                end

            end
        end

    end
end


function onWindowMessage(msg, wparam, lparam) 
    if (window.v) and wparam == VK_ESCAPE then
        consumeWindowMessage(true,true)
        window.v = false
    end
end

function onScriptTerminate(s)
    if s == thisScript() then 
        removeUser3dMarker(target.marker)
    end
end

function imgui.OnDrawFrame()

	if pie.window.v then
		if j.binds[activePieMenu] ~= nil then
    		for k,v in ipairs(j.binds) do
    			if k == activePieMenu then
        			imgui.OpenPopup(tostring(k))
        			if pie.BeginPiePopup(tostring(k), 0,
                        {
                        button = imgui.ImVec4(v.color[1],v.color[2],v.color[3],(v.color[4]*255 >= 200 and 200/255 or v.color[4])),
                        buttonHovered = imgui.ImVec4(v.color[1],v.color[2],v.color[3],(v.color[4]+0.15)),
                    },j.binds[activePieMenu].diameter,j.binds[activePieMenu].radiusEmpty
                    ) then

						-- for kk,vv in ipairs(j.binds[k].binds) do
							binds(k,k+k,v)
						-- end
					end
    				pie.EndPiePopup()
				end
			end
		end
	end


    if window.v then
        imgui.SetNextWindowSize(imgui.ImVec2(300,300),1)
        imgui.SetNextWindowPos(imgui.ImVec2(sw/2,sh/2), imgui.Cond.FirstUseEver)
        imgui.Begin('pie binder by vespan',window,32+2)

        imgui.BeginChild('menu',imgui.ImVec2(-1,40),true)
        if imgui.Button('binds',imgui.ImVec2(130,-1)) then activeMenu = 'binds' end
        imgui.SameLine()
        if imgui.Button('other',imgui.ImVec2(130,-1)) then activeMenu = 'other' end
        imgui.EndChild()

        if activeMenu == 'binds' then

            if imgui.Button('add pie bind',imgui.ImVec2(-1,0)) then
            	table.insert(j.binds,{
            		name = 'test',
            		hk = '[]',
                    hkDown = false,
                    color = {0.19, 0.30, 0.63,0.5},
            		binds = {},
                    radiusEmpty = 15,
                    diameter = 2,
            	}) s()
                registerHK()
            end
            
            imgui.Spacing()
            imgui.Spacing()

            for k,v in pairs(j.binds) do
            	if imgui.Button(u8(v.name) .. '##' .. k,imgui.ImVec2(230,30)) then
            		imgui.OpenPopup(u8('edit pie menu '..v.name))
            	end
            	imgui.SameLine()
            	if imgui.Button('remove##'..k,imgui.ImVec2(50,30)) then
            		hotkey().unregister('hk pie menu '..k)
            		table.remove(j.binds,k) s()
            	end

            	if imgui.BeginPopupModal(u8('edit pie menu '..v.name),imgui.ImBool(true),64+32) then
                    local rename = imgui.ImBuffer(u8(v.name),256)
                    if imgui.InputText('rename current pie binder',rename) then v.name = u8:decode(rename.v) s() end
            		if hotkey().imgui('activation pie menu','key:','hk pie menu '..k) then
            			j.binds[k].hk = hotkey().getKeys('hk pie menu '..k) 
            			s()
                        registerHK()
            		end
                    imgui.SameLine()
                    local hkDown = imgui.ImBool(v.hkDown)
                    if imgui.Checkbox('pressKey',hkDown) then v.hkDown = hkDown.v s() registerHK() end
                    imgui.SameLine()
                    if imgui.Button('custom {tags}',imgui.ImVec2(-1,0)) then
                        imgui.OpenPopup('custom {tags}')
                    end
                    local color = imgui.ImFloat4(unpack(v.color))
                    if imgui.ColorEdit4('pie color',color,512) then v.color = {color.v[1],color.v[2],color.v[3],color.v[4]} s() end
                    local radiusEmpty = imgui.ImFloat(v.radiusEmpty)
                    if imgui.SliderFloat('radiusEmpty',radiusEmpty,5,100) then v.radiusEmpty = radiusEmpty.v s() end
                    local diameter = imgui.ImFloat(v.diameter)
                    if imgui.SliderFloat('diameter',diameter,1,6) then v.diameter = diameter.v s() end

                    if imgui.BeginPopup('custom {tags}') then

                        imgui.BeginChild('chield custom {tags}',imgui.ImVec2(300,200),false)
                        if imgui.Button('add',imgui.ImVec2(-1,0)) then table.insert(v.customTags,{tag='{rank}',replacement='Officer'}) s() end
                        imgui.Columns(2,'{tags}')
                        imgui.CenterColumnText('{tag} or tag')
                        imgui.NextColumn()
                        imgui.CenterColumnText('replacement')
                        imgui.NextColumn()
                        for k,v in ipairs(v.customTags) do
                            local tag = imgui.ImBuffer(u8(v.tag),256)
                            local replacement = imgui.ImBuffer(u8(v.replacement),256)
                            imgui.PushItemWidth(135)
                            if imgui.InputText(u8'##{tag}##'..k,tag) then v.tag = u8:decode(tag.v) s() end
                            imgui.PopItemWidth()
                            imgui.NextColumn()
                            imgui.PushItemWidth(125)
                            if imgui.InputText(u8'##replacement##'..k,replacement) then v.tag = u8:decode(tag.v) s() end
                            imgui.PopItemWidth()
                            imgui.SameLine()
                            if imgui.Button('R##'..k) then table.remove(v.customTags,k) s() end
                            imgui.NextColumn()
                        end
                        imgui.Columns()
                        imgui.EndChild()

                        imgui.EndPopup()
                    end

            		imgui.BeginChild('_',imgui.ImVec2(500,400),true)

            		editBinds(k,k+k,v,0)

            		imgui.EndChild()
            		imgui.EndPopup()
            	end
            end

        elseif activeMenu == 'other' then --activeMenu

            if upd ~= nil then
                if imgui.Button('about of update',imgui.ImVec2(-1,35)) then
                    imgui.OpenPopup('about of update')
                end
                if imgui.BeginPopupModal('about of update',imgui.ImBool(true),64) then
                    imgui.Text(u8(([[your version %s
new version %s
about - 
%s]]):format( thisScript().version_num,upd.version,upd.log ) ))
                    if imgui.Button('update!',imgui.ImVec2(-1,50)) then

                    end
                    imgui.EndPopup()
                end
            end

            if imgui.Button('reload script',imgui.ImVec2(imgui.GetWindowWidth()-30,0)) then thisScript():reload() end
            imgui.TextQuestion('fix input text')

            imgui.Text('commands:')
            for k,v in pairs(j.cmd) do
                local buff = imgui.ImBuffer(u8(v),256)
                imgui.PushItemWidth(100)
                if imgui.InputText(k,buff) then
                    sampUnregisterChatCommand(v)
                    j.cmd[k] = u8:decode(buff.v)
                    registerCmds()
                end
                imgui.PopItemWidth()
            end
            imgui.Text('hotkeys:')
            if hotkey().imgui('quick target selection','','quick target selection') then
                j.hk.target = hotkey().getKeys('quick target selection') s()
            end

            local nearPedCarColor = imgui.ImFloat4(unpack(j.nearPedCarColor))
            if imgui.ColorEdit4('color text near car/ped',nearPedCarColor,32+512) then j.nearPedCarColor = {nearPedCarColor.v[1],nearPedCarColor.v[2],nearPedCarColor.v[3],nearPedCarColor.v[4]} s() end

        end--activeMenu

        imgui.End()
    end

end

function binds(mainIndex,k,v)
    local i = mainIndex+k
	if v.bind == nil then
		for kk,vv in ipairs(v.binds) do
            if vv.bind == nil then
    			if pie.BeginPieMenu(u8(tostring(vv.name)),'category') then
    				binds(mainIndex+k,kk,vv)
    				pie.EndPieMenu()
    			end
            else
                binds(mainIndex+k,kk,vv)
            end
		end
	else
        local bind = v.bind
		if pie.PieMenuItem(u8(tostring(v.name)),u8(readBinds(bind)) ) then
            local bind = workTags(v.bind,false)
            bind = (bind == false and '' or bind)
            if bind:find("%{%d+%:%S+%}") then
                sampShowDialog(10,'pie binder enter params','','send','cancel',1)
                pie.window.v = false
                -- pie.inputArgs.focus = true
                -- pie.inputArgs.window.v = true
                pie.bind = v.bind
            else
                send(v.bind)
    			pie.window.v = false
            end
		end
	end
end

function move_server(t,from, to)
    table.insert(t, to, table.remove(t, from))
end
moving_bind = nil
function editBinds(mainIndex,k,v,sep)
	local i = mainIndex+k
	local function CollapsingHeader(k,v)
        local function btns(v,kk)
            if imgui.Button('rename ##' ..i..'_'..mainIndex..'_'..kk) then
                imgui.OpenPopup('rename ' ..i..'_'..mainIndex..'_'..kk)
            end
            imgui.SameLine(nil,imgui.GetWindowWidth()-155)
            if imgui.Button('remove ##' ..i..'_'..mainIndex..'_'..kk) then
                table.remove(v.binds,kk)
                s()
            end
        end
        local function moveBinds(n,tbl,kk)
            if moving_bind then
                if imgui.RadioButton('##move_'..n, moving_bind == kk) then
                    move_server(tbl,moving_bind, kk)
                    moving_bind = nil
                end
                
            else
                if imgui.RadioButton('##move_'..n, moving_bind == kk) then
                    moving_bind = kk
                end
            end
        end

		for kk,vv in ipairs(v.binds) do
            if vv.bind == nil then
    			if imgui.CollapsingHeader((sep == 0 and '' or ('>'):rep(sep)) .. u8(vv.name) .. (vv.bind == nil and '(category)' or '(bind)').. '##' ..i..'_'..mainIndex..'_'..kk) then
                    moveBinds(i..'_'..mainIndex..'_'..kk,v.binds,kk)
                    imgui.SameLine(nil,10)
                    btns(v,kk)
    				editBinds(mainIndex+i,k+kk,vv,sep+1)
                    imgui.Separator()
    			end
            else
                moveBinds('bind'..i..'_'..mainIndex..'_'..kk,v.binds,kk)
                imgui.SameLine(nil,10)
                if imgui.Button('rename ##' ..i..'_'..mainIndex..'_'..kk) then; imgui.OpenPopup('rename ' ..i..'_'..mainIndex..'_'..kk); end
                editBinds(mainIndex+i,k+kk,vv,sep+1)
                imgui.SameLine(nil,10)
                if imgui.Button('R##' ..i..'_'..mainIndex..'_'..kk) then;   table.remove(v.binds,kk);  s();  end
            end
			if imgui.BeginPopup('rename ' ..i..'_'..mainIndex..'_'..kk) then
				local rename = imgui.ImBuffer(u8(vv.name),256)
				if imgui.InputText('rename##'..i..mainIndex..k,rename) then vv.name = u8:decode(rename.v) s() end
				imgui.EndPopup()
			end
		end
	end



	if v.bind == nil then
		add(mainIndex,k,v.binds)
		CollapsingHeader(k,v)
	else
		imgui.SameLine(nil,10)
		if imgui.Button('edit bind <'..u8(v.name)..'>##'..i..mainIndex..k,imgui.ImVec2(imgui.GetWindowWidth()-135,0)) then
			imgui.OpenPopup('edit bind '..i..mainIndex..k)
		end
        -- imgui.Separator()
        imgui.SetNextWindowPos(imgui.ImVec2((sw/2-imgui.CalcTextSize(u8(v.bind)).x/2)-100,sh/2-imgui.CalcTextSize(u8(v.bind)).y/2),4)
		if imgui.BeginPopup('edit bind '..i..mainIndex..k) then
            imgui.SetWindowPos(imgui.ImVec2((sw/2-imgui.CalcTextSize(u8(v.bind)).x/2)-100,sh/2-imgui.CalcTextSize(u8(v.bind)).y/2),1)

			local buf = imgui.ImBuffer(u8(v.bind),0xffff)
			if imgui.InputTextMultiline('##text',buf,imgui.ImVec2(imgui.CalcTextSize(u8(v.bind)).x+50,imgui.CalcTextSize(u8(v.bind)).y+50)) then
				v.bind = u8:decode(buf.v)
				s()
			end
            imgui.SameLine()
            if imgui.Button('TAGS/FUNCTIONS-PARAMS',imgui.ImVec2(0,imgui.CalcTextSize(u8(v.bind)).y+50)) then
                imgui.OpenPopup('TAGS/FUNCTIONS-PARAMS')
            end
            imgui.Spacing()
            imgui.Text(u8(readBinds(v.bind)))


            if imgui.BeginPopup('TAGS/FUNCTIONS-PARAMS') then
                if imgui.CollapsingHeader('regulars') then
                    local text = [[
arguments = 
in string paste = {LABEL_CHAR:REGULAR(+/*)}
examples:
{1:S+} (Any letter, symbol or number other than a space character)
{1:+} (Any character)
'/report {1:S+} {2:+}'
-
symbol : replaces . and %
if there are two regular expressions and you wrote a command with one expression]]
                    for k,v in pairs(regulars) do
                        text = text .. ('%s\t\t%s\n'):format(k,v)
                    end
                    text = text .. [[

* Single character class, which corresponds to any single character from the given class;
* Single character class, followed by '*', which corresponds to 0 or more repetitions of characters from the given class. These repetition elements will always correspond to the longest possible sequence.
* Single character class followed by '+', ]]
                    local i = imgui.ImBuffer(text,0xffff)
                    imgui.InputTextMultiline('##r',i,imgui.ImVec2(700,300),16384)
                    if imgui.Button('regular expressions RU') then os.execute('explorer "https://www.blast.hk/threads/62661/"') end
                end
                local function show(t,b)
                    for k,v in pairs(t) do
                        k = (b and ('{'..k..'}') or k)
                        if imgui.Button(k) then
                            setClipboardText(k)
                        end
                        imgui.NextColumn()
                        imgui.Text(u8(v))
                        imgui.tip(u8(v))
                        imgui.NextColumn()
                        imgui.Separator()
                    end
                end
                imgui.BeginChild('t/f',imgui.ImVec2(500,200),false)
                imgui.Columns(2,'t',true)
                imgui.TextDisabled('click to copy')
                imgui.NextColumn()
                imgui.NextColumn()
                local t = {
                    ['#'] = 'send message to chat',
                    ['>>>'] = 'send message to clist\n(example ">>>/rec")',
                    ['w'] = 'wait\nexample "w1000" - 1 seconds delay',
                }
                show(t,false)
                imgui.Spacing()
                local t = {
                    ['carmodel(carId)'] = 'return veh model',
                    ['nick(playerId)'] = 'return nick_name by player id',
                    ['sendkey(VK_KEY,DELAY)'] = 'emul key(example {sendkey(VK_F8,10)} make screenshot)',
                    ['getcarpassengersnickname(carId)'] = 'return all the nicknames of the passengers in your car\format N.Name',
                    ['square(position)'] = 'return the square by position\nexample {square({carpos({id})})}',
                    ['carpos(carId)'] = 'return "X,Y,Z" position vehicle',
                    ['surname(playerId)'] = 'return surname player',
                    ['carid(playerId)'] = 'return id vehicle by player id',
                    ['name(playerId)'] = 'return name player',
                    ['pedpos(playerId)'] = 'return "X,Y,Z" position player',
                    ['myid'] = 'return your id',
                    ['nearcaridonscreen(ANY_ARG)'] = 'return the nearest vehicle on the screen to\nspecify any argument({nearcaridonscreen(_)})',
                    ['nearpedidonscreen(ANY_ARG)'] = 'return the nearest player on the screen to\nspecify any argument({nearcaridonscreen(_)})',
                    ['carname(carId)'] = 'return name car',
                    ['target'] = 'return target id',
                    ['getcarpassengersid(carId)'] = 'return driver-passenger id via vehicle id',
                    ['getcity(position)'] = 'return city',
                    ['getzone(position)'] = 'return zone/areas',
                    ['direction(playerId)'] = 'return direction',
                    ['carcolor(carId)'] = 'return car color name',
                }

                show(t,true)

                imgui.Columns(1)
                imgui.EndChild()
                imgui.EndPopup()
            end
			imgui.EndPopup()
		end
	end
	-- imgui.Separator()
end

function readBinds(b)
    local t = ''
    for n in b:gmatch('[^\n]+') do
        t = t .. '#' .. #n
        for l in n:gmatch('%S+') do
            local bind,err = l,''
            if not l:find("{sendkey") then
                bind,err = workTags(bind,false)
                bind = (bind == false and ('%s-%s'):format(l,err) or bind)
            end
            t = t .. ' ' .. tostring(bind)
        end
        t = t .. '\n'
    end
    return t
end

function send(text)
    if text == false then return end
	lua_thread.create(function()
		for l in text:gmatch('[^\n]+') do
			if l:find('^w%d+%s*$') then
				wait(tonumber(l:match('^w(%d+)%s*$')))
			else
                local b,err = pcall(function() workTags(l) end)
                l = workTags(l)
                if b and l ~= false then
    				if l:find('^%>%>%>') then
                        sampProcessChatInput(l:gsub('^%>%>%>',''))
                    elseif l:find('^%#') then
                        sampAddChatMessage(l)
                    else
                        sampSendChat(l)
                    end
                else return
                end
			end
		end
	end)
end

function workTags(text,message)
    if text == nil then return 'text==nil' end
    message = message == nil and true or message
    local t = tags
    if j.binds[activePieMenu] ~= nil and j.binds[activePieMenu].customTags ~= nil then
        for k,v in ipairs(j.binds[activePieMenu].customTags) do
            t[v.tag:gsub('%{',''):gsub('%}','')] = v.replacement
        end
    end
	for k,v in pairs(t) do
		for ll in text:gmatch('%{(%S+)%}') do
            local b = pcall(function() return (ll~=nil and #ll > 2 and ((ll:match("^(%w+)")):lower() ~= nil) and (ll:match("^(%w+)")):lower() == k  ) end)
			if b then
                if ll~=nil and #ll > 2 and ((ll:match("^(%w+)")):lower() ~= nil) and (ll:match("^(%w+)")):lower() == k then 
    				if type(v) == 'function' and ll:find("%(%S+%)") then
    					local arg = ll:match('^'..k..'%((%S+)%)$')
                        local err = ''
                        arg,err = workTags(arg,message)
    					if arg == false or v(arg) == 'NO GSUB' then return false,err end
                        if tostring(v(arg)):find("^ERROR") then
                            if message then
                                sampAddChatMessage(('%s error {AB000C}%s'):format(ll,(v(arg)):match("^ERROR (.+)")) )
                            end
                            return false,(v(arg)):match("^ERROR (.+)")
                        end
        				text = text:gsub('%{'..removePattern(ll)..'%}',(type(v(arg)) == 'table' and table.concat(v(arg),',') or v(arg)))
    				else
    					text = text:gsub('%{'..removePattern(ll)..'%}',(tostring(v)))
    				end
    			end
            end
		end
	end
    return text
end

tags = {
    carcolor = function(carid) 
        local h = carExits(carid)
        if tostring(h):find('^ERROR') then return h end
        return getCarColorName(h) 
    end,
    nearcaridonscreen = function(_) return getNearCarOnScreen() end,
    carid = function(id)
        if not tonumber(id) then return 'ERROR player id == nil' end
        local id = tonumber(id)
        local b,h = true,PLAYER_PED
        if id ~= tags.myid then
            b,h = sampGetCharHandleBySampPlayerId(id)
        end
        if not doesCharExist(h) then return 'ERROR char not exits' end
        if not isCharInAnyCar(h) then return 'ERROR char not is in car' end
        return select(2,sampGetVehicleIdByCarHandle(storeCarCharIsInNoSave(h))) 
    end,
    carmodel = function(carid)
        local h = carExits(carid)
        if tostring(h):find('^ERROR') then return h end
        return getCarModel(h) 
    end,
    carpos = function(carid)
        local h = carExits(carid)
        if tostring(h):find('^ERROR') then return h end
        local x,y,z = getCarCoordinates(h)
        return {x,y,z}
    end,
    carname = function(carid)
        local h = carExits(carid)
        if tostring(h):find('^ERROR') then return h end
        return (carsName[getCarModel(h)-399] == nil and 'ERROR unknown car name' or carsName[getCarModel(h)-399])
    end,
    getcarpassengersnickname = function(carid)
        local h = carExits(carid)
        if tostring(h):find('^ERROR') then return h end
        local text = 'none'
        for k,v in ipairs(getAllChars()) do
            if doesCharExist(v) and v ~= playerPed then
                if isCharInCar(v,h) then
                    local nick = sampGetPlayerNickname(select(2,sampGetPlayerIdByCharHandle(v)))
                    if text == 'none' then text = '' end
                    text = text .. (nick:match('^(%w)')):upper() .. '.' .. (nick:match('^%w+_(%w+)$')) .. ','
                end
            end
        end
        return text:gsub(",$",'')
    end,
    getcarpassengersid = function(carid)
        local h = carExits(carid)
        if tostring(h):find('^ERROR') then return h end
        for k,v in ipairs(getAllChars()) do
            if doesCharExist(v) and v ~= playerPed then
                if isCharInCar(v,h) then
                    return select(2,sampGetPlayerIdByCharHandle(v))
                end
            end
        end
        return -1
    end,
    --
    nearpedidonscreen = function(_) return getNearPedOnScreen() end,
    pedpos = function(id)
        local h = charExits(id)
        if tostring(h):find('^ERROR') then return h end
        local x,y,z = getCharCoordinates(h)
        return {x,y,z}
    end,
    direction = function(id)
        local h = charExits(id)
        if tostring(h):find('^ERROR') then return h end
        return direction(h)
    end,
    --
    getzone = function(arg)
        local coords = coordsConv(arg)
        if type(coords) == 'string' and coords:find('^ERROR') then return coords end
        return getZone(unpack(coords))
    end,
    getcity = function(arg)
        local coords = coordsConv(arg)
        if type(coords) == 'string' and coords:find('^ERROR') then return coords end
        return getCity(unpack(coords))
    end,
    nick = function(arg)
        local id = tonumber(arg)
        if not tonumber(id) then return 'ERROR player id == nil' end
        if (tags.myid ~= id) and not sampIsPlayerConnected(tonumber(id)) then return "ERROR player disconnected" end
        return sampGetPlayerNickname(id)
    end,
    name = function(id)
        if not tonumber(id) then return 'ERROR player id == nil' end
        if (tags.myid ~= tonumber(id)) and not sampIsPlayerConnected(tonumber(id)) then return "ERROR player disconnected" end
        return sampGetPlayerNickname(tonumber(id)):match("^(%w+)_%w+$")
    end,
    surname = function(id)
        if not tonumber(id) then return 'ERROR player id == nil' end
        if (tags.myid ~= tonumber(id)) and not sampIsPlayerConnected(tonumber(id)) then return "ERROR player disconnected" end
        return sampGetPlayerNickname(tonumber(id)):match("^%w+_(%w+)$")
    end,
    square = function(arg)
        local coords = coordsConv(arg)
        if type(coords) == 'string' and coords:find('^ERROR') then return coords end
        return square(unpack(coords))
    end,
    sendkey = function(arg)
        if not arg:find('%S+,%d+') then return 'ERROR invalid args "key,delay"' end
        local bw = pcall(function() wait(0) end)
        if bw then
            local key,w = arg:match("(%S+),(%d+)")
            for k,v in pairs(vkeys) do
                if k:sub(1, 3) == 'VK_' and key:upper() == k:upper() then
                    setVirtualKeyDown(v,true)
                    wait(tonumber(w))
                    setVirtualKeyDown(v,false)
                end
            end
        end
        return 'NO GSUB'
    end,
}

function carExits(carid)
    if not tonumber(carid) then return 'ERROR invalid vehicle id' end
    local res,h = sampGetCarHandleBySampVehicleId(carid)
    if not res then return 'ERROR vehicle does not exist' end
    return h
end
function charExits(id)
    if not tonumber(id) then return 'ERROR invalid player id' end
    if tonumber(id) ~= tags.myid and not sampIsPlayerConnected(tonumber(id)) then return "ERROR player disconnected" end
    local res,h = true,PLAYER_PED
    if tonumber(id) ~= select(2,sampGetPlayerIdByCharHandle(playerPed)) then
        res,h = sampGetCharHandleBySampPlayerId(tonumber(id))
    end
    if not res then return 'ERROR char does not exist' end
    return h
end

function coordsConv(text)
    if text == false then return 'ERROR text==boolean' end
    local x,y,z = text:match('(%S+),(%S+),(%S+)')
    if x == nil or y == nil or z == nil then return 'ERROR "X,Y,Z"==nil' end
    return {tonumber(x),tonumber(y),tonumber(z)}
end

function setTarget(id)
    if target.id ~= -1 then
        sampAddChatMessage('{BC5D00}remove target')
        target.id = -1
        removeUser3dMarker(target.marker)
        target.marker = nil
        return
    end
    if not sampIsPlayerConnected(id) or id == tags.myid then
        sampAddChatMessage('{AB000C} player disconnected!');return
    end
    target.id = id
    sampAddChatMessage(('{00830C}new target! {%s}%s[%s]'):format( bit.tohex(sampGetPlayerColor(id)):gsub('^%w%w',''),sampGetPlayerNickname(id),id ))
end

function square(X,Y,Z)
    local KV = {[1] = "�",[2] = "�",[3] = "�",[4] = "�",[5] = "�",[6] = "�",[7] = "�",[8] = "�",[9] = "�",[10] = "�",[11] = "�",[12] = "�",[13] = "�",[14] = "�",[15] = "�",[16] = "�",[17] = "�",[18] = "�",[19] = "�",[20] = "�",[21] = "�",[22] = "�",[23] = "�",[24] = "�",}
    X = math.ceil((X + 3000) / 250)
    Y = math.ceil((Y * - 1 + 3000) / 250)
    Y = KV[Y]
    local KVX = (Y.."-"..X)
    return KVX
end

function imgui.GetNameClickedMouse()
    local n = {
        0x01,0x02,0x04
    }
    for i = 0,2 do
        if imgui.IsMouseClicked(i) then
            return n[i+1]
        end
    end
    return 'none'
end

function getNearCarOnScreen()
    local dist,id = 0xffff,-1
    for k,v in ipairs(getAllVehicles()) do
        if doesVehicleExist(v) and not isCharInCar(PLAYER_PED,v) then
            local x,y,z = getCarCoordinates(v)
            local camX, camY, camZ = getActiveCameraCoordinates()
            local R, _ = processLineOfSight(camX, camY, camZ, x, y, z, true, false, false, true, false, false, false, true) 
            local RES = false
            if select(4,convert3DCoordsToScreenEx(x,y,z)) > 1 and not R then
                RES = true
            end
            MYPOS = {getCharCoordinates(PLAYER_PED)}
            if RES and getDistanceBetweenCoords3d(x,y,z,unpack(MYPOS)) < dist then
                dist,id = getDistanceBetweenCoords3d(x,y,z,unpack(MYPOS)),select(2,sampGetVehicleIdByCarHandle(v))
            end
        end
    end
    return id
end
function getNearPedOnScreen()
    local dist,id = 0xffff,-1
    for k,v in ipairs(getAllChars()) do
        if not isCharDead(v) and doesCharExist(v) and v ~= playerPed then
            local x,y,z = getCharCoordinates(v)
            local camX, camY, camZ = getActiveCameraCoordinates()
            local R, _ = processLineOfSight(camX, camY, camZ, x, y, z, true, false, false, true, false, false, false, true) 
            local RES = false
            if select(4,convert3DCoordsToScreenEx(x,y,z)) > 1 and not R then
                RES = true
            end
            MYPOS = {getCharCoordinates(PLAYER_PED)}
            if RES and getDistanceBetweenCoords3d(x,y,z,unpack(MYPOS)) < dist then
                if isCharInAnyCar(v) and isCharInAnyCar(PLAYER_PED) and isCharInCar(v,storeCarCharIsInNoSave(PLAYER_PED)) then
                    goto s
                end
                dist,id = getDistanceBetweenCoords3d(x,y,z,unpack(MYPOS)),select(2,sampGetPlayerIdByCharHandle(v))
            end
            ::s::
        end
    end
    return id
end

function getCoordinates(h)
    if not doesCharExist(h) then return -1,-1,-1 end
    local x,y,z = getCharCoordinates(h)
    if isCharInAnyCar(h) then
        local x,y,z = getCarCoordinates(storeCarCharIsInNoSave(h))
    end
    return x,y,z
end

function registerCmds()
    sampRegisterChatCommand(j.cmd.menu,function() window.v = not window.v end)

    sampRegisterChatCommand(j.cmd.target,function(id)
        if #id > 0 and tonumber(id) then
            setTarget(tonumber(id))
        end
    end)
end
function registerHK()
    hotkey().register('quick target selection',j.hk.target,false,false,function()
        target.select = not target.select
        showCursor(target.select,false)
    end)
    for k,v in ipairs(j.binds) do
        hotkey().unregister('hk pie menu '..k )
        hotkey().register('hk pie menu '..k,v.hk,v.hkDown,false,function()
            if v.hkDown then
                clockKeyDown = os.clock()
            end
            activePieMenu = k
            pie.window.v = (v.hkDown and true or (not pie.window.v))
        end)
    end
end

function add(mk,k,v)
    if imgui.Button('add category##'..mk .. '_'..k .. '_' .. #v) then
        table.insert(v,{
            name = 'pie bind #'..(#v+1),
            binds = {
                {
                    name = 'lol',
                    bind = 'text',
                    binds = {},
                }
            },
        })
        s()
    end
    imgui.SameLine()
    if imgui.Button('add bind##'..mk .. '_'..k .. '_' .. #v) then
        table.insert(v,{
            name = 'pie bind #'..(#v+1),
            bind = 'TEXT!',
            binds = {
            
            },
        })
        s()
    end
    imgui.Separator()
end

function removePattern(text)
    local p = {
        '(',')','{','}','|','<','>','-','.','$','^','[',']'
    }
    for k,v in ipairs(p) do
        text = text:gsub('%'..v,'%%'..v)
    end
    return text
end

function imgui.tip(text)
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.Text(text)
        imgui.EndTooltip()
    end
end

function apply_custom_style()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4

    style.WindowRounding = 2.0
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ChildWindowRounding = 2.0
    style.FrameRounding = 5.0
    style.ItemSpacing = imgui.ImVec2(5.0, 4.0)
    style.ScrollbarSize = 13.0
    style.ScrollbarRounding = 0
    style.GrabMinSize = 8.0
    style.GrabRounding = 1.0

    colors[imgui.Col.Text]                  = ImVec4(0.85, 0.87, 0.92, 1.00);
    colors[imgui.Col.TextDisabled]          = ImVec4(0.85, 0.87, 0.92, 0.58);
    colors[imgui.Col.WindowBg]              = ImVec4(0.12, 0.13, 0.16, 1.00);
    colors[imgui.Col.ChildWindowBg]         = ImVec4(0.20, 0.25, 0.39, 0.00);
    colors[imgui.Col.PopupBg]               = ImVec4(0.05, 0.05, 0.10, 0.90);
    colors[imgui.Col.Border]                = ImVec4(0.85, 0.87, 0.92, 0.30);
    colors[imgui.Col.BorderShadow]          = ImVec4(0.00, 0.00, 0.00, 0.00);
    colors[imgui.Col.FrameBg]               = ImVec4(0.20, 0.25, 0.39, 1.00);
    colors[imgui.Col.FrameBgHovered]        = ImVec4(0.19, 0.30, 0.63, 0.68);
    colors[imgui.Col.FrameBgActive]         = ImVec4(0.19, 0.30, 0.63, 1.00);
    colors[imgui.Col.TitleBg]               = ImVec4(0.19, 0.30, 0.63, 0.45);
    colors[imgui.Col.TitleBgCollapsed]      = ImVec4(0.19, 0.30, 0.63, 0.35);
    colors[imgui.Col.TitleBgActive]         = ImVec4(0.19, 0.30, 0.63, 0.78);
    colors[imgui.Col.MenuBarBg]             = ImVec4(0.20, 0.25, 0.39, 0.57);
    colors[imgui.Col.ScrollbarBg]           = ImVec4(0.20, 0.25, 0.39, 1.00);
    colors[imgui.Col.ScrollbarGrab]         = ImVec4(0.19, 0.30, 0.63, 0.31);
    colors[imgui.Col.ScrollbarGrabHovered]  = ImVec4(0.19, 0.30, 0.63, 0.78);
    colors[imgui.Col.ScrollbarGrabActive]   = ImVec4(0.19, 0.30, 0.63, 1.00);
    colors[imgui.Col.ComboBg]               = ImVec4(0.20, 0.25, 0.39, 1.00);
    colors[imgui.Col.CheckMark]             = ImVec4(0.18, 0.39, 1.00, 0.88);
    colors[imgui.Col.SliderGrab]            = ImVec4(0.19, 0.30, 0.63, 0.24);
    colors[imgui.Col.SliderGrabActive]      = ImVec4(0.19, 0.30, 0.63, 1.00);
    colors[imgui.Col.Button]                = ImVec4(0.19, 0.30, 0.63, 0.44);
    colors[imgui.Col.ButtonHovered]         = ImVec4(0.19, 0.30, 0.63, 0.86);
    colors[imgui.Col.ButtonActive]          = ImVec4(0.19, 0.30, 0.63, 1.00);
    colors[imgui.Col.Header]                = ImVec4(0.19, 0.30, 0.63, 0.76);
    colors[imgui.Col.HeaderHovered]         = ImVec4(0.19, 0.30, 0.63, 0.86);
    colors[imgui.Col.HeaderActive]          = ImVec4(0.19, 0.30, 0.63, 1.00);
    colors[imgui.Col.ResizeGrip]            = ImVec4(0.19, 0.30, 0.63, 0.20);
    colors[imgui.Col.ResizeGripHovered]     = ImVec4(0.19, 0.30, 0.63, 0.78);
    colors[imgui.Col.ResizeGripActive]      = ImVec4(0.19, 0.30, 0.63, 1.00);
    colors[imgui.Col.CloseButton]           = ImVec4(0.85, 0.87, 0.92, 0.16);
    colors[imgui.Col.CloseButtonHovered]    = ImVec4(0.85, 0.87, 0.92, 0.39);
    colors[imgui.Col.CloseButtonActive]     = ImVec4(0.85, 0.87, 0.92, 1.00);
    colors[imgui.Col.PlotLines]             = ImVec4(0.85, 0.87, 0.92, 0.63);
    colors[imgui.Col.PlotLinesHovered]      = ImVec4(0.19, 0.30, 0.63, 1.00);
    colors[imgui.Col.PlotHistogram]         = ImVec4(0.85, 0.87, 0.92, 0.63);
    colors[imgui.Col.PlotHistogramHovered]  = ImVec4(0.19, 0.30, 0.63, 1.00);
    colors[imgui.Col.TextSelectedBg]        = ImVec4(0.19, 0.30, 0.63, 0.43);
    colors[imgui.Col.ModalWindowDarkening]  = ImVec4(0.20, 0.20, 0.20, 0.35);
end
apply_custom_style()

local origsampAddChatMessage = sampAddChatMessage
function sampAddChatMessage(text); origsampAddChatMessage('[pie binder]{cccccc}'..text,0x304da1); end

function imgui.TextQuestion(text)
    imgui.SameLine()
    imgui.TextDisabled('(?)')
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.Text(text)
        imgui.EndTooltip()
    end
end

regulars = {
    ['.'] = 'Any character',
    ['%a'] = 'A letter (English only!)',
    ['%A'] = 'Any letter (Russian), symbol or number except an English letter',
    ['%c'] = 'Control character',
    ['%d'] = 'Digit',
    ['%D'] = 'Any letter or symbol but a number',
    ['%l'] = 'A lowercase letter (English only!)',
    ['%L'] = 'Any letter, symbol or number but a lowercase English letter',
    ['%p'] = 'Punctuation',
    ['%P'] = 'Any letter, symbol or number except punctuation marks',
    ['%s'] = 'A space character',
    ['%S'] = 'Any letter, symbol or number other than a space character',
    ['%u'] = 'Uppercase letter (English only!)',
    ['%U'] = 'Any letter, symbol or number except a capital English letter',
    ['%w'] = 'Any letter, symbol or number (English only!)',
    ['%W'] = 'Any letter or symbol (Russian), but not an uppercase English letter or number',
    ['%x'] = 'Hexadecimal number',
    ['%X'] = 'Any letter or symbol but a digit or letter, used to represent a hexadecimal number',
    ['%z'] = 'String parameters containing characters with the code 0',
}

function paramSplit(text)
    for l in text:gmatch("%{(%S+)%}") do
        if l:find('%{.+%}') then
            return paramSplit(l)
        end
        return l
    end
    return text
end

function gsubTextByRegulars(args,text)
    if #args == 0 or args:find('^%s+$') then return false,'string nil',args end
    local regular = {}
    for n in args:gmatch('[^\n]+') do
        for l in n:gmatch('%{(%d+%:%S+)%}') do
            l = paramSplit(l)
            local orig = l
            l = l:gsub('%d+%:','%.')
            for k,v in pairs(regulars) do
                if k == k:sub(1,1) .. ((l):sub(2,(l:sub(#l,#l):find('%p') and #l-1 or #l ))) then
                    table.insert(regular,{desc=v,orig=orig,reg='('..(k:sub(1,1) .. ((l):sub(2,#l)))..')',result=nil})
                end
            end
        end
    end
    if #regular == 0 then return true,nil,args end
    local prev = '^%s*'
    for k,v in ipairs(regular) do
        prev = prev .. (k == 1 and '' or '%s+') .. v.reg .. (k == #regular and '%s*$' or '')
        local r = {text:match(prev)}
        if r[k] == nil then
            return false,("not found regular expression %s #%s (%s)\n%s\n%s"):format(v.reg,k,v.orig,v.desc,args),args
        end
        v.result = r[k]
    end
    for k,v in ipairs(regular) do
        args = args:gsub('%{'..v.orig..'%p%}',v.result)
    end
    return true,nil,args
end

function hotkey()
    local vkeys = require'vkeys'
    if HOTKEY == nil then
        HOTKEY = {
            wait_for_key = 'press any key..',
            no_key = 'none',
            list = {},
            eventHandlers = false,
        }
    end
local function getKeysNameByBind(keys)
    local t = {}
    for k,v in ipairs(keys) do; table.insert(t,vkeys.id_to_name(v)); end
    return (#t == 0 and HOTKEY.no_key or (#t == 1 and table.concat(t,'') or table.concat(t,' + ')))
end
    local c = {}
    function c.register(hk,keys,keyDown,activeOnCursorActive,callback)
        if HOTKEY.list[hk] == nil then
            keys = decodeJson(keys or '{}')
            HOTKEY.list[hk] = {
                edit = false,
                tick = os.clock(),
                keys = keys,
                keyDown = keyDown,
                activeOnCursorActive = activeOnCursorActive,
                callback = callback,
            };  return true
        end;    return false
    end
    function c.unregister(hk)
        if HOTKEY.list[hk] == nil then;   return false;    end
        HOTKEY.list[hk] = nil
        return true
    end
    function c.imgui(name,textInButton,hk,width)
        textInButton = (textInButton == nil and '' or (#textInButton == 0 and '' or (textInButton .. ' ')) )
        local b = false
        local h = HOTKEY.list[hk]
        imgui.Text(name)
        imgui.SameLine()
        if h == nil then;   imgui.Button(textInButton.."NOT FIND HOTKEY "..hk);   return false; end
        if not h.edit then; h.tick = os.clock();    end
        if os.clock()-h.tick >= 1 then;    h.tick = os.clock();    end
        imgui.PushStyleColor(imgui.Col.Text,(os.clock()-h.tick) <= 0.5 and imgui.GetStyle().Colors[imgui.Col.Text] or imgui.ImVec4(1,1,1,0))
        if imgui.Button(textInButton.. (h.edit and (#h.keys == 0 and HOTKEY.wait_for_key or getKeysNameByBind(h.keys)) or getKeysNameByBind(h.keys) .. '##'..hk),imgui.ImVec2(width or 0,0)) then
            h.edit = true;  h.keys = {}
        end
        imgui.PopStyleColor(1)
        if h.edit then
            for k,v in pairs(vkeys) do
                if isKeyDown(v) and (v ~= VK_MENU and v ~= VK_CONTROL and v ~= VK_SHIFT) or (v == imgui.GetNameClickedMouse()) then
                    for kk,vv in ipairs(h.keys) do
                        if v == vv then;    goto s; end
                    end
                    table.insert(h.keys,v)
                    h.tick = os.clock()
                    ::s::
                    if #h.keys > 2 then
                        for i = 3,#h.keys do;   table.remove(h.keys,i);    end
                    end
                else
                    for kk,vv in ipairs(h.keys) do
                        if v == vv then;    h.edit = false; b = true;   end
                    end
                end
            end--
            if isKeyJustPressed(VK_BACK) then;  h.keys = {};    h.edit = false;   end

        end
        return b
    end
    function c.getKeys(hk)
        return HOTKEY.list[hk].keys == nil and 'nil_'..hk or encodeJson(HOTKEY.list[hk].keys or '{}')
    end
    if not HOTKEY.eventHandlers then
        addEventHandler("onWindowMessage",
            function (message, wparam, lparam)    
                for k,v in pairs(HOTKEY.list) do
                    if v.edit then
                        if message == 0x0102 then--CHAR
                            consumeWindowMessage(true,true)
                        elseif message == 0x0008 then--KILLFOCUS
                            v.edit = false
                            v.keys = {}
                        end
                    end
                end
            end
        )
        lua_thread.create(function()
            while true do wait(0)
            -- addEventHandler('onD3DPresent',function()
                if HOTKEY~=nil then
                    for k,v in pairs(HOTKEY.list) do
                        if HOTKEY.list[k] ~= nil and v.activeOnCursorActive and true or not (sampIsCursorActive() or sampIsDialogActive() or sampIsChatInputActive()) and not v.edit then
                            
                            if v.keyDown and (#v.keys == 1 and isKeyDown(v.keys[1]) or #v.keys == 2 and (isKeyDown(v.keys[1]) and isKeyDown(v.keys[2])) or false) or (#v.keys == 1 and isKeyJustPressed(v.keys[1]) or #v.keys == 2 and (isKeyDown(v.keys[1]) and isKeyJustPressed(v.keys[2])) or false)  then
                                v.callback()
                            end

                        end

                    end
                end
            end
        end)
        HOTKEY.eventHandlers = true
    end

    return c
end

function imgui.CenterColumnText(col,text)
    if type(col) == 'string' then 
        text = col
        col = nil
    end
    imgui.SetCursorPosX((imgui.GetColumnOffset() + (imgui.GetColumnWidth() / 2)) - imgui.CalcTextSize(text).x / 2)
    if col == nil then
        imgui.Text(text)
    else
        imgui.TextColored(col,text)
    end
end

carsName = {"Landstalker", "Bravura", "Buffalo", "Linerunner", "Perrenial", "Sentinel", "Dumper", "Firetruck", "Trashmaster", "Stretch", "Manana", "Infernus",
"Voodoo", "Pony", "Mule", "Cheetah", "Ambulance", "Leviathan", "Moonbeam", "Esperanto", "Taxi", "Washington", "Bobcat", "Whoopee", "BFInjection", "Hunter",
"Premier", "Enforcer", "Securicar", "Banshee", "Predator", "Bus", "Rhino", "Barracks", "Hotknife", "Trailer", "Previon", "Coach", "Cabbie", "Stallion", "Rumpo",
"RCBandit", "Romero","Packer", "Monster", "Admiral", "Squalo", "Seasparrow", "Pizzaboy", "Tram", "Trailer", "Turismo", "Speeder", "Reefer", "Tropic", "Flatbed",
"Yankee", "Caddy", "Solair", "Berkley'sRCVan", "Skimmer", "PCJ-600", "Faggio", "Freeway", "RCBaron", "RCRaider", "Glendale", "Oceanic", "Sanchez", "Sparrow",
"Patriot", "Quad", "Coastguard", "Dinghy", "Hermes", "Sabre", "Rustler", "ZR-350", "Walton", "Regina", "Comet", "BMX", "Burrito", "Camper", "Marquis", "Baggage",
"Dozer", "Maverick", "NewsChopper", "Rancher", "FBIRancher", "Virgo", "Greenwood", "Jetmax", "Hotring", "Sandking", "BlistaCompact", "PoliceMaverick",
"Boxvillde", "Benson", "Mesa", "RCGoblin", "HotringRacerA", "HotringRacerB", "BloodringBanger", "Rancher", "SuperGT", "Elegant", "Journey", "Bike",
"MountainBike", "Beagle", "Cropduster", "Stunt", "Tanker", "Roadtrain", "Nebula", "Majestic", "Buccaneer", "Shamal", "hydra", "FCR-900", "NRG-500", "HPV1000",
"CementTruck", "TowTruck", "Fortune", "Cadrona", "FBITruck", "Willard", "Forklift", "Tractor", "Combine", "Feltzer", "Remington", "Slamvan", "Blade", "Freight",
"Streak", "Vortex", "Vincent", "Bullet", "Clover", "Sadler", "Firetruck", "Hustler", "Intruder", "Primo", "Cargobob", "Tampa", "Sunrise", "Merit", "Utility", "Nevada",
"Yosemite", "Windsor", "Monster", "Monster", "Uranus", "Jester", "Sultan", "Stratum", "Elegy", "Raindance", "RCTiger", "Flash", "Tahoma", "Savanna", "Bandito",
"FreightFlat", "StreakCarriage", "Kart", "Mower", "Dune", "Sweeper", "Broadway", "Tornado", "AT-400", "DFT-30", "Huntley", "Stafford", "BF-400", "NewsVan",
"Tug", "Trailer", "Emperor", "Wayfarer", "Euros", "Hotdog", "Club", "FreightBox", "Trailer", "Andromada", "Dodo", "RCCam", "Launch", "PoliceCar", "PoliceCar",
"PoliceCar", "PoliceRanger", "Picador", "S.W.A.T", "Alpha", "Phoenix", "GlendaleShit", "SadlerShit", "Luggage A", "Luggage B", "Stairs", "Boxville", "Tiller",
"UtilityTrailer"}

function getZone(x, y, z)
    local Zones = {
        {"Avispa Country Club", -2667.810, -302.135, -28.831, -2646.400, -262.320, 71.169},
        {"Easter Bay Airport", -1315.420, -405.388, 15.406, -1264.400, -209.543, 25.406},
        {"Avispa Country Club", -2550.040, -355.493, 0.000, -2470.040, -318.493, 39.700},
        {"Easter Bay Airport", -1490.330, -209.543, 15.406, -1264.400, -148.388, 25.406},
        {"Garcia", -2395.140, -222.589, -5.3, -2354.090, -204.792, 200.000},
        {"Shady Cabin", -1632.830, -2263.440, -3.0, -1601.330, -2231.790, 200.000},
        {"East Los Santos", 2381.680, -1494.030, -89.084, 2421.030, -1454.350, 110.916},
        {"LVA Freight Depot", 1236.630, 1163.410, -89.084, 1277.050, 1203.280, 110.916},
        {"Blackfield Intersection", 1277.050, 1044.690, -89.084, 1315.350, 1087.630, 110.916},
        {"Avispa Country Club", -2470.040, -355.493, 0.000, -2270.040, -318.493, 46.100},
        {"Temple", 1252.330, -926.999, -89.084, 1357.000, -910.170, 110.916},
        {"Unity Station", 1692.620, -1971.800, -20.492, 1812.620, -1932.800, 79.508},
        {"LVA Freight Depot", 1315.350, 1044.690, -89.084, 1375.600, 1087.630, 110.916},
        {"Los Flores", 2581.730, -1454.350, -89.084, 2632.830, -1393.420, 110.916},
        {"Starfish Casino", 2437.390, 1858.100, -39.084, 2495.090, 1970.850, 60.916},
        {"Easter Bay Chemicals", -1132.820, -787.391, 0.000, -956.476, -768.027, 200.000},
        {"Downtown Los Santos", 1370.850, -1170.870, -89.084, 1463.900, -1130.850, 110.916},
        {"Esplanade East", -1620.300, 1176.520, -4.5, -1580.010, 1274.260, 200.000},
        {"Market Station", 787.461, -1410.930, -34.126, 866.009, -1310.210, 65.874},
        {"Linden Station", 2811.250, 1229.590, -39.594, 2861.250, 1407.590, 60.406},
        {"Montgomery Intersection", 1582.440, 347.457, 0.000, 1664.620, 401.750, 200.000},
        {"Frederick Bridge", 2759.250, 296.501, 0.000, 2774.250, 594.757, 200.000},
        {"Yellow Bell Station", 1377.480, 2600.430, -21.926, 1492.450, 2687.360, 78.074},
        {"Downtown Los Santos", 1507.510, -1385.210, 110.916, 1582.550, -1325.310, 335.916},
        {"Jefferson", 2185.330, -1210.740, -89.084, 2281.450, -1154.590, 110.916},
        {"Mulholland", 1318.130, -910.170, -89.084, 1357.000, -768.027, 110.916},
        {"Avispa Country Club", -2361.510, -417.199, 0.000, -2270.040, -355.493, 200.000},
        {"Jefferson", 1996.910, -1449.670, -89.084, 2056.860, -1350.720, 110.916},
        {"Julius Thruway West", 1236.630, 2142.860, -89.084, 1297.470, 2243.230, 110.916},
        {"Jefferson", 2124.660, -1494.030, -89.084, 2266.210, -1449.670, 110.916},
        {"Julius Thruway North", 1848.400, 2478.490, -89.084, 1938.800, 2553.490, 110.916},
        {"Rodeo", 422.680, -1570.200, -89.084, 466.223, -1406.050, 110.916},
        {"Cranberry Station", -2007.830, 56.306, 0.000, -1922.000, 224.782, 100.000},
        {"Downtown Los Santos", 1391.050, -1026.330, -89.084, 1463.900, -926.999, 110.916},
        {"Redsands West", 1704.590, 2243.230, -89.084, 1777.390, 2342.830, 110.916},
        {"Little Mexico", 1758.900, -1722.260, -89.084, 1812.620, -1577.590, 110.916},
        {"Blackfield Intersection", 1375.600, 823.228, -89.084, 1457.390, 919.447, 110.916},
        {"Los Santos International", 1974.630, -2394.330, -39.084, 2089.000, -2256.590, 60.916},
        {"Beacon Hill", -399.633, -1075.520, -1.489, -319.033, -977.516, 198.511},
        {"Rodeo", 334.503, -1501.950, -89.084, 422.680, -1406.050, 110.916},
        {"Richman", 225.165, -1369.620, -89.084, 334.503, -1292.070, 110.916},
        {"Downtown Los Santos", 1724.760, -1250.900, -89.084, 1812.620, -1150.870, 110.916},
        {"The Strip", 2027.400, 1703.230, -89.084, 2137.400, 1783.230, 110.916},
        {"Downtown Los Santos", 1378.330, -1130.850, -89.084, 1463.900, -1026.330, 110.916},
        {"Blackfield Intersection", 1197.390, 1044.690, -89.084, 1277.050, 1163.390, 110.916},
        {"Conference Center", 1073.220, -1842.270, -89.084, 1323.900, -1804.210, 110.916},
        {"Montgomery", 1451.400, 347.457, -6.1, 1582.440, 420.802, 200.000},
        {"Foster Valley", -2270.040, -430.276, -1.2, -2178.690, -324.114, 200.000},
        {"Blackfield Chapel", 1325.600, 596.349, -89.084, 1375.600, 795.010, 110.916},
        {"Los Santos International", 2051.630, -2597.260, -39.084, 2152.450, -2394.330, 60.916},
        {"Mulholland", 1096.470, -910.170, -89.084, 1169.130, -768.027, 110.916},
        {"Yellow Bell Gol Course", 1457.460, 2723.230, -89.084, 1534.560, 2863.230, 110.916},
        {"The Strip", 2027.400, 1783.230, -89.084, 2162.390, 1863.230, 110.916},
        {"Jefferson", 2056.860, -1210.740, -89.084, 2185.330, -1126.320, 110.916},
        {"Mulholland", 952.604, -937.184, -89.084, 1096.470, -860.619, 110.916},
        {"Aldea Malvada", -1372.140, 2498.520, 0.000, -1277.590, 2615.350, 200.000},
        {"Las Colinas", 2126.860, -1126.320, -89.084, 2185.330, -934.489, 110.916},
        {"Las Colinas", 1994.330, -1100.820, -89.084, 2056.860, -920.815, 110.916},
        {"Richman", 647.557, -954.662, -89.084, 768.694, -860.619, 110.916},
        {"LVA Freight Depot", 1277.050, 1087.630, -89.084, 1375.600, 1203.280, 110.916},
        {"Julius Thruway North", 1377.390, 2433.230, -89.084, 1534.560, 2507.230, 110.916},
        {"Willowfield", 2201.820, -2095.000, -89.084, 2324.000, -1989.900, 110.916},
        {"Julius Thruway North", 1704.590, 2342.830, -89.084, 1848.400, 2433.230, 110.916},
        {"Temple", 1252.330, -1130.850, -89.084, 1378.330, -1026.330, 110.916},
        {"Little Mexico", 1701.900, -1842.270, -89.084, 1812.620, -1722.260, 110.916},
        {"Queens", -2411.220, 373.539, 0.000, -2253.540, 458.411, 200.000},
        {"Las Venturas Airport", 1515.810, 1586.400, -12.500, 1729.950, 1714.560, 87.500},
        {"Richman", 225.165, -1292.070, -89.084, 466.223, -1235.070, 110.916},
        {"Temple", 1252.330, -1026.330, -89.084, 1391.050, -926.999, 110.916},
        {"East Los Santos", 2266.260, -1494.030, -89.084, 2381.680, -1372.040, 110.916},
        {"Julius Thruway East", 2623.180, 943.235, -89.084, 2749.900, 1055.960, 110.916},
        {"Willowfield", 2541.700, -1941.400, -89.084, 2703.580, -1852.870, 110.916},
        {"Las Colinas", 2056.860, -1126.320, -89.084, 2126.860, -920.815, 110.916},
        {"Julius Thruway East", 2625.160, 2202.760, -89.084, 2685.160, 2442.550, 110.916},
        {"Rodeo", 225.165, -1501.950, -89.084, 334.503, -1369.620, 110.916},
        {"Las Brujas", -365.167, 2123.010, -3.0, -208.570, 2217.680, 200.000},
        {"Julius Thruway East", 2536.430, 2442.550, -89.084, 2685.160, 2542.550, 110.916},
        {"Rodeo", 334.503, -1406.050, -89.084, 466.223, -1292.070, 110.916},
        {"Vinewood", 647.557, -1227.280, -89.084, 787.461, -1118.280, 110.916},
        {"Rodeo", 422.680, -1684.650, -89.084, 558.099, -1570.200, 110.916},
        {"Julius Thruway North", 2498.210, 2542.550, -89.084, 2685.160, 2626.550, 110.916},
        {"Downtown Los Santos", 1724.760, -1430.870, -89.084, 1812.620, -1250.900, 110.916},
        {"Rodeo", 225.165, -1684.650, -89.084, 312.803, -1501.950, 110.916},
        {"Jefferson", 2056.860, -1449.670, -89.084, 2266.210, -1372.040, 110.916},
        {"Hampton Barns", 603.035, 264.312, 0.000, 761.994, 366.572, 200.000},
        {"Temple", 1096.470, -1130.840, -89.084, 1252.330, -1026.330, 110.916},
        {"Kincaid Bridge", -1087.930, 855.370, -89.084, -961.950, 986.281, 110.916},
        {"Verona Beach", 1046.150, -1722.260, -89.084, 1161.520, -1577.590, 110.916},
        {"Commerce", 1323.900, -1722.260, -89.084, 1440.900, -1577.590, 110.916},
        {"Mulholland", 1357.000, -926.999, -89.084, 1463.900, -768.027, 110.916},
        {"Rodeo", 466.223, -1570.200, -89.084, 558.099, -1385.070, 110.916},
        {"Mulholland", 911.802, -860.619, -89.084, 1096.470, -768.027, 110.916},
        {"Mulholland", 768.694, -954.662, -89.084, 952.604, -860.619, 110.916},
        {"Julius Thruway South", 2377.390, 788.894, -89.084, 2537.390, 897.901, 110.916},
        {"Idlewood", 1812.620, -1852.870, -89.084, 1971.660, -1742.310, 110.916},
        {"Ocean Docks", 2089.000, -2394.330, -89.084, 2201.820, -2235.840, 110.916},
        {"Commerce", 1370.850, -1577.590, -89.084, 1463.900, -1384.950, 110.916},
        {"Julius Thruway North", 2121.400, 2508.230, -89.084, 2237.400, 2663.170, 110.916},
        {"Temple", 1096.470, -1026.330, -89.084, 1252.330, -910.170, 110.916},
        {"Glen Park", 1812.620, -1449.670, -89.084, 1996.910, -1350.720, 110.916},
        {"Easter Bay Airport", -1242.980, -50.096, 0.000, -1213.910, 578.396, 200.000},
        {"Martin Bridge", -222.179, 293.324, 0.000, -122.126, 476.465, 200.000},
        {"The Strip", 2106.700, 1863.230, -89.084, 2162.390, 2202.760, 110.916},
        {"Willowfield", 2541.700, -2059.230, -89.084, 2703.580, -1941.400, 110.916},
        {"Marina", 807.922, -1577.590, -89.084, 926.922, -1416.250, 110.916},
        {"Las Venturas Airport", 1457.370, 1143.210, -89.084, 1777.400, 1203.280, 110.916},
        {"Idlewood", 1812.620, -1742.310, -89.084, 1951.660, -1602.310, 110.916},
        {"Esplanade East", -1580.010, 1025.980, -6.1, -1499.890, 1274.260, 200.000},
        {"Downtown Los Santos", 1370.850, -1384.950, -89.084, 1463.900, -1170.870, 110.916},
        {"The Mako Span", 1664.620, 401.750, 0.000, 1785.140, 567.203, 200.000},
        {"Rodeo", 312.803, -1684.650, -89.084, 422.680, -1501.950, 110.916},
        {"Pershing Square", 1440.900, -1722.260, -89.084, 1583.500, -1577.590, 110.916},
        {"Mulholland", 687.802, -860.619, -89.084, 911.802, -768.027, 110.916},
        {"Gant Bridge", -2741.070, 1490.470, -6.1, -2616.400, 1659.680, 200.000},
        {"Las Colinas", 2185.330, -1154.590, -89.084, 2281.450, -934.489, 110.916},
        {"Mulholland", 1169.130, -910.170, -89.084, 1318.130, -768.027, 110.916},
        {"Julius Thruway North", 1938.800, 2508.230, -89.084, 2121.400, 2624.230, 110.916},
        {"Commerce", 1667.960, -1577.590, -89.084, 1812.620, -1430.870, 110.916},
        {"Rodeo", 72.648, -1544.170, -89.084, 225.165, -1404.970, 110.916},
        {"Roca Escalante", 2536.430, 2202.760, -89.084, 2625.160, 2442.550, 110.916},
        {"Rodeo", 72.648, -1684.650, -89.084, 225.165, -1544.170, 110.916},
        {"Market", 952.663, -1310.210, -89.084, 1072.660, -1130.850, 110.916},
        {"Las Colinas", 2632.740, -1135.040, -89.084, 2747.740, -945.035, 110.916},
        {"Mulholland", 861.085, -674.885, -89.084, 1156.550, -600.896, 110.916},
        {"King's", -2253.540, 373.539, -9.1, -1993.280, 458.411, 200.000},
        {"Redsands East", 1848.400, 2342.830, -89.084, 2011.940, 2478.490, 110.916},
        {"Downtown", -1580.010, 744.267, -6.1, -1499.890, 1025.980, 200.000},
        {"Conference Center", 1046.150, -1804.210, -89.084, 1323.900, -1722.260, 110.916},
        {"Richman", 647.557, -1118.280, -89.084, 787.461, -954.662, 110.916},
        {"Ocean Flats", -2994.490, 277.411, -9.1, -2867.850, 458.411, 200.000},
        {"Greenglass College", 964.391, 930.890, -89.084, 1166.530, 1044.690, 110.916},
        {"Glen Park", 1812.620, -1100.820, -89.084, 1994.330, -973.380, 110.916},
        {"LVA Freight Depot", 1375.600, 919.447, -89.084, 1457.370, 1203.280, 110.916},
        {"Regular Tom", -405.770, 1712.860, -3.0, -276.719, 1892.750, 200.000},
        {"Verona Beach", 1161.520, -1722.260, -89.084, 1323.900, -1577.590, 110.916},
        {"East Los Santos", 2281.450, -1372.040, -89.084, 2381.680, -1135.040, 110.916},
        {"Caligula's Palace", 2137.400, 1703.230, -89.084, 2437.390, 1783.230, 110.916},
        {"Idlewood", 1951.660, -1742.310, -89.084, 2124.660, -1602.310, 110.916},
        {"Pilgrim", 2624.400, 1383.230, -89.084, 2685.160, 1783.230, 110.916},
        {"Idlewood", 2124.660, -1742.310, -89.084, 2222.560, -1494.030, 110.916},
        {"Queens", -2533.040, 458.411, 0.000, -2329.310, 578.396, 200.000},
        {"Downtown", -1871.720, 1176.420, -4.5, -1620.300, 1274.260, 200.000},
        {"Commerce", 1583.500, -1722.260, -89.084, 1758.900, -1577.590, 110.916},
        {"East Los Santos", 2381.680, -1454.350, -89.084, 2462.130, -1135.040, 110.916},
        {"Marina", 647.712, -1577.590, -89.084, 807.922, -1416.250, 110.916},
        {"Richman", 72.648, -1404.970, -89.084, 225.165, -1235.070, 110.916},
        {"Vinewood", 647.712, -1416.250, -89.084, 787.461, -1227.280, 110.916},
        {"East Los Santos", 2222.560, -1628.530, -89.084, 2421.030, -1494.030, 110.916},
        {"Rodeo", 558.099, -1684.650, -89.084, 647.522, -1384.930, 110.916},
        {"Easter Tunnel", -1709.710, -833.034, -1.5, -1446.010, -730.118, 200.000},
        {"Rodeo", 466.223, -1385.070, -89.084, 647.522, -1235.070, 110.916},
        {"Redsands East", 1817.390, 2202.760, -89.084, 2011.940, 2342.830, 110.916},
        {"The Clown's Pocket", 2162.390, 1783.230, -89.084, 2437.390, 1883.230, 110.916},
        {"Idlewood", 1971.660, -1852.870, -89.084, 2222.560, -1742.310, 110.916},
        {"Montgomery Intersection", 1546.650, 208.164, 0.000, 1745.830, 347.457, 200.000},
        {"Willowfield", 2089.000, -2235.840, -89.084, 2201.820, -1989.900, 110.916},
        {"Temple", 952.663, -1130.840, -89.084, 1096.470, -937.184, 110.916},
        {"Prickle Pine", 1848.400, 2553.490, -89.084, 1938.800, 2863.230, 110.916},
        {"Los Santos International", 1400.970, -2669.260, -39.084, 2189.820, -2597.260, 60.916},
        {"Garver Bridge", -1213.910, 950.022, -89.084, -1087.930, 1178.930, 110.916},
        {"Garver Bridge", -1339.890, 828.129, -89.084, -1213.910, 1057.040, 110.916},
        {"Kincaid Bridge", -1339.890, 599.218, -89.084, -1213.910, 828.129, 110.916},
        {"Kincaid Bridge", -1213.910, 721.111, -89.084, -1087.930, 950.022, 110.916},
        {"Verona Beach", 930.221, -2006.780, -89.084, 1073.220, -1804.210, 110.916},
        {"Verdant Bluffs", 1073.220, -2006.780, -89.084, 1249.620, -1842.270, 110.916},
        {"Vinewood", 787.461, -1130.840, -89.084, 952.604, -954.662, 110.916},
        {"Vinewood", 787.461, -1310.210, -89.084, 952.663, -1130.840, 110.916},
        {"Commerce", 1463.900, -1577.590, -89.084, 1667.960, -1430.870, 110.916},
        {"Market", 787.461, -1416.250, -89.084, 1072.660, -1310.210, 110.916},
        {"Rockshore West", 2377.390, 596.349, -89.084, 2537.390, 788.894, 110.916},
        {"Julius Thruway North", 2237.400, 2542.550, -89.084, 2498.210, 2663.170, 110.916},
        {"East Beach", 2632.830, -1668.130, -89.084, 2747.740, -1393.420, 110.916},
        {"Fallow Bridge", 434.341, 366.572, 0.000, 603.035, 555.680, 200.000},
        {"Willowfield", 2089.000, -1989.900, -89.084, 2324.000, -1852.870, 110.916},
        {"Chinatown", -2274.170, 578.396, -7.6, -2078.670, 744.170, 200.000},
        {"El Castillo del Diablo", -208.570, 2337.180, 0.000, 8.430, 2487.180, 200.000},
        {"Ocean Docks", 2324.000, -2145.100, -89.084, 2703.580, -2059.230, 110.916},
        {"Easter Bay Chemicals", -1132.820, -768.027, 0.000, -956.476, -578.118, 200.000},
        {"The Visage", 1817.390, 1703.230, -89.084, 2027.400, 1863.230, 110.916},
        {"Ocean Flats", -2994.490, -430.276, -1.2, -2831.890, -222.589, 200.000},
        {"Richman", 321.356, -860.619, -89.084, 687.802, -768.027, 110.916},
        {"Green Palms", 176.581, 1305.450, -3.0, 338.658, 1520.720, 200.000},
        {"Richman", 321.356, -768.027, -89.084, 700.794, -674.885, 110.916},
        {"Starfish Casino", 2162.390, 1883.230, -89.084, 2437.390, 2012.180, 110.916},
        {"East Beach", 2747.740, -1668.130, -89.084, 2959.350, -1498.620, 110.916},
        {"Jefferson", 2056.860, -1372.040, -89.084, 2281.450, -1210.740, 110.916},
        {"Downtown Los Santos", 1463.900, -1290.870, -89.084, 1724.760, -1150.870, 110.916},
        {"Downtown Los Santos", 1463.900, -1430.870, -89.084, 1724.760, -1290.870, 110.916},
        {"Garver Bridge", -1499.890, 696.442, -179.615, -1339.890, 925.353, 20.385},
        {"Julius Thruway South", 1457.390, 823.228, -89.084, 2377.390, 863.229, 110.916},
        {"East Los Santos", 2421.030, -1628.530, -89.084, 2632.830, -1454.350, 110.916},
        {"Greenglass College", 964.391, 1044.690, -89.084, 1197.390, 1203.220, 110.916},
        {"Las Colinas", 2747.740, -1120.040, -89.084, 2959.350, -945.035, 110.916},
        {"Mulholland", 737.573, -768.027, -89.084, 1142.290, -674.885, 110.916},
        {"Ocean Docks", 2201.820, -2730.880, -89.084, 2324.000, -2418.330, 110.916},
        {"East Los Santos", 2462.130, -1454.350, -89.084, 2581.730, -1135.040, 110.916},
        {"Ganton", 2222.560, -1722.330, -89.084, 2632.830, -1628.530, 110.916},
        {"Avispa Country Club", -2831.890, -430.276, -6.1, -2646.400, -222.589, 200.000},
        {"Willowfield", 1970.620, -2179.250, -89.084, 2089.000, -1852.870, 110.916},
        {"Esplanade North", -1982.320, 1274.260, -4.5, -1524.240, 1358.900, 200.000},
        {"The High Roller", 1817.390, 1283.230, -89.084, 2027.390, 1469.230, 110.916},
        {"Ocean Docks", 2201.820, -2418.330, -89.084, 2324.000, -2095.000, 110.916},
        {"Last Dime Motel", 1823.080, 596.349, -89.084, 1997.220, 823.228, 110.916},
        {"Bayside Marina", -2353.170, 2275.790, 0.000, -2153.170, 2475.790, 200.000},
        {"King's", -2329.310, 458.411, -7.6, -1993.280, 578.396, 200.000},
        {"El Corona", 1692.620, -2179.250, -89.084, 1812.620, -1842.270, 110.916},
        {"Blackfield Chapel", 1375.600, 596.349, -89.084, 1558.090, 823.228, 110.916},
        {"The Pink Swan", 1817.390, 1083.230, -89.084, 2027.390, 1283.230, 110.916},
        {"Julius Thruway West", 1197.390, 1163.390, -89.084, 1236.630, 2243.230, 110.916},
        {"Los Flores", 2581.730, -1393.420, -89.084, 2747.740, -1135.040, 110.916},
        {"The Visage", 1817.390, 1863.230, -89.084, 2106.700, 2011.830, 110.916},
        {"Prickle Pine", 1938.800, 2624.230, -89.084, 2121.400, 2861.550, 110.916},
        {"Verona Beach", 851.449, -1804.210, -89.084, 1046.150, -1577.590, 110.916},
        {"Robada Intersection", -1119.010, 1178.930, -89.084, -862.025, 1351.450, 110.916},
        {"Linden Side", 2749.900, 943.235, -89.084, 2923.390, 1198.990, 110.916},
        {"Ocean Docks", 2703.580, -2302.330, -89.084, 2959.350, -2126.900, 110.916},
        {"Willowfield", 2324.000, -2059.230, -89.084, 2541.700, -1852.870, 110.916},
        {"King's", -2411.220, 265.243, -9.1, -1993.280, 373.539, 200.000},
        {"Commerce", 1323.900, -1842.270, -89.084, 1701.900, -1722.260, 110.916},
        {"Mulholland", 1269.130, -768.027, -89.084, 1414.070, -452.425, 110.916},
        {"Marina", 647.712, -1804.210, -89.084, 851.449, -1577.590, 110.916},
        {"Battery Point", -2741.070, 1268.410, -4.5, -2533.040, 1490.470, 200.000},
        {"The Four Dragons Casino", 1817.390, 863.232, -89.084, 2027.390, 1083.230, 110.916},
        {"Blackfield", 964.391, 1203.220, -89.084, 1197.390, 1403.220, 110.916},
        {"Julius Thruway North", 1534.560, 2433.230, -89.084, 1848.400, 2583.230, 110.916},
        {"Yellow Bell Gol Course", 1117.400, 2723.230, -89.084, 1457.460, 2863.230, 110.916},
        {"Idlewood", 1812.620, -1602.310, -89.084, 2124.660, -1449.670, 110.916},
        {"Redsands West", 1297.470, 2142.860, -89.084, 1777.390, 2243.230, 110.916},
        {"Doherty", -2270.040, -324.114, -1.2, -1794.920, -222.589, 200.000},
        {"Hilltop Farm", 967.383, -450.390, -3.0, 1176.780, -217.900, 200.000},
        {"Las Barrancas", -926.130, 1398.730, -3.0, -719.234, 1634.690, 200.000},
        {"Pirates in Men's Pants", 1817.390, 1469.230, -89.084, 2027.400, 1703.230, 110.916},
        {"City Hall", -2867.850, 277.411, -9.1, -2593.440, 458.411, 200.000},
        {"Avispa Country Club", -2646.400, -355.493, 0.000, -2270.040, -222.589, 200.000},
        {"The Strip", 2027.400, 863.229, -89.084, 2087.390, 1703.230, 110.916},
        {"Hashbury", -2593.440, -222.589, -1.0, -2411.220, 54.722, 200.000},
        {"Los Santos International", 1852.000, -2394.330, -89.084, 2089.000, -2179.250, 110.916},
        {"Whitewood Estates", 1098.310, 1726.220, -89.084, 1197.390, 2243.230, 110.916},
        {"Sherman Reservoir", -789.737, 1659.680, -89.084, -599.505, 1929.410, 110.916},
        {"El Corona", 1812.620, -2179.250, -89.084, 1970.620, -1852.870, 110.916},
        {"Downtown", -1700.010, 744.267, -6.1, -1580.010, 1176.520, 200.000},
        {"Foster Valley", -2178.690, -1250.970, 0.000, -1794.920, -1115.580, 200.000},
        {"Las Payasadas", -354.332, 2580.360, 2.0, -133.625, 2816.820, 200.000},
        {"Valle Ocultado", -936.668, 2611.440, 2.0, -715.961, 2847.900, 200.000},
        {"Blackfield Intersection", 1166.530, 795.010, -89.084, 1375.600, 1044.690, 110.916},
        {"Ganton", 2222.560, -1852.870, -89.084, 2632.830, -1722.330, 110.916},
        {"Easter Bay Airport", -1213.910, -730.118, 0.000, -1132.820, -50.096, 200.000},
        {"Redsands East", 1817.390, 2011.830, -89.084, 2106.700, 2202.760, 110.916},
        {"Esplanade East", -1499.890, 578.396, -79.615, -1339.890, 1274.260, 20.385},
        {"Caligula's Palace", 2087.390, 1543.230, -89.084, 2437.390, 1703.230, 110.916},
        {"Royal Casino", 2087.390, 1383.230, -89.084, 2437.390, 1543.230, 110.916},
        {"Richman", 72.648, -1235.070, -89.084, 321.356, -1008.150, 110.916},
        {"Starfish Casino", 2437.390, 1783.230, -89.084, 2685.160, 2012.180, 110.916},
        {"Mulholland", 1281.130, -452.425, -89.084, 1641.130, -290.913, 110.916},
        {"Downtown", -1982.320, 744.170, -6.1, -1871.720, 1274.260, 200.000},
        {"Hankypanky Point", 2576.920, 62.158, 0.000, 2759.250, 385.503, 200.000},
        {"K.A.C.C. Military Fuels", 2498.210, 2626.550, -89.084, 2749.900, 2861.550, 110.916},
        {"Harry Gold Parkway", 1777.390, 863.232, -89.084, 1817.390, 2342.830, 110.916},
        {"Bayside Tunnel", -2290.190, 2548.290, -89.084, -1950.190, 2723.290, 110.916},
        {"Ocean Docks", 2324.000, -2302.330, -89.084, 2703.580, -2145.100, 110.916},
        {"Richman", 321.356, -1044.070, -89.084, 647.557, -860.619, 110.916},
        {"Randolph Industrial Estate", 1558.090, 596.349, -89.084, 1823.080, 823.235, 110.916},
        {"East Beach", 2632.830, -1852.870, -89.084, 2959.350, -1668.130, 110.916},
        {"Flint Water", -314.426, -753.874, -89.084, -106.339, -463.073, 110.916},
        {"Blueberry", 19.607, -404.136, 3.8, 349.607, -220.137, 200.000},
        {"Linden Station", 2749.900, 1198.990, -89.084, 2923.390, 1548.990, 110.916},
        {"Glen Park", 1812.620, -1350.720, -89.084, 2056.860, -1100.820, 110.916},
        {"Downtown", -1993.280, 265.243, -9.1, -1794.920, 578.396, 200.000},
        {"Redsands West", 1377.390, 2243.230, -89.084, 1704.590, 2433.230, 110.916},
        {"Richman", 321.356, -1235.070, -89.084, 647.522, -1044.070, 110.916},
        {"Gant Bridge", -2741.450, 1659.680, -6.1, -2616.400, 2175.150, 200.000},
        {"Lil' Probe Inn", -90.218, 1286.850, -3.0, 153.859, 1554.120, 200.000},
        {"Flint Intersection", -187.700, -1596.760, -89.084, 17.063, -1276.600, 110.916},
        {"Las Colinas", 2281.450, -1135.040, -89.084, 2632.740, -945.035, 110.916},
        {"Sobell Rail Yards", 2749.900, 1548.990, -89.084, 2923.390, 1937.250, 110.916},
        {"The Emerald Isle", 2011.940, 2202.760, -89.084, 2237.400, 2508.230, 110.916},
        {"El Castillo del Diablo", -208.570, 2123.010, -7.6, 114.033, 2337.180, 200.000},
        {"Santa Flora", -2741.070, 458.411, -7.6, -2533.040, 793.411, 200.000},
        {"Playa del Seville", 2703.580, -2126.900, -89.084, 2959.350, -1852.870, 110.916},
        {"Market", 926.922, -1577.590, -89.084, 1370.850, -1416.250, 110.916},
        {"Queens", -2593.440, 54.722, 0.000, -2411.220, 458.411, 200.000},
        {"Pilson Intersection", 1098.390, 2243.230, -89.084, 1377.390, 2507.230, 110.916},
        {"Spinybed", 2121.400, 2663.170, -89.084, 2498.210, 2861.550, 110.916},
        {"Pilgrim", 2437.390, 1383.230, -89.084, 2624.400, 1783.230, 110.916},
        {"Blackfield", 964.391, 1403.220, -89.084, 1197.390, 1726.220, 110.916},
        {"'The Big Ear'", -410.020, 1403.340, -3.0, -137.969, 1681.230, 200.000},
        {"Dillimore", 580.794, -674.885, -9.5, 861.085, -404.790, 200.000},
        {"El Quebrados", -1645.230, 2498.520, 0.000, -1372.140, 2777.850, 200.000},
        {"Esplanade North", -2533.040, 1358.900, -4.5, -1996.660, 1501.210, 200.000},
        {"Easter Bay Airport", -1499.890, -50.096, -1.0, -1242.980, 249.904, 200.000},
        {"Fisher's Lagoon", 1916.990, -233.323, -100.000, 2131.720, 13.800, 200.000},
        {"Mulholland", 1414.070, -768.027, -89.084, 1667.610, -452.425, 110.916},
        {"East Beach", 2747.740, -1498.620, -89.084, 2959.350, -1120.040, 110.916},
        {"San Andreas Sound", 2450.390, 385.503, -100.000, 2759.250, 562.349, 200.000},
        {"Shady Creeks", -2030.120, -2174.890, -6.1, -1820.640, -1771.660, 200.000},
        {"Market", 1072.660, -1416.250, -89.084, 1370.850, -1130.850, 110.916},
        {"Rockshore West", 1997.220, 596.349, -89.084, 2377.390, 823.228, 110.916},
        {"Prickle Pine", 1534.560, 2583.230, -89.084, 1848.400, 2863.230, 110.916},
        {"Easter Basin", -1794.920, -50.096, -1.04, -1499.890, 249.904, 200.000},
        {"Leafy Hollow", -1166.970, -1856.030, 0.000, -815.624, -1602.070, 200.000},
        {"LVA Freight Depot", 1457.390, 863.229, -89.084, 1777.400, 1143.210, 110.916},
        {"Prickle Pine", 1117.400, 2507.230, -89.084, 1534.560, 2723.230, 110.916},
        {"Blueberry", 104.534, -220.137, 2.3, 349.607, 152.236, 200.000},
        {"El Castillo del Diablo", -464.515, 2217.680, 0.000, -208.570, 2580.360, 200.000},
        {"Downtown", -2078.670, 578.396, -7.6, -1499.890, 744.267, 200.000},
        {"Rockshore East", 2537.390, 676.549, -89.084, 2902.350, 943.235, 110.916},
        {"San Fierro Bay", -2616.400, 1501.210, -3.0, -1996.660, 1659.680, 200.000},
        {"Paradiso", -2741.070, 793.411, -6.1, -2533.040, 1268.410, 200.000},
        {"The Camel's Toe", 2087.390, 1203.230, -89.084, 2640.400, 1383.230, 110.916},
        {"Old Venturas Strip", 2162.390, 2012.180, -89.084, 2685.160, 2202.760, 110.916},
        {"Juniper Hill", -2533.040, 578.396, -7.6, -2274.170, 968.369, 200.000},
        {"Juniper Hollow", -2533.040, 968.369, -6.1, -2274.170, 1358.900, 200.000},
        {"Roca Escalante", 2237.400, 2202.760, -89.084, 2536.430, 2542.550, 110.916},
        {"Julius Thruway East", 2685.160, 1055.960, -89.084, 2749.900, 2626.550, 110.916},
        {"Verona Beach", 647.712, -2173.290, -89.084, 930.221, -1804.210, 110.916},
        {"Foster Valley", -2178.690, -599.884, -1.2, -1794.920, -324.114, 200.000},
        {"Arco del Oeste", -901.129, 2221.860, 0.000, -592.090, 2571.970, 200.000},
        {"Fallen Tree", -792.254, -698.555, -5.3, -452.404, -380.043, 200.000},
        {"The Farm", -1209.670, -1317.100, 114.981, -908.161, -787.391, 251.981},
        {"The Sherman Dam", -968.772, 1929.410, -3.0, -481.126, 2155.260, 200.000},
        {"Esplanade North", -1996.660, 1358.900, -4.5, -1524.240, 1592.510, 200.000},
        {"Financial", -1871.720, 744.170, -6.1, -1701.300, 1176.420, 300.000},
        {"Garcia", -2411.220, -222.589, -1.14, -2173.040, 265.243, 200.000},
        {"Montgomery", 1119.510, 119.526, -3.0, 1451.400, 493.323, 200.000},
        {"Creek", 2749.900, 1937.250, -89.084, 2921.620, 2669.790, 110.916},
        {"Los Santos International", 1249.620, -2394.330, -89.084, 1852.000, -2179.250, 110.916},
        {"Santa Maria Beach", 72.648, -2173.290, -89.084, 342.648, -1684.650, 110.916},
        {"Mulholland Intersection", 1463.900, -1150.870, -89.084, 1812.620, -768.027, 110.916},
        {"Angel Pine", -2324.940, -2584.290, -6.1, -1964.220, -2212.110, 200.000},
        {"Verdant Meadows", 37.032, 2337.180, -3.0, 435.988, 2677.900, 200.000},
        {"Octane Springs", 338.658, 1228.510, 0.000, 664.308, 1655.050, 200.000},
        {"Come-A-Lot", 2087.390, 943.235, -89.084, 2623.180, 1203.230, 110.916},
        {"Redsands West", 1236.630, 1883.110, -89.084, 1777.390, 2142.860, 110.916},
        {"Santa Maria Beach", 342.648, -2173.290, -89.084, 647.712, -1684.650, 110.916},
        {"Verdant Bluffs", 1249.620, -2179.250, -89.084, 1692.620, -1842.270, 110.916},
        {"Las Venturas Airport", 1236.630, 1203.280, -89.084, 1457.370, 1883.110, 110.916},
        {"Flint Range", -594.191, -1648.550, 0.000, -187.700, -1276.600, 200.000},
        {"Verdant Bluffs", 930.221, -2488.420, -89.084, 1249.620, -2006.780, 110.916},
        {"Palomino Creek", 2160.220, -149.004, 0.000, 2576.920, 228.322, 200.000},
        {"Ocean Docks", 2373.770, -2697.090, -89.084, 2809.220, -2330.460, 110.916},
        {"Easter Bay Airport", -1213.910, -50.096, -4.5, -947.980, 578.396, 200.000},
        {"Whitewood Estates", 883.308, 1726.220, -89.084, 1098.310, 2507.230, 110.916},
        {"Calton Heights", -2274.170, 744.170, -6.1, -1982.320, 1358.900, 200.000},
        {"Easter Basin", -1794.920, 249.904, -9.1, -1242.980, 578.396, 200.000},
        {"Los Santos Inlet", -321.744, -2224.430, -89.084, 44.615, -1724.430, 110.916},
        {"Doherty", -2173.040, -222.589, -1.0, -1794.920, 265.243, 200.000},
        {"Mount Chiliad", -2178.690, -2189.910, -47.917, -2030.120, -1771.660, 576.083},
        {"Fort Carson", -376.233, 826.326, -3.0, 123.717, 1220.440, 200.000},
        {"Foster Valley", -2178.690, -1115.580, 0.000, -1794.920, -599.884, 200.000},
        {"Ocean Flats", -2994.490, -222.589, -1.0, -2593.440, 277.411, 200.000},
        {"Fern Ridge", 508.189, -139.259, 0.000, 1306.660, 119.526, 200.000},
        {"Bayside", -2741.070, 2175.150, 0.000, -2353.170, 2722.790, 200.000},
        {"Las Venturas Airport", 1457.370, 1203.280, -89.084, 1777.390, 1883.110, 110.916},
        {"Blueberry Acres", -319.676, -220.137, 0.000, 104.534, 293.324, 200.000},
        {"Palisades", -2994.490, 458.411, -6.1, -2741.070, 1339.610, 200.000},
        {"North Rock", 2285.370, -768.027, 0.000, 2770.590, -269.740, 200.000},
        {"Hunter Quarry", 337.244, 710.840, -115.239, 860.554, 1031.710, 203.761},
        {"Los Santos International", 1382.730, -2730.880, -89.084, 2201.820, -2394.330, 110.916},
        {"Missionary Hill", -2994.490, -811.276, 0.000, -2178.690, -430.276, 200.000},
        {"San Fierro Bay", -2616.400, 1659.680, -3.0, -1996.660, 2175.150, 200.000},
        {"Restricted Area", -91.586, 1655.050, -50.000, 421.234, 2123.010, 250.000},
        {"Mount Chiliad", -2997.470, -1115.580, -47.917, -2178.690, -971.913, 576.083},
        {"Mount Chiliad", -2178.690, -1771.660, -47.917, -1936.120, -1250.970, 576.083},
        {"Easter Bay Airport", -1794.920, -730.118, -3.0, -1213.910, -50.096, 200.000},
        {"The Panopticon", -947.980, -304.320, -1.1, -319.676, 327.071, 200.000},
        {"Shady Creeks", -1820.640, -2643.680, -8.0, -1226.780, -1771.660, 200.000},
        {"Back o Beyond", -1166.970, -2641.190, 0.000, -321.744, -1856.030, 200.000},
        {"Mount Chiliad", -2994.490, -2189.910, -47.917, -2178.690, -1115.580, 576.083}
    }
    for i, v in ipairs(Zones) do
        if (x >= v[2]) and (y >= v[3]) and (z >= v[4]) and (x <= v[5]) and (y <= v[6]) and (z <= v[7]) then
            return v[1]
        end
    end
    return "unknown"
end

function getCity(x, y, z)
    local Cities = {
        {"Las Venturas", 685.0, 476.093, -500.0, 3000.0, 3000.0, 500.0},
        {"Las Venturas", 869.461, 596.349, -242.990, 2997.060, 2993.870, 900.000},
        {"San Fierro", -3000.0, -742.306, -500.0, -1270.53, 1530.24, 500.0},
        {"San Fierro", -1270.53, -402.481, -500.0, -1038.45, 832.495, 500.0},
        {"San Fierro", -1038.45, -145.539, -500.0, -897.546, 376.632, 500.0},
        {"San Fierro", -2997.470, -1115.580, -242.990, -1213.910, 1659.680, 900.000},
        {"Los Santos", 480.0, -3000.0, -500.0, 3000.0, -850.0, 500.0},
        {"Los Santos", 80.0, -2101.61, -500.0, 1075.0, -1239.61, 500.0},
        {"Los Santos", 44.615, -2892.970, -242.990, 2997.060, -768.027, 900.000},
        {"Tierra Robada", -1213.91, 596.349, -242.99, -480.539, 1659.68, 900.0},
        {"Tierra Robada", -2997.470, 1659.680, -242.990, -480.539, 2993.870, 900.000},
        {"Red County", -1213.91, -768.027, -242.99, 2997.06, 596.349, 900.0},
        {"Flint County", -1213.91, -2892.97, -242.99, 44.6147, -768.027, 900.0},
        {"Whetstone", -2997.47, -2892.97, -242.99, -1213.91, -1115.58, 900.0},
        {"Bone County", -480.539, 596.349, -242.990, 869.461, 2993.870, 900.000}
    }
    for i, v in ipairs(Cities) do
        if (x >= v[2]) and (y >= v[3]) and (z >= v[4]) and (x <= v[5]) and (y <= v[6]) and (z <= v[7]) then
            return v[1]
        end
    end
    return "unknown"
end

function direction(h)
    if doesCharExist(h) then
        local angel = math.ceil(getCharHeading(h))
        if angel then
            if (angel >= 0 and angel <= 30) or (angel <= 360 and angel >= 330) then
                return "�����"
            elseif (angel > 80 and angel < 100) then
                    return "�����"
            elseif (angel > 260 and angel < 280) then
                    return "������"
            elseif (angel >= 170 and angel <= 190) then
                    return "��"
            elseif (angel >= 31 and angel <= 79) then
                    return "������-�����"
            elseif (angel >= 191 and angel <= 259) then
                    return "���-������"
            elseif (angel >= 81 and angel <= 169) then
                    return "���-�����"
            elseif (angel >= 259 and angel <= 329) then
                    return "������-������"
            else
                return angel
            end
        else
            return "����������"
        end
    else
        return "����������"
    end
end

function getCarColorName(handle)
    local names = {
        {{1, 41},"������"},
        {{2},"�����"},
        {{3},"�������-�����"},
        {{4},"�������"},
        {{5},"�������"},
        {{6},"��������� ������-���������"},
        {{7},"������"},
        {{8, 136},"��������� �����"},
        {{9, 139},"������-�����"},
        {{10, 48, 251},"��������� �����"},
        {{11},"��������� �����"},
        {{12},"������������-���������"},
        {{13, 60, 101},"���������-�����"},
        {{14},"���� ������� ��������"},
        {{15},"������� �����"},
        {{16},"����� �����������"},
        {{17, 92},"����� ������"},
        {{18, 43, 59, 83, 125, 182, 213},"��������-�������"},
        {{19, 71, 116, 118, 122},"������������-���������"},
        {{20, 70, 77, 90},"������������� ������-�����"},
        {{21, 29, 205},"���������-�����"},
        {{22},"���������-����������"},
        {{23, 89, 243},"�����-�������"},
        {{24, 51, 97, 121},"����� �������"},
        {{25},"����������-�����"},
        {{26, 255},"������ ��������-������"},
        {{27, 91},"�������� �����"},
        {{28, 123},"������-�����"},
        {{30, 39, 61, 197},"���������� �����"},
        {{31},"�����-�������"},
        {{32},"�����-���������"},
        {{33},"���� ����������"},
        {{34, 254},"������-�����"},
        {{35},"����������-�����"},
        {{36},"������ ����������-�����"},
        {{37, 206},"��������-������"},
        {{38},"������ ����������-�����-�������"},
        {{40, 68, 72, 98},"������-����� �����"},
        {{42},"��������-�����"},
        {{44},"������� ���"},
        {{45},"������ ����-��������-�������"},
        {{46, 133, 225},"������-����������"},
        {{47},"����-�������"},
        {{49},"������������� �����-�����"},
        {{50},"����������"},
        {{52},"�������� �������"},
        {{53, 110},"��������-�����"},
        {{54},"������-�����"},
        {{55, 96, 117, 204, 256},"��������� ����"},
        {{56},"����������-�����"},
        {{57},"����� ����"},
        {{58, 105},"�����-�����"},
        {{62},"������� ����-���������"},
        {{63},"������ �������"},
        {{64, 74, 112},"����������-�����"},
        {{65},"����-�����������"},
        {{66, 196},"��������� �����-�������"},
        {{67},"������ ����-������-����������"},
        {{69},"�������� �����"},
        {{73},"�����-�����"},
        {{75, 231},"�������� ����������"},
        {{76},"����� �����"},
        {{78},"������� ����������-�����"},
        {{79},"���������-�������"},
        {{80},"������������ �����"},
        {{81},"�������� ������-���������"},
        {{82},"��������-�����-�������"},
        {{84},"��������"},
        {{85},"��������� �����"},
        {{86},"������-����������"},
        {{87},"�������������-�������"},
        {{88, 247},"������ ����"},
        {{93, 186},"�����"},
        {{94},"���������� ����������-�����"},
        {{95},"�����-���������"},
        {{99},"��������-�����"},
        {{100},"������� ����-����������"},
        {{102},"������������� ��������"},
        {{103},"��������"},
        {{104, 210},"�����-��������"},
        {{106},"������� �����"},
        {{107},"���� ������� ����"},
        {{108},"������������� ������-�����"},
        {{109, 209},"���� ��������"},
        {{111, 219},"������� ��������� �����"},
        {{113},"�����-���������"},
        {{114},"���������-����������"},
        {{115},"���������"},
        {{119},"�������"},
        {{120},"��������-���������"},
        {{124},"�����-����������"},
        {{126},"����������"},
        {{127},"�������� �������"},
        {{128, 134},"����������-������"},
        {{129, 230},"��������� �������"},
        {{130},"���������-�������"},
        {{131},"�������-�����"},
        {{132},"������ ���������-����������"},
        {{135},"���������� �����"},
        {{137},"��������� ������"},
        {{138},"������� �������"},
        {{140},"������ �������-�����"},
        {{141, 194},"������ ��������"},
        {{142},"��������-�����"},
        {{143},"���������� �����-�������"},
        {{144, 145},"����-���������"},
        {{146},"��������� ���������-�������"},
        {{147, 179, 238},"��������� ���������"},
        {{148, 185},"������-���������"},
        {{149},"�����������-������"},
        {{150},"����������-������"},
        {{151},"��������-������"},
        {{152},"������� ���"},
        {{153, 163},"���������-����� �������"},
        {{154},"��������-�������"},
        {{155},"������� ����"},
        {{156},"������� ������� ������� 90-�� ����"},
        {{157},"������-�������"},
        {{158},"������� �����"},
        {{159, 223},"������ ������-���������"},
        {{160},"������ ��������-����������"},
        {{161},"��������-������"},
        {{162},"��������-��������-�������"},
        {{164},"������� ����� �������"},
        {{165},"�����-�����"},
        {{166},"���������� ��������-�������"},
        {{167, 199},"����� �����"},
        {{168},"�����������������"},
        {{169},"���� ��������� ������"},
        {{170},"������� ��������-�����"},
        {{171},"������������-����������"},
        {{172},"���������� ����������"},
        {{173},"���������-�������"},
        {{174},"������ ����������"},
        {{175},"������� ����������"},
        {{176},"�������-�������"},
        {{177},"�������� �������"},
        {{178},"���������� ����������"},
        {{180, 250},"��������-����������"},
        {{181},"��������� ����������"},
        {{183, 184},"����� ������"},
        {{187, 216},"������ ������"},
        {{188, 235},"����� �������� �����-�������"},
        {{189, 190, 207, 237},"����� ������ �������"},
        {{191},"������ ��������"},
        {{192},"�������"},
        {{193},"������� �����"},
        {{195, 229},"������ ����������-������"},
        {{198},"������-����������"},
        {{200},"����� ������ ����"},
        {{201},"������� �����"},
        {{202},"�����������-�����"},
        {{203},"��������������� �������"},
        {{208},"����-�������"},
        {{211},"������������� ������"},
        {{212},"��������-�����"},
        {{214},"��������"},
        {{215},"��������-���������"},
        {{217},"������������"},
        {{218},"������� ����������-�����"},
        {{220},"���� ����������"},
        {{221},"���������� ������-���������"},
        {{222},"���� ������"},
        {{224},"�����-�����"},
        {{226},"������ ���������-�������"},
        {{227, 242},"��������"},
        {{228},"�����-�������"},
        {{232},"����������� �����"},
        {{233},"����� ���������"},
        {{234},"��������"},
        {{236},"����� ������ ���������"},
        {{239},"���������-�������"},
        {{240},"���������� ����������"},
        {{241},"��������� ����������-�����"},
        {{244},"���������-�������"},
        {{245},"������ ������-����������"},
        {{246},"����� ������ �����-�������"},
        {{248},"������������"},
        {{249},"��������"},
        {{252},"�����-�������"},
        {{253},"�����"},
    }
    local c1,c2 = getCarColours(handle)
    local name = ''
    for _,v in ipairs(names) do
        v[2] = v[2]:gsub('��$','���')
        for _,vv in ipairs(v[1]) do
            if c1 == c2 and c1 == vv-1 then;   return v[2];   end
            if c1 == vv-1 then; name = v[2]; end
            if name ~= '' and c2 == vv-1 then 
                name = name .. ' ' .. v[2]
            end
        end
    end
    return name
end