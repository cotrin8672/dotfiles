-- Run from the repository root: nvim --headless -u NONE -i NONE -n -l tests/nvim_matlab_help_source.lua
local config = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
vim.opt.rtp:prepend(config)
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/site")
local source_help = require("config.matlab.help_source")
local cases = 0

local function check(source, symbol, expected, row)
	local actual = source_help.extract(source, symbol, row)
	assert(
		vim.deep_equal(actual, expected),
		symbol .. ": expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual)
	)
	cases = cases + 1
end

local function source(lines)
	return table.concat(lines, "\n")
end

local cached = {
	"function runner = cached(solver, scheme)",
	"% Cache the solver outputs using the committed Scheme's Keys and Values.",
	"arguments",
	"    solver (1, 1) function_handle",
	"    scheme (1, 1) store.Scheme",
	"end",
	'runner = store.wrap("cached", solver, scheme);',
	"end",
}
local cached_info = {
	signature = { cached[1] },
	arguments = { cached[3], cached[4], cached[5], cached[6] },
	help = { cached[2]:sub(3) },
}
check(source(cached), "store.cached", cached_info)
local cached_path = "C:/Users/minol/sakaue/LLE/common/+store/cached.m"
if vim.fn.filereadable(cached_path) == 1 then
	check(source(vim.fn.readfile(cached_path)), "store.cached", cached_info, 0)
end
local scheme_path = "C:/Users/minol/sakaue/LLE/common/+store/Scheme.m"
if vim.fn.filereadable(scheme_path) == 1 then
	local lines = vim.fn.readfile(scheme_path)
	for i, line in ipairs(lines) do
		if line:match("function commit%(obj, options%)") then
			check(source(lines), "scheme.commit", {
				signature = { "function commit(obj, options)" },
				arguments = { "arguments", "    obj", "    options.ExistingValues (1, 1) struct = struct()", "end" },
				help = {},
			}, i - 1)
			break
		end
	end
end
check(source(cached):gsub("\n", "\r\n"), "store.cached", cached_info)

local multiline = {
	"    function [first, ...",
	"            second] = ...",
	"            process( ... % input declaration",
	"                x, ...",
	"                y ...",
	"            )",
	"        arguments (Input)",
	"            x (1, 1) double {mustBePositive, mustBeFinite} = 1",
	'            y (1, :) string = "arguments end"',
	"        end",
	"        arguments (Output)",
	"            first (1, 1) double",
	"            second (1, 1) double",
	"        end",
	"        % PROCESS Description after both blocks.",
	'        %   process(1, "end")',
	"        first = x;",
	"        second = y;",
	"        % Body documentation must stay out.",
	"    end",
}
check(source(multiline), "process", {
	signature = {
		"function [first, ...",
		"        second] = ...",
		"        process( ... % input declaration",
		"            x, ...",
		"            y ...",
		"        )",
	},
	arguments = {
		"arguments (Input)",
		"    x (1, 1) double {mustBePositive, mustBeFinite} = 1",
		'    y (1, :) string = "arguments end"',
		"end",
		"",
		"arguments (Output)",
		"    first (1, 1) double",
		"    second (1, 1) double",
		"end",
	},
	help = { "PROCESS Description after both blocks.", '  process(1, "end")' },
}, 2)

check(
	[[function total = sum_all(varargin)
arguments (Repeating)
    varargin (1, :) double {mustBeFinite}
end
% SUM_ALL Comment mentions function, arguments, and end.
total = 0;
end]],
	"sum_all",
	{
		signature = { "function total = sum_all(varargin)" },
		arguments = { "arguments (Repeating)", "    varargin (1, :) double {mustBeFinite}", "end" },
		help = { "SUM_ALL Comment mentions function, arguments, and end." },
	}
)
check(
	[[function result = literal_defaults(input, mode, options)
arguments (Input)
    input (1, :) double = ... % function arguments end
        [1, 2, 3]
    mode (1, 1) string {mustBeMember(mode, ["fast", "slow"])} = "fast"
    options.Metadata (1, 1) struct = struct("label", "end")
end
arguments (Output)
    result (1, :) double
end
result = input;
end]],
	"literal_defaults",
	{
		signature = { "function result = literal_defaults(input, mode, options)" },
		arguments = {
			"arguments (Input)",
			"    input (1, :) double = ... % function arguments end",
			"        [1, 2, 3]",
			'    mode (1, 1) string {mustBeMember(mode, ["fast", "slow"])} = "fast"',
			'    options.Metadata (1, 1) struct = struct("label", "end")',
			"end",
			"",
			"arguments (Output)",
			"    result (1, :) double",
			"end",
		},
		help = {},
	}
)

local nested = [[function out = outer(x)
% OUTER Help.
arguments
    x (1, 1) double
end
out = helper(x);
function value = helper(input)
    % HELPER Nested help.
    arguments
        input (1, 1) double {mustBePositive} = 2
    end
    value = input;
end
end
function out = local_function(value)
arguments
    value (1, :) string
end
% LOCAL Help after arguments.
out = value;
end]]
check(nested, "outer", {
	signature = { "function out = outer(x)" },
	arguments = { "arguments", "    x (1, 1) double", "end" },
	help = { "OUTER Help." },
})
check(nested, "helper", {
	signature = { "function value = helper(input)" },
	arguments = { "arguments", "    input (1, 1) double {mustBePositive} = 2", "end" },
	help = { "HELPER Nested help." },
}, 6)
check(nested, "local_function", {
	signature = { "function out = local_function(value)" },
	arguments = { "arguments", "    value (1, :) string", "end" },
	help = { "LOCAL Help after arguments." },
}, 14)

local class = [[classdef Scheme
    methods
        function obj = Scheme(name)
            % SCHEME Construct a scheme.
            arguments
                name (1, 1) string = "default"
            end
            obj.Name = name;
        end
        function result = cached(obj, solver)
            arguments
                obj (1, 1) Scheme
                solver (1, 1) function_handle
            end
            % CACHED Return a runner.
            result = solver;
        end
        function value = get.Name(obj)
            % NAME Property getter.
            value = obj.Name;
        end
        function obj = set.Name(obj, value)
            % NAME Property setter.
            obj.Name = value;
        end
    end
end]]
local constructor = {
	signature = { "function obj = Scheme(name)" },
	arguments = { "arguments", '    name (1, 1) string = "default"', "end" },
	help = { "SCHEME Construct a scheme." },
}
check(class, "store.Scheme", constructor)
check(class, "store.Scheme", constructor, 0)
check(class, "Scheme.cached", {
	signature = { "function result = cached(obj, solver)" },
	arguments = { "arguments", "    obj (1, 1) Scheme", "    solver (1, 1) function_handle", "end" },
	help = { "CACHED Return a runner." },
}, 9)
check(class, "Other.cached", nil)
check(class, "scheme.cached", {
	signature = { "function result = cached(obj, solver)" },
	arguments = { "arguments", "    obj (1, 1) Scheme", "    solver (1, 1) function_handle", "end" },
	help = { "CACHED Return a runner." },
}, 9)
check(class, "Scheme.get.Name", {
	signature = { "function value = get.Name(obj)" },
	arguments = {},
	help = { "NAME Property getter." },
})
check(class, "Scheme.set.Name", {
	signature = { "function obj = set.Name(obj, value)" },
	arguments = {},
	help = { "NAME Property setter." },
})
check(class, "Scheme.Name", nil)
check(class, "Scheme.Name", {
	signature = { "function value = get.Name(obj)" },
	arguments = {},
	help = { "NAME Property getter." },
}, 17)

local repeated = [[function parent
function out = helper(x)
% FIRST Help.
out = x;
end
end
function second
function out = helper(y)
% SECOND Help.
out = y;
end
end]]
check(repeated, "helper", nil)
check(repeated, "helper", {
	signature = { "function out = helper(y)" },
	arguments = {},
	help = { "SECOND Help." },
}, 7)
check(repeated, "receiver.helper", {
	signature = { "function out = helper(y)" },
	arguments = {},
	help = { "SECOND Help." },
}, 7)
check(repeated, "helper", nil, 0)
check(
	[[classdef Scheme
    methods
        function out = method(obj)
            out = helper(obj);
            function result = helper(value)
                % Nested method helper.
                result = value;
            end
        end
    end
end]],
	"receiver.helper",
	{
		signature = { "function result = helper(value)" },
		arguments = {},
		help = { "Nested method helper." },
	},
	4
)

check(
	[[function y = unfinished(x)
arguments
    x (1, 1) double
end
% UNFINISHED Completed preamble.
y = (
end]],
	"unfinished",
	{
		signature = { "function y = unfinished(x)" },
		arguments = { "arguments", "    x (1, 1) double", "end" },
		help = { "UNFINISHED Completed preamble." },
	}
)
check(
	[[function y = no_end(x)
arguments
    x (1, 1) double
end
y = x;]],
	"no_end",
	{
		signature = { "function y = no_end(x)" },
		arguments = { "arguments", "    x (1, 1) double", "end" },
		help = {},
	}
)
for _, body in ipairs({ ")", "..." }) do
	check(
		"function incomplete_body(x)\narguments\n    x double\nend\n" .. body .. "\n% Body comment.\nend",
		"incomplete_body",
		{
			signature = { "function incomplete_body(x)" },
			arguments = { "arguments", "    x double", "end" },
			help = {},
		}
	)
end
check(
	[[function invalid(x)
arguments
    x (1, 1) double
]],
	"invalid",
	nil
)
check(
	[[function invalid(x)
arguments
    x (1, 1) double {
end
x = x;
end]],
	"invalid",
	nil
)
check(
	[[function invalid(x)
arguments (Input
x double
end
end]],
	"invalid",
	nil
)
check(
	[[function invalid(x)
arguments
x double =
end]],
	"invalid",
	nil
)
check(
	[[function [a, ...
    b] = invalid( ...
    x,
end]],
	"invalid",
	nil
)
check("function invalid ...\nend", "invalid", nil)
check("function inline(x), x=x; end", "inline", { signature = { "function inline(x)" }, arguments = {}, help = {} })
check(
	[[function f(x) % inline comment
% F Attached help.
arguments
    x double
end
% More help after arguments.
x = x;
end]],
	"f",
	{
		signature = { "function f(x) % inline comment" },
		arguments = { "arguments", "    x double", "end" },
		help = { "F Attached help.", "", "More help after arguments." },
	}
)
check(
	[[function block_help
%{
Description in a block comment.
%}
end]],
	"block_help",
	{ signature = { "function block_help" }, arguments = {}, help = { "Description in a block comment." } }
)
check("function unsaved(x)\narguments\n    x double = [1, 2]\nend\nend", "unsaved", {
	signature = { "function unsaved(x)" },
	arguments = { "arguments", "    x double = [1, 2]", "end" },
	help = {},
})
check(nil, "builtin", nil)
check("% A built-in function.", "builtin", nil)
check("", "builtin", nil)
check(source(cached), "missing", nil)
check(source(cached), "cached", nil, 100)
check(source(cached), "cached", nil, -1)
check(source(cached), "cached", nil, "0")
local get_parser = vim.treesitter.get_string_parser
vim.treesitter.get_string_parser = function()
	error("Parser unavailable")
end
check(source(cached), "store.cached", nil)
vim.treesitter.get_string_parser = get_parser

print("PASS: " .. cases .. " MATLAB help source cases")
