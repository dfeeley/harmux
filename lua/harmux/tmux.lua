local harmux = require("harmux")
local log = require("harmux.dev").log
local utils = require("harmux.utils")

local M = {}

function M.goto_pane(target)
    log.trace("tmux: goto_pane(): :", target)

    target = target or harmux.get_target_config()

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

function M.emit_changed()
    log.trace("_emit_changed()")
    if harmux.get_global_settings().save_on_change then
        harmux.save()
    end
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
