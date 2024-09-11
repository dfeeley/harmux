local harmux = require("harmux")
local log = require("harmux.dev").log
local global_config = harmux.get_global_settings()
local utils = require("harmux.utils")

local M = {}

local function get_first_empty_slot()
    log.trace("_get_first_empty_slot()")
    for idx, cmd in pairs(harmux.get_cmds_config()) do
        if cmd == "" then
            return idx
        end
    end
    return M.get_length() + 1
end

function M.gotoPane(target)
    log.trace("tmux: gotoPane(): :", target)

    local _, ret, stderr = utils.get_os_command_output({
        "tmux",
        "select-pane",
        "-t",
        target
    }, vim.loop.cwd())

    if ret ~= 0 then
        error("Failed to go to tmux pane." .. stderr[1])
    end
end

function M.send_command(cmd, target, ...)
    log.trace("tmux: send_command(): Window:", target)

    target = target or harmux.get_target_config()

    if type(cmd) == "number" then
        cmd = harmux.get_cmds_config()[cmd]
    end

    if cmd then
        log.debug("send_command:", cmd)

		harmux.set_last_cmd_config(cmd)

		cmd = cmd .. "\n"

        local _, ret, stderr = utils.get_os_command_output({
            "tmux",
            "send-keys",
            "-t",
            target,
            string.format(cmd, ...),
        }, vim.loop.cwd())

        if ret ~= 0 then
            error("Failed to send command. " .. stderr[1])
        end
    end
end

function M.send_last_cmd()
	local last_cmd = harmux.get_last_cmd_config()
	if last_cmd == nil then
		return
	end
	M.send_command(last_cmd, nil)
end

function M.get_length()
    log.trace("_get_length()")
    return table.maxn(harmux.get_cmds_config())
end

function M.valid_index(idx)
    if idx == nil or idx > M.get_length() or idx <= 0 then
        return false
    end
    return true
end

function M.emit_changed()
    log.trace("_emit_changed()")
    if harmux.get_global_settings().save_on_change then
        harmux.save()
    end
end

function M.add_cmd(cmd)
    log.trace("add_cmd()")
    local found_idx = get_first_empty_slot()
    harmux.get_cmds_config()[found_idx] = cmd
    M.emit_changed()
end

function M.rm_cmd(idx)
    log.trace("rm_cmd()")
    if not M.valid_index(idx) then
        log.debug("rm_cmd(): no cmd exists for index", idx)
        return
    end
    table.remove(harmux.get_cmds_config(), idx)
    M.emit_changed()
end

function M.set_cmd_list(new_list)
    log.trace("set_cmd_list(): New list:", new_list)
    for k in pairs(harmux.get_cmds_config()) do
        harmux.get_cmds_config()[k] = nil
    end
    for k, v in pairs(new_list) do
        harmux.get_cmds_config()[k] = v
    end
    M.emit_changed()
end

return M
