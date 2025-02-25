-- string.lua
-- Copyright (C) 2020-2022 Posit Software, PBC


-- tests whether a string ends with another string
function endsWith(str, ending) 
  return ending == "" or str:sub(-#ending) == ending
end

function startsWith(str, starting) 
  return starting == "" or str:sub(1, #starting) == starting
end

-- trim a string
function trim(s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

-- splits a string on a separator
function split(str, sep)
  local fields = {}
  
  local sep = sep or " "
  local pattern = string.format("([^%s]+)", sep)
  local _ignored = string.gsub(str, pattern, function(c) fields[#fields + 1] = c end)
  
  return fields
end

-- escape string by converting using Pandoc
function stringEscape(str, format)
  local doc = pandoc.Pandoc({pandoc.Para(str)})
  return pandoc.write(doc, format)
end

-- The character `%´ works as an escape for those magic characters. 
-- So, '%.' matches a dot; '%%' matches the character `%´ itself. 
-- You can use the escape `%´ not only for the magic characters, 
-- but also for all other non-alphanumeric characters. When in doubt, 
-- play safe and put an escape.
-- ( from http://www.lua.org/pil/20.2.html )
function patternEscape(str) 
  return str:gsub("([^%w])", "%%%1")
end