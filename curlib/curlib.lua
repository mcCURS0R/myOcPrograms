local component = require("component");
local term = require("term");
local keyboard = require("keyboard");
local txt = require("text");
local s = require("serialization");
local event = require("event");
local computer = require("computer");
local align = require("textalign");
local unicode = require("unicode")

local gpu = component.gpu;

if gpu.getDepth() < 4 then
  error("curlib requires at least a tier2 screen/gpu... ");
end

local curlib = {};

curlib.getParamErrorMsg = function (fnc, param)
  fnc = fnc or "fnc";
  param = param or "parameter"
  return param .. " cannot be nil! did you forgot do call function '" 
    .. fnc .. "' as 'obj:" .. fnc .. "'?";
end

curlib.defaults = {};
curlib.defaults.app = {};
curlib.defaults.control = {};
curlib.defaults.window = {};
curlib.defaults.button = {};
curlib.defaults.input = {};

--TODO get this from a configuration file;
curlib.defaults.shadow = 0x101010;
curlib.defaults.app.background = 0x484848;
curlib.defaults.app.foreground = 0xCCCCCC;
curlib.defaults.control.background = 0x333333;
curlib.defaults.control.foreground = 0xCCCCCC;
curlib.defaults.window.foreground = 0x383838;
curlib.defaults.window.background = 0xA0A0A0;
curlib.defaults.button.foreground = 0xCCCC00;
curlib.defaults.button.background = 0x000066;
curlib.defaults.input.foreground = 0x101010;
curlib.defaults.input.background = 0xE0E0E0;

curlib.palette = {};
curlib.orgPalette = {};

if gpu.getDepth() == 4 then
  local pNum = 1
  for k, v in pairs(curlib.defaults) do
    if k == "shadow"
      or k == "foreground" 
      or k == "background" 
      or k == "color"
    then
      if curlib.palette[v] == nil then
        curlib.palette[v] = pNum;
        pNum = pNum + 1;
      end
    else 
      if type(v) == "table" then
        for kl, vl in pairs(v) do
          if kl == "shadow"
            or kl == "foreground"
            or kl == "background"
            or kl == "color"
          then
            if curlib.palette[vl] == nil then
              curlib.palette[vl] = pNum;
              pNum = pNum + 1;
            end
          end
        end
      end
    end
    if (pNum > 16) then 
      error("curlib: more then 16 unique colors found in configuration. we need a better screen/gpu");    
    end
  end
  for k, v in pairs(curlib.palette) do
    curlib.orgPalette[v] = gpu.getPaletteColor(v);
    gpu.setPaletteColor(v, k);
  end
end

curlib.cleanPalette = function()
  for k, v in pairs(curlib.orgPalette) do
    gpu.setPaletteColor(k, v);
  end
end

curlib.screen = {};
curlib.screen.cursor = {}
curlib.screen.cursor.blink = false;
curlib.screen.cursor.x = 1;
curlib.screen.cursor.y = 1;

curlib.control = {};

curlib.control.new = function(self, obj)
  if not self then error(curlib.getParamErrorMsg("new", "self")); end
  obj = obj or {};
  setmetatable(obj, self);
  self.__index = self;    

  gpu.setForeground(0xFFFFFF);

  --defaults
  obj.x = obj.x or 1;
  obj.y = obj.y or 1;
  obj.width = obj.width or 10;
  obj.height = obj.height or 1;
  obj.children = obj.children or {};
  obj.dirty = true;
  obj.visible = true;
  obj.shadow = obj.shadow or false;
  obj.foreground = obj.foreground or curlib.defaults.control.foreground;
  obj.background = obj.background or curlib.defaults.control.background;

  return obj;
end

curlib.control.status = function(text) 
  local width, height = gpu.getResolution();
  gpu.setForeground(0xFF0000);
  gpu.fill(1, height, width, height, " ");
  gpu.set(1, height, text);
end

curlib.control.clearFocus = function(self, fulltree)
  if not self then error(curlib.getParameterErrorMsg("clearFocus", "self")); end

  if fulltree then
    local root = self;

    while root.parent do
      root = root.parent;
    end

    self = root;    
  end

  for k, v in ipairs(self.children) do
    v:clearFocus(false);
  end

  if self.focus then
    self.focus = false;
    self.lostFocus = true;
  end

end

curlib.control.setFocus = function(self, focus)
  if not self then error(curlib.getParamErrorMsg("focus", "self")); end
  focus = (focus == nil) or true;

  if focus then
    self:clearFocus(true);
  elseif self.focus then
    self.lostFocus = true;
  end
  
  self.focus = focus;
end

curlib.control.addChild = function(self, control)
  if not self then error(curlib.getParamErrorMsg("addChild", "self")); end
  if not control then error(curlib.getParamErrorMsg("new", "control")); end
  if not self.children then self.children = {}; end
  table.insert(self.children, control);
  control.parent = self;
end

curlib.control.updateColors = function(self)
  if not self then error(curlib.getParamErrorMsg("updateColors", "self")); end
  if not self.foreground then self.foreground = curlib.defaults.foreground; end
  if not self.background then self.background = curlib.defaults.background; end

  local fg = self.flashColors and self.background or self.foreground;
  local bg = self.flashColors and self.foreground or self.background;

  gpu.setForeground(fg);
  gpu.setBackground(bg);

  return fg, bg;
end

curlib.control.invalidate = function(self, invalidateChildren)
  if not self then error(curlib.getParamErrorMsg("invalidate", "self")); end
  self.dirty = true;
  if invalidateChildren == nil and invalidateChildren or true then
    for k, v in ipairs(self.children) do
      v:invalidate(invalidateChildren);
    end
  end
end

curlib.control.drawChildren = function(self)
  if not self then error(curlib.getParamErrorMsg("drawChildren", "self")); end
  if self.children then
    for k, v in ipairs(self.children) do
      v:draw();
    end
  end  
end

curlib.control.getScreenCoords = function (self)

  local px = 1;
  local py = 1;

  if self.parent then
    px, py = self.parent:getScreenCoords();
  end

  local x = self.x + px -1;
  local y = self.y + py -1;
  return x, y;
end

curlib.control.drawShadow = function(self)
  if not self then error(curlib.getParamErrorMsg("drawShadow", "self")); end
  if not self.shadow then return; end
  if not self.parent then return; end;

  local bg = self.parent.background;

  gpu.setForeground(curlib.defaults.shadow);
  gpu.setBackground(bg);

  local x, y  = self:getScreenCoords();

  gpu.set(x + self.width, y, "▄");
  gpu.fill(x + self.width, y + 1, 1, self.height -1, "█");
  gpu.fill(x + 1, y + self.height, self.width, 1, "▀");

end

curlib.control.draw = function(self)
  if not self then error(curlib.getParamErrorMsg("draw", "self")); end
  if self.visible then
    if self.dirty then
      self.dirty = false;
      self:updateColors();

      local x, y = self:getScreenCoords();

      gpu.fill(x, y, self.width, self.height, " ");
      self:drawShadow();
    end

    self:drawChildren();
  end

end

curlib.control.__onClick = function(self, x, y)

  self.status("click " .. x .. "," .. y);

  local done = false;

  if self.children then
    for k, v in ipairs(self.children) do
      done = v:__onClick(x, y);
      if (done) then goto ctrlOnClickContinue; end
    end
    ::ctrlOnClickContinue::
  end

  local sx, sy = self:getScreenCoords();

  if not done
    and x >= sx 
    and y >= sy 
    and x <= sx + self.width
    and y <= sy + self.height
  then
    self:setFocus(true);
    if self.onClick then self:onClick(x, y); end
    return true;
  else
    return done;
  end
end


curlib.control.__onKeyDown = function(self, char, code)

  local done = false;
  if self and self.children then
    for k, v in ipairs(self.children) do
      done = v:__onKeyDown(char, code);
      if (done) then goto ctrlOnKeyDownContinue; end
    end
    ::ctrlOnKeyDownContinue::
  end

  if self and self.focus then
    if self.onKeyDown then
      self:onKeyDown(char, code);
    end
    return true;
  else
    return done;
  end
end

curlib.control.__onKeyUp = function(self, char, code)
  
  local done = false;
  if self and self.children then
    for k, v in ipairs(self.children) do
      done = v:__onKeyUp(char, code);
      if (done) then goto ctrlOnKeyUpContinue; end
    end
    ::ctrlOnKeyUpContinue::
  end

  if self and self.focus then
    if self.onKeyUp then
      self:onKeyUp(char, code);
    end
    return true;
  else
    return done;
  end
end


curlib.control.doEvent = function (self, eventId, addr, arg1, arg2, arg3)
  if not self then error(curlib.getParamErrorMsg("doEvent", "self")); end
  if eventId == "key_down" then
    return self:__onKeyDown(arg1, arg2);
  elseif eventId == "touch" or eventId == "drag" then
    return self:__onClick(arg1, arg2);
  else return false; end
end

curlib.app = curlib.control:new();

curlib.app.new = function (self, obj)
  obj = obj or {};
  obj.background = obj.background or curlib.defaults.app.background;
  obj.foreground = obj.foreground or curlib.defaults.app.foreground;
  obj = curlib.control.new(self, obj);
  obj.width, obj.height = gpu.getResolution(); 
  return obj;
end

curlib.app.init = function(self)
  if not self then error(curlib.getParamErrorMsg("init", "self")); end
  self:draw();
end

curlib.app.doEvents = function(self)
  if not self then error(curlib.getParamErrorMsg("doEvents", "self")); end
  
--  self.status("free memory " 
--    .. tostring(computer.freeMemory()) .. " of " 
--    .. tostring(computer.totalMemory())
--  );    
--  os.sleep();

  local eventId, attr, arg1, arg2, arg3 = event.pull();

  if (eventId) then
    os.sleep();
    done = self:doEvent(eventId, attr, arg1, arg2, arg3)

    if done then
      curlib.screen.cursor.blink = false;
      term.setCursorBlink(false);

      self:draw();
  
      if (curlib.screen.cursor.blink) then
        gpu.setForeground(curlib.screen.cursor.foreground);
        gpu.setBackground(curlib.screen.cursor.background);
        term.setCursorBlink(true)
        term.setCursor(curlib.screen.cursor.x, curlib.screen.cursor.y);
      else
        term.setCursorBlink(false)
      end
    end

  end
  
  return eventId, addr, arg1, arg2, arg3; --this event is not mine
  
end

curlib.window = curlib.control:new()

curlib.window.new = function(self, obj)
  obj = obj or {};
  obj.background = obj.background or curlib.defaults.window.background;
  obj.foreground = obj.foreground or curlib.defaults.window.foreground;
  obj.title = obj.title or "window";
  obj.shadow = obj.shadow or true;
  obj = curlib.control.new(self, obj);
  return obj;
end

curlib.button = curlib.control:new()

curlib.button.new = function(self, obj)
  obj = obj or {};
  obj.foreground = obj.foreground or curlib.defaults.button.foreground;
  obj.background = obj.background or curlib.defaults.button.background;
  obj.shadow = obj.shadow or true;
  obj.align = obj.align or align.direction.middleCenter;
  obj = curlib.control.new(self, obj);
  return obj;
end

curlib.button.__onClick = function (self, x, y)
  local ok = curlib.control.__onClick(self, x, y);
  if (ok) then
    self.dirty = true;
    self.flashColors = true;
  end
  return ok;
end

curlib.button.draw = function (self) 
  if not self then error(curlib.getParamErrorMsg("draw", "self")); end
  if not self.text then self.text = "BTN"; end

  if self.visible then
    if self.dirty then
      
      gpu.setForeground(self.parent and self.parent.foreground or self.foreground);
      gpu.setBackground(self.parent and self.parent.background or self.background);
      local x, y = self:getScreenCoords();

      local txtTable = align.align(self.text, self.width, self.height or 1, self.align);      

      self:updateColors();
      
      local ln = 0;
      for k, v in ipairs(txtTable) do
        gpu.set(x, y + ln, v);
        ln = ln + 1;
      end
      
      self:drawShadow();

      if self.flashColors then
        self.flashColors = false;
        for n = 1, 10 do os.sleep(); end
        self:draw();
      end
      self.dirty = false;

    end
    self:drawChildren();     
  end      
end

curlib.text = curlib.control:new();

curlib.text.draw = function(self)
  if not self then error(curlib.getParamErrorMsg("draw", "self")); end
  if not self.text then self.text = "..."; end;


  if self.visible then
    if self.dirty then

      gpu.setForeground(self.parent and self.parent.foreground or self.foreground);
      gpu.setBackground(self.parent and self.parent.background or self.background);
      local x, y = self:getScreenCoords();

      local txtTable = align.align(self.text, self.width, nil, self.align);      
      local ln = 0;
      for k, v in ipairs(txtTable) do
        gpu.set(x, y + ln, v);
        ln = ln + 1;
      end

      self.dirty = false;
    end
  end  

end

curlib.input = curlib.control:new();

curlib.input.new = function (self, obj)
  obj = obj or {};
  obj.foreground = obj.foreground or curlib.defaults.input.foreground;
  obj.background = obj.background or curlib.defaults.input.background;
  obj.width = obj.width or 10;
  obj.height = 1;
  obj.text = obj.text or "";
  obj.shadow = obj.shadow or true;
  obj.cursor = {};
  obj.cursor.position = unicode.len(obj.text) + 1;
  obj.cursor.scrollX = 0;
  obj.focus = false;
  obj = curlib.control.new(self, obj);
  return obj;
end

curlib.input.insert = function (self, value)
  if not value or unicode.len(value) < 1 then
    return
  end
  term.setCursorBlink(false)
  self.text = unicode.sub(self.text, 1, self.cursor.position - 1) ..
                value ..
                unicode.sub(self.text, self.cursor.position)
  self.cursor.position = self.cursor.position + 1;
  if (self.cursor.position > self.width) then
    self.cursor.scrollX = 
      self.cursor.position - self.width;
  end
  self.dirty = true;
  
  --we need to be fast with this draw so, we will just draw the input
  --and return false to avoid a a search and draw of every dirty control out there
  self:draw();
  return false;
end

curlib.input.delete = function (self) 
  term.setCursorBlink(false)
  local p1 = unicode.sub(self.text, 1, self.cursor.position - 1)
  local p2 = unicode.sub(self.text, self.cursor.position)
  if p2 and unicode.len(p2) > 0 then
    p2 = unicode.sub(p2, 2);
  end
  self.text = p1 .. p2;
  self.dirty = true;
  self:draw();
  return false;
end

curlib.input.backspace = function (self)
  term.setCursorBlink(false)
  local p1 = unicode.sub(self.text, 1, self.cursor.position - 1)
  local p2 = unicode.sub(self.text, self.cursor.position)
  if p1 and unicode.len(p1) > 0 then
    p1 = unicode.sub(p1, 1, unicode.len(p1) -1);
    self.cursor.position = self.cursor.position -1;
  end
  self.text = p1 .. p2;
  self.dirty = true;
  return true;
end

curlib.input.__onKeyDown = function (self, char, code)
  if self and self.focus then
    if code == keyboard.keys.enter then
      self.focus = false;
      self.lostFocus = true;
      return true;
    elseif code == keyboard.keys.delete then
      return self:delete();
    elseif code == keyboard.keys.back then
      return self:backspace();
    elseif not keyboard.isControl(char) then
      return self:insert(unicode.char(char))
    end
  end
  return false;
end

curlib.input.__onClick = function (self, x, y)  
  local ok = curlib.control.__onClick(self, x, y);
  if (ok) then
    self.dirty = true;
  end
  return ok;
end

curlib.input.draw = function(self, fast)
  if not self then error(curlib.getParamErrorMsg("draw", "self")); end
  
  if self.visible then
    if self.dirty or self.lostFocus then    
      fg, bg = self:updateColors();
      local x, y = self:getScreenCoords();

      local scrText = self.focus 
        and unicode.sub(self.text, self.cursor.scrollX)
        or self.text;

      gpu.set(x, y, align.left(scrText, self.width));

      if (not fast) then self:drawShadow(); end

--      curlib.control.status(self.text .. "|" .. self.cursor.position
--        .. "|" .. self.cursor.scrollX .. "|" .. (self.focus and "yes" or "no"));
      
      if self.focus then
        curlib.screen.cursor.blink = true;
        curlib.screen.cursor.x = x + self.cursor.position - self.cursor.scrollX -1;
        curlib.screen.cursor.y = y;
        curlib.screen.cursor.foreground = fg;
        curlib.screen.cursor.background = bg;
      end
      self.dirty = false;
      self.lostFocus = false;
    end
  end
  
end

return curlib;