local plain = SILE.require("book", "classes")
local triglot = pl.tablex.deepcopy(plain)
SILE.require("packages/counters")
SILE.scratch.counters.folio = { value = 1, display = "arabic" }
triglot:declareFrame("a",    {left = "5%pw",            right = "28%pw",            top = "11.6%ph",       bottom = "80%ph"        })
triglot:declareFrame("b",    {left = "33%pw",             right = "60%pw", top = "top(a)",      bottom = "bottom(a)"    })
triglot:declareFrame("c",    {left = "66%pw",             right = "95%pw", top = "top(a)",      bottom = "bottom(a)"    })
triglot:declareFrame("folio",{left = "left(a)",         right = "right(b)",       top = "bottom(a)+3%pw",bottom = "bottom(a)+8%ph" })

triglot:loadPackage("parallel", { frames = { left = "a", middle = "b", right= "c" } })
SILE.settings.set("linebreak.tolerance", 5000)
SILE.settings.set("document.parindent", SILE.nodefactory.glue())

return triglot
