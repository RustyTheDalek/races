fx_version "cerulean"
game "gta5"

lua54 "yes"

dependency "chat"

client_script {
    "client/race.lua",
    "client/editor.lua"
}

server_scripts {
    "server/races.lua",
    "port.lua"
}

ui_page "html/index.html"
files {
    "html/index.css",
    "html/index.html",
    "html/index.js",
    "html/js/leaderboard.js",
    "html/reset.css",
    "html/css/leaderboard.css"
}