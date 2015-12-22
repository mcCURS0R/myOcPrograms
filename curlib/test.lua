package.loaded.curlib = nil; --need if you are developing curlib.lua itself
package.loaded.textalign = nil;

--require the curlib library.
--the name 'curlib' stands for _CURS0R_'s library 
--but has also some libname inpiration on 'curses' or 'pcurses'
--just the name, because comparing 'curses' or 'pcurses' with this
--is like comparing a continent with a rock.
local curlib = require("curlib");
local align = require("textalign");

--make some other default requirments...
local component = require("component");
local term = require("term");
local gpu = component.gpu;

local running = true;

--create a new app
local app = curlib.app:new();

--create a new window
local win1 = curlib.window:new({ x = 3, y = 2, 
  width = 60, height = 20, shadow = true});

--create a new button
local button = curlib.button:new({
  x = win1.width - 9, 
  y = win1.height -1, 
  width = 8, height = 1, 
  text = "Quit", shadow = true}
);

--create a onClick event handler
button.onClick = function(control, x, y) 
  app.status("my click function called");
  running = false;
end

--create a new text or label or whatevery text thing
local txt1 = curlib.text:new({ x = 2, y = 2, width = 15, 
  text = "all your base are bellong to us...", align = align.direction.topLeft });

local txt2 = curlib.text:new({ x = 20, y = 2, width = 15,
  text = "all your base are bellong to us...", align = align.direction.topCenter });

local txt3 = curlib.text:new({ x = 38, y = 2, width = 15,
  text = "all your base are bellong to us...", align = align.direction.topRight });

local btnAlign1 = curlib.button:new({ x = 2,  y = 8, width = 10, height = 5, text = "align labels left"});
local btnAlign2 = curlib.button:new({ x = 20, y = 8, width = 10, height = 5, text = "align labels center"});
local btnAlign3 = curlib.button:new({ x = 38, y = 8, width = 10, height = 5, text = "align labels right"});

btnAlign1.onClick = function (control, x, y) 
  txt1.align = align.direction.topLeft;
  txt2.align = align.direction.topLeft;
  txt3.align = align.direction.topLeft;
  txt1.dirty = true;
  txt2.dirty = true;
  txt3.dirty = true;
end

btnAlign2.onClick = function (control, x, y)
  txt1.align = align.direction.topCenter;
  txt2.align = align.direction.topCenter;
  txt3.align = align.direction.topCenter;
  txt1.dirty = true;
  txt2.dirty = true;
  txt3.dirty = true;
end

btnAlign3.onClick = function (control, x, y)
  txt1.align = align.direction.topRight;
  txt2.align = align.direction.topRight;
  txt3.align = align.direction.topRight;
  txt1.dirty = true;
  txt2.dirty = true;
  txt3.dirty = true;
end

--create a new input box
local input1 = curlib.input:new({x = 2, y = 15, width = 30, 
  text="some text in inputbox nº1"});

--and another one :)
local input2 = curlib.input:new({x = 2, y = 17, width = 30});

--adds the button to the window
win1:addChild(button);
--adds the text to the window
win1:addChild(txt1);
win1:addChild(txt2);
win1:addChild(txt3);
win1:addChild(btnAlign1);
win1:addChild(btnAlign2);
win1:addChild(btnAlign3);

--adds the input box1 to the window
win1:addChild(input1);
--adds the input box2 to the window
win1:addChild(input2);

--adds the window to the app
app:addChild(win1);

--initializes the app and makes a first screen draw of everything
app:init();


-- application main loop
while running do

  -- makes the app treat events, every event not handled is returned
  -- to be handled by the user.
  local event, addr, arg1, arg2, arg3 =  app:doEvents();

  --in this case we are handling the 'interrupted' event
  --so we can quit the app in Ctrl+C
  if (event == "interrupted") then
    running = false;
  end
end

-- clean the pallete (need for tier2 screens)
curlib.cleanPalette();

-- do a lame screen restore... you can do it in a better way ^^
gpu.setBackground(0);
gpu.setForeground(0xc1c1c1);
term.clear();

--end