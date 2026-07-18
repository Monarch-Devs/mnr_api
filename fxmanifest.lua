fx_version 'cerulean'
game 'gta5'

name 'mnr_api'
description 'Monarch Devs utilities APIs'
author 'IlMelons'
version '1.1.0'
repository 'https://github.com/Monarch-Devs/mnr_api'
checker 'https://raw.githubusercontent.com/Monarch-Devs/mnr_api/refs/heads/main/version.json'

files {
    'api.lua',
    'api/shared/*.lua',
    'api/client/*.lua',
}

client_scripts {
    'client/*.lua',
}

server_scripts {
    'server/*.lua',
}