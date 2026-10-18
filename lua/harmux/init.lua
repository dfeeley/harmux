local Path = require("plenary.path")
local utils = require("harmux.utils")
local Dev = require("harmux.dev")
local log = Dev.log

local config_path = vim.fn.stdpath("config")
local data_path = vim.fn.stdpath("data")
local user_config = string.format("%s/harmux.json", config_path)
local cache_config = string.format("%s/harmux.json", data_path)


local M = {}

--[[
{
  "projects": {
    "/path/to/some/dir": {
      "cmds": [
        "make build deploy"
      ],
      "last_cmd": "make build deploy",
      "target": ".2"
    },
  },
  "global_settings": {
    "menu": {
      "width": 80,
      "height": 30
    },
    "save_on_toggle": false,
    "tabline": false,
    "excluded_filetypes": [
      "harpoon"
    ],
    "save_on_change": true,
    "tabline_suffix": "   ",
    "enter_on_sendcmd": false,
    "tabline_prefix": "   ",
    "tmux_autoclose_windows": false
  }
}
--]]

HarmuxConfig = HarmuxConfig or {}

-- tbl_deep_extend does not work the way you would think
local function merge_table_impl(t1, t2)
    for k, v in pairs(t2) do
        if type(v) == "table" then
            if type(t1[k]) == "table" then
                merge_table_impl(t1[k], v)
            else
                t1[k] = v
            end
        else
            t1[k] = v
        end
    end
end

local function merge_tables(...)
    log.trace("_merge_tables()")
    local out = {}
    for i = 1, select("#", ...) do
        merge_table_impl(out, select(i, ...))
    end
    return out
end

local function ensure_correct_config(config)
    log.trace("_ensure_correct_config()")
    local projects = config.projects
    local cmds_key = utils.project_key()
    if projects[cmds_key] == nil then
        log.debug("ensure_correct_config(): No config found for:", cmds_key)
        projects[cmds_key] = {
          cmds = { },
          target = ".1",
          last_cmd = ""
        }
    end

    local proj = projects[cmds_key]
    if proj.cmds == nil then
        log.debug("ensure_correct_config(): No marks found for", cmds_key)
        proj.cmds = {}
    end

    if proj.target == nil then
        log.debug(
            "ensure_correct_config(): No default target found for",
            cmds_key
        )
        proj.target = ".1"
    end

    if proj.last_cmd == nil then
        log.debug(
            "ensure_correct_config(): No default last_cmd found for",
            cmds_key
        )
        proj.last_cmd = ""
      end
    return config
end

function M.save()
    -- first refresh from disk everything but our project
    M.refresh_projects_b4update()

    log.trace("save(): Saving cache config to", cache_config)
    Path:new(cache_config):write(vim.fn.json_encode(HarmuxConfig), "w")
end

local function read_config(local_config)
    log.trace("_read_config():", local_config)
    return vim.json.decode(Path:new(local_config):read())
end

function M.setup(config)
    log.trace("setup(): Setting up...")

    if not config then
        config = {}
    end

    local ok, u_config = pcall(read_config, user_config)

    if not ok then
        log.debug("setup(): No user config present at", user_config)
        u_config = {}
    end

    local ok2, c_config = pcall(read_config, cache_config)

    if not ok2 then
        log.debug("setup(): No cache config present at", cache_config)
        c_config = {}
    end

    local complete_config = merge_tables({
        projects = {},
        global_settings = {
            ["menu"] = {
              ["width"] = 80,
              ["height"] = 20,
            },
            ["save_on_toggle"] = false,
            ["save_on_change"] = true,
            ["enter_on_sendcmd"] = false,
            ["tmux_autoclose_windows"] = false,
            ["excluded_filetypes"] = { "harpoon" },
            ["tabline"] = false,
            ["tabline_suffix"] = "   ",
            ["tabline_prefix"] = "   ",
        },
    }, c_config, u_config, config)

    -- There was this issue where the vim.loop.cwd() didn't have marks or term, but had
    -- an object for vim.loop.cwd()
    ensure_correct_config(complete_config)

    HarmuxConfig = complete_config

    log.debug("setup(): Complete config", HarmuxConfig)
    log.trace("setup(): log_key", Dev.get_log_key())
end

function M.get_global_settings()
    log.trace("get_global_settings()")
    return HarmuxConfig.global_settings
end

-- refresh all projects from disk, except our current one
function M.refresh_projects_b4update()
    log.trace(
        "refresh_projects_b4update(): refreshing other projects",
        cache_config
    )
    -- save current runtime version of our project config for merging back in later
    local cwd = utils.project_key()
    local current_p_config = {
        projects = {
            [cwd] = ensure_correct_config(HarmuxConfig).projects[cwd],
        },
    }

    -- erase all projects from global config, will be loaded back from disk
    HarmuxConfig.projects = nil

    -- this reads a stale version of our project but up-to-date versions
    -- of all other projects
    local ok2, c_config = pcall(read_config, cache_config)

    if not ok2 then
        log.debug(
            "refresh_projects_b4update(): No cache config present at",
            cache_config
        )
        c_config = { projects = {} }
    end
    -- don't override non-project config in HarmuxConfig later
    c_config = { projects = c_config.projects }

    -- erase our own project, will be merged in from current_p_config later
    c_config.projects[cwd] = nil

    local complete_config = merge_tables(
        HarmuxConfig,
        c_config,
        current_p_config
    )

    -- There was this issue where the vim.loop.cwd() didn't have marks or term, but had
    -- an object for vim.loop.cwd()
    ensure_correct_config(complete_config)

    HarmuxConfig = complete_config
    log.debug("refresh_projects_b4update(): Complete config", HarmuxConfig)
    log.trace("refresh_projects_b4update(): log_key", Dev.get_log_key())
end

function M.get_target_config()
    log.trace("get_target_config()")
    return ensure_correct_config(HarmuxConfig).projects[utils.project_key()].target
end

function M.set_last_cmd_config(last_cmd)
    log.trace("set_last_cmd_config()")
    ensure_correct_config(HarmuxConfig).projects[utils.project_key()].last_cmd = last_cmd
    M.save()
end

function M.get_last_cmd_config()
    log.trace("get_last_cmd_config()")
    return ensure_correct_config(HarmuxConfig).projects[utils.project_key()].last_cmd
end

function M.set_target_config(target)
    log.trace("set_target_config()")
    ensure_correct_config(HarmuxConfig).projects[utils.project_key()].target = target
    M.save()
end

function M.get_cmds_config()
    log.trace("get_cmds_config()")
    return ensure_correct_config(HarmuxConfig).projects[utils.project_key()].cmds
end

function M.get_menu_config()
    log.trace("get_menu_config()")
    return HarmuxConfig.global_settings.menu or {}
end

-- should only be called for debug purposes
function M.print_config()
    print(vim.inspect(HarmuxConfig))
end

-- Sets a default config with no values
M.setup()

return M
