local harmux = require("harmux")
local popup = require("plenary.popup")
local utils = require("harmux.utils")
local log = require("harmux.dev").log
local tmux = require("harmux.tmux")

local M = {}

Harmux_cmd_win_id = nil
Harmux_cmd_bufh = nil

local function close_menu(force_save)
    force_save = force_save or false
    local global_config = harmux.get_global_settings()

    if global_config.save_on_toggle or force_save then
        require("harmux.ui").on_menu_save()
    end

    vim.api.nvim_win_close(Harmux_cmd_win_id, true)

    Harmux_cmd_win_id = nil
    Harmux_cmd_bufh = nil
end

local function create_window()
    log.trace("_create_window()")
    local config = harmux.get_menu_config()
    local width = config.width or 60
    local height = config.height or 10
    local borderchars = config.borderchars
        or { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }
    local bufnr = vim.api.nvim_create_buf(false, false)

    local Harmux_cmd_win_id, win = popup.create(bufnr, {
        title = "Harmux Commands",
        highlight = "HarmuxWindow",
        line = math.floor(((vim.o.lines - height) / 2) - 1),
        col = math.floor((vim.o.columns - width) / 2),
        minwidth = width,
        minheight = height,
        borderchars = borderchars,
    })

    vim.api.nvim_win_set_option(
        win.border.win_id,
        "winhl",
        "Normal:HarmuxBorder"
    )

    return {
        bufnr = bufnr,
        win_id = Harmux_cmd_win_id,
    }
end

local function get_menu_items()
    log.trace("_get_menu_items()")
    local lines = vim.api.nvim_buf_get_lines(Harmux_cmd_bufh, 0, -1, true)
    local indices = {}

    for _, line in pairs(lines) do
        if not utils.is_white_space(line) then
            table.insert(indices, line)
        end
    end

    return indices
end

function M.toggle_quick_menu()
    log.trace("ui#toggle_quick_menu()")
    if
        Harmux_cmd_win_id ~= nil
        and vim.api.nvim_win_is_valid(Harmux_cmd_win_id)
    then
        close_menu()
        return
    end

    local win_info = create_window()
    local contents = {}
    local global_config = harmux.get_global_settings()

    Harmux_cmd_win_id = win_info.win_id
    Harmux_cmd_bufh = win_info.bufnr

    for idx, cmd in pairs(harmux.get_cmds_config()) do
        contents[idx] = cmd
    end

    vim.api.nvim_win_set_option(Harmux_cmd_win_id, "number", true)
    vim.api.nvim_buf_set_name(Harmux_cmd_bufh, "harmux-cmd-menu")
    vim.api.nvim_buf_set_lines(Harmux_cmd_bufh, 0, #contents, false, contents)
    vim.api.nvim_buf_set_option(Harmux_cmd_bufh, "filetype", "harmux")
    vim.api.nvim_buf_set_option(Harmux_cmd_bufh, "buftype", "acwrite")
    vim.api.nvim_buf_set_option(Harmux_cmd_bufh, "bufhidden", "delete")
    vim.api.nvim_buf_set_keymap(
        Harmux_cmd_bufh,
        "n",
        "q",
        "<Cmd>lua require('harmux.ui').toggle_quick_menu()<CR>",
        { silent = true }
    )
    vim.api.nvim_buf_set_keymap(
        Harmux_cmd_bufh,
        "n",
        "<ESC>",
        "<Cmd>lua require('harmux.ui').toggle_quick_menu()<CR>",
        { silent = true }
    )
    vim.api.nvim_buf_set_keymap(
        Harmux_cmd_bufh,
        "n",
        "<CR>",
        "<Cmd>lua require('harmux.ui').select_menu_item(false)<CR>",
        {}
    )
    vim.api.nvim_buf_set_keymap(
        Harmux_cmd_bufh,
        "n",
        "<space><space>",
        "<Cmd>lua require('harmux.ui').select_menu_item(true)<CR>",
        {}
    )
    vim.cmd(
        string.format(
            "autocmd BufWriteCmd <buffer=%s> lua require('harmux.ui').on_menu_save()",
            Harmux_cmd_bufh
        )
    )
    if global_config.save_on_change then
        vim.cmd(
            string.format(
                "autocmd TextChanged,TextChangedI <buffer=%s> lua require('harmux.ui').on_menu_save()",
                Harmux_cmd_bufh
            )
        )
    end
    vim.cmd(
        string.format(
            "autocmd BufModifiedSet <buffer=%s> set nomodified",
            Harmux_cmd_bufh
        )
    )
end

function M.select_menu_item(confirm)
    log.trace("ui#select_menu_item()")
    local cmd = vim.fn.line(".")

    if type(cmd) == "number" then
        cmd = harmux.get_cmds_config()[cmd]
    end

    local default_target = harmux.get_target_config()
    close_menu(true)
	local target = default_target
	if confirm then
		target = vim.fn.input({prompt="Run '" .. cmd .. "', Tmux pane (default to " .. default_target .. "): ", cancelreturn=-1})
		if target == -1 then
			return
		end
		if target == "" then
			target = default_target
		end
    end
	harmux.set_target_config(target)
    tmux.send_command(cmd, target)
end

function M.on_menu_save()
    log.trace("ui#on_menu_save()")
    tmux.set_cmd_list(get_menu_items())
end

return M
