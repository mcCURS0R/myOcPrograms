local text = require("text");
local unicode = require("unicode");

local align = {};

align.direction = {};
                                      -- VVHH
align.direction.any           = 0x00; -- 0000
align.direction.left          = 0x01; -- 0001
align.direction.right         = 0x02; -- 0010
align.direction.center        = 0x03; -- 0011

align.direction.top           = 0x04; -- 0100
align.direction.topLeft       = 0x05; -- 0101
align.direction.topRight      = 0x06; -- 0110
align.direction.topCenter     = 0x07; -- 0111

align.direction.middle        = 0x08; -- 1000
align.direction.middleLeft    = 0x09; -- 1001
align.direction.middleRight   = 0x0A; -- 1010
align.direction.middleCenter  = 0x0B; -- 1011

align.direction.bottom        = 0x0C; -- 1100
align.direction.bottomLeft    = 0x0D; -- 1101
align.direction.bottomRight   = 0x0E; -- 1110
align.direction.bottomCenter  = 0x0F; -- 1111

align.center = function(str, width)

  if not str then return text.padLeft("", width); end

  str = text.trim(str);
  local offset = width - unicode.len(str);

  if offset == 0 then
    return str;
  elseif offset > 0 then
    return text.padRight(text.padLeft("", math.floor(offset / 2)) .. str, width);
  else
    return string.sub(str, 1 + math.floor(-offset / 2), 
      unicode.len(str) - math.ceil(-offset / 2));
  end

end

align.left = function(str, width)
  if not str then return text.padLeft("", width); end

  str = text.trim(str);
  local offset = width - unicode.len(str);

  if offset == 0 then
    return str;
  elseif offset > 0 then
    return text.padRight(str, width);
  else
    return string.sub(str, 1, width);
  end

end

align.right = function(str, width)
  if not str then return text.padLeft("", width); end;

  str = text.trim(str);
  local offset = width - unicode.len(str);
  
  if offset == 0 then
    return str;
  elseif offset > 0 then
    return text.padLeft(str, width);
  else
    return string.sub(str, 1 + -offset, unicode.len(str));
  end

end

align.wrap = function(str, width)
  
  local retTable = {};
  if str and width then
    local fnc = text.wrappedLines(str, width, width);
    local line = fnc();
    while line do
      table.insert(retTable, line);
      line = fnc();
    end
  end
  return retTable;
  
end

align.top = function(str, width, height, hAlign)
  str = str or "";
  width = width or 1;
  local linesTable = align.wrap(str, width);
  height = height or #linesTable
  hAlign = bit32.band(hAlign or 1, 0x3);
  local retTable = {};
  
  for n = 1, height do
    local line = #linesTable >= n and linesTable[n] or "";
    if (hAlign == align.direction.center) then
      table.insert(retTable, align.center(line, width));
     elseif (hAlign == align.direction.right) then
      table.insert(retTable, align.right(line, width));
     else
      table.insert(retTable, align.left(line, width));
     end
  end

  return retTable;
end

align.topLeft = function(str, width, height)
  return align.top(str, width, height, align.direction.left);
end

align.topRigth = function(str, width, height)
  return align.top(str, width, height, align.direction.right);
end

align.topCenter = function(str, width, height)
  return align.top(str, width, height, align.direction.center);
end

align.middle = function(str, width, height, hAlign)

  str = str or "";
  width = width or 1;
  local linesTable = align.wrap(str, width);
  local nLines = #linesTable;
  height = height or nLines;
  hAlign = bit32.band(hAlign or 1, 0x3);
  
  local offset = height - nLines;
  
  local retTable = {}
  local fnc = text.wrappedLines(str, width, width);
  
  for n = 1, math.min(height, nLines) do
    local line = fnc();
    local insertLine = false;
    if line then
      if offset == 0 then
        insertLine = true;
      elseif offset > 0 and n == 1 then
        for bl = 1, math.ceil(offset / 2) do 
          table.insert(retTable, align.left(nil, width));
        end
        insertLine = true;
      else
        if n > math.floor(-offset / 2) then
          insertLine = true;
        end
      end
    end
    
    if (insertLine) then
      if hAlign == align.direction.center then
        table.insert(retTable, align.center(line, width));
      elseif hAlign == align.direction.right then
        table.insert(retTable, align.right(line, width));
      else
        table.insert(retTable, align.left(line, width));
      end
    end
    
  end
  
  if #retTable < height then
    for n = 1, height - #retTable do
      table.insert(retTable, align.left(nil, width));
    end
  end
  
  return retTable;
  
end

align.middleLeft = function(str, width, height)
  return align.middle(str, width, height, align.direction.left);
end

align.middleRigth = function(str, width, height)
  return align.middle(str, width, height, align.direction.right);
end

align.middleCenter = function(str, width, height)
  return align.middle(str, width, height, align.direction.center);
end

align.bottom = function(str, width, height, hAlign)
  str = str or "";
  width = width or 1;
  local linesTable = align.wrap(str, width);
  local nLines = #linesTable;
  height = height or nLines;
  hAlign = bit32.band(hAlign or 1, 0x3);
  
  local offset = height - nLines;
  
  local retTable = {}
  local fnc = text.wrappedLines(str, width, width);
  
  for n = 1, height do
    local line = fnc();
    local insertLine = false;
    if line then
      if offset == 0 then
        insertLine = true;
      elseif offset > 0 and n == 1 then
        for bl = 1, math.ceil(offset) do 
          table.insert(retTable, align.left(nil, width));
        end
        insertLine = true;
      else
        if n > math.floor(-offset) then
          insertLine = true;
        end
      end
    end
    
    if (insertLine) then
      if hAlign == align.direction.center then
        table.insert(retTable, align.center(line, width));
      elseif hAlign == align.direction.right then
        table.insert(retTable, align.right(line, width));
      else
        table.insert(retTable, align.left(line, width));
      end
    end
    
  end
  
  return retTable;
end

align.bottomLeft = function(str, width, height)
  return align.bottom(str, width, height, align.direction.left);
end

align.bottomRigth = function(str, width, height)
  return align.bottom(str, width, height, align.direction.right);
end

align.bottomCenter = function(str, width, height)
  return align.bottom(str, width, height, align.direction.center);
end

align.align = function(str, width, height, direction)
  local vAlign = bit32.band(direction or align.direction.top, 0xC);
  local hAlign = bit32.band(direction or align.direction.left, 0x3);

  str = str or "";
    
  if vAlign == align.direction.middle then
    return align.middle(str, width, height, hAlign);
  elseif vAlign == align.direction.bottom then
    return align.bottom(str, width, height, hAlign);
  else
    return align.top(str, width, height, hAlign);
  end
  
end

return align;