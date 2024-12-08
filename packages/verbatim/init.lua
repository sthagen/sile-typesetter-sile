local base = require("packages.base")

local package = pl.class(base)
package._name = "verbatim"

function package:registerCommands ()
   self:registerCommand("verbatim:font", function (options, content)
      options.family = options.family or "Hack"
      options.size = options.size or SILE.settings:get("font.size") - 3
      SILE.call("font", options, content)
   end, "The font chosen for the verbatim environment")

   self:registerCommand("verbatim", function (_, content)
      SILE.typesetter:pushVglue(6)
      SILE.typesetter:leaveHmode()
      local lskip = SILE.settings:get("document.lskip") or SILE.types.node.glue()
      local rskip = SILE.settings:get("document.rskip") or SILE.types.node.glue()
      SILE.settings:temporarily(function ()
         SILE.call("verbatim:font")
         SILE.call("language", { main = "und" })
         SILE.settings:set("typesetter.parseppattern", "\n")
         SILE.settings:set("typesetter.obeyspaces", true)
         SILE.settings:set("document.lskip", SILE.types.node.glue(lskip.width.length))
         SILE.settings:set("document.rskip", SILE.types.node.glue(rskip.width.length))
         SILE.settings:set("document.parindent", SILE.types.node.glue())
         SILE.settings:set("document.parskip", SILE.types.node.vglue())
         SILE.settings:set("document.spaceskip", SILE.types.length("1spc"))
         SILE.settings:set("shaper.variablespaces", false)
         SILE.process(content)
         SILE.typesetter:leaveHmode()
      end)
   end, "Typesets its contents in a monospaced font.")

   self:registerCommand("obeylines", function (_, content)
      SILE.settings:temporarily(function ()
         SILE.settings:set("typesetter.parseppattern", "\n")
         SILE.process(content)
      end)
   end)
end

function package:registerRawHandlers ()
   self:registerRawHandler("verbatim", function (options, content)
      SILE.call("verbatim", options, { content[1] })
   end)
end

package.documentation = [[
\begin{document}
The \autodoc:package{verbatim} package is useful when quoting pieces of computer code and other text for which formatting is significant.
It changes SILE’s settings so that text is set ragged right, with no hyphenation, no indentation and regular spacing.
It tells SILE to honor multiple spaces, and sets a monospaced font.

\autodoc:note{Despite the name, \autodoc:environment{verbatim} does not alter the way that SILE sees special characters.
You still need to escape backslashes and braces: to produce a backslash, you need to write \code{\\\\}.
See the use of the \\autodoc:environment{raw} with a verbatim type handler for more literal verbatim behavior.
}

Here is some text set in the \autodoc:environment{verbatim} environment:

\begin[type=autodoc:codeblock]{raw}
local function init (class, _)
  class:loadPackage("rebox")
  class:loadPackage("raiselower")
end
\end{raw}

If you want to specify what font the verbatim environment should use, you can redefine the \autodoc:command{\verbatim:font} command.
Unless otherwise set, the default verbatim font will be \em{Hack}.
For example you could change it from XML like this:

\begin[type=autodoc:codeblock]{raw}
<define command="verbatim:font">
   <font family="DejaVu Sans Mono" size="9pt"/>
</define>
\end{raw}

This handles spaces, newlines, tabs and other similar whitespace literally in a way that SILE would otherwise have handled specially.
If additionally you want to ignore nested SILE content (e.g. SIL commands in SIL) then you need to use a raw enviroment instead:

\begin[type=autodoc:codeblock]{raw}
\begin[type=verbatim]{raw}
Sile commands like \em{emphasis} will not be intercepted.
\end‌{raw}
\end{raw}

Displays as:

\begin[type=verbatim]{raw}
Sile commands like \em{emphasis} will not be intercepted.
\end{raw}

\end{document}
]]

return package
