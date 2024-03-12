fx_version "cerulean"
game "gta5"

lua54 "yes"

dependency "chat"  

loadscreen_manual_shutdown 'yes'

resource_type 'gametype' { name = 'Race' }

shared_scripts {
    "shared/**/*.lua"
}

client_scripts {
    "lib/*.lua",
    "client/race.lua",
    "client/editor.lua"
}

server_scripts {
    "lib/mapManager.lua",
    "server/*.lua"
}

ui_page "html/index.html"
files {
    "html/index.css",
    "html/index.html",
    "html/index.js",
    "html/js/leaderboard.js",
    "html/reset.css",
    "html/css/leaderboard.css",
    "config.json"
}

export {
    'RaceActive'
}