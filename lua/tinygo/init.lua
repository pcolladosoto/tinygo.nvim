local M = {
	config_file = ".tinygo.json",
}

function M.setup(opts)
	local ok, goEnv = pcall(vim.fn.system, "go env -json")
	if not ok then vim.print("go is not in the PATH..."); return end

	local ok, goEnvJSON = pcall(vim.fn.json_decode, goEnv)
	if not ok then vim.print("error parsing the go environment"); return end

	if opts["config_file"] then
		M.config_file = opts["config_file"]
	end

	M["originalGOROOT"]  = goEnvJSON["GOROOT"]
	M["originalGOFLAGS"] = goEnvJSON["GOFLAGS"]
	M["currentTarget"] = "original"
	M["currentGOROOT"]  = M["originalGOROOT"]
	M["currentGOFLAGS"] = M["originalGOFLAGS"]

	local pipe = io.popen("tinygo targets")

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

	vim.api.nvim_create_autocmd({"LspAttach"}, {
		group=vim.api.nvim_create_augroup("TinyGoApplyConfigFile", {}),
		pattern="*.go",
		callback=function (ev)
			if #vim.lsp.get_clients({bufnr=ev.buf, name="gopls"}) > 0 and M.currentTarget == "original" then
				M.applyConfigFile()
			end
		end,
	})
	vim.api.nvim_create_autocmd({"BufWritePost"}, {pattern=M.config_file, callback=M.applyConfigFile})
end

-- As seen on https://neovim.io/doc/user/api.html#nvim_create_user_command(), autocompletions written in
-- Lua are treated as custom autocompletions, so we cannot leverage Nvim's builtin regexps...
function M.targetOptions(ArgLead, CmdLine, CursorPos)
	local filteredTargets = {}
	for _, target in ipairs(M["targets"]) do
		if string.find(target, ArgLead, 1, true) == 1 then
			table.insert(filteredTargets, target)
		end
	end

	return filteredTargets
end

function M.setTarget(opts)
	local currentGOROOT = ""
	local currentGOFLAGS = ""

	if opts.fargs[1] == "original" then
		currentGOROOT = M["originalGOROOT"]
		currentGOFLAGS = M["originalGOFLAGS"]

		M["currentTarget"] = opts.fargs[1]
		M["currentGOROOT"] = currentGOROOT
		M["currentGOFLAGS"] = currentGOFLAGS
	else
		local ok, rawData = pcall(vim.fn.system, string.format("tinygo info -json %s", opts.fargs[1]))
		if not ok then
			vim.print("error calling tinygo: " .. rawData)
			return
		end

		local ok, rawJSON = pcall(vim.fn.json_decode, rawData)
		if not ok then
			vim.print("error decoding the JSON: " .. rawJSON)
			return
		end

		if not vim.fn.has_key(rawJSON, "goroot") or not vim.fn.has_key(rawJSON, "build_tags") then
			vim.print("the generated JSON is missing keys...")
			return
		end

		currentGOROOT = rawJSON["goroot"]
		currentGOFLAGS = "-tags=" .. vim.fn.join(rawJSON["build_tags"], ',')

		M["currentTarget"] = opts.fargs[1]
		M["currentGOROOT"] = currentGOROOT
		M["currentGOFLAGS"] = currentGOFLAGS
	end

	-- Update the configuration
	vim.lsp.config('gopls', {
		cmd_env = {
			GOROOT = currentGOROOT,
			GOFLAGS = currentGOFLAGS
		}
	})

	-- Restart the LSP server
	vim.lsp.enable('gopls', false)
	vim.lsp.enable('gopls', true)
end

function M.printTargets()
	local ok, targets = pcall(vim.fn.system, "tinygo targets")
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
	local f = io.open(M.config_file, "r")
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

return M
