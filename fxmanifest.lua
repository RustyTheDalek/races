fx_version "cerulean"
game "gta5"

lua54 "yes"

dependency "chat"

shared_scripts {
    "shared/utility.lua"
}

client_script { "client/*.lua"}

server_scripts {
    "server/*.lua",
    "port.lua"
}

ui_page "html/index.html"
files {
    "html/index.css",
    "html/index.html",
    "html/index.js",
    "html/reset.css",
    'vehicles.txt',
    'raceData.json',
    'vehicleListData.json',
    'rolesData.json'
}