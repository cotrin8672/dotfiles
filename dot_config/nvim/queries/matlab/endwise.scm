((function_definition
   "function" @indent
   name: (identifier) @cursor)
 (#endwise! "end"))

((function_definition
   "function" @indent
   name: (identifier)
   (function_arguments) @cursor)
 (#endwise! "end"))

((function_definition
   "function" @indent
   name: (property_name) @cursor)
 (#endwise! "end"))

((function_definition
   "function" @indent
   name: (property_name)
   (function_arguments) @cursor)
 (#endwise! "end"))

((for_statement
   ["for" "parfor"] @indent
   (iterator) @cursor) @endable
 (#endwise! "end"))

((for_statement
   "parfor" @indent
   "("
   (iterator) @cursor
   ","
   (parfor_options) @cursor
   ")" @cursor) @endable
 (#endwise! "end"))

((while_statement
   "while" @indent
   condition: (_) @cursor) @endable
 (#endwise! "end"))

((if_statement
   "if" @indent
   condition: (_) @cursor) @endable
 (#endwise! "end"))

((switch_statement
   "switch" @indent
   condition: (_) @cursor) @endable
 (#endwise! "end"))

((try_statement
   "try" @indent @cursor) @endable
 (#endwise! "end"))

((class_definition
   "classdef" @indent
   name: (identifier) @cursor) @endable
 (#endwise! "end"))

((class_definition
   "classdef" @indent
   name: (identifier)
   (superclasses) @cursor) @endable
 (#endwise! "end"))

; Incomplete control-flow headers are represented by an ERROR node until
; their body or closing `end` is typed.
((ERROR
   "if" @indent
   (_) @cursor)
 (#endwise! "end"))

((ERROR
   "for" @indent
   (_) @cursor)
 (#endwise! "end"))

((ERROR
   "parfor" @indent
   (_) @cursor)
 (#endwise! "end"))

((ERROR
   "while" @indent
   (_) @cursor)
 (#endwise! "end"))

((ERROR
   "switch" @indent
   (_) @cursor)
 (#endwise! "end"))

((ERROR
   "try" @indent @cursor)
 (#endwise! "end"))

((ERROR) @indent @cursor
 (#match? @cursor "^classdef")
 (#endwise! "end"))

; MATLAB class sections are parsed as a command or identifier while their
; body is still empty.
((command
   (command_name) @indent) @cursor
 (#match? @indent "^(properties|methods|events|enumeration|arguments)$")
 (#endwise! "end"))

((function_call
   name: (identifier) @indent
   (arguments)) @cursor
 (#match? @indent "^(properties|methods|events|enumeration|arguments)$")
 (#endwise! "end"))

((arguments_statement
   "arguments" @indent @cursor)
 (#endwise! "end"))

((identifier) @indent @cursor
 (#match? @cursor "^(properties|methods|events|enumeration|arguments)$")
 (#endwise! "end"))

((ERROR) @indent @cursor
 (#match? @cursor "^spmd")
 (#endwise! "end"))
