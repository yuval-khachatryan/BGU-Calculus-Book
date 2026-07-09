--[[
theorem-numbering.lua

One shared, section-scoped counter for every theorem-like box. Definitions,
theorems, propositions, examples (and lemmas/corollaries) are numbered
    chapter.section.item        e.g.  2.4.1, 2.4.2, 2.4.3, 2.5.1, ...
in a single running sequence per "##" section — instead of Quarto's default
of a separate counter per type.

The chapter number is read from the input filename (NN-slug.qmd), so it stays
correct automatically when chapters are reordered. The book has no
@-cross-references to these boxes, so we simply (re)title each box and hand its
styling to CSS classes (.thmbox / .thmbox-<type>); the crossref class is removed
so Quarto does not also number it.

Wire it in _quarto.yml:
    filters:
      - theorem-numbering.lua
      - quarto
]]

local PREFIX = {
  definition  = "הגדרה",
  theorem     = "משפט",
  proposition = "טענה",
  lemma       = "למה",
  corollary   = "מסקנה",
  example     = "דוגמה",
}

-- chapter number "NN" from the input file basename  NN-slug.qmd
local function chapter_number()
  -- >>> DEBUG (temporary): dump the paths the filter can see to thmdebug.txt.
  local dbg = io.open("thmdebug.txt", "a")
  if dbg then
    dbg:write("quarto.doc.input_file = "
      .. tostring(quarto and quarto.doc and quarto.doc.input_file) .. "\n")
    if PANDOC_STATE and PANDOC_STATE.input_files then
      for i, f in ipairs(PANDOC_STATE.input_files) do
        dbg:write("PANDOC_STATE.input_files[" .. i .. "] = " .. tostring(f) .. "\n")
      end
    end
    dbg:write("----\n")
    dbg:close()
  end
  -- <<< DEBUG

  local files = {}
  if quarto and quarto.doc and quarto.doc.input_file then
    files[#files + 1] = quarto.doc.input_file
  end
  if PANDOC_STATE and PANDOC_STATE.input_files then
    for _, f in ipairs(PANDOC_STATE.input_files) do files[#files + 1] = f end
  end
  for _, f in ipairs(files) do
    local base = tostring(f):match("([^/\\]+)$") or tostring(f)
    local nn = base:match("^(%d%d)%-")
    if nn then return nn end
  end
  return nil
end

function Pandoc(doc)
  local chap = chapter_number()

  -- >>> DEBUG: dump the top-level block structure the filter actually receives
  local dbg = io.open("thmdebug.txt", "a")
  if dbg then
    dbg:write("=== Pandoc chap=" .. tostring(chap) .. " nblocks=" .. #doc.blocks .. "\n")
    for _, b in ipairs(doc.blocks) do
      if b.t == "Header" then
        dbg:write("  Header level=" .. tostring(b.level) .. "\n")
      elseif b.t == "Div" then
        dbg:write("  Div classes=[" .. table.concat(b.classes, ",") .. "]\n")
      else
        dbg:write("  " .. tostring(b.t) .. "\n")
      end
    end
    dbg:close()
  end
  -- <<< DEBUG

  if not chap then return doc end   -- unknown chapter: leave Quarto's numbering

  local section, item = 0, 0
  for _, b in ipairs(doc.blocks) do
    if b.t == "Header" and b.level == 2 then
      section = section + 1
      item = 0
    elseif b.t == "Div" then
      local kind
      for _, c in ipairs(b.classes) do
        if PREFIX[c] then kind = c; break end
      end
      if kind and section > 0 then
        item = item + 1
        local num = chap .. "." .. section .. "." .. item
        local title = pandoc.Para({
          pandoc.Strong({ pandoc.Str(PREFIX[kind] .. " " .. num .. ".") })
        })
        table.insert(b.content, 1, title)
        b.classes = { "thmbox", "thmbox-" .. kind }   -- keep identifier, restyle
      end
    end
  end
  return doc
end
