fx_version "cerulean"
game "gta5"

lua54 "yes"

dependency "chat"  

shared_scripts {
    "shared/*.lua"
}

client_script {
    "lib/*.lua",
    "client/race.lua",
    "client/editor.lua"
}

server_scripts {
    "server/races.lua"
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