-- jats.lua
-- Copyright (C) 2021-2022 Posit Software, PBC
local normalizeAuthors = require 'modules/authors'
local normalizeLicense = require 'modules/license'

local kTags = "tags"
local kKeywords = "keywords"

local kQuartoInternal = "quarto-internal"
local kHasAuthorNotes = "has-author-notes"
local kHasPermissions = "has-permissions"

local function isCell(el) 
  return el.classes:includes("cell") 
end

local function jatsMeta(meta) 
  -- inspect the meta and set flags that will aide the rendering of
  -- the JATS template by providing some synthesize properties
  -- to prevent empty container XML elements

  -- are there author notes?
  local authors = meta[normalizeAuthors.constants.author.output_key]
  if authors ~= nil then

    -- has author notes
    local hasNotes = authors:find_if(function(author) 
      local hasAttr = author[normalizeAuthors.constants.author.attributes] ~= nil and next(author[normalizeAuthors.constants.author.attributes])
      local hasNote = author[normalizeAuthors.constants.author.note] and next(author[normalizeAuthors.constants.author.note])
      return hasAttr or hasNote
    end)

    -- has permissions
    local hasCopyright = meta[normalizeLicense.constants.copyright] ~= nil
    local hasLicense = meta[normalizeLicense.constants.license] ~= nil
    local hasPermissions = hasCopyright or hasLicense

    if meta[kQuartoInternal] == nil then
      meta[kQuartoInternal] = {}
    end
    meta[kQuartoInternal][kHasAuthorNotes] = hasNotes;
    meta[kQuartoInternal][kHasPermissions] = hasPermissions;

    -- normalize keywords into tags if they're present and tags aren't
    if meta[kTags] == nil and meta[kKeywords] ~= nil and meta[kKeywords].t == "Table" then
      meta[kKeywords] = meta[kTags]
    end

    return meta
  end
end

function unrollDiv(div, fnSkip)

  -- unroll blocks contained in divs
  local blocks = pandoc.List()
  for _, childBlock in ipairs(div.content) do
    if childBlock.t == "Div" then
      if fnSkip and not fnSkip(div) then
        blocks:insert(childBlock)
      else
        tappend(blocks, childBlock.content)
      end
    else
      blocks:insert(childBlock)
    end
  end
  return blocks
end

function jatsCallout(node)
  local contents = resolveCalloutContents(node, true)

  local boxedStart = '<boxed-text>'
  if node.id and node.id ~= "" then
    boxedStart = "<boxed-text id='" .. node.id .. "'>"
  end
  contents:insert(1, pandoc.RawBlock('jats', boxedStart))
  contents:insert(pandoc.RawBlock('jats', '</boxed-text>'))
  return contents
end

function jats()
  if not _quarto.format.isJatsOutput() then
    return {}
  end

  return {
    Meta = jatsMeta,

    -- clear out divs
    Div = function(div)
      return unrollDiv(div)
    end,

    Callout = jatsCallout,
  }
end

function jatsSubarticle() 

  if _quarto.format.isJatsOutput() then

    local kNoteBookCode = "notebook-code"
    local kNoteBookContent = "notebook-content"
    local kNoteBookOutput = "notebook-output"

    local isCodeCell = function(el) 
      return not el.classes:includes('markdown')
    end

    local isCodeCellOutput = function(el)
      return el.classes:includes("cell-output")
    end

    local ensureValidIdentifier = function(identifier) 
      -- Identifiers may not start with a digit, so add a prefix
      -- if necessary to ensure that they're valid
      if identifier:find('^%d.*') then
        return "cell-" .. identifier
      else
        return identifier
      end
    end

    local function renderCell(el, type)
      local renderedCell = pandoc.List()
      renderedCell:insert(pandoc.RawBlock('jats', '<sec id="' .. ensureValidIdentifier(el.identifier) .. '" sec-type="' .. type .. '">'))
      for _i, v in ipairs(el.content) do
        renderedCell:insert(v)
      end
      renderedCell:insert(pandoc.RawBlock('jats', '</sec>'))
      return renderedCell
    end

    local function renderCellOutput(el, type)
      local renderedCell = pandoc.List()
      renderedCell:insert(pandoc.RawBlock('jats', '<sec id="' .. el.identifier .. '" content-type="' .. type .. '">'))
      for _i, v in ipairs(el.content) do
        renderedCell:insert(v)
      end
      renderedCell:insert(pandoc.RawBlock('jats', '</sec>'))
      return renderedCell
    end

    return {
      Meta = jatsMeta,
      Div = function(div)
        
        -- TODO: Code cell with #fig-asdas label gets turned into a figure div, need to stop that

        -- this is a notebook cell, handle it
        if isCell(div) then
          if isCodeCell(div) then

              -- if this is an executable notebook cell, walk the contents and add identifiers
              -- to the outputs
              local parentId = div.identifier

              local count = 0
              div = _quarto.ast.walk(div, {
                Div = function(childEl)
                  if (isCodeCellOutput(childEl)) then
                    childEl.identifier = parentId .. '-output-' .. count
                    count = count + 1
                    return renderCellOutput(childEl, kNoteBookOutput)
                  end
                end
              })

            -- render the cell
            return renderCell(div, kNoteBookCode)
          else
            if #div.content == 0 then
              -- eat empty markdown cells
              return {}
            else
              -- the is a valid markdown cell, let it through              
              return renderCell(div, kNoteBookContent)
            end
          end
        elseif isCodeCellOutput(div) then
          -- do nothing
        else
          -- Forward the identifier from a table div onto the table itself and 
          -- discard the div
          if isTableDiv(div) then
            local tbl = div.content[1]
            tbl.identifier = div.identifier
            return tbl
          else
            -- otherwise, if this is a div, we can unroll its contents
            return unrollDiv(div, function(el) 
              return isCodeCellOutput(el) or isCell(el)
            end)
          end 

        end
      end,
    }

  else 
    return {}
  end
end
