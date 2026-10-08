local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt
local rep = require("luasnip.extras").rep

return {
	s(
		"fn",
		fmt(
			[[
function {output} = {name}({args})
    {body}
end]],
			{
				output = i(1, "output"),
				name = i(2, "functionName"),
				args = i(3, "args"),
				body = i(0),
			}
		)
	),
	s(
		"fno",
		fmt(
			[[
function {name}({args})
    {body}
end]],
			{
				name = i(1, "functionName"),
				args = i(2, "args"),
				body = i(0),
			}
		)
	),
	s(
		"arg",
		fmt(
			[[
arguments
    {body}
end]],
			{
				body = i(0, "opts"),
			}
		)
	),
	s(
		"hook",
		fmt(
			[[
function state = {name}(state, spec, k)
arguments
    state (1, 1) struct
    spec (1, 1) struct
    k (1, 1) double
end

{body}
end]],
			{
				name = i(1, "hookName"),
				body = i(0),
			}
		)
	),
	s(
		"bld",
		fmt(
			[[
function {output} = {name}(opts)
arguments
    opts.physical (1, 1) struct
    opts.pump (1, 1) struct
    opts.numerical (1, 1) struct
end

{body}
end]],
			{
				output = i(1, "output"),
				name = i(2, "builderName"),
				body = i(0),
			}
		)
	),
	s(
		"for",
		fmt(
			[[
for {index} = {first}:{last}
    {body}
end]],
			{
				index = i(1, "i"),
				first = i(2, "1"),
				last = i(3, "n"),
				body = i(0),
			}
		)
	),
	s(
		"pfor",
		fmt(
			[[
parfor {index} = {first}:{last}
    {body}
end]],
			{
				index = i(1, "i"),
				first = i(2, "1"),
				last = i(3, "n"),
				body = i(0),
			}
		)
	),
	s(
		"if",
		fmt(
			[[
if {condition}
    {body}
end]],
			{
				condition = i(1, "condition"),
				body = i(0),
			}
		)
	),
	s(
		"ife",
		fmt(
			[[
if {condition}
    {then_body}
else
    {else_body}
end]],
			{
				condition = i(1, "condition"),
				then_body = i(2),
				else_body = i(0),
			}
		)
	),
	s(
		"sw",
		fmt(
			[[
switch {expression}
    case {value}
        {case_body}
    otherwise
        {otherwise_body}
end]],
			{
				expression = i(1, "expression"),
				value = i(2, "value"),
				case_body = i(3),
				otherwise_body = i(0),
			}
		)
	),
	s(
		"try",
		fmt(
			[[
try
    {try_body}
catch {error}
    {catch_body}
end]],
			{
				try_body = i(1),
				error = i(2, "err"),
				catch_body = i(0),
			}
		)
	),
	s(
		"spec",
		fmt(
			[[
{} = struct;
{}.{} = {};]],
			{
				i(1, "group"),
				rep(1),
				i(2, "field"),
				i(0, "value"),
			}
		)
	),
	s(
		"class",
		fmt(
			[[
classdef {} < handle
    properties
        {}
    end

    methods
        function obj = {}({})
            {}
        end
    end
end]],
			{
				i(1, "ClassName"),
				i(2, "property"),
				rep(1),
				i(3, "args"),
				i(0),
			}
		)
	),
}
