--- The core SILE library.
-- Depending on how SILE was loaded, everything in here will probably be available under a top level `SILE` global. Note
-- that an additional global `SU` is typically available as an alias to `SILE.utilities`. Also some 3rd party Lua
-- libraries are always made available in the global scope, see `globals`.
-- @module SILE

-- Placeholder for 3rd party Lua libraries SILE always provides as globals
require("core.globals")

-- Lua loader modifications to support more resource types and module layouts
require("core.loaders")

-- Placeholder for SILE internals table
SILE = {}

--- Fields
-- @section fields

--- Machine friendly short-form version.
-- Semver, prefixed with "v", possible postfixed with ".r" followed by VCS version information.
-- @string version
SILE.version = require("core.version")

--- Status information about what options SILE was compiled with.
-- @table SILE.features
-- @tfield boolean appkit
-- @tfield boolean font_variations
-- @tfield boolean fontconfig
-- @tfield boolean harfbuzz
-- @tfield boolean icu
SILE.features = require("core.features")

-- Initialize Lua environment and global utilities

--- ABI version of Lua VM.
-- For example may be `"5.1"` or `"5.4"` or others. Note that the ABI version for most LuaJIT implementations is 5.1.
-- @string lua_version
SILE.lua_version = _VERSION:sub(-3)

--- Whether or not Lua VM is a JIT compiler.
-- @boolean lua_isjit
-- luacheck: ignore jit
SILE.lua_isjit = type(jit) == "table"

--- User friendly long-form version string.
-- For example may be "SILE v0.14.17 (Lua 5.4)".
-- @string full_version
SILE.full_version = string.format("SILE %s (%s)", SILE.version, SILE.lua_isjit and jit.version or _VERSION)

--- Default to verbose mode, can be changed from the CLI or by libraries
--- @boolean quiet
SILE.quiet = false

-- Backport of lots of Lua 5.3 features to Lua 5.[12]
if not SILE.lua_isjit and SILE.lua_version < "5.3" then
   require("compat53")
end

--- Modules
-- @section modules

--- Utilities module, typically accessed via `SU` alias.
-- @see SU
SILE.utilities = require("core.utilities")
SU = SILE.utilities -- regrettable global alias

-- For warnings and shims scheduled for removal that are easier to keep track
-- of when they are not spread across so many locations...
-- Loaded early to make it easier to manage migrations in core code.
require("core.deprecations")

--- Data tables
--- @section data

--- Stash of all Lua functions used to power typesetter commands.
-- @table Commands
SILE.Commands = {}

--- Short usage messages corresponding to typesetter commands.
-- @table Help
SILE.Help = {}

--- List of currently enabled debug flags.
-- E.g. `{ typesetter = true, frames, true }`.
-- @table debugFlags
SILE.debugFlags = {}

SILE.nodeMakers = {}
SILE.tokenizers = {}
SILE.status = {}

--- The wild-west of stash stuff.
-- No rules, just right (or usually wrong). Everything in here *should* be somewhere else, but lots of early SILE code
-- relied on this as a global key/value store for various class, document, and package values. Since v0.14.0 with many
-- core SILE components being instances of classes –and especially with each package having it's own variable namespace–
-- there are almost always better places for things. This scratch space will eventually be completely deprecated, so
-- don't put anything new in here and only use things in it if there are no other current alternatives.
-- @table scratch
SILE.scratch = {}

--- Data storage for typesetter, frame, and class information.
-- Current document class instances, node queues, and other "hot" data can be found here. As with `SILE.scratch`
-- everything in here probably belongs elsewhere, but for now it is what it is.
-- @table documentState
-- @tfield table documentClass The instantiated document processing class.
-- @tfield table thisPageTemplate The frameset used for the current page.
-- @tfield table paperSize The current paper size.
-- @tfield table orgPaperSize The original paper size if the current one is modified via packages.
SILE.documentState = {}

--- Callback functions for handling types of raw content.
-- All registered handlers for raw content blocks have an entry in this table with the type as the key and the
-- processing function as the value.
-- @ table rawHandlers
SILE.rawHandlers = {}

--- User input
-- @section input

--- All user-provided input collected before beginning document processing.
-- User input values, currently from CLI options, potentially all the inuts
-- needed for a user to use a SILE-as-a-library version to produce documents
-- programmatically.
-- @table input
-- @tfield table filenames Path names of file(s) intended for processing. Files are processed in the order provided.
-- File types may be mixed of any formaat for which SILE has an inputter module.
-- @tfield table evaluates List of strings to be evaluated as Lua code snippets *before* processing inputs.
-- @tfield table evaluateAfters List of strings to be evaluated as Lua code snippets *after* processing inputs.
-- @tfield table uses List of strings specifying module names (and optionally optionns) for modules to load *before*
-- processing inputs. For example this accommodates loading inputter modules before any input of that type is encountered.
-- Additionally it can be used to process a document using a document class *other than* the one specified in the
-- document itself. Document class modules loaded here are instantiated after load, meaning the document will not be
-- queried for a class at all.
-- @tfield table options Extra document class options to set or override in addition to ones found in the first input
-- document.
SILE.input = {
   filenames = {},
   evaluates = {},
   evaluateAfters = {},
   luarocksTrees = {},
   uses = {},
   options = {},
   preambles = {}, -- deprecated, undocumented
   postambles = {}, -- deprecated, undocumented
}

-- Internal libraries that are idempotent and return classes that need instantiation
SILE.inputters = SILE.utilities._module_loader("inputters")
SILE.shapers = SILE.utilities._module_loader("shapers")
SILE.outputters = SILE.utilities._module_loader("outputters")
SILE.classes = SILE.utilities._module_loader("classes")
SILE.packages = SILE.utilities._module_loader("packages")
SILE.typesetters = SILE.utilities._module_loader("typesetters")
SILE.pagebuilders = SILE.utilities._module_loader("pagebuilders")
SILE.types = SILE.utilities._module_loader("types")

-- Internal libraries that don't try to use anything on load, only provide something
SILE.parserBits = require("core.parserbits")
SILE.frameParser = require("core.frameparser")
SILE.fontManager = require("core.fontmanager")
SILE.papersize = require("core.papersize")

-- NOTE:
-- See remainaing internal libraries loaded at the end of this file because
-- they run core SILE functions on load instead of waiting to be called (or
-- depend on others that do).

--- Core functions
-- @section functions

--- Initialize a SILE instance.
-- Presumes CLI args have already been processed and/or library inputs are set.
--
-- 1. If no backend has been loaded already (e.g. via `--use`) then assumes *libtexpdf*.
-- 2. Loads and instantiates a shaper and outputter module appropriate for the chosen backend.
-- 3. Instantiates a pagebuilder.
-- 4. Starts a Lua profiler if the profile debug flag is set.
-- 5. Instantiates a dependency tracker if we've been asked to write make dependencies.
-- 6. Runs any code snippents passed with `--eval`.
--
-- Does not move on to processing input document(s).
SILE.init = require("core.init").init

--- Multi-purpose loader to load and initialize modules.
-- This is used to load and initialize core parts of SILE and also 3rd party modules.
-- Module types supported bay be an *inputter*, *outputer*, *shaper*, *typesetter*, *pagebuilder*, or *package*.
-- @tparam string|table module The module spec name to load (dot-separated, e.g. `"packages.lorem"`) or a table with
--   a module that has already been loaded.
-- @tparam[opt] table options Startup options as key/value pairs passed to the module when initialized.
-- @tparam[opt=false] boolean reload whether or not to reload a module that has been loaded and initialized before.
SILE.use = require("core.use")

-- --- Content loader like Lua's `require()` but with special path handling for loading SILE resource files.
-- -- Used for example by commands that load data via a `src=file.name` option.
-- -- @tparam string dependency Lua spec
SILE.require = require("core.require").require

--- Process content.
-- This is the main 'action' SILE does. Once input files are parsed into an abstract syntax tree, then we recursively
-- iterate through the tree handling each item in the order encountered.
-- @tparam table ast SILE content in abstract syntax tree format (a table of strings, functions, or more AST trees).
SILE.process = require("core.process").process

--- Process an input string.
-- First converts the string to an AST, then runs `process` on it.
-- @tparam string doc Input string to be converted to SILE content.
-- @tparam[opt] nil|string format The name of the formatter. If nil, defaults to using each intputter's auto detection.
-- @tparam[opt] nil|string filename Pseudo filename to identify the content with, useful for error messages stack traces.
-- @tparam[opt] nil|table options Options to pass to the inputter instance when instantiated.
SILE.processString = require("core.process").processString

--- Process an input file
-- Opens a file, converts the contents to an AST, then runs `process` on it.
-- Roughly equivalent to listing the file as an input, but easier to embed in code.
-- @tparam string filename Path of file to open string to be converted to SILE content.
-- @tparam[opt] nil|string format The name of the formatter. If nil, defaults to using each intputter's auto detection.
-- @tparam[opt] nil|table options Options to pass to the inputter instance when instantiated.
SILE.processFile = require("core.process").processFile

-- TODO: this probably needs deprecating, moved here just to get out of the way so
-- typesetters classing works as expected
SILE.typesetNaturally = require("core.misc").typesetNaturally

--- Resolve relative file paths to identify absolute resources locations.
-- Makes it possible to load resources from relative paths, relative to a document or project or SILE itself.
-- @tparam string filename Name of file to find using the same order of precedence logic in `require()`.
-- @tparam[opt] nil|string pathprefix Optional prefix in which to look for if the file isn't found otherwise.
SILE.resolveFile = require("core.require").resolveFile

--- Execute a registered SILE command.
-- Uses a function previously registered by any modules explicitly loaded by the user at runtime via `--use`, the SILE
-- core, the document class, or any loaded package.
-- @tparam string command Command name.
-- @tparam[opt={}] nil|table options Options to pass to the command.
-- @tparam[opt] nil|table content Any valid AST node to be processed by the command.
SILE.call = require("core.misc").call

--- (Deprecated) Register a function as a SILE command.
-- Takes any Lua function and registers it for use as a SILE command (which will in turn be used to process any content
-- nodes identified with the command name.
--
-- Note that alternative versions of this action are available as methods on document classes and packages. Those
-- interfaces should be preferred to this global one.
-- @tparam string name Name of cammand to register.
-- @tparam function func Callback function to use as command handler.
-- @tparam[opt] nil|string help User friendly short usage string for use in error messages, documentation, etc.
-- @tparam[opt] nil|string pack Information identifying the module registering the command for use in error and usage
-- messages. Usually auto-detected.
-- @see SILE.classes:registerCommand
-- @see SILE.packages:registerCommand
SILE.registerCommand = require("core.misc").registerCommand

--- Wrap an existing command with new default options.
-- Modifies an already registered SILE command with a new table of options to be used as default values any time it is
-- called. Calling options still take precedence.
-- @tparam string command Name of command to overwrite.
-- @tparam table options Options to set as updated defaults.
SILE.setCommandDefaults = require("core.misc").setCommandDefaults

-- TODO: Move to new table entry handler in types.unit
SILE.registerUnit = require("core.misc").registerUnit

SILE.paperSizeParser = require("core.misc").paperSizeParser

--- Finalize document processing
-- Signals that all the `SILE.process()` calls have been made and SILE should move on to finish up the output
--
-- 1. Tells the document class to run its `:finish()` method. This method is typically responsible for calling the
-- `:finish()` method of the outputter module in the appropriate sequence.
-- 2. Closes out anything in active memory we don't need like font instances.
-- 3. Evaluate any snippets in SILE.input.evalAfter table.
-- 4. Stops logging dependencies and writes them to a makedepends file if requested.
-- 5. Close out the Lua profiler if it was running.
-- 6. Output version information if versions debug flag is set.
SILE.finish = require("core.init").finish

-- Internal libraries that return classes, but we have no subclasses an only ever use one instantiation of the base
SILE.traceStack = require("core.tracestack")()
SILE.settings = require("core.settings")()

-- Internal libraries that run core SILE functions on load
require("core.hyphenator-liang")
require("core.languages")
SILE.linebreak = require("core.break")
require("core.frame")
SILE.font = require("core.font")

return SILE
