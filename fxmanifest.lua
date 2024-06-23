fx_version "cerulean"
game "gta5"

lua54 "yes"

track_version '1'

dependency "chat"  

loadscreen_manual_shutdown 'yes'

resource_type 'gametype' { name = 'Race' }

shared_scripts {
    "shared/**/*.lua",
    "lib/tracks/*.lua"
}

client_scripts {
    "lib/*.lua",
    "client/race.lua"
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
    "html/js/*.js",
    "html/reset.css",
    "html/css/*.css",
    "config.json"
}

export {
    'RaceState',
    'UpdateVehicleName'
}