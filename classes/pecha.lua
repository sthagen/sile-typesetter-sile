local plain = SILE.require("plain", "classes")
local pecha = plain { id = "pecha" }

local tibetanNumber = function (n)
  local out = ""
  local a = 0x0f20
  repeat
    out = SU.utf8char(n%10 + a) .. out
    n = (n - n%10)/10
  until n < 1
  return out
end

function pecha:init()
  self:declareFrame("content", {left = "5%pw",  right = "95%pw",  top = "5%ph",  bottom = "90%ph" })
  self:declareFrame("folio",   {left = "right(content)", rotate = -90, width = "2.5%pw", top = "top(content)", height = "height(content)" })
  self:declareFrame("runningHead", { width = "2.5%pw", rotate = -90, right = "left(content)", top = "top(content)", height = "height(content)"})
  self.pageTemplate.firstContentFrame = self.pageTemplate.frames["content"]
  self:loadPackage("rotate")
  -- SILE.outputter:debugFrame(SILE.getFrame("content"))
  -- SILE.outputter:debugFrame(SILE.getFrame("runningHead"))
  -- SILE.outputter:debugFrame(SILE.getFrame("folio"))
  return plain.init(self)
end

function pecha:endPage()
  local folioframe = SILE.getFrame("folio")
  SILE.typesetNaturally(folioframe, function ()
    SILE.settings.pushState()
    SILE.settings.reset()
    SILE.settings.set("typesetter.breakwidth", folioframe:height())
    SILE.typesetter:typeset(" ")
    SILE.call("vfill")
    SILE.call("pecha-folio-font")
    SILE.call("center", {}, function ()
        SILE.typesetter:typeset(tibetanNumber(SILE.scratch.counters.folio.value))
    end)
    SILE.call("vfill")
    SILE.typesetter:leaveHmode()
    SILE.settings.popState()
  end)
  return plain.endPage(self)
end

function pecha:newPage()
  SILE.outputter:newPage()
  SILE.outputter:debugFrame(SILE.getFrame("content"))
  return self:initialFrame()
end

function pecha:registerCommands()
  plain.registerCommands(self)
  SILE.call("language", { main = "bo" })
  SILE.settings.set("document.lskip", SILE.nodefactory.hfillglue())
  SILE.settings.set("typesetter.parfillskip", SILE.nodefactory.glue())
  SILE.settings.set("document.parindent", SILE.nodefactory.glue())
end

return pecha

-- \right-running-head{\font[size=15pt]{\center{ཤེས་རབ་སྙིང་པོ་ }}}
