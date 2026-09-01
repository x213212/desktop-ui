-- Direct app choices avoid the generic command-probing wrapper on hotkeys.
-- GNOME Terminal is Mint's built-in terminal; --window keeps each workspace
-- launch independent while tabs remain available inside the window. Start
-- Fish explicitly so shortcuts and restored desktop sessions agree.
terminal = "/usr/bin/gnome-terminal --window -- /usr/bin/fish"
fileManager = "/usr/bin/nemo " .. HOME
