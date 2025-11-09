local M = {
	configFile = ".tinygo.json",
	tinygo = "tinygo",

	monitor = nil, ---@type monitor.Monitor?
	monitorOpts = nil, ---@type tinygo.SetupMonitorOpts?
}

---@class tinygo.SetupOpts
---@field cmd? string: The TinyGo command to execute [default: tinygo]
---@field config_file? string: The name of the config file [default: .tinygo.json]
---@field monitor? tinygo.SetupMonitorOpts

---@class tinygo.SetupMonitorOpts
---@field width? number
---@field height? number
---@field style? monitor.Style

---@param opts tinygo.SetupOpts
function M.setup(opts)
	local ok, goEnv = pcall(vim.fn.system, "go env -json")
	if not ok then vim.print("go is not in the PATH..."); return end

	local ok, goEnvJSON = pcall(vim.fn.json_decode, goEnv)
	if not ok then vim.print("error parsing the go environment"); return end

	M.loadOptions(opts)

	M["originalGOROOT"]  = goEnvJSON["GOROOT"]
	M["originalGOFLAGS"] = goEnvJSON["GOFLAGS"]
	M["currentTarget"] = "original"
	M["currentGOROOT"]  = M["originalGOROOT"]
	M["currentGOFLAGS"] = M["originalGOFLAGS"]

	local pipe = io.popen(M.tinygo .. " targets")

	if not pipe then
		vim.print("error executing 'tinygo targets'...")
		return
	end

	local targets = {"original"}
	for target in pipe:lines() do
		table.insert(targets, target)
	end

	M["targets"] = targets

	vim.api.nvim_create_user_command("TinyGoSetTarget", M.setTarget, {nargs = 1, complete = M.targetOptions})
	vim.api.nvim_create_user_command("TinyGoTargets", M.printTargets, {nargs = 0})
	vim.api.nvim_create_user_command("TinyGoEnv", M.printEnv, {nargs = 0})
	vim.api.nvim_create_user_command("TinyGoFlash", M.flash, {nargs = "?", complete = M.targetOptions})
	vim.api.nvim_create_user_command("TinyGoMonitor", M.toggleMonitor, {nargs = "*"})

	vim.api.nvim_create_autocmd({"LspAttach"}, {
		group=vim.api.nvim_create_augroup("TinyGoApplyConfigFile", {}),
		pattern="*.go",
		callback=function (ev)
			if #vim.lsp.get_clients({bufnr=ev.buf, name="gopls"}) > 0 and M.currentTarget == "original" then
				M.applyConfigFile()
			end
		end,
	})
	vim.api.nvim_create_autocmd({"BufWritePost"}, {pattern=M.configFile, callback=M.applyConfigFile})
end

---@param opts tinygo.SetupOpts
function M.loadOptions(opts)
	if opts.config_file then
		M.configFile = opts.config_file
	end
	if opts.cmd then
		M.tinygo = opts.cmd
	end
	if opts.monitor then
		M.monitorOpts = opts.monitor
	end
end

-- As seen on https://neovim.io/doc/user/api.html#nvim_create_user_command(), autocompletions written in
-- Lua are treated as custom autocompletions, so we cannot leverage Nvim's builtin regexps...
function M.targetOptions(ArgLead, cmdLine, cursorPos)
	local filteredTargets = {}
	for _, target in ipairs(M["targets"]) do
		if string.find(target, ArgLead, 1, true) == 1 then
			table.insert(filteredTargets, target)
		end
	end

	return filteredTargets
end

function M.setTarget(opts)
    local clients = vim.lsp.get_clients({name="gopls"})
    if #clients <= 0 then
        vim.print("gopls is not running")
        return
    end

    for _, c in ipairs(clients)do
        local cfg = c.config
        vim.lsp.stop_client(c.id, true)
        if opts.fargs[1] == "original" then
            M["currentTarget"] = opts.fargs[1]
            M["currentGOROOT"] = M["originalGOROOT"]
            M["currentGOFLAGS"] = M["originalGOFLAGS"]

            cfg.cmd_env= {
                GOROOT = M["originalGOROOT"],
                GOFLAGS = M["originalGOFLAGS"],
            }
            vim.lsp.config.gopls = cfg
            break
        end

        local ok, rawData = pcall(vim.fn.system, string.format(M.tinygo .. " info -json %s", opts.fargs[1]))
        if not ok then
            vim.print("error calling tinygo: " .. rawData)
            break
        end

        local ok, rawJSON = pcall(vim.fn.json_decode, rawData)
        if not ok then
            vim.print("error decoding the JSON: " .. rawJSON)
            break
        end

        if not vim.fn.has_key(rawJSON, "goroot") or not vim.fn.has_key(rawJSON, "build_tags") then
            vim.print("the generated JSON is missing keys...")
            break
        end

        local currentGOROOT = rawJSON["goroot"]
        local currentGOFLAGS = "-tags=" .. vim.fn.join(rawJSON["build_tags"], ',')

        M["currentTarget"] = opts.fargs[1]
        M["currentGOROOT"] = currentGOROOT
        M["currentGOFLAGS"] = currentGOFLAGS

        cfg.cmd_env = {
            GOROOT = currentGOROOT,
            GOFLAGS = currentGOFLAGS
        }

        vim.lsp.config.gopls = cfg
        break
    end
    vim.cmd.update()
	vim.defer_fn(vim.cmd.edit, 1000)
end

function M.flash(opts)
	local target = opts.fargs[1]
	if not target then
		target = M["currentTarget"]
	end

	if target == "original" then
		vim.print("cannot flash: no target set")
		return
	end

	vim.cmd("!" .. M.tinygo .. " flash -target=" .. opts.args)
end


function M.printTargets()
	local ok, targets = pcall(vim.fn.system, M.tinygo .. " targets")
	if not ok then
		vim.print("error calling tinygo: " .. targets)
		return
	end
	vim.print(targets)
end

function M.printEnv()
	vim.print(string.format(
		"Current Target: %q\nCurrent GOROOT: %q\nCurrent GOFLAGS: %q",
		M["currentTarget"], M["currentGOROOT"], M["currentGOFLAGS"]
	))
end

function M.applyConfigFile()
	local f = io.open(M.configFile, "r")
	if not f then
		return
	end

	local ok, rawCfg = pcall(f.read, f, "a")
	if not ok then
		vim.print("error reading config file")
		f:close()
		return
	end
	f:close()

	local ok, cfg = pcall(vim.json.decode, rawCfg)
	if not ok then
		vim.print("error decoding config file")
		return
	end

	local target = cfg["target"]
	if target then
		vim.cmd.TinyGoSetTarget(cfg["target"])
	end
end

function M.toggleMonitor(opts)
	---@type monitor.Opts
	local setupOpts = {
		header={
			"TinyGo Monitor",
			"'q' quit | 'd' detach | 'r' reattach | 'c' clear",
		},
	}
	if M.monitorOpts.height then
		setupOpts.height = M.monitorOpts.height
	end
	if M.monitorOpts.width then
		setupOpts.width = M.monitorOpts.width
	end
	if M.monitorOpts.style then
		setupOpts.style = M.monitorOpts.style
	end
	M.monitor = require("tinygo.monitor"):new(setupOpts)

	if M.monitor.job then
		vim.api.nvim_win_close(M.monitor.win, true)
	end

	local cmd = {M.tinygo, "monitor"}
	if opts.args and opts.args ~= "" then
		cmd[#cmd+1] = opts.args
	end

	-- Add keymaps and autocmd to the local monitoring buffer
	vim.api.nvim_create_autocmd({"BufWinLeave"}, {once=true, buffer=M.monitor.buf, callback=function ()
		M.monitor:kill_job()
		M.monitor = nil
	end})

	---@type vim.keymap.set.Opts
	local keymapOpts = {buffer=M.monitor.buf, silent=true, noremap=true}

	opts.desc = "TinyGo: [c]lear floating window"
	vim.keymap.set({"n"},"c", function ()
		M.monitor:clear()
	end, keymapOpts)

	opts.desc = "TinyGo: [q]uit serial monitor"
	vim.keymap.set({"n"},"q", function ()
		vim.api.nvim_win_close(M.monitor.win, true)
	end, keymapOpts)

	opts.desc = "TinyGo: [d]etach from serial monitor without closing floating window"
	vim.keymap.set({"n"},"d", function ()
		M.monitor:kill_job("-- Detached from serial monitor! --")
	end, keymapOpts)

	opts.desc = "TinyGo: [r]eattach serial monitor"
	vim.keymap.set({"n"},"r", function ()
		M.monitor:kill_job("-- Detached from serial monitor! --")
		M.monitor:start_job(cmd)
	end, keymapOpts)

	M.monitor:start_job(cmd)
end

return M
