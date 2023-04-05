libs = {
    {
        saveTo = '/lib',
        repo = 'THE-FYP/SAMP.Lua', 
        files = {
            ["samp.events"] = "samp/events.lua",
            ["samp.events.bitstream_io"] = "samp/events/bitstream_io.lua",
            ["samp.events.core"] = "samp/events/core.lua",
            ["samp.events.extra_types"] = "samp/events/extra_types.lua",
            ["samp.events.handlers"] = "samp/events/handlers.lua",
            ["samp.events.utils"] = "samp/events/utils.lua",
            ["samp.raknet"] = "samp/raknet.lua",
            ["samp.synchronization"] = "samp/synchronization.lua",
        },
    },

    {
        saveTo = '/lib',
        repo = 'lunarmodules/luasocket', 
        files = {
            ['socket.http'] = 'src/http.lua',
            ['socket.headers'] = 'src/headers.lua',
            ['socket.ftp'] = 'src/ftp.lua',
            ['socket.smtp'] = 'src/smtp.lua',
            ['socket.tp'] = 'src/tp.lua',
            ['socket.url'] = 'src/url.lua',

            ['mime'] = 'src/mime.lua',
            ['ltn12'] = 'src/ltn12.lua',
        },
    },

    {
        saveTo = '/lib',
        repo = 'v3sp4n/pie-binder', 
        files = {
            ['imgui_piemenu(for pie binder)'] = 'lib/imgui_piemenu(for pie binder).lua',

            ['MoonImGui'] = 'lib/MoonImGui.dll',
            ['imgui'] = 'lib/imgui.lua',

            ['socket.core'] = 'lib/socket/core.dll',
        },
    },
}

function main()
    while not isSampAvailable() do wait(0) end

    local d = -1
    for _,r in ipairs(libs) do
        for k,v in pairs(r.files) do
            local file = getWorkingDirectory() .. r.saveTo .. '/' .. k:gsub('%.','/') .. v:match('(%.%S+)$')
            if k:find('%.') then
                createDirectory(file:match('(.+)/.+%.%S+$'))
            end

            if not doesFileExist(file) then
                d = (d == -1 and 0 or d)
                d = d + 1
                downloadUrlToFile('https://raw.githubusercontent.com/'..r.repo..'/master/' .. v,
                    file,
                    function(_,s) 
                        if s == 58 then
                            d = d - 1
                            print('successful download',v,r.repo,file)
                        end
                    end
                )
            else
                --
            end
        end
    end
    if d == -1 then goto s end
    while (d~=0) do wait(0) end
    wait(500);
    reloadScripts()
    ::s::
    wait(5000)
    os.remove(thisScript().path)
end
