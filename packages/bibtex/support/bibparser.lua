local epnf = require("epnf")
local nbibtex = require("packages.bibtex.support.nbibtex")
local namesplit, parse_name = nbibtex.namesplit, nbibtex.parse_name
local isodatetime = require("packages.bibtex.support.isodatetime")

local nbsp = luautf8.char(0x00A0)
local function sanitize (str)
   local s = str
      -- TeX special characters:
      -- Backslash-escaped tilde is a tilde,
      -- but standalone tilde is a non-breaking space
      :gsub(
         "(.?)~",
         function (prev)
            if prev == "\\" then
               return "~"
            end
            return prev .. nbsp
         end
      )
      -- Other backslash-escaped characters are skipped
      -- TODO FIXME:
      -- This ok for \", \& etc. which we want to unescape,
      -- BUT what should we do with other TeX-like commands?
      :gsub(
         "\\",
         ""
      )
      -- We will wrap the content in <sile> tags so we need to XML-escape
      -- the input.
      :gsub("&", "&amp;")
      :gsub("<", "&lt;")
      :gsub(">", "&gt;")
   return s
end

-- luacheck: push ignore
-- stylua: ignore start
---@diagnostic disable: undefined-global, unused-local, lowercase-global
local bibtexparser = epnf.define(function (_ENV)
   local strings = {} -- Local store for @string entries

   local identifier = (SILE.parserBits.identifier + S":-")^1
   local balanced = C{ "{" * P" "^0 * C(((1 - S"{}") + V(1))^0) * "}" } / function (...) local t={...}; return t[2] end
   local quoted = C( P'"' * C(((1 - S'"\r\n\f\\') + (P'\\' * 1)) ^ 0) * '"' ) / function (...) local t={...}; return t[2] end
   local _ = WS^0
   local sep = S",;" * _
   local myID = C(identifier)
   local myStrID = myID / function (t) return strings[t] or t end
   local myTag = C(identifier) / function (t) return t:lower() end
   local pieces = balanced + quoted + myStrID
   local value = Ct(pieces * (WS * P("#") * WS * pieces)^0)
      / function (t) return table.concat(t) end / sanitize
   local pair = myTag * _ * "=" * _ * value * _ * sep^-1
      / function (...) local t= {...}; return t[1], t[#t] end
   local list = Cf(Ct("") * pair^0, rawset)
   local skippedType = Cmt(R("az", "AZ")^1, function(_, _, tag)
      -- ignore both @comment and @preamble
      local t = tag:lower()
      return t == "comment" or t == "preamble"
   end)

   START "document"
   document = (V"skipped" -- order important: skipped (@comment, @preamble) must be first
      + V"stringblock" -- order important: @string must be before @entry
      + V"entry")^1
      * (-1 + E("Unexpected character at end of input"))
   skipped  = WS + (V"blockskipped" + (1 - P"@")^1 ) / ""
   blockskipped = (P("@") * skippedType) + balanced / ""
   stringblock = Ct( P("@string") * _ * P("{") * pair * _ * P("}") * _ )
       / function (t)
          strings[t[1]] = t[2]
          return t end
   entry = Ct( P("@") * Cg(myTag, "type") * _ * P("{") * _ * Cg(myID, "label") * _ * sep * list * P("}") * _ )
end)
-- luacheck: pop
-- stylua: ignore end
---@diagnostic enable: undefined-global, unused-local, lowercase-global

local bibcompat = require("packages.bibtex.support.bibmaps")
local crossrefmap, fieldmap = bibcompat.crossrefmap, bibcompat.fieldmap
local months =
   { jan = 1, feb = 2, mar = 3, apr = 4, may = 5, jun = 6, jul = 7, aug = 8, sep = 9, oct = 10, nov = 11, dec = 12 }

local function consolidateEntry (entry, label)
   local consolidated = {}
   -- BibLaTeX aliases for legacy BibTeX fields
   for field, value in pairs(entry.attributes) do
      consolidated[field] = value
      local alias = fieldmap[field]
      if alias then
         if entry.attributes[alias] then
            SU.warn("Duplicate field '" .. field .. "' and alias '" .. alias .. "' in entry '" .. label .. "'")
         else
            consolidated[alias] = value
         end
      end
   end
   -- Names field split and parsed
   for _, field in ipairs({ "author", "editor", "translator", "shortauthor", "shorteditor", "holder" }) do
      if consolidated[field] then
         -- FIXME Check our corporate names behave, we are probably bad currently
         -- with nested braces !!!
         -- See biblatex manual v3.20 §2.3.3 Name Lists
         -- e.g. editor = {{National Aeronautics and Space Administration} and Doe, John}
         local names = namesplit(consolidated[field])
         for i = 1, #names do
            names[i] = parse_name(names[i])
         end
         consolidated[field] = names
      end
   end
   -- Month field in either number or string (3-letter code)
   if consolidated.month then
      local month = tonumber(consolidated.month) or months[consolidated.month:lower()]
      if month and (month >= 1 and month <= 12) then
         consolidated.month = month
      else
         SU.warn("Unrecognized month skipped in entry '" .. label .. "'")
         consolidated.month = nil
      end
   end
   -- Extended date fields
   for _, field in ipairs({ "date", "origdate", "eventdate", "urldate" }) do
      if consolidated[field] then
         local dt = isodatetime(consolidated[field])
         if dt then
            consolidated[field] = dt
         else
            SU.warn("Invalid '" .. field .. "' skipped in entry '" .. label .. "'")
            consolidated[field] = nil
         end
      end
   end
   entry.attributes = consolidated
   return entry
end

--- Parse a BibTeX file and populate a bibliography table.
-- @tparam string fn Filename
-- @tparam table biblio Table of entries
local function parseBibtex (fn, biblio)
   fn = SILE.resolveFile(fn) or SU.error("Unable to resolve Bibtex file " .. fn)
   local fh, e = io.open(fn)
   if e then
      SU.error("Error reading bibliography file: " .. e)
   end
   local doc = fh:read("*all")
   local t = epnf.parsestring(bibtexparser, doc)
   if not t or not t[1] or t.id ~= "document" then
      SU.error("Error parsing bibtex")
   end
   for i = 1, #t do
      if t[i].id == "entry" then
         local ent = t[i][1]
         local entry = { type = ent.type, label = ent.label, attributes = ent[1] }
         if biblio[ent.label] then
            SU.warn("Duplicate entry key '" .. ent.label .. "', picking the last one")
         end
         biblio[ent.label] = consolidateEntry(entry, ent.label)
      end
   end
end

--- Copy fields from the parent entry to the child entry.
-- BibLaTeX/Biber have a complex inheritance system for fields.
-- This implementation is more naive, but should be sufficient for reasonable
-- use cases.
-- @tparam table parent Parent entry
-- @tparam table entry Child entry
local function fieldsInherit (parent, entry)
   local map = crossrefmap[parent.type] and crossrefmap[parent.type][entry.type]
   if not map then
      -- @xdata and any other unknown types: inherit all missing fields
      for field, value in pairs(parent.attributes) do
         if not entry.attributes[field] then
            entry.attributes[field] = value
         end
      end
      return -- done
   end
   for field, value in pairs(parent.attributes) do
      if map[field] == nil and not entry.attributes[field] then
         entry.attributes[field] = value
      end
      for childfield, parentfield in pairs(map) do
         if parentfield and not entry.attributes[parentfield] then
            entry.attributes[parentfield] = parent.attributes[childfield]
         end
      end
   end
end

--- Resolve the 'crossref' and 'xdata' fields on a bibliography entry.
-- (Supplementing the entry with the attributes of the parent entry.)
-- Once resolved recursively, the crossref and xdata fields are removed
-- from the entry.
-- So this is intended to be called at first use of the entry, and have no
-- effect on subsequent uses: BibTeX does seem to mandate cross references
-- to be defined before the entry that uses it, or even in the same bibliography
-- file.
-- Implementation note:
-- We are not here to check the consistency of the BibTeX file, so there is
-- no check that xdata refers only to @xdata entries
-- Removing the crossref field implies we won't track its use and implicitly
-- cite referenced entries in the bibliography over a certain threshold.
-- @tparam table bib Bibliography
-- @tparam table entry Bibliography entry
local function crossrefAndXDataResolve (bib, entry)
   local refs
   local xdata = entry.attributes.xdata
   if xdata then
      refs = xdata and pl.stringx.split(xdata, ",")
      entry.attributes.xdata = nil
   end
   local crossref = entry.attributes.crossref
   if crossref then
      refs = refs or {}
      table.insert(refs, crossref)
      entry.attributes.crossref = nil
   end

   if not refs then
      return
   end
   for _, ref in ipairs(refs) do
      local parent = bib[ref]
      if parent then
         crossrefAndXDataResolve(bib, parent)
         fieldsInherit(parent, entry)
      else
         SU.warn("Unknown crossref " .. ref .. " in bibliography entry " .. entry.label)
      end
   end
end

return {
   parseBibtex = parseBibtex,
   crossrefAndXDataResolve = crossrefAndXDataResolve,
}
