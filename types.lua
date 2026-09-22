---@alias MnrDebugLevel 'debug' | 'info' | 'warn' | 'error'| 'fatal'

---@alias MnrDebugAPI fun(level: MnrDebugLevel, text: string, ...: any)
---@alias MnrKeymappingAPI fun(data: MnrKeymappingOptions): MnrKeymapping
---@alias MnrI18NAPI fun(key: string, ...: any): string?

---@class MnrKeymappingOptions
---@field name string
---@field description string
---@field default MnrControlSettings
---@field secondary MnrControlSettings
---@field warning boolean
---@field pausemenu boolean
---@field active boolean
---@field onPressed fun(self: self)
---@field onReleased fun(self: self)

---@class MnrControlSettings
---@field device string
---@field control string

---@class MnrKeymapping
---@field name string
---@field description string
---@field default MnrControlSettings
---@field secondary MnrControlSettings
---@field warning boolean
---@field pausemenu boolean
---@field active boolean
---@field onPressed fun(self: self)
---@field onReleased fun(self: self)
---@field pressed fun(self: self): boolean
---@field current fun(self: self): string, string?
---@field toggle fun(self: self, enable: boolean)
---@field _1sthash number
---@field _2ndhash number?
---@field _pressed boolean
---@field _available fun(self: self): boolean
---@field _press fun(self: self)
---@field _release fun(self: self)
---@field _register fun(self: self)

---@class MnrControlsAPI
---@field enable fun(control: number)
---@field disable fun(control: number)

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

---@class TypecheckDefinition
---@field expected string
---@field required? boolean
---@field defaults? any

---@alias MnrImportAPI fun(path: string, ext: 'lua'|'json', cache?: boolean, env?: table): any

---@class MnrNumAPI
---@field clamp fun(value: number, min: number, max: number): number

---@class MnrTimestampAPI
---@field unix fun(value: string): integer                                                                      Parses a DATE or DATETIME string into a Unix timestamp using the host's local time
---@field string fun(unix: integer, withTime?: boolean): string                                                 Formats a Unix timestamp back into a DATE or DATETIME string using the host's local time

---@class MnrTypecheckAPI
---@field single fun(value: any, definition: TypecheckDefinition): any?, string?
---@field schema fun(input: table, schema: table<string, TypecheckDefinition>, output?: table): table?, string?

---@class MnrServerRPC
---@field send fun(name: string, playerId: number, timeout: number | false | nil, cb: function, ...: any)
---@field fetch fun(name: string, playerId: number, timeout: number | false | nil, ...: any): any
---@field handle fun(name: string, handler: fun(playerId: number, ...: any))

---@class MnrSharedAPI
---@field debug MnrDebugAPI
---@field i18n MnrI18NAPI
---@field import MnrImportAPI
---@field num MnrNumAPI
---@field timestamp MnrTimestampAPI
---@field typecheck MnrTypecheckAPI

---@class MnrClientAPI : MnrSharedAPI
---@field controls MnrControlsAPI
---@field keymapping MnrKeymappingAPI
---@field rpc MnrClientRPC

---@class MnrServerAPI : MnrSharedAPI
---@field cronjob fun(expression: string, callback: fun(d: osdate), options: CronjobAPIOptions): MnrCronjob
---@field rpc MnrServerRPC

---@alias MnrAPI MnrClientAPI | MnrServerAPI