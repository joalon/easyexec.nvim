local M = {}

-- Command line typed up to the cursor, saved by the findstart call
local pending = ""

-- Matches from bash-completion waiting to be shown by the next completefunc call
local cached = nil

-- Runs the bash-completion function registered for a command line (passed as
-- $1) the way bash would on <Tab>, and prints the matches one per line
local BASH_SCRIPT = [=[
source "$2" || exit 1
COMP_LINE=$1
COMP_POINT=${#COMP_LINE}
read -ra COMP_WORDS <<< "$COMP_LINE"
[[ $COMP_LINE == *[[:space:]] ]] && COMP_WORDS+=("")
COMP_CWORD=$(( ${#COMP_WORDS[@]} - 1 ))
cmd=${COMP_WORDS[0]}
cur=${COMP_WORDS[COMP_CWORD]}
prev=${COMP_WORDS[COMP_CWORD-1]}

# Most completions are loaded on demand: _comp_load in bash-completion 2.12+,
# _completion_loader before. Some (ls, cat, ...) are registered up front.
if ! complete -p "$cmd" &>/dev/null; then
	if declare -F _comp_load >/dev/null; then
		_comp_load "$cmd"
	else
		_completion_loader "$cmd"
	fi
fi &>/dev/null
spec=$(complete -p "$cmd" 2>/dev/null) || exit 0

if [[ $spec =~ -F\ ([^ ]+) ]]; then
	"${BASH_REMATCH[1]}" "$cmd" "$cur" "$prev" &>/dev/null
else
	# -W wordlists, -A actions etc. work through compgen with the same options
	opts=${spec#complete }
	opts=${opts% *}
	eval "COMPREPLY=(\$(compgen $opts -- \"\$cur\"))" 2>/dev/null
fi
printf '%s\n' "${COMPREPLY[@]}"
]=]

local BASH_COMPLETION_PATHS = {
	"/usr/share/bash-completion/bash_completion",
	"/usr/local/share/bash-completion/bash_completion",
	"/opt/homebrew/share/bash-completion/bash_completion",
	"/etc/bash_completion",
}

local bash_completion_path = nil
local function find_bash_completion()
	if bash_completion_path == nil then
		bash_completion_path = false
		if vim.fn.executable("bash") == 1 then
			for _, path in ipairs(BASH_COMPLETION_PATHS) do
				if vim.uv.fs_stat(path) then
					bash_completion_path = path
					break
				end
			end
		end
	end
	return bash_completion_path
end

-- Text after the last |, ;, & so each command in a pipeline or chain completes
-- like a command line of its own
local function current_segment(text)
	local last = 0
	for pos in text:gmatch("()[|;&]") do
		last = pos
	end
	return (text:sub(last + 1):gsub("^%s+", ""))
end

local function candidates(segment)
	local ok, items = pcall(vim.fn.getcompletion, segment, "shellcmdline")
	if ok then
		return items
	end

	-- "shellcmdline" needs Neovim 0.11, fall back to commands or files
	local word = segment:match("%S*$")
	local type = segment:find("%s") and "file" or "shellcmd"
	return vim.fn.getcompletion(word, type)
end

-- Turn bash's COMPREPLY lines into complete-items. Some completions (dnf) pad
-- the word with a description, which goes into the menu column instead.
local function parse_reply(output)
	local items, seen = {}, {}
	for _, line in ipairs(vim.split(output, "\n", { trimempty = true })) do
		local word, description = line:match("^(%S+)%s%s+(.-)%s*$")
		word = word or vim.trim(line)
		if word ~= "" and not seen[word] then
			seen[word] = true
			-- bash only adds the / for directories when readline displays them
			if vim.fn.isdirectory(word) == 1 and not word:find("/$") then
				word = word .. "/"
			end
			table.insert(items, { word = word, menu = description })
		end
	end
	table.sort(items, function(a, b)
		return a.word < b.word
	end)
	return items
end

local function show_menu()
	vim.api.nvim_feedkeys(vim.keycode("<C-x><C-u>"), "n", false)
end

-- Start completion for the input buffer on <Tab>. Arguments are completed by
-- the command's bash-completion in the background, everything else (and
-- commands bash has nothing for) by Neovim's own shell completion.
-- Returns the keys for an expr mapping, so they stay in order with typeahead.
function M.trigger()
	cached = nil
	local col = vim.api.nvim_win_get_cursor(0)[2]
	local before = vim.api.nvim_get_current_line():sub(1, col)
	local segment = current_segment(before)
	local word = before:match("[^%s|;&]*$")

	local script = find_bash_completion()
	if not script or not segment:find("%s") or word:find("^%$") then
		return "<C-x><C-u>"
	end

	local buf = vim.api.nvim_get_current_buf()
	local tick = vim.api.nvim_buf_get_changedtick(buf)
	vim.system(
		{ "bash", "--norc", "--noprofile", "-c", BASH_SCRIPT, "easyexec", segment, script },
		{ text = true, cwd = vim.fn.getcwd(), timeout = 3000 },
		vim.schedule_wrap(function(result)
			-- Drop results for text that has changed since, or a prompt that's gone
			if
				not vim.api.nvim_buf_is_valid(buf)
				or buf ~= vim.api.nvim_get_current_buf()
				or vim.api.nvim_buf_get_changedtick(buf) ~= tick
				or vim.fn.mode() ~= "i"
			then
				return
			end

			local items = result.code == 0 and parse_reply(result.stdout or "") or {}
			if #items > 0 then
				local start = #before - #word
				-- bash splits words on = and :, so --opt=val completes just val
				local prefix_matches = vim.iter(items):any(function(item)
					return vim.startswith(item.word, word)
				end)
				if not prefix_matches and word:find("[=:]") then
					start = #before - #word:match("[^=:]*$")
				end
				cached = { start = start, items = items }
			end
			show_menu()
		end)
	)
	return ""
end

-- 'completefunc' for the input buffer: results from M.trigger when there are
-- any, otherwise commands for the first word, files for arguments and
-- environment variables after $
function M.complete(findstart, base)
	if findstart == 1 then
		if cached then
			return cached.start
		end

		local col = vim.api.nvim_win_get_cursor(0)[2]
		local before = vim.api.nvim_get_current_line():sub(1, col)
		pending = current_segment(before)

		local start = before:find("[^%s|;&]*$")
		-- Variable names are completed without the $
		if before:sub(start, start) == "$" then
			start = start + 1
		end
		return start - 1
	end

	if cached then
		local items = cached.items
		cached = nil
		return vim.tbl_filter(function(item)
			return vim.startswith(item.word, base)
		end, items)
	end
	return candidates(pending)
end

return M
