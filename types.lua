---@class MnrClientRPC
---@field send fun(name: string, timeout: number | false | nil, cb: function, ...: any)
---@field fetch fun(name: string, timeout: number | false | nil, ...: any): any
---@field handle fun(name: string, handler: function)

---@alias MnrImportAPI fun(path: string, ext: 'lua'|'json', cache?: boolean, env?: table): any

---@class MnrServerRPC
---@field send fun(name: string, playerId: number, timeout: number | false | nil, cb: function, ...: any)
---@field fetch fun(name: string, playerId: number, timeout: number | false | nil, ...: any): any
---@field handle fun(name: string, handler: function)

---@class MnrClientAPI
---@field rpc MnrClientRPC

---@class MnrSharedAPI
---@field import MnrImportAPI

---@class MnrServerAPI
---@field rpc MnrServerRPC