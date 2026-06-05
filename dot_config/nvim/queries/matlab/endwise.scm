((function_definition
   "function" @indent
   name: (identifier) @cursor) @endable
 (#endwise! "end"))

((function_definition
   "function" @indent
   name: (identifier)
   (function_arguments) @cursor) @endable
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
