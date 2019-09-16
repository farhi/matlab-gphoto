# matlab-gphoto
GPHOTO A class to control DSLR camera handled by gPhoto.
========================================================

Usage
-----
This class can currently connect to a single DSLR camera via USB cable and GPhoto2.
Basically, type from Matlab:
- addpath /path/to/gphoto
- g = gphoto;           % start the connection
- plot(g);              % plot the GUI (with basic liveview)
- image(g);             % trigger a capture/shoot
- get(g);               % display all settings
- set(g, 'iso', 3200);  % set the ISO
- set(g)                % display a dialogue to change camera settings

You may as well specify a port used for the connection (for instance when 
using multiple cameras), e.g.:
- g=gphoto('usb:002,004');

You may as well try the simulator mode, which does not require gPhoto, 
nor a camera. Then, images are read from the gphoto/Images directory by default.
- g = gphoto('sim');

Then images are read from the gphoto/Images directory by default.

The Plot Window
---------------
[The gPhoto Plot window](@gphoto/doc/gphoto_plot.png)
[The gPhoto Settings dialogue](@gphoto/doc/gphoto_settings.png)
The 'plot' method displays the current camera livewview, at a low refresh rate.
The menus allow to:
- cpature an image
- start/stop a continuous shooting (timelapse)
- change settings
- change storage directory and liveview refresh rate
- display an X mark and focus quality indicator.

Time-lapse/continuous capture
-----------------------------
The 'continuous' method and the similar menu item in the plot window allow
to start/stop a periodic capture. The current camera settings are used.
When the livewview refresh rate is smaller than the acquisition shutter time
the images are capture as soon as possible, with minimal waitings. 
- period(g, 0.5);
- continuous(g,'on'); % start time-lapse, capture asap (0.5 s).
- ...
- continuous(g, 'off');

When the refresh rate is larger than the shutter time, the next image is 
captured is synchronized with it.
- period(g, 15);
- continuous(g,'on'); % start time-lapse, capture every 15 seconds.

Trigger action on event
-----------------------
You may attach an action to a specific gPhoto event, e.g.:
- addlistener(g, 'captureStop', @(src,evt)disp('capture done.'))

Known actions are: captureStart, captureStop, idle and busy.

Methods
-------
- about       display a dialog box showing settings.
- cd          change or get current directory where images are stored. 
- char        returns a character representation of the object
- continuous  set/toggle continuous shooting (timelapse).
- delete      close the Gphoto connection.
- disp        display GPhoto object (details)
- display     display GPhoto object (from command line)
- get         get the camera configuration.
- grid        set/toggle line markers and focus quality on plot.
- identify    identify the connected camera
- image       capture an image with current camera settings.
- ishold      get the camera status (IDLE, BUSY).
- plot        plot the camera interface, liveview and captured images.
- period      set/get plot update periodicity, in seconds.
- preview     capture a preview (small) image with current camera settings.
- set         set a configuration value.
- start       start the background gphoto control.
- stop        stop the background gphoto control. Restart it with start.

Installation
------------
You should first install [gPhoto2](http://www.gphoto.org/ "gPhoto"). It exists
as pre-built packages for Debian and RedHat type Linux systems, e.g.:
- sudo apt install gphoto2

Then, extract the project archive, which should contain a @gphoto and @process 
directories. Then, add its path into Matlab:
- addpath /path/to/gphoto

Connect your camera to the computer using e.g. a USB cable.

(c) E. Farhi, GPL2, 2019.
