-- ProgresSVG Quarto Extension
-- Enables progressive display of SVG elements in reveal.js presentations

-- Global state tracking
local svg_files = {}
local svg_labels = {}  -- maps filepath -> set of known labels
local svg_injected = {}
local current_slide = 0
local fragment_index = 0
local assets_injected = false

local function log(message)
  print("[ProgresSVG] " .. message)
end

-- Escape ALL Lua magic pattern characters in a string
local function escape_pattern(s)
  return s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

-- Escape % in gsub replacement strings (only special char in replacements)
-- Wrapping in () forces single return value, preventing gsub's count from
-- leaking as an extra argument when used inline (Lua multiple-return gotcha)
local function escape_replacement(s)
  return (s:gsub("%%", "%%%%"))
end

-- Sanitize a label into a valid HTML/SVG id attribute
local function sanitize_id(label)
  local id = label:gsub("[^a-zA-Z0-9_%-]", "_")
  if id:match("^[^a-zA-Z_]") then
    id = "_" .. id
  end
  if id == "" then
    id = "_element"
  end
  return id
end

local function read_file(filepath)
  local file = io.open(filepath, "r")
  if not file then
    log("ERROR: Could not open file: " .. filepath)
    return nil
  end
  local content = file:read("*all")
  file:close()
  return content
end

local function process_svg(svg_content, filepath)
  log("Processing SVG file: " .. filepath)

  local modified = svg_content
  local label_count = 0

  local elements_to_process = {}
  local known_labels = {}

  for label in svg_content:gmatch('inkscape:label="([^"]+)"') do
    label_count = label_count + 1
    log("Found element with label: '" .. label .. "'")
    table.insert(elements_to_process, label)
    known_labels[label] = true
  end

  svg_labels[filepath] = known_labels

  for _, label in ipairs(elements_to_process) do
    local pattern = '(<[^>]-)inkscape:label="' .. escape_pattern(label) .. '"([^>]*)>'

    local element_start, element_end = modified:match(pattern)
    if element_start then
      local is_group = element_start:match('<g[%s>]')

      if not is_group then
        -- Replace or add ID (using sanitized label for valid HTML id)
        local safe_id = sanitize_id(label)
        local has_id = element_start:match('id="([^"]+)"')
        if has_id then
          element_start = element_start:gsub('id="[^"]+"', 'id="' .. safe_id .. '"')
        else
          element_start = element_start .. ' id="' .. safe_id .. '"'
        end

        -- Handle style attribute
        local existing_style = element_start:match('style="([^"]*)"')
        if existing_style then
          -- Remove existing display and opacity properties if present
          local new_style = existing_style:gsub('display%s*:%s*[^;]+;?', '')
          new_style = new_style:gsub('opacity%s*:%s*[^;]+;?', '')
          -- Add opacity:0 at the beginning (no display:none, so CSS transitions work)
          new_style = 'opacity:0;' .. new_style
          element_start = element_start:gsub('style="[^"]*"', escape_replacement('style="' .. new_style .. '"'))
          log("  Updated style for '" .. label .. "'")
        else
          -- No style attribute, add one
          element_start = element_start .. ' style="opacity:0"'
          log("  Added style for '" .. label .. "'")
        end

        local replacement = escape_replacement(element_start .. element_end .. '>')
        modified = modified:gsub(pattern, replacement, 1)
      else
        -- For groups, just update ID
        local safe_id = sanitize_id(label)
        local has_id = element_start:match('id="([^"]+)"')
        if has_id then
          element_start = element_start:gsub('id="[^"]+"', 'id="' .. safe_id .. '"')
        else
          element_start = element_start .. ' id="' .. safe_id .. '"'
        end
        local replacement = escape_replacement(element_start .. element_end .. '>')
        modified = modified:gsub(pattern, replacement, 1)
        log("  Group element, ID updated")
      end
    end
  end

  log("Removing width/height from SVG")
  modified = modified:gsub('(<svg[^>]-)%s+width="[^"]*"', '%1')
  modified = modified:gsub('(<svg[^>]-)%s+height="[^"]*"', '%1')

  log("Normalizing viewBox")
  modified = modified:gsub('viewbox="', 'viewBox="')
  modified = modified:gsub('VIEWBOX="', 'viewBox="')

  log("Total labels processed: " .. label_count)
  return modified
end

local function get_svg(filepath)
  if svg_files[filepath] then
    log("Using cached SVG")
    return svg_files[filepath]
  end

  log("Processing SVG for first time: " .. filepath)
  local content = read_file(filepath)
  if not content then
    return nil
  end

  local processed = process_svg(content, filepath)
  svg_files[filepath] = processed
  return processed
end

local function get_assets_html()
  if assets_injected then
    return ""
  end

  local extension_dir = pandoc.path.directory(PANDOC_SCRIPT_FILE) .. "/"
  local css_content = read_file(extension_dir .. "progressvg.css")
  local js_content = read_file(extension_dir .. "progressvg.js")

  if not css_content or not js_content then
    log("ERROR: Could not read assets")
    return ""
  end

  assets_injected = true

  return string.format([[
<style>
%s
</style>
<script>
%s
</script>
]], css_content, js_content)
end

function Div(el)
  if not el.classes:includes('progressvg') then
    return nil
  end

  local file = el.attributes.file
  local element = el.attributes.element
  local action = el.attributes.action or "show"

  if not file or not element then
    log("ERROR: Missing file or element attribute")
    return el
  end

  if action ~= "show" and action ~= "hide" then
    action = "show"
  end

  log("Processing: file=" .. file .. ", element=" .. element .. ", action=" .. action)

  local svg_content = get_svg(file)
  if not svg_content then
    return el
  end

  -- Warn if the referenced element doesn't exist in the SVG
  if svg_labels[file] and not svg_labels[file][element] then
    log("WARNING: element '" .. element .. "' not found in " .. file)
    log("  Available labels: " .. table.concat(
      (function()
        local keys = {}
        for k, _ in pairs(svg_labels[file]) do table.insert(keys, "'" .. k .. "'") end
        table.sort(keys)
        return keys
      end)(), ", "))
  end

  local slide_key = current_slide .. "_" .. file
  local needs_injection = not svg_injected[slide_key]

  if needs_injection then
    svg_injected[slide_key] = true
  end

  local html_parts = {}
  table.insert(html_parts, get_assets_html())

  if needs_injection then
    local container_id = "progressvg-container-" .. file:gsub("[^a-zA-Z0-9]", "-")
    table.insert(html_parts, string.format(
      '<div id="%s" class="progressvg-container" data-svg-file="%s">',
      container_id, file
    ))
    table.insert(html_parts, svg_content)
    table.insert(html_parts, '</div>')
  end

  table.insert(html_parts, string.format(
    '<div class="progressvg-trigger" data-svg-file="%s" data-element="%s" data-action="%s"></div>',
    file, sanitize_id(element), action
  ))

  return pandoc.RawBlock('html', table.concat(html_parts, "\n"))
end

function Header(el)
  if el.level == 2 then
    current_slide = current_slide + 1
    svg_injected = {}
    log("\n### Slide #" .. current_slide .. " ###\n")
  end
  return el
end

return {
  {Header = Header, Div = Div}
}
