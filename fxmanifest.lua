fx_version 'cerulean'
game 'gta5'

author 'NukepugDesigns'
description 'Premium Nitrous Oxide (NOS) System'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locale/en.lua',
    'locale/nl.lua',
    'locale/locale.lua'
}

client_scripts {
    'bridge/client.lua',
    'cl_main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'sv_main.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
