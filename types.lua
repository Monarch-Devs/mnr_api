---@alias MnrDebugLevel 'debug' | 'info' | 'warn' | 'error'| 'fatal'

---@alias MnrDebugAPI fun(level: MnrDebugLevel, text: string, ...: any)

---@class CronjobAPIOptions
---@field maxDelay number

---@class MnrCronjob
---@field schedulerId number
---@field expression string
---@field stop fun(self: MnrCronjob): boolean

---@class MnrClientRPC
---@field send fun(name: string, timeout: number | false | nil, cb: function, ...: any)
---@field fetch fun(name: string, timeout: number | false | nil, ...: any): any
---@field handle fun(name: string, handler: function)

---@alias MnrImportAPI fun(path: string, ext: 'lua'|'json', cache?: boolean, env?: table): any

---@class MnrNumAPI
---@field clamp fun(value: number, min: number, max: number): number

---@class MnrServerRPC
---@field send fun(name: string, playerId: number, timeout: number | false | nil, cb: function, ...: any)
---@field fetch fun(name: string, playerId: number, timeout: number | false | nil, ...: any): any
---@field handle fun(name: string, handler: fun(playerId: number, ...: any))

---@class MnrSharedAPI
---@field debug MnrDebugAPI
---@field import MnrImportAPI
---@field num MnrNumAPI

---@class MnrClientAPI : MnrSharedAPI
---@field rpc MnrClientRPC

---@class MnrServerAPI : MnrSharedAPI
---@field cronjob fun(expression: string, callback: fun(d: osdate), options: CronjobAPIOptions): MnrCronjob
---@field rpc MnrServerRPC

---@alias MnrAPI MnrClientAPI | MnrServerAPI