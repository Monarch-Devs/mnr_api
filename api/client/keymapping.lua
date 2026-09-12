---@technicaldebt Keymapping removal can't be implemented in Legacy because UnregisterKeyMapping is only available in Enhanced

---@class MnrKeymapping
local MnrKeymapping = {}
MnrKeymapping.__index = MnrKeymapping

function MnrKeymapping:new(data)
    local self = setmetatable({}, MnrKeymapping)

    self.name = data.name
    self.description = data.description
    self.default = { device = data.default.device, control = data.default.control }
    self.secondary = data.secondary and { device = data.secondary.device, control = data.secondary.control } or nil
    self.warning = data.warning or false
    self.pausemenu = data.pausemenu or false
    self.active = data.active ~= false

    ---@note bitwise transformation [[https://github.com/citizenfx/fivem/blob/0d8a2a6f78a9922445d8930305af82a7b1826980/code/components/gta-core-five/src/GameInput.cpp#L1152]]
    self._1sthash = joaat(('+%s'):format(self.name)) | 0x80000000
    self._2ndhash = self.secondary and joaat(('~!+%s'):format(self.name)) | 0x80000000 or nil

    self._pressed = false

    self.onPressed = data.onPressed
    self.onReleased = data.onReleased

    self:_register()

    return self
end

function MnrKeymapping:_available()
    if not self.active then
        return false
    end

    if not self.pausemenu and IsPauseMenuActive() then
        return false
    end

    return true
end

function MnrKeymapping:_press()
    if not self:_available() then return end
    if self._pressed then return end

    self._pressed = true

    if self.onPressed then
        self:onPressed()
    end
end

function MnrKeymapping:_release()
    if not self._pressed then return end

    self._pressed = false

    if not self:_available() then return end

    if self.onReleased then
        self:onReleased()
    end
end

function MnrKeymapping:_register()
    RegisterCommand(('+%s'):format(self.name), function()
        self:_press()
    end, false)

    RegisterCommand(('-%s'):format(self.name), function()
        self:_release()
    end, false)

    RegisterKeyMapping(('+%s'):format(self.name), self.description, self.default.device, self.default.control)

    if self.secondary then
        RegisterKeyMapping(('~!+%s'):format(self.name), self.description, self.secondary.device, self.secondary.control)
    end
end

function MnrKeymapping:pressed()
    return self._pressed
end

function MnrKeymapping:current()
    return GetControlInstructionalButton(0, self._1sthash, true), self._2ndhash and GetControlInstructionalButton(0, self._2ndhash, true) or nil
end

function MnrKeymapping:toggle(enable)
    if self.active == enable then return end

    self.active = enable

    if not enable and self._pressed then
        self:_release()
    end
end

---@type MnrKeymappingAPI
local function keymapping(data)
    if data.warning then
        local success, err = exports.mnr_api:RegisterControl(data)
        if not success then
            error(err, 2)
        end
    end

    return MnrKeymapping:new(data)
end

return keymapping