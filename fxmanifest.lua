fx_version 'cerulean'
game 'gta5'

author 'Distortionz'
description 'Distortionz Money Laundering - Dirty money cleaning system for Qbox/Ox servers'
version '1.0.2'

lua54 'yes'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua',
    'version_check.lua'
}

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory'
}