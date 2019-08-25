classdef gphoto < handle
  % GPHOTO A class to control DSLR camera handled by gPhoto
  %
  % Usage
  % -----
  %
  % >> camera = gphoto;
  % >> image(camera);
  %
  % Then you can use the Methods:
  %   getstatus(camera):  get the camera status
  %   start:              set the camera ready for shooting pictures
  %   stop:               stop the shooting mode
  %
  %   iso:                set/get ISO setting
  %   shutter:            set/get shutter speed setting
  %   mode:               set/get the PASM mode
  %   timer:              set/get the self timer
  %   fnumber:            set/get the F/D aperture
  %   white:              set/get the white balance
  %   exp:                set/get the exposure compensation
  %   focus:              set/get the focus mode
  %   zoom:               zoom in or out
  %
  %   urlread:            take a picture and return the distant URL (no download)
  %   urlread(s,'bkg')    same, and executed as background task
  %   imread:             take a picture and download the RGB image (no display)
  %   image:              take a picture and display it
  %   plot:               show the live-view image (not stored)
  %   close:              close plot/image window and stop shooting mode.
  %
  %   continuous:         start/stop continuous shooting with current settings.
  %   timelapse:          start/stop timelapse  shooting with current settings.
  %
  % Connecting the Camera: wifi or USB
  % ---------------------
  %
  % Your should connect the camera with a USB cable. The gphoto2 
  % library will then be used (must be installed - see http://www.gphoto.org/).
  % Set the USB camera in 'PC remote' mode. GPhoto mode is rather slow.
  %
  % Using the Plot Window
  % ---------------------
  %
  %  The Plot window is shown when shooting still images or updating the LiveView. 
  %  It contains the File, View, Settings and Shoot menus. It also shows the main
  %  settings, as well as a focus quality measure (higher is better).
  %
  %  The View menu allows to add Pointers and Marks on top of the current image. 
  %  These can be used for e.g. alignment. You can equally add Pointers directly
  %  right-clicking on the image.
  %
  %  The Settings menu allows to change the most important camera settings, including 
  %  the zoom level (when available).
  %
  %  The Shoot menu allows to take a single picture, update the live view (lower 
  %  resolution), as well as start a continuous or timelapse shooting. To stop the 
  %  continuous/timelapse session, select the Shoot item again.
  %
  % Monitoring the camera
  % ---------------------
  %  The captureStart and captureStop events are triggered when a capture is
  %  initiated/finalised. You may then monitor these events with e.g.
  %    so = gphoto;
  %    addlistener(so, 'captureStop', @(src,evt)disp('capture just ended'))
  %
  % Requirements/Installation
  % -------------------------
  %
  %  - Matlab, no external toolbox
  %  - A USB connection
  %  - A DSLR Camera supported by gPhoto
  %  - GPhoto2 (for usb connection). Get it at http://gphoto.org
  %
  %  Just copy the files and go into the directory. Then type commands above, once the
  %  camera is configured (see above).
  %
  % (c) E. Farhi, GPL2, 2019.
  
  % api from man:gphoto2 commands are 'gphoto2 ...'
  % gphoto2 --abilities
  % gphoto2 --version
  % gphoto2 --auto-detect
  % gphoto2 --port <port> e.g. ptpip: usb:XX,YY
  % gphoto2 --filename (output file)
  % gphoto2 --folder
  % gphoto2 --list-folders
  % gphoto2 --list-files
  % gphoto2 --capture-preview
  % gphoto2 --bulb SEC
  % --capture-image-and-download (only on computer)
  % --capture-movie=TIMEs (e.g. 10s)
  % --keep (also keep on camera)
  % --keep-raw (keep raw on camera)
  % --capture-movie (should stream into Matlab figure ?)
  % --list-config 3s
  % --list-all-config 3s
  % --get-config CONFIGENTRY  3s
  % --set-config CONFIGENTRY=CONFIGVALUE
  % --set-config-index CONFIGENTRY=CONFIGVALUE_CHOICEINDEX
  % --reset
  % --storage-info 0.1s
  % --sumary (camera info) 0.1 s
  %
  % capture-movie: 
  %   gphoto2 --capture-movie --stdout | ffmpeg -i pipe:0 http://localhost:8080/feed1.ffm
  %
  % mplayer -demuxer mpegts 'ffmpeg://tcp://127.0.0.1:5001?listen'
  % gphoto2 --capture-movie --stdout | ffmpeg -f mjpeg -i pipe:0 -r 20 -vcodec libx264 -pix_fmt yuv420p -tune zerolatency -preset ultrafast -f mpegts "tcp://127.0.0.1:5001"
  
  % actions are slow...
  
  % much faster: https://github.com/alexdu/piggyphoto
  % C = piggyphoto.camera()
  % print C.abilities
  % C.capture_preview('preview.jpg')
  % C.capture_image('image.jpg')
  %
  % 'abilities',
  % 'about',
  % 'capture_image',
  % 'capture_preview',
  % 'config',
  % 'download_file',
  % 'exit',
  % 'init',
  % 'initialized',
  % 'leave_locked',
  % 'list_config',
  % 'list_files',
  % 'list_folders',
  % 'manual',
  % 'port_info',
  % 'ptp_canon_eos_requestdevicepropvalue',
  % 'ref',
  % 'reinit',
  % 'summary',
  % 'trigger_capture',
  % 'unref',
  % 'wait_for_event']


  % camera: connect
  % capture
  % get_preview
  % list_files
  % list_files

  properties
    url           = 'http://192.168.122.1:8080';
    
    % settings, updated on getstatus
    exposureMode  = 'P';
    cameraStatus  = 'IDLE';
    selfTimer     = 0;
    zoomPosition  = -1;
    shootMode     = 'still';
    exposureCompensation = 0; % in EV
    fNumber       = '2.8';
    focusMode     = 'AF-S';
    isoSpeedRate  = 'AUTO';
    shutterSpeed  = '1/60';
    whiteBalance  = 'Auto WB';
    imageQuality  = 'Standard';
    
    status        = struct();
    available     = struct();
    version       = '2.40';
    liveview      = true;
    lastImage     = []; % last RGB image matrix
    lastImageURL  = []; % last image URL (e.g. local)
    lastImageDate = [];
    UserData      = [];
    
    jsonFile = [];  % last JSON filename
    json     = [];  % last json result (string)
  end % properties
  
  properties (Access=private)
  
    updateTimer   = ''; % a timer object for auto getstatus every 5 s.
    
    % continuous/timelapse modes
    timelapse_clock = 0;    % clock when last shot
    timelapse_interval = 0; % time between shots
    figure   = [];
    axes     = [];
    x        = []; % a list of coordinates where to add pointers
    y        = [];
    int      = []; % the intensity contrast around pointers
    show_lines = false;
    ffmpeg   = [];
    period   = 2.0;

  end % properties
  
  events
    captureStart
    captureStop
    idle
    busy
  end
  
  methods
    function self = gphoto(url)
      % GPHOTO initialize the remote control for Sony Alpha Camera
      %   The camera is accessbile through JSON messages at URL 
      %   http://192.168.122.1:8080/sony/camera
      % 
      %   s = SONYALPHA start the Sony remote control with default IP
      %   http://192.168.122.1:8080
      %
      %   s = SONYALPHA('http://IP:8080') starts the camera remote control with 
      %   given IP and port.
      if nargin == 1
        self.url = 'usb';
      end
      
      if any(strcmp(self.url, {'gphoto2','gphoto', 'usb'}))
        self.url    = 'gphoto2';
        self.period = 20.0;
        self.liveview = false;
      end
      
      try
        self.version = self.api('getApplicationInfo');
      catch ME
        getReport(ME)
        error([ mfilename ': No Camera found.' ]);
      end
      if iscell(self.version), self.version = [ self.version{:} ]; end
      
      ret = self.api('startRecMode');
      self.getstatus;

      % get the camera available settings
      for f = {'mode','iso','timer','fnumber','white','exp','shutter','focus','quality'}
        self.available.(f{1}) = feval(f{1}, self, 'available');
        this = self.available.(f{1});
        if strcmp(f{1}, 'exp')
          try
          self.available.(f{1}) = unique(round((min(this):max(this))/3))*3;
          end
        elseif strcmp(f{1}, 'fnumber') && isempty(this)
          self.available.(f{1}) = {'2.8' '3.5' '4.0' '4.5' '5.0' '5.6' '6.3' ...
           '7.1' '8.0' '9.0' '10' '11' '13' '16' '20' '22' };
        elseif strcmp(f{1}, 'shutter') && isempty(this)
          self.available.(f{1}) = {'30\"' '25\"' '20\"' '15\"' '10\"' '5\"' '4\"' ...
          '3\"' '2\"' '1\"' '1/10' '1/30' '1/60' '1/125' '1/250' '1/400' '1/1000' };
        end
      end
       
      % init timer for regular updates, timelapse, etc
      disp([ mfilename ': [' datestr(now) '] Welcome to Matlab/gPhoto ' num2str(self.version) ' at ' char(self.url) ]);
      self.ffmpeg = ffmpeg_check;
      
      self.updateTimer  = timer('TimerFcn', @TimerCallback, ...
          'Period', self.period, 'ExecutionMode', 'fixedDelay', ...
          'Name', mfilename);
      set(self.updateTimer, 'UserData', self);
      start(self.updateTimer);
      try
        plot(self); % request initial LiveView
      catch ME
        getReport(ME);
      end

    end % gphoto
    
    % main communication method (low-level)
    function message = curl(self, post, target)
      % CURL prepare curl command
      %   result = CURL(s, post) sends the JSON message post to the camera.
      %   the result is a struct or JSON string.
      
      if nargin < 3, target = 'camera'; end
      
      cmd = post;
      [ret, message, self] = api_gphoto2(self, post);
      
      if isempty(self.jsonFile) self.json = message; end
      
      if ret % error
        disp(cmd)
        disp([ mfilename ': Connection failed: ' post])
        error(message);
      end
      
    end % curl
    
    % --------------------------------------------------------------------------

    % INFO stuff
    function status = getstatus(self)
      % GETSTATUS get the Camera status and all settings.
      %   status = GETSTATUS(s) returns a structure with main settings.
      json = '{"method": "getEvent", "params": [false], "id": 1, "version": "1.2"}';
      message = curl(self, json);
      if ~iscell(message), message = { message }; end
      status  = struct();
      status.unsorted ={};
      for index=1:numel(message)
        this = message{index};
        if isempty(this), continue; end
        if isfield(this, 'type') && isfield(this, this.type)
          status.(this.type) = this.(this.type);
          if iscell(status.(this.type)) && numel(status.(this.type)) == 1
            status.(this.type) = status.(this.type){1};
          end
        elseif isfield(this, 'type')
          status.(this.type) = this;
        else
          if iscell(this) && numel(this) == 1
            this = this{1};
          end
          status.unsorted{end+1} = this;
        end
      end
      
      % store that information into properties
      self.status       = status;
      try; self.exposureMode = status.exposureMode.currentExposureMode; end
      try; self.cameraStatus = status.cameraStatus; end
      try; self.selfTimer    = status.selfTimer.currentSelfTimer; end
      try; self.zoomPosition = status.zoomInformation.zoomPosition; end
      try; self.shootMode    = status.shootMode.currentShootMode; end
      try; self.exposureCompensation = ...
             status.exposureCompensation.currentExposureCompensation/3; end
      try; self.fNumber      = status.fNumber.currentFNumber; end
      try; self.focusMode    = status.focusMode.currentFocusMode; end
      try; self.isoSpeedRate = status.isoSpeedRate.currentIsoSpeedRate; end
      try; self.shutterSpeed = status.shutterSpeed.currentShutterSpeed; end
      try; self.whiteBalance = status.whiteBalance.currentWhiteBalanceMode; end
      try; self.imageQuality = status.imageQuality.currentImageQuality; end

    end % getstatus
    
    function settings = char(self)
    % CHAR returns a string that gathers main camera settings.
    %   c = CHAR(s) returns a string with settings.
      wb = strtok(self.whiteBalance); if numel(wb)> 4, wb=wb(1:4); end
      settings = sprintf('%s %s F%s EV%d ISO %s %s Foc:%.2f', ...
        self.exposureMode, ...
        num2str(self.shutterSpeed), num2str(self.fNumber), ...
        num2str(self.exposureCompensation), ...
        num2str(self.isoSpeedRate), wb, self.int);
      if ~strcmp(self.cameraStatus, 'IDLE')
        settings = [ settings ' BUSY' ];
      end
    end
    
    function display(self)
      % DISPLAY display Camera object (short)
      
      if ~isempty(inputname(1))
        iname = inputname(1);
      else
        iname = 'ans';
      end
      if isdeployed || ~usejava('jvm') || ~usejava('desktop'), id=class(self);
      else id=[  '<a href="matlab:doc ' class(self) '">' class(self) '</a> ' ...
                 '(<a href="matlab:methods ' class(self) '">methods</a>,' ...
                 '<a href="matlab:image(' iname ');">shoot</a>,' ...
                 '<a href="matlab:disp(' iname ');">more...</a>)' ];
      end
      if ~isempty(self.lastImageURL) 
        if isdeployed || ~usejava('jvm') || ~usejava('desktop')
          fprintf(1,'%s = %s [%s] %s\n',iname, id, char(self), self.lastImageURL);
        else
          fprintf(1,'%s = %s [%s] <a href="%s">%s</a>\n',iname, id, char(self), ...
            char(self.lastImageURL),char(self.lastImageURL));
        end
      else
        fprintf(1,'%s = %s [%s]\n',iname, id, char(self));
      end
    end % display
    
    function disp(self)
      % DISP display Camera object (details)
      
      if ~isempty(inputname(1))
        iname = inputname(1);
      else
        iname = 'ans';
      end
      if isdeployed || ~usejava('jvm') || ~usejava('desktop'), id=class(self);
      else id=[  '<a href="matlab:doc ' class(self) '">' class(self) '</a> ' ...
                 '(<a href="matlab:methods ' class(self) '">methods</a>,' ...
                 '<a href="matlab:image(' iname ');">shoot</a>)' ];
      end
      fprintf(1,'%s = %s [%s] \n',iname, id, char(self));
      % display settings
      items = {'exposureMode','cameraStatus','selfTimer','zoomPosition', ...
        'shootMode','exposureCompensation','fNumber','focusMode', ...
        'isoSpeedRate','shutterSpeed','whiteBalance' };
      c = { };
      for f=items
        val = num2str(self.(f{1}));
        fprintf(1, '%15s = %s\n', f{1}, val);
      end
      if ~isempty(self.lastImageURL)
        if isdeployed || ~usejava('jvm') || ~usejava('desktop')
          fprintf(1,'   lastImageURL = s\n', self.lastImageURL);
        else
          fprintf(1,'   lastImageURL = <a href="%s">%s</a>\n', ...
            char(self.lastImageURL),char(self.lastImageURL));
        end
      end
    end % disp
      
    function about(self)
      % ABOUT display camera settings in a dialogue window
      
      % display settings
      items = {'exposureMode','cameraStatus','selfTimer','zoomPosition', ...
        'shootMode','exposureCompensation','fNumber','focusMode', ...
        'isoSpeedRate','shutterSpeed','whiteBalance' };
      c = { };
      for f=items
        val = num2str(self.(f{1}));
        c{end+1} = sprintf('%s = %s', f{1}, val);
      end
      c{end+1} = 'gPhoto for Matlab';
      c{end+1} = '(c) E. Farhi <https://github.com/farhi/matlab-gphoto>';
      helpdlg(c, 'gPhoto: Settings');
      
    end
    
    % generic API call ---------------------------------------------------------
    
    function ret = api(self, method, value, service)
      % API calls the camera API with method.
      %   API('method') call the given API method call (without argument), e.g. 
      %   for getting settings and simple actions.
      %
      %   API('method', param) call the given API method call (with argument), e.g.
      %   to set the method values.
      %
      %   API(..., service) call the given API method call, for the API service.
      %   Default is service='camera'. Other choice is 'avContent'.
      if nargin < 4, service=''; end
      if isempty(service), service='camera'; end
      if nargin < 3 || isempty(value)
        json = [ '{"method": "' method '","params": [],"id": 1,"version": "1.0"}' ];
      else
        if isnumeric(value),  value = num2str(value);
        elseif ischar(value), value = [ '"' value '"' ];
        elseif islogical(value)
          if value, value = 'true'; else value = 'false'; end
        end
        json = [ '{"method": "' method '","params": [' value '],"id": 1,"version": "1.0"}' ];
      end
      
      ret  = curl(self, json, service);
    end % api
    
    % usual object life handling -----------------------------------------------
    function url=help(self)
      % HELP open the Help page (web browser)
      url = fullfile('file:///',fileparts(which(mfilename)),'doc','gPhoto.html');
      open_system_browser(url);
    end
    
    function start(self)
      % START set the camera into shooting mode
      %   START(s) can be used to reset/restart camera control and its timer.
      ret = self.api('startRecMode');
      self.getstatus;
      if isempty(self.updateTimer) || ~isvalid(self.updateTimer)
        self.updateTimer  = timer('TimerFcn', @TimerCallback, ...
          'Period', self.period, 'ExecutionMode', 'fixedDelay', ...
          'Name', mfilename);
      set(self.updateTimer, 'UserData', self);
      end
      if strcmp(self.updateTimer.Running, 'off') 
        start(self.updateTimer); plot(self);
      end
    end % start
    
    function stop(self)
      % STOP stop the camera shooting.
      %   STOP(s) stops camera control and timer.
      %   Then, START(s) must be used to be able to take pictures again.
      %   Use e.g. PLOT(s) to display the interface.
      if isvalid(self.updateTimer) && strcmp(self.updateTimer.Running, 'on') 
        stop(self.updateTimer);
      end
      self.timelapse_clock = 0;
      self.liveview        = false;
      if ishandle(self.figure), delete(self.figure); end
    end % stop
    
    function close(self)
      % CLOSE delete the gPhoto connection and its timer.
      stop(self);
      delete(self.updateTimer);
      self.updateTimer='';
    end
    
    function waitfor(self)
      % WAITFOR waits for the camera to be idle
      flag = true;
      while flag
        self.getstatus;
        if strcmp(self.cameraStatus, 'IDLE'); flag=false; break; end
        pause(2)
      end
    end % waitfor
    
    % Camera Shooting ----------------------------------------------------------
    function url = urlread(self, varargin)
      % URLREAD take a picture and return the distant URL (no upload)
      %   URLREAD(self) take a picture and wait for completion. Return URL of image.
      %   The camera must have been started with START before (e.g. at init).
      %   The resulting image is the 'postview' one, e.g. 2M pixels. The original
      %   image remains on the camera.
      %
      %   URLREAD(self, 'background') take a picture as a background task. The URL of
      %   the image is displayed upon completion, and made available in
      %   self.lastImageURL. The image RGB matrix is stored in self.lastImage
      %   This syntax is only available in WIFI mode.
      url = [];
      if ~strcmp(self.cameraStatus, 'IDLE') % BUSY
        return
      end
      
      notify(self, 'captureStart');
      notify(self, 'busy');
      if nargin > 1
        background(self);
        return
      end
      
      url = self.api('actTakePicture');
      % in case result is error 40403 "Long Exposure" "Still Capturing Not Finished"
      % then re-send self.api('awaitTakePicture') until we obtain a result with URL.
      waitme = true;
      while waitme
        if iscell(url) && isnumeric(url{1}) && isequal(url{1}, 40403)
          plot_pointers('','',self); % set display to BUSY
          drawnow
          url = self.api('awaitTakePicture');
        else
          waitme = false;
        end
      end
      if iscellstr(url)
        url = char(url); % ok
        self.lastImage    = url;
        self.lastImageURL = url;
        self.lastImageDate= now;
        notify(self, 'captureStop');
        notify(self, 'idle');
      else
        self.start; % try to start the camera
        disp([ mfilename ': camera is not ready.' ]);
      end
    end % urlread
    
    function [url,im,info] = urlwrite(self, filename, varargin)
      % URLWRITE take a picture, and download it as a local file
      %   [url,im] = URLWRITE(s) takes a picture and return the RGB image and
      %   its URL. The camera must have been started with START before (e.g. at init).
      %   The resulting image is the 'postview' one, e.g. 2M pixels. The original
      %   image remains on the camera.
      %
      %   [url,im] = URLWRITE(s, filename) write image into 'filename' and 
      %   return the distant image URL.
      %
      %   URLWRITE(s, filename, 'background') takes a picture in background. 
      %   The URL of the image is displayed upon completion, and made available in
      %   self.lastImageURL. The image RGB matrix is stored in self.lastImage
      %   This syntax is only available in WIFI mode.
      
      if nargin < 2, filename = ''; end
      
      % get the URL and its extension
      im=[]; info=[];
      url = self.urlread(varargin{:});
      if isempty(url), return; end % BUSY
      
      if any(strcmp(self.url, {'gphoto2','gphoto', 'usb'}))
        % for gphoto, we just read the images and return
        im = {}; url = cellstr(url); info={};
        for index=1:size(url, 1)
          disp(url{index})
          try
            info{end+1} = imfinfo(url{index});
            info{end}.url = url{index};
          catch
            info{end+1} =  [];
          end
          try
            im{end+1}   = imread(url{index});
          catch
            im{end+1}   = [];
          end
        end
        self.lastImage    = im{end};
        self.lastImageURL = url{end};
        self.lastImageDate= now;
        % image has already been saved locally by gphoto2
        % copy to an other specified location ?
        [p,f,ext] = fileparts(url{end});
        if ~isempty(filename) && isdir(filename) && ~strcmp(p, filename)
          copyfile(url{end}, fullfile(filename, [f ext]));
        elseif ~isempty(filename)
          % check extension
          [p,f,E] = fileparts(filename);
          if isempty(E), filename = [ filename ext ]; end
          copyfile(url{end}, filename);
        end
      else % wifi API: download images
        if ~isempty(url) && ~ischar(url)
          disp(url)
          return
        end
        [p, f, ext] = fileparts(url);
          
        if isempty(filename)
          filename = fullfile(tempdir, [ f ext ]); % saves locally using the distant image name
        elseif isdir(filename)
          filename = fullfile(filename, [ f ext ]);
        else
          % check extension
          [p,f,E] = fileparts(filename);
          if isempty(E), filename = [ filename ext ]; end
        end
        % then get URL and display it
        im   = urlwrite(url, filename);
        info = imfinfo(filename); % contains actual local image FileName
        info.url = url; % distant location
        self.lastImage    = im;
        self.lastImageURL = url;
        self.lastImageDate= now;
      end
      % save the LiveView.jpg image to show in the plot window
      if ~isempty(self.lastImage)
        if ischar(self.lastImage) && exist(self.lastImage)
          copyfile(self.lastImage, fullfile(tempdir, 'LiveView.jpg'));
          self.lastImage = imread(self.lastImage);
          self.lastImageDate= now;
        elseif isnumeric(self.lastImage)
          imwrite(self.lastImage, fullfile(tempdir, 'LiveView.jpg'));
        end
      end
    end % urlwrite
    
    function [im, exif] = imread(self, varargin)
      % IMREAD take a picture, read it as an RGB matrix, and delete any local file.
      %   The camera must have been started with START before (e.g. at init).
      %   The resulting image is the 'postview' one, e.g. 2M pixels. The original
      %   image remains on the camera.
      %
      %   [im, exif] = IMREAD(s) returns the RGB image and its EXIF data.
      %
      %   IMREAD(s, 'background') same as above, but shooting is done in background. 
      %   The final RGB image is stored in s.lastImage, and its URL in s.lastImageURL
      %   This syntax is only available in WIFI mode.
      [url,im,exif] = urlwrite(self, '', varargin{:});
      if isempty(im), return; end % BUSY
      if  ischar(im),   im   = cellstr(im); end
      if ~iscell(exif), exif = { exif }; end
      for index=1:numel(im)
        if ischar(im{index}), im{index} = imread(im{index}); end
        
        if isfield(exif{index}, 'Filename') 
          filename = exif{index}.Filename;
          if ~isempty(dir(filename))
            delete(filename);   
          end
        end
      end
      if iscell(im)
        im = im(~cellfun(@isempty, im));
      end
      if numel(im) == 1,   im   = im{1}; end
      if numel(exif) == 1, exif = exif{1}; end
      if iscell(url) && numel(url) == 1,  url  = url{1}; end
     
    end % imread
    
    function [url, im, exif] = image(self, varargin)
      % IMAGE take a picture, and display it.
      %   [url, im, exif] = IMAGE(s) return image URL, image RGB matrix and EXIF data.
      %
      %   IMAGE(s, 'background') same as above, but shooting is done in background. 
      %   The final RGB image is stored in s.lastImage, and its URL in s.lastImageURL
      %   This syntax is only available in WIFI mode.
      im = []; exif = [];
      if any(strcmp(self.url, {'gphoto2','gphoto', 'usb'}))
        [im, exif] = imread(self);
        url = self.lastImageURL;
      else % WIFI -> asynchronous capture
        if strcmp(self.cameraStatus, 'IDLE')
          [url,im, exif] = urlwrite(self, '', varargin{:}); % new picture when IDLE
        else url = [];
        end
      end
      if isempty(url) || isempty(im), return; end % BUSY
      if ischar(im) && ~isempty(dir(im)), im = imread(im); end
      fig        = plot_window(self);
      h          = image(im); axis tight;
      if isfield(exif, 'Filename') title(exif.Filename, 'Interpreter','none'); end
      set(h, 'ButtonDownFcn',        {@ButtonDownCallback, self}, ...
        'Tag', 'gPhoto_Image');
      set(fig, 'HandleVisibility','off', 'NextPlot','new');
      plot_pointers('','',self);
    end % image
    
    function h = plot(self)
      % PLOT get a live-view image, display it, but does not store it.
      %   The response time is around 2s.
      
      % we could set the ffmpeg as a background commands then monitor for the
      % temporary file, and plot when it comes. 
      %
      % could also launch external viewer:
      % gst-launch-1.0 souphttpsrc location=http://192.168.122.1:8080/liveview/liveviewstream ! sonyalphademux ! jpegparse ! jpegdec ! videoconvert ! autovideosink
      %
      % or: https://github.com/erik-smit/sony-camera-api/blob/master/liveView.py
      
      % check for SonyAlpha viewer
      
      h = [];
      if isempty(self.ffmpeg)
        return; % ffmpeg not available, no liveview
      end
      
      % start the LiveView mode and get a frame
      filename = fullfile(tempdir, 'LiveView.jpg');
      if ~exist(filename, 'file')
        % get the livestream URL e.g. 
        %   http://192.168.122.1:8080/liveview/liveviewstream
        url = self.api('startLiveview');
        if ~any(strcmp(self.url, {'gphoto2','gphoto', 'usb'}))
          if ischar(url) && ~isempty(self.ffmpeg)
            cmd = [ self.ffmpeg ' -ss 1 -i ' url ' -frames:v 1 ' filename ];
            if strcmp(self.updateTimer.Running,'on')
              if ispc
                cmd = [ 'start /b ' cmd ];
              else
                cmd = [ cmd '&' ];
              end
            end
            
            [ret, message] = system(cmd);
            self.api('stopLiveView');
          else return
          end
        end
      end
      
      % when timer is Running, the image will be displayed by its Callback
      if self.liveview && strcmp(self.updateTimer.Running, 'on')
        return
      elseif exist(filename, 'file')
        % read the image and display it immediately. delete tmp file.
        im  = imread(filename);
        fig = plot_window(self);
        h   = image(im); axis tight;
        set(h, 'ButtonDownFcn',        {@ButtonDownCallback, self}, ...
          'Tag', 'gPhoto_Image');
        set(fig, 'HandleVisibility','off', 'NextPlot','new');
        delete(filename);
        plot_pointers('','',self);
      end
      
    end % plot

    % upper level continuous/timelapse modes
    function continuous(self)
      % CONTINUOUS take pictures continuously
      %
      % A second call will stop the shooting.
      timelapse(self, 0);
    end % continuous
    
    function timelapse(self, wait)
      % TIMELAPSE take pictures with current settings every 'wait' seconds
      %   A second call will stop the shooting.
      %
      %   TIMELAPSE(s, wait) use 'wait' as interval between pictures (in seconds).
      if self.timelapse_clock
        % stop after next capture
        self.timelapse_clock = 0;
        disp([ mfilename ': stop shooting' ])
      else
        if nargin < 2
          prompt = {'Enter Time-Lapse Periodicity [s]'};
          name = 'gPhoto: Time-Lapse';
          options.Resize='on';
          options.WindowStyle='normal';
          options.Interpreter='tex';
          answer=inputdlg(prompt,name, 1, {'30'}, options);
          if isempty(answer), return; end
          wait=str2double(answer{1});
          if ~isfinite(wait), return; end
        end
        self.timelapse_interval = wait;
        self.timelapse_clock    = clock;
        if wait > 0
          disp([ mfilename ': start shooting (timelapse every ' num2str(wait) ' [s])' ]);
        else
          disp([ mfilename ': start shooting (continuous)' ]);
        end
      end
    end
    
    % Camera settings ----------------------------------------------------------
    function ret = iso(self, value)
      % ISO get/set the ISO setting as a string (can be 'AUTO')
      %   ISO(s) get the ISO setting as a string (can be 'AUTO')
      %
      %   ISO(s, 'iso') set the ISO setting as a string (can be 'AUTO')
      %   The ISO value can be e.g. AUTO 100 200 400 800 1600 3200 6400 12800 25600
      %
      %   ISO(s, 'supported') return supported ISO settings (strings)
      %
      %  
      if nargin < 2, value = ''; end
      if isempty(value)
        ret = api(self, 'getIsoSpeedRate');
      elseif strcmp(lower(value), 'available') || strcmp(lower(value), 'supported')
        ret = api(self, 'getSupportedIsoSpeedRate');
      else
        ret = self.api('setIsoSpeedRate', num2str(value));
      end
    end % iso
    
    function ret = mode(self, value)
      % MODE get/set the shooting Mode (e.g. PASM)
      %   MODE(s) get the shooting Mode (e.g. PASM)
      %
      %   MODE(s, 'PASM') set the shooting Mode (e.g. PASM) as a string
      %   The shooting Mode can be 'Program Auto', 'Aperture', 'Shutter', 'Manual'
      %   'Intelligent Auto', or 'P', 'A', 'S', 'M'
      %
      %   MODE(s, 'supported') return supported shooting Modes (strings)
      
      if nargin < 2, value = ''; end
      if isempty(value)
        ret = api(self, 'getExposureMode');
        switch ret
        case 'Program Auto'; ret = 'P';
        case 'Aperture';     ret = 'A';
        case 'Shutter';      ret = 'S';
        case 'Manual';       ret = 'M';
        end
      elseif strcmp(lower(value), 'available') || strcmp(lower(value), 'supported')
        ret = api(self, 'getSupportedExposureMode');
      else
        switch upper(value(1))
        case 'P'; value = 'Program Auto';
        case 'A'; value = 'Aperture';
        case 'S'; value = 'Shutter';
        case 'M'; value = 'Manual';
        end
        ret = self.api('setExposureMode', value);
      end
    end % mode
    
    function ret = timer(self, value)
      % TIMER get/set the self Timer setting
      %   TIMER(s) get the self Timer setting in seconds
      %
      %   TIMER(s, val) set the self Timer setting in seconds
      %   The self Timer value can be e.g. 0, 2 or 10 (numeric)
      %
      %   TIMER(s, 'supported') return supported self Timer settings (numeric)
      if nargin < 2, value = ''; end
      if isempty(value)
        ret = api(self, 'getSelfTimer');
      elseif strcmp(lower(value), 'available') || strcmp(lower(value), 'supported')
        ret = api(self, 'getSupportedSelfTimer');
      else
        ret = self.api('setSelfTimer', value);
      end
    end % timer
    
    function ret = shutter(self, value)
      % SHUTTER get/set the shutter speed setting (S mode)
      %   SHUTTER(s) get the shutter speed setting
      %
      %   SHUTTER(s, val) set the shutter speed setting (S mode) as a string
      %   The shutter speed value can be e.g. '30"', '1"', '1/2', '1/30', '1/250'
      %   (string) where the " symbol stands for seconds.
      %
      %   SHUTTER(s, 'supported') return supported shutter speed settings (strings)
      if nargin < 2, value = ''; end
      if isempty(value)
        ret = api(self, 'getShutterSpeed');
      elseif strcmp(lower(value), 'available') || strcmp(lower(value), 'supported')
        ret = api(self, 'getSupportedShutterSpeed');
        if iscell(ret), ret=ret{end}; end
        if ~isempty(ret), ret = strrep(ret, '"', '\"'); end
      else
        if isnumeric(value)
          if   value >= 1, value = sprintf('%d\\"', ceil(value));
          else             value = sprintf('1/%d',  ceil(1/value)); end
        end
        ret = self.api('setShutterSpeed', num2str(value));
      end
    end % shutter
    
    function ret = fnumber(self, value)
      % FNUMBER get/set the F/D number (apperture) setting (A mode)
      %   FNUMBER(s) get the F/D number (apperture) setting (A mode)
      %
      %   FNUMBER(s, val) set the F/D number (apperture) setting (A mode) as a string
      %   The F/D number value can be e.g. '1.4','2.0','2.8','4.0','5.6'
      %
      %   FNUMBER(s, 'supported') return supported F/D numbers (strings)

      if nargin < 2, value = ''; end
      if isempty(value)
        ret = api(self, 'getFNumber');
      elseif strcmp(lower(value), 'available') || strcmp(lower(value), 'supported')
        ret = api(self, 'getSupportedFNumber');
      else
        ret = self.api('setFNumber', num2str(value));
      end
    end % fnumber
    
    function ret = white(self, value)
      % WHITE get/set the white balance setting
      %   WHITE(s) get the white balance setting
      %
      %   WHITE(s, val) set the white balance setting
      %
      %   WHITE(s, 'supported') return supported white balance modes (strings)
      %
      % The white balance can be a string such as 
      %  'Auto WB'
      %  'Daylight'
      %  'Shade' 
      %  'Cloudy' 
      %  'Incandescent' 
      %  'Fluorescent: Warm White (-1)' 
      %  'Fluorescent: Cool White (0)'
      %  'Fluorescent: Day White (+1)'
      %  'Fluorescent: Daylight (+2)'
      %  'Flash'
      % or a Temperature (numeric for 'Color Temperature' mode) in 2500-9900 K
      if nargin < 2, value = ''; end
      if isempty(value)
        ret = api(self, 'getWhiteBalance');
      elseif strcmp(lower(value), 'available') || strcmp(lower(value), 'supported')
        ret = api(self, 'getSupportedWhiteBalance');
      else
        if ischar(value)
          json = [ '{"method": "setWhiteBalance","params": ["' value '", false, -1],"id": 1,"version": "1.0"}' ];
          ret = curl(self, json);
        elseif isnumeric(value)
          value = round(value/100)*100;
          json = [ '{"method": "setWhiteBalance","params": ["Color Temperature", true, ' num2str(value) '],"id": 1,"version": "1.0"}' ];
          ret = curl(self, json);
        end
      end
    end % white
    
    function ret=exp(self, value)
      % EXP get/set the Exposure Compensation
      %   EXP(s) get the Exposure Compensation
      %
      %   EXP(s, val) set the Exposure Compensation as a string
      %
      %   EXP(s, 'supported') return supported Exposure Compensations (strings)
      %
      % The Exposure Compensation value can be e.g. -9 to 9 in [1/3 EV] units.
      if nargin < 2, value = ''; end
      if isempty(value)
        ret = api(self, 'getExposureCompensation');
      elseif strcmp(lower(value), 'available') || strcmp(lower(value), 'supported')
        ret = api(self, 'getSupportedExposureCompensation');
      else
        ret = self.api('setExposureCompensation', value);
      end
    end % exp
    
    function ret=quality(self, value)
      % QUALITY get/set the image quality
      %   QUALITY(s) get the current quality
      %
      %   QUALITY(s, val) set the image quality as a string
      %
      %   QUALITY(s, 'supported') return supported image quality (strings)
      %
      % The quality value can be e.g. "RAW+JPEG", "Fine", "Standard"
      if nargin < 2, value = ''; end
      if isempty(value)
        ret = api(self, 'getStillQuality');
      elseif strcmp(lower(value), 'available') || strcmp(lower(value), 'supported')
        ret = api(self, 'getSupportedStillQuality');
      else
        ret = self.api('setStillQuality', value);
      end
    end % exp
    
    function ret=focus(self, value)
      % FOCUS get/set the focus mode 
      %   FOCUS(s) get the focus mode
      %
      %   FOCUS(s, val) set the focus mode as a string
      %
      %   FOCUS(s, 'supported') return supported focus modes (strings)
      %
      % The F/D number value can be e.g. 'AF-S','AF-C','DMF','MF'
      if nargin < 2, value = ''; end
      if isempty(value)
        ret = api(self, 'getFocusMode');
      elseif strcmp(lower(value), 'available') || strcmp(lower(value), 'supported')
        ret = api(self, 'getSupportedFocusMode');
      else
        ret = self.api('setFocusMode', num2str(value));
      end
    end % focus
    
    function ret = zoom(self, d)
      % ZOOM get/set the zoom value
      %   ZOOM(s) get the zoom value
      %
      %   ZOOM(s, 'in' or 'out') zoom in or out
      if nargin < 2
        ret = self.zoomPosition;
      elseif any(strcmpi(d, {'in','out'}))
        json = [ '{"method": "setZoomSetting","params": ["zoom", "On:Clear Image Zoom"],"id": 1,"version": "1.0"}' ];
        ret = curl(self, json);
        json = [ '{"method": "actZoom","params": ["' d '", "1shot"],"id": 1,"version": "1.0"}' ];
        ret = curl(self, json);
      else ret = [];
      end
    end % zoom
    
  end % methods
  
end % sonyalpha class

% simple interface build: show current live-view/last image, and
% camera set-up menu.
% -----------------------------------------------------------------------

function h = plot_window(self)

  h = findall(0, 'Tag', 'SonyAlpha');
  if isempty(h)
    % build the plot/menu window
    h = figure('Tag', 'SonyAlpha', ...
      'UserData', self, 'MenuBar','none', ...
      'CloseRequestFcn', {@MenuCallback, 'stop', self });
      
    % File menu
    m = uimenu(h, 'Label', 'File');
    uimenu(m, 'Label', 'Save',        ...
      'Callback', 'filemenufcn(gcbf,''FileSave'')','Accelerator','s');
    uimenu(m, 'Label', 'Save As...',        ...
      'Callback', 'filemenufcn(gcbf,''FileSaveAs'')');
    uimenu(m, 'Label', 'Print',        ...
      'Callback', 'printdlg(gcbf)');
    uimenu(m, 'Label', 'Close',        ...
      'Callback', {@MenuCallback, 'stop', self }, ...
      'Accelerator','w', 'Separator','on');
      
    m0 = uimenu(h, 'Label', 'View');
    uimenu(m0, 'Label', 'Add pointer', ...
      'Callback', {@plot_pointers, self, 'new'});
    uimenu(m0, 'Label', 'Clear pointers', ...
      'Callback', {@plot_pointers, self, 'clear'});
    uimenu(m0, 'Label', 'Show/Hide Lines', ...
      'Callback', {@plot_pointers, self, 'toggle'});
    m1 = uimenu(m0, 'Label', 'Auto Update', ...
      'Callback', {@MenuCallback, 'autoupdate', self }, 'Separator','on');
    if self.liveview, set(m1, 'Checked','on');
    else              set(m1, 'Checked','off'); end
    uimenu(m0, 'Label', 'Help', ...
      'Callback', {@MenuCallback, 'help', self });
    uimenu(m0, 'Label', 'About Matlab/gPhoto', ...
      'Callback', {@MenuCallback, 'about', self });
    
    % Settings menu
    m0 = uimenu(h, 'Label', 'Settings');
      
    labs = { 'Mode (Program)',          'mode'; ...
             'Aperture (F/D)',          'fnumber'; ...
             'Shutter Speed',           'shutter'; ...
             'ISO',                     'iso'; ...
             'Exp. Compensation (EV/3)',  'exp'; ...
             'White Balance',           'white'; ...
             'Focus',                   'focus'; ...
             'Timer',                   'timer' };
    for index1 = 1:size(labs, 1)
      m1        = uimenu(m0, 'Label', labs{index1,1});
      % get list of available choices
      method    = labs{index1,2};
      available = self.available.(method);
      if isnumeric(available)
        available = num2cell(available);
      end
      if ~isempty(available) && iscell(available)
        for index2 = 1:numel(available)
          if isstruct(available{index2})
            available{index2} = getfield(available{index2},'whiteBalanceMode');
          end
          if isnumeric(available{index2}) && numel(available{index2}) > 1
            tmp = available{index2}; tmp=tmp(:)'; available{index2} = tmp;
          end
          m2 = uimenu(m1, 'Label', num2str(available{index2}), ...
            'Callback', {@MenuCallback, method, self, available{index2} });
        end
      end
    end
    uimenu(m0, 'Label', 'Zoom in',  ...
      'Callback', {@MenuCallback, 'zoom', self, 'in'},...
      'Accelerator','i', 'Separator','on');
    uimenu(m0, 'Label', 'Zoom out', ...
      'Callback', {@MenuCallback,'zoom', self, 'out'}, ...
      'Accelerator','o');
  
    m0 = uimenu(h, 'Label', 'Shoot');
    uimenu(m0, 'Label', 'Update Live-View', 'Accelerator','u', ...
      'Callback', {@MenuCallback, 'plot', self });
    uimenu(m0, 'Label', 'Reset', 'Accelerator','r', ...
      'Callback', {@MenuCallback, 'start', self });
    labs = { 'Single',                    'image'; ...
             'Continuous Start/Stop',     'continuous'; ...
             'Time-Lapse Start/Stop...',  'timelapse' };
    for index1 = 1:size(labs, 1)
      method    = labs{index1,2};
      m1        = uimenu(m0, 'Label', labs{index1,1}, ...
        'Callback', {@MenuCallback, method, self });
    end
    self.axes   = gca;
    self.figure = h;
    set(self.axes, 'Tag', 'gPhoto_Axes');
  else
    if numel(h) > 1, delete(h(2:end)); h=h(1); end
    set(0, 'CurrentFigure',h);
  end
  cla(self.axes);
  set(self.figure, 'HandleVisibility','on', 'NextPlot','add');
  set(self.figure, 'Name', [ 'gPhoto: ' self.cameraStatus ' ' self.url ]);
  
end % plot_window

function plot_pointers(src, evnt, self, cmd)
  % plot pointers and marks
  
  fig = self.figure;
  if ~ishandle(fig) || isempty(fig), return; end
  set(0, 'CurrentFigure', fig);
  set(fig, 'HandleVisibility','on', 'NextPlot','add');
  
  for f={'gPhoto_Pointers','gPhoto_Line1','gPhoto_Line2','gPhoto_Info'}
    h = findall(0, 'Tag', f{1});
    if ~isempty(h), delete(h); end
  end
  
  xl = xlim(self.axes);
  yl = ylim(self.axes);
    
  if nargin > 3
    switch cmd
    case 'new'
      % add a new pointer
      
      % halt the timer to avoid update during ginput
      flag = self.liveview;
      if flag, self.liveview=false; end
      axes(self.axes);
      [x,y] = ginput(1);
      % restart timer if it was running
      if flag, self.liveview=true; end
      
      self.x(end+1) = x/max(xl);
      self.y(end+1) = y/max(yl);
    case 'clear'
      self.x = [];
      self.y = [];
    case 'toggle'
      self.show_lines = ~self.show_lines;
    end
  end
  
  % compute the peak width around pointers
  h = findall(0, 'Tag', 'gPhoto_Image');
  int = 0;
  if ~isempty(h) % not implemented yet
    im = double(get(h, 'CData'));
    % a blurred image has smooth variations. We sum up diff
    im1 = abs(diff(im,[], 1))/numel(im);
    im2 = abs(diff(im,[], 2))/numel(im);
    self.int = sum(im1(:))+sum(im2(:));
  end

  hold on
  h = scatter(self.x*max(xl),self.y*max(yl), 400, 'g', '+');
  set(h, 'Tag', 'gPhoto_Pointers');
  
  if self.show_lines
    hl = line([ 0 max(xl) ], [ 0 max(yl)]);
    set(hl, 'LineStyle','--','Tag', 'gPhoto_Line1');
    hl = line([ 0 max(xl) ], [ max(yl) 0]);
    set(hl, 'LineStyle','--','Tag', 'gPhoto_Line2');
  end
  
  % now display the shutter F exp ISO
  t = text(0.05*max(xl), .95*max(yl), char(self));
  if ~strcmp(self.cameraStatus, 'IDLE') % BUSY
    set(t,'Color', 'r', 'FontSize', 18, 'Tag', 'gPhoto_Info');
  else
    set(t,'Color', 'y', 'FontSize', 18, 'Tag', 'gPhoto_Info');
  end
  set(self.figure, 'Name', [ 'gPhoto: ' self.cameraStatus ' ' self.url ]);

  set(fig, 'HandleVisibility','off', 'NextPlot','new');
  
end % plot_pointers

% ------------------------------------------------------------------------------
% CallBacks
% ------------------------------------------------------------------------------

function MenuCallback(src, evnt, varargin)
  % menu actions, as stored in the uimenu UserData

  arg = get(src, 'UserData');
  
  if numel(varargin) > 1 && strcmp(varargin{1}, 'autoupdate')
    self = varargin{2};
    self.liveview = ~self.liveview;
    if self.liveview, set(src, 'Checked','on');
    else              set(src, 'Checked','off'); end
  else
    feval(varargin{:});
  end

end % MenuCallback

function ButtonDownCallback(src, evnt, self)
  % ButtonDownCallback: callback when user clicks on the StarBook image
  % where the mouse click is

  fig = self.figure;
  if ~ishandle(fig), return; end
  
  if strcmp(get(self.figure, 'SelectionType'),'alt')
    
    xy = get(self.axes, 'CurrentPoint'); 
    x = xy(1,1); y = xy(1,2);

    self.x(end+1) = x/max(xlim(self.axes));
    self.y(end+1) = y/max(ylim(self.axes));
    
    plot_pointers('','',self);
  end
  
end % ButtonDownCallback

% main timer to auto update the camera status and handle e.g. time-lapse
% ----------------------------------------------------------------------

function TimerCallback(src, evnt)
  % TimerCallback: update from timer event
  self = get(src, 'UserData');
  if isvalid(self), 
    try; self.getstatus; plot_pointers('','',self); end
  else delete(src); return; end
  
  % check if a background command is running. Is it finished ?
  % we read the json result
  if ~isempty(self.jsonFile) && ~isempty(dir(self.jsonFile))
    File = fileread(self.jsonFile);
    if ~isempty(File)
      delete(self.jsonFile);
      url = curl_read_json(self, File);
      if iscell(url) && isnumeric(url{1}) && isequal(url{1}, 40403)
        background(self, 'awaitTakePicture');
      elseif iscellstr(url) || ischar(url)
        try
          url = char(url);
          disp([ mfilename ': [' datestr(now) ']: ' url ]);
          self.json         = url;
          % in case result is error 40403 "Long Exposure" "Still Capturing Not Finished"
          % then re-send self.api('awaitTakePicture') until we obtain a result with URL.
          self.jsonFile = [];
          % we save the image as LiveView.jpg
          [p, f, ext] = fileparts(url);
          filename = fullfile(tempdir, [ f ext ]); % saves locally using the distant image name
          urlwrite(url, filename);
          self.lastImage   = imread(filename); % store so that we can get it !
          self.lastImageURL= filename;
          self.lastImageDate= now;
          copyfile(filename, fullfile(tempdir, 'LiveView.jpg'));
          notify(self, 'captureStop');
          notify(self, 'idle');
        catch
          disp([ mfilename ': error in gphoto timer callback'])
          whos
          url{:}
        end
       
      end
    end
  end
  
  % handle continuous shooting mode: do something when camera is IDLE
  if strcmpi(self.cameraStatus,'IDLE')
    if any(self.timelapse_clock) && etime(clock, self.timelapse_clock) > self.timelapse_interval
      self.background; % take a new picture (background execution)
    end
  end

  % test if an image was generated in background and update the plot
  filename = fullfile(tempdir, 'LiveView.jpg');

  if self.liveview && exist(filename, 'file')
    % read the image and display it. delete tmp file.
    im  = imread(filename);
    fig = plot_window(self);
    h   = image(im); axis tight;
    set(h, 'ButtonDownFcn',        {@ButtonDownCallback, self}, ...
      'Tag', 'gPhoto_Image');
    set(fig, 'HandleVisibility','off', 'NextPlot','new');
    delete(filename);
    plot_pointers('','',self);
    
    % trigger new image
    plot(self);
  end
  
end % TimerCallback

