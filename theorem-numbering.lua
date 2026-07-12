--[[
theorem-numbering.lua

One shared, section-scoped counter for every theorem-like box. Definitions,
theorems, propositions and examples are numbered

    chapter.section.item        e.g.  2.4.1, 2.4.2, 2.4.3, 2.5.1, ...

as a single running sequence per "##" section, instead of Quarto's default of a
separate counter per type.

Why custom classes: Quarto's own crossref runs before any user filter and would
number these boxes per-type and strip their classes, so we can't intercept the
standard .definition/.theorem/... classes. Instead the boxes use classes Quarto
does NOT recognise (.thmdef/.thmthm/.thmprp/.thmexm/.thmlem/.thmcor), so Quarto
leaves them untouched and this filter owns them completely: it prepends the
title and applies the styling classes (.thmbox / .thmbox-<type>, defined in
_styles.html for HTML). Because that happens at the content level, the numbering
is identical in HTML and PDF.

The chapter number is read from the input filename (NN-slug.qmd) via Quarto's
quarto.doc.input_file, so it stays correct automatically when chapters are
reordered. There are no @-cross-references to these boxes.
]]

local BOX = {
  thmdef = { word = "הגדרה", css = "definition"  },
  thmthm = { word = "משפט",  css = "theorem"     },
  thmprp = { word = "טענה",  css = "proposition" },
  thmexm = { word = "דוגמה", css = "example"     },
  thmlem = { word = "למה",   css = "lemma"       },
  thmcor = { word = "מסקנה", css = "corollary"   },
}

-- chapter number "NN" from the input file basename  NN-slug.qmd
local function chapter_number()
  local f = quarto and quarto.doc and quarto.doc.input_file
  if not f then return nil end
  local base = tostring(f):match("([^/\\]+)$") or tostring(f)
  local nn = base:match("^(%d%d)%-")
  if nn then return tostring(tonumber(nn)) end   -- "03" -> "3"
  return nil
end

function Pandoc(doc)
  local chap = chapter_number()
  if not chap then return doc end   -- unknown chapter: leave boxes as-is

  local section, item = 0, 0
  for _, b in ipairs(doc.blocks) do
    if b.t == "Header" and b.level == 2 then
      section = section + 1
      item = 0
    elseif b.t == "Div" then
      local box
      for _, c in ipairs(b.classes) do
        if BOX[c] then box = BOX[c]; break end
      end
      if box then
        item = item + 1
        local num = chap .. "." .. section .. "." .. item
        local title = pandoc.Para({
          pandoc.Strong({ pandoc.Str(box.word .. " " .. num .. ".") })
        })
        table.insert(b.content, 1, title)
        b.classes = { "thmbox", "thmbox-" .. box.css }   -- keep identifier, restyle
      end
    end
  end
  return doc
end
