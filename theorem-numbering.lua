--[[
theorem-numbering.lua

One shared, section-scoped counter for numbered theorem-like boxes, numbered

    chapter.section.item        e.g.  2.4.1, 2.4.2, 2.4.3, 2.5.1, ...

as a single running sequence per "##" section. The boxes use classes Quarto does
NOT recognise (.thmdef/.thmthm/.thmprp/.thmexm/.thmlem/.thmcor), so Quarto leaves
them alone and this filter owns them: it prepends the numbered title and applies
the styling classes (.thmbox / .thmbox-<type>, defined in _styles.html for HTML).
The chapter number is read from the input filename NN-slug.qmd.

Extensions:
  * .thmproof — proof box: label "הוכחה." but UNNUMBERED; styled .thmbox-proof.
  * .optional — "רשות" wrapper: its inner boxes are labelled but UNNUMBERED
                (\newtheorem* style). Tinted via _styles.html (HTML) / the
                'optionalbox' LaTeX environment (PDF).
  * .foldable — in HTML the block is wrapped in <details> (click to reveal); in
                PDF it is shown as-is. (Marker class only; deliberately NOT named
                "collapse", which is a Bootstrap utility that forces display:none.)

The filter RECURSES into nested divs, so boxes inside .optional (or any wrapper)
are still labelled. Top-level boxes are numbered; boxes inside .optional are not.
]]

local BOX = {
  thmdef = { word = "הגדרה", css = "definition"  },
  thmthm = { word = "משפט",  css = "theorem"     },
  thmprp = { word = "טענה",  css = "proposition" },
  thmexm = { word = "דוגמה", css = "example"     },
  thmlem = { word = "למה",   css = "lemma"       },
  thmcor = { word = "מסקנה", css = "corollary"   },
}

local function chapter_number()
  local f = quarto and quarto.doc and quarto.doc.input_file
  if not f then return nil end
  local base = tostring(f):match("([^/\\]+)$") or tostring(f)
  local nn = base:match("^(%d%d)%-")
  if nn then return tostring(tonumber(nn)) end   -- "03" -> "3"
  return nil
end

local function has_class(classes, name)
  for _, c in ipairs(classes) do if c == name then return true end end
  return false
end

local function box_for(classes)
  for _, c in ipairs(classes) do if BOX[c] then return BOX[c] end end
  return nil
end

local function label_para(text)
  return pandoc.Para({ pandoc.Strong({ pandoc.Str(text) }) })
end

local chap, section, item, is_html
local process

process = function(blocks, in_optional)
  local out = {}
  for _, b in ipairs(blocks) do
    if b.t == "Header" and b.level == 2 and not in_optional then
      section = section + 1
      item = 0
      out[#out + 1] = b
    elseif b.t == "Div" then
      local orig       = b.classes
      local do_collapse = has_class(orig, "foldable") or has_class(orig, "optional")   -- NB: not "collapse" (Bootstrap owns that; it sets display:none)
      local is_proof    = has_class(orig, "thmproof")
      local is_remark   = has_class(orig, "thmrem")

      if is_proof then
        table.insert(b.content, 1, label_para("הוכחה."))
        b.content = process(b.content, in_optional)
        b.classes = { "thmbox", "thmbox-proof" }
      elseif is_remark then
        -- Remark box: NUMBERED (chapter.section.item) like the other boxes; an optional
        -- title= is folded into the label. Change `word` to rename the label everywhere.
        local word = "הערה"
        local text
        if in_optional then
          text = word
        else
          item = item + 1
          text = word .. " " .. chap .. "." .. section .. "." .. item
        end
        local t = b.attributes and b.attributes.title
        text = (t and t ~= "") and (text .. " (" .. t .. ").") or (text .. ".")
        table.insert(b.content, 1, label_para(text))
        b.content = process(b.content, in_optional)
        b.classes = { "thmbox", "thmbox-remark" }
      elseif has_class(orig, "extra") then
        -- Enrichment ("העשרה"): NOT foldable, part of the running text; inner boxes numbered
        -- (in_optional = false). A `## heading` inside becomes the box's header bar (a real
        -- numbered section, via makeSections). For a small aside with no heading, a `title=`
        -- attribute is rendered instead as a (non-section) header bar. Box look is pure CSS.
        local t = b.attributes and b.attributes.title
        if t and t ~= "" and not (b.content[1] and b.content[1].t == "Header") then
          table.insert(b.content, 1,
            pandoc.Div({ pandoc.Plain({ pandoc.Str(t) }) }, pandoc.Attr("", { "extra-title" })))
        end
        b.content = process(b.content, false)
        -- keep the .extra class for HTML/CSS
      elseif has_class(orig, "optional") then
        b.content = process(b.content, true)
        if not is_html then
          table.insert(b.content, 1, pandoc.RawBlock("latex", "\\begin{optionalbox}"))
          table.insert(b.content, pandoc.RawBlock("latex", "\\end{optionalbox}"))
        end
        -- keep the .optional class for HTML CSS
      else
        local box = box_for(orig)
        if box then
          local text
          if in_optional then
            text = box.word .. "."                       -- unnumbered
          else
            item = item + 1
            text = box.word .. " " .. chap .. "." .. section .. "." .. item .. "."
          end
          table.insert(b.content, 1, label_para(text))
          b.content = process(b.content, in_optional)
          b.classes = { "thmbox", "thmbox-" .. box.css }
        else
          b.content = process(b.content, in_optional)   -- generic wrapper: recurse
        end
      end

      if do_collapse and is_html then
        local summary = "הצג/הסתר"
        local attrs = ' class="thmcollapse"'
        if is_proof then
          summary = "הוכחה"
        elseif has_class(orig, "optional") then
          summary = (b.attributes and b.attributes.title) or "קריאת רשות"
          attrs = ' class="thmcollapse thmoptional"'   -- collapsed by default (no "open")
        end
        out[#out + 1] = pandoc.RawBlock("html", '<details' .. attrs .. '><summary>' .. summary .. '</summary>')
        out[#out + 1] = b
        out[#out + 1] = pandoc.RawBlock("html", '</details>')
      else
        out[#out + 1] = b
      end
    else
      out[#out + 1] = b
    end
  end
  return out
end

function Pandoc(doc)
  chap = chapter_number()
  if not chap then return doc end   -- unknown chapter: leave boxes as-is
  section, item = 0, 0
  if quarto and quarto.doc and quarto.doc.is_format then
    is_html = quarto.doc.is_format("html")
  else
    is_html = (FORMAT ~= nil and FORMAT:match("html") ~= nil)
  end
  doc.blocks = process(doc.blocks, false)
  return doc
end
