classdef gphoto < handle
  % GPHOTO A class to control DSLR camera handled by gPhoto.
  % ========================================================
  %
  % Usage
  % -----
  % This class can currently connect to DSLR cameras via USB cable and GPhoto2.
  % Basically, type from Matlab:
  % - addpath /path/to/gphoto
  % - g = gphoto;           % start the connection
  % - plot(g);              % plot the GUI (with basic liveview)
  % - image(g);             % trigger a capture/shoot
  % - get(g);               % display all settings
  % - set(g, 'iso', 3200);  % set the ISO
  % - set(g)                % display a dialogue to change camera settings
  %
  % You may as well specify a port used for the connection (for instance when 
  % using multiple cameras), e.g.:
  % - g=gphoto('usb:002,004');
  %
  % You may as well try the simulator mode, which does not require gPhoto, 
  % nor a camera. Then, images are read from the gphoto/Images directory by default.
  % - g = gphoto('sim');
  %
  % Then images are read from the gphoto/Images directory by default.
  %
  % The Plot Window
  % ---------------
  % The 'plot' method displays the current camera livewview, at a low refresh rate.
  % The menus allow to:
  % - capture an image
  % - start/stop a continuous shooting (timelapse)
  % - change settings
  % - change storage directory and liveview refresh rate
  % - display an X mark and focus quality indicator.
  %
  % Time-lapse/continuous capture
  % -----------------------------
  % The 'continuous' method and the similar menu item in the plot window allow
  % to start/stop a periodic capture. The current camera settings are used.
  % When the livewview refresh rate is smaller than the acquisition shutter time
  % the images are capture as soon as possible, with minimal waitings. 
  % - period(g, 0.5);
  % - continuous(g,'on'); % start time-lapse, capture asap (0.5 s).
  % - ...
  % - continuous(g, 'off');
  % 
  % When the refresh rate is larger than the shutter time, the next image is 
  % captured is synchronized with it.
  % - period(g, 15);
  % - continuous(g,'on'); % start time-lapse, capture every 15 seconds.
  %
  % Trigger action on event
  % -----------------------
  % You may attach an action to a specific gPhoto event, e.g.:
  % - addlistener(g, 'captureStop', @(src,evt)disp('capture done.'))
  %
  % Known actions are: captureStart, captureStop, idle and busy.
  %
  % For instance, for astrophotography you may automatically annotate new images:
  %  - install https://github.com/farhi/matlab-astrometry
  %  - addlistener(g, 'captureStop', ...
  %    @(src,evt)astrometry(g.lastImageFile, 'scale-low', 0.5, 'scale-high',2,'autoplot'))
  %
  % Methods
  % -------
  % - about       display a dialog box showing settings.
  % - cd          change or get current directory where images are stored. 
  % - capture     same as 'image', e.g. shoot an image.
  % - char        returns a character representation of the object.
  % - continuous  set/toggle continuous shooting (timelapse).
  % - delete      close the Gphoto connection.
  % - disp        display GPhoto object (details).
  % - display     display GPhoto object (from command line).
  % - get         get the camera configuration.
  % - get_state   get the camera state.
  % - grid        set/toggle line markers and focus quality on plot.
  % - identify    identify the connected camera.
  % - image       capture an image with current camera settings.
  % - ishold      get the camera status (IDLE, BUSY).
  % - plot        plot the camera interface, liveview and captured images.
  % - period      set/get plot update periodicity, in seconds.
  % - preview     capture a preview (small) image with current camera settings.
  % - set         set a configuration value.
  % - start       start the background gphoto control.
  % - stop        stop the background gphoto control. Restart it with start.
  %
  % Installation
  % ------------
  % You should first install [gPhoto2](http://www.gphoto.org/ "gPhoto"). It exists
  % as pre-built packages for Debian and RedHat type Linux systems, e.g.:
  % - sudo apt install gphoto2
  %
  % Then, extract the project archive, which should contain a @gphoto and @process 
  % directories. Then, add its path into Matlab:
  % - addpath /path/to/gphoto
  %
  % Connect your camera to the computer using e.g. a USB cable.
  %
  % (c) E. Farhi, GPL2, 2019.

  properties
    settings       = [];     % all camera settings
    status         = 'INIT'; % IDLE or BUSY
    UserData       = [];     % User area
    lastImageFile  = '';     % last image file name(s)
    lastImageDate  = '';     % last image capture date
    lastPreviewFile= '';     % last preview file
    lastPreviewDate= '';     % last preview date
    dir            = pwd;    % the current directory where images are stored
    verbose        = 0;      % gives more I/O output when 1 or 2
    port           = 'auto'; % how is connected the camera
    version        = '';     % identification of the camera
  end % properties
  
  properties (Access=private)
    executable    = [];     % location of gphoto executable
    proc          = [];     % the gphoto2 background process (shell)
    expect        = {};     % commands being cached
    lastPlotDate  = clock;  % the date of last plot
    show_lines    = false;
    period_preview= 1;
    focus_history = [];
    figure        = [];
    focus_axes    = [];
    image_axes    = [];
    shoot_endless = false;
  end % properties
  
  events
    captureStart
    captureStop
    idle
    busy
  end
  
  methods
    function self = gphoto(varargin)
      % GPHOTO initialize the remote control for DSLR Cameras
      %   g=GPHOTO auto-detect a connected camera and connect to it.
      % 
      %   g=GPHOTO(port) connect using the specified port, e.g.
      %   'usb:XXX,YYY'         USB cable
      %   'ptpip:XX.YY.ZZ.TT'   PTP over IP
      %   'serial:/dev/ttyXX'   serial port
      %   'sim'                 simulation mode
      
      persistent checkstart
      if isempty(checkstart)
        checkstart = false;
        try
          p = process;
          if isa(p, 'process') % must be a class
            checkstart = true;
          end
        end
        if ~checkstart
          d = fileparts(fileparts(which(mfilename))); % dir above class
          addpath(fullfile(d,'matlab-process'));
          if ~exist('process')
            disp([ mfilename ': WARNING: "process" can not be found.' ])
            disp('*** Use "git submodule init", then "git submodule update" to import it.');
            disp('    Using simulation mode')
            self.port='sim';
          end
        end
      end

      if nargin && ischar(varargin{1})
        self.port = varargin{1};
      end
      if ~strncmp(self.port,'sim',3)
        % where is the executable ?
        self.executable = gphoto_executable;
        
        % we identify the connected cameras
        [cameras,ports] = gphoto_ports(self);
      else
        self.executable = 'gphoto_simulator';
        cameras = {'Fake camera'}; ports = { 'sim:' };
        self.dir = fullfile(fileparts(which(mfilename)),'Images');
      end
      if ~isempty(cameras)
        disp('Connected cameras (gPhoto):');
        disp('-----------------------------------------------------------')
        for index=1:numel(cameras)
          fprintf(1, '%-30s %s\n', cameras{index}, ports{index});  
        end
        if ~nargin && numel(cameras) > 1
          error([ '[' datestr(now) ']: ' mfilename  ': there are more than one camera connected. Specify the port.' ])
        end
      end
      
      % start gphoto shell and initiate view with a preview capture
      start(self);
      preview(self);
      
      % update all settings
      try
        gphoto_getall(self);
      catch
        disp([ mfilename ': ERROR: the camera can not be found on port ' self.port ]);
        disp('*** Switching to simulate mode.');
        self = gphoto('sim');
      end
      
    end % gphoto instantiate
    
    function start(self)
      % START start the background gphoto control
      if strncmp(self.port, 'sim', 3)
        self.proc = timer( ...
          'ExecutionMode', 'fixedSpacing', ...
          'Name', 'gPhoto simulator', ...
          'UserData', [], ...
          'Period', 1.0, ...
          'TimerFcn',@(src,evt)CameraWatchFcn(self));
        start(self.proc);
        return;
      elseif isempty(self.proc) || ~isvalid(self.proc)
        cmd = [ self.executable ' --shell --force-overwrite' ];
        if ~strcmp(self.port,'auto')
          % specify the port
          cmd = [ cmd ' --port=' self.port ];
        end
        % we start the gphoto shell which is reactive and allows background
        % set, get, capture.
        self.proc = process(cmd);
        silent(self.proc);
        self.period_preview = period(self.proc, 1); % auto update period for stdout/err/in
        
        % attach our CameraWatchFcn to the gphoto shell'update'
        addlistener(self.proc, 'processUpdate', @(src,evt)CameraWatchFcn(self));
      end
    end % start
    
    function stop(self)
      % STOP stop the background gphoto control. Restart it with start.
      if ~isempty(self.proc) && isvalid(self.proc)
        if strncmp(self.port, 'sim', 3)
          stop(self.proc);
        end
        delete(self.proc); % stop and kill gphoto shell
      end
      self.proc = [];
    end % stop
    
    function delete(self)
      % DELETE close the Gphoto connection
      stop(self);
    end % delete
    
    function c = char(self, op)
      % CHAR returns a character representation of the object
      %   CHAR(s,'long') displays a detailed state with all settings.
      c = { sprintf(' %6s   %s [port: %s] ', self.status, self.version, self.port) };
      if nargin > 1
        f = fieldnames(self.settings);
        for index=1:numel(f)
          if isfield(self.settings.(f{index}),'Current')
            val = self.settings.(f{index}).Current;
            if isnumeric(val), val = val(:)'; end
            c{end+1} = [ '  ' f{index} ': ' num2str(val) ];
          else
            c{end+1} = [ '  ' f{index} ];
          end
        end
      end
      c = char(c);
    end % char
    
    function reset(self)
      % RESET reset the camera connection.
      stop(self);
      gphoto_exec(self, '--reset'); % does not work from shell
      pause(2);
      start(self);
    end % reset
    
    function id = identify(self)
     % IDENTIFY identify the connected camera
      id = '';
      try
        if isfield(self.settings, 'manufacturer')
          id = [ id self.settings.manufacturer.Current ' ' ];
        end
      end
      try
        if isfield(self.settings, 'cameramodel')
          id = [ id self.settings.cameramodel.Current ' ' ];
        end
      end
      self.version = id;
      if ~isempty(id) disp([ '[' datestr(now) ']: ' mfilename  ': connected to ' id ]); end
    end % identify
    
    function get(self, config)
      % GET get the camera configuration
      %   GET(g) get all configuration states (from cache) as a struct, into 'ans'.
      %
      %   GET(g, config) update the specified configuration from the camera.
      %
      %   GET(g, 'all') force to read all configuration values.
      if ~strcmp(self.status,'IDLE'), return; end
      if nargin == 1, config = ''; end
      if ~ischar(config), return; end
      
      if strcmp(config, 'all')
        gphoto_getall(self);
      elseif isempty(config)
        f = fieldnames(self.settings);
        s = struct();
        for index=1:numel(f)
          if isfield(self.settings.(f{index}),'Current')
            val = self.settings.(f{index}).Current;
            if isnumeric(val), val = val(:)'; end
            s.(f{index})= val;
          else
            s.(f{index})=[];
          end
        end
        ans = s
      elseif isfield(self.settings, config)
        if ~strncmp(self.port, 'sim', 3)
          % we clear the stdout from the process (to get only what is new)
          self.proc.stdout = '';
          % update value from the camera
          write(self.proc, sprintf('get-config %s\n', config));
          % register expect action as post_get (to get the value when ready)
          self.expect{end+1} = { 'post_get', self, config };
        else
          ans = self.settings.(config).Current
        end
      end
    end % get
    
    function st = get_state(self)
      % GET_STATE Return the camera state, e.g. BUSY, IDLE.
      st = self.status;
    end % get_state

    function image(self)
      % IMAGE capture an image with current camera settings
      
      if ~strcmp(self.status,'IDLE')
        % add the request into the 'expect' cache
        self.expect{end+1} = {'image', self};
        return
      end

      if ~strncmp(self.port, 'sim', 3)
        % we clear the stdout from the process (to get only what is new)
        self.proc.stdout = '';
        write(self.proc, sprintf('capture-image-and-download\n'));
        notify(self, 'captureStart');
        % register a post_image (to get image names)
        self.expect{end+1} = {'post_image', self};
      else % simulate: we generate an image file
        % simulation mode: we generate a preview image
        notify(self, 'captureStart');
        d = dir(self.dir);
        index = [ d.isdir ];
        index = find(~index);
        r = ceil(rand*numel(index));
        self.lastImageFile = cellstr(fullfile(self.dir, d(index(r)).name));
        self.lastImageDate = clock;
        notify(self, 'captureStop');
        CameraWatchFcn(self);
        if self.verbose, disp([ '[' datestr(now) '] ' mfilename ': ' char(self.lastImageFile) ]); end
      end
      
    end % image
    
    function capture(self)
      % CAPTURE capture an image with current camera settings
      image(self);
    end % capture
    
    function preview(self)
      % PREVIEW capture a preview (small) image with current camera settings
      if ~strcmp(self.status,'IDLE'), return; end
      if ~isempty(dir(fullfile(self.dir,'capture-preview.png')))
        delete(fullfile(self.dir,'capture-preview.png'));
      end
      if ~strncmp(self.port, 'sim', 3)
        % we clear the stdout from the process (to get only what is new)
        self.proc.stdout = '';
        write(self.proc, sprintf('capture-preview\n'));
        % the capture filename is 'capture_preview.jpg'. Just need to wait for it.
        % the plot window will automatically update its content with the last image 
        % or preview file.
        self.expect{end+1} = {'post_image', self};
      else
        % simluation mode: we generate a preview image
        d = dir(self.dir);
        index = [ d.isdir ];
        index = find(~index);
        r = ceil(rand*numel(index));
        self.lastPreviewFile = fullfile(self.dir, d(index(r)).name);
        self.lastPreviewDate = clock;
      end
      
    end % preview
    
    function dt = period(self, varargin)
      % PERIOD get or set the gphoto preview/continuous rate, in [s].
      %   PERIOD(s, 'gui') displays a dialogue to change the refresh rate.
      
      % special case for d='gui'
      
      if strncmp(self.port, 'sim', 3)
        dt0 = get(self.proc, 'period');
      elseif isa(self.proc,'process')
        dt0 = period(self.proc);
      else dt0 = inf;
      end
      if ~isempty(varargin) && ischar(varargin{1}) && strcmp(varargin{1}, 'gui')
        dt = inputdlg('Specify preview/continuous rate [s]. Use Inf or 0 to disable liveview.', ...
          [ mfilename ': Preview rate' ],1,{num2str(dt0)});
        if isempty(dt), return; end
        dt = str2num(dt{1});
        if isnan(dt), return; end
        if dt <= 0, dt = Inf; end
        varargin{1} = dt;
      elseif ~isempty(varargin) && isnumeric(varargin{1})
        dt = varargin{1};
      else dt = dt0;
      end

      if 0.1 < dt && dt < dt0
        if strncmp(self.port, 'sim', 3)
          set(self.proc, 'Period', dt);
        else
          dt = period(self.proc, dt); % faster gphoto shell background proc
        end
      elseif 1 < dt && dt0 < 1
        if strncmp(self.port, 'sim', 3)
          set(self.proc, 'Period', 1);
        elseif isa(self.proc,'process')
          period(self.proc, 1); % keep 1s reresh rate for external gphoto shell
        end
      end
      self.period_preview = dt;
    end % period
    
    function grid(self, st)
      % GRID set or toggle lines
      %   GRID(s, 'on'|'off'|'toggle') controls line display
      if nargin == 1, st = ''; end
      if ischar(st)
        switch lower(st)
        case 'on'
          self.show_lines = true;
        case 'off'
          self.show_lines = false;
        case {'','toggle'}
          self.show_lines = ~self.show_lines;
        end
      end
    end % grid
    
    function continuous(self, st)
      % CONTINUOUS set or toggle continuous shooting (timelapse)
      %   CONTINUOUS(s, 'on'|'off'|'toggle') controls continuous shooting.
      %   The capture rate is the same as the liveview. To lower the rate,
      %   increase the liveview period, e.g.:
      %     period(s, 10) 
      %   will take an image every 10s.
      if nargin == 1, st = ''; end
      if isnumeric(st) && isscalar(st)
        if st, st='on'; else st='off'; end
      end
      if ischar(st)
        switch lower(st)
        case {'on','start'}
          self.shoot_endless = true;
        case {'off','stop'}
          self.shoot_endless = false;
        case {'','toggle'}
          self.shoot_endless = ~self.shoot_endless;
        end
      end
      h = findall(0, 'Tag', [ mfilename '_continuous' ]);
      if self.shoot_endless
        disp([ '[' datestr(now) ']: ' mfilename  ': continuous shooting: ON' ]);
        if ~isempty(h), set(h, 'Checked','on'); end
      else
        disp([ '[' datestr(now) ']: ' mfilename  ': continuous shooting: OFF' ]);
        if ~isempty(h), set(h, 'Checked','off'); end
      end
    end % continuous
    
    function st = ishold(self)
      % ISHOLD get the camera status (IDLE, BUSY)
      %   st = ISHOLD(s) returns 1 when the camera is BUSY.
      
      % the last line of the shell prompt starts with 'gphoto2:' and ends with '> '
      if strncmp(self.port, 'sim', 3)
        self.status = 'IDLE'; st=0;
        return
      end
      lines = strread(self.proc.stdout,'%s','delimiter','\n\r');
      if isempty(lines) || isempty(lines{1})
        self.status = 'ERROR';
        if self.verbose > 1, disp(self.proc.stdout); end
        self.UserData.error = self.proc.stdout;
        st = 1;
        return
      end
      lines = lines{end};
      if strncmp(lines, 'gphoto2:',8) && lines(end-1) == '>' && isspace(lines(end))
        self.status = 'IDLE'; st = 0;
        notify(self, 'idle');
      elseif ~isempty(lines)
        self.status = 'BUSY'; st = 1;
        notify(self, 'busy');
      else
        self.status = 'ERROR'; st=0;
      end
    end % ishold
    
    function d = cd(self, d)
      % CD change or get current directory where images are stored.
      %   CD(g) get the current directory on the computer where images are stored.
      %
      %   CD(g, d) set the directory used for storing images.
      if nargin == 1
        d = self.dir;
      else
        if ~strcmp(self.status,'IDLE'), return; end
        
        % special case for d='gui'
        if strcmp(d, 'gui')
          d = inputdlg('Specify directory where to store images', ...
            [ mfilename ': Directory for images' ],1,{self.dir});
          if isempty(d), return; end
          d = d{1};
        end
        
        if ~ischar(d), return; end
        % test if dir exists
        [p,f] = fileparts(d);
        if (isempty(p) || isdir(p)) && ~isdir(d)
          mkdir(d);
        end
        if ~isdir(d), return; end
        if ~strncmp(self.port, 'sim', 3)
          write(self.proc, sprintf('lcd %s\n', d));
        end
        self.dir = d;
      end
    end % cd
    
    function about(self)
      % ABOUT display a dialog box showing settings.
      %   You may as well use set(g) to change settings and char(g,'long') to
      %   print them.
      c = cellstr(char(self,'long'));
      c{end+1} = [ mfilename ' for Matlab' ];
      c{end+1} = '(c) E. Farhi <https://github.com/farhi/matlab-gphoto>';
      listdlg('ListString', c, 'Name', [ mfilename ': About' ], ...
        'ListSize',[ 320 400 ],'SelectionMode','single');
    end % about

    function waitfor(self)
      % WAITFOR waits for camera to be IDLE
      while ishold(self)
        pause(self.period_preview);
      end
    end % waitfor
    
  end % methods
  
end % gphoto class

% ------------------------------------------------------------------------------
%               MAIN LOOP EXECUTED WHEN GPHOTO IS UPDATED
% ------------------------------------------------------------------------------
function CameraWatchFcn(self)
  % CameraWatchFcn callback attached to the proc timer

  if ~ishold(self) % 'IDLE'
    % when an action has been registered, we execute it, but only one at a time
    if ~isempty(self.expect) && iscell(self.expect)
      this = self.expect{1};
      feval(this{:}); % expand callback for action
      self.expect(1) = [];
    end
  end

  % PLOT_UPDATE update image in plot window when available
  h = findall(0, 'Tag', [ mfilename '_figure' ]);
  if isempty(h), return; end % nothing to do when not opened
  
  if numel(h) > 1, delete(h(2:end)); h=h(1); end
  set(0, 'CurrentFigure', h); % make it active witout raising

  % check if Capture or Preview is ready to be plotted
  imRGB =[]; imName = ''; file = []; ispreview = false;
  if     ~isempty(self.lastImageDate)   && etime(self.lastImageDate,self.lastPlotDate) > 0
    file = self.lastImageFile; notify(self, 'captureStop');
  elseif ~isempty(self.lastPreviewDate) && etime(self.lastPreviewDate,self.lastPlotDate) > self.period_preview
    file = self.lastPreviewFile; ispreview = true;
  end
  
  if ~isempty(file)
    if ~iscell(file), file = { file }; end
    % check if an image can be read
    
    for index = 1:numel(file)
      try; imRGB = imread(file{index}); imName=file{index}; break; end
    end
  end
  if ~isempty(imRGB)
    if (~ispreview || ...
      (isempty(self.lastImageDate) || etime(self.lastPreviewDate,self.lastImageDate) > 5))
      image(imRGB,'Parent',self.image_axes); 
      axis(self.image_axes, 'tight');
      set(self.image_axes,'XTickLabel',[],'XTick',[]); 
      set(self.image_axes,'YTickLabel',[],'YTick',[]); 
      set(self.image_axes,'ZTickLabel',[],'ZTick',[]);
      
      
      % compute image quality: blurred image has smooth variations. We sum up diff.
      im = double(imRGB);
      im1 = abs(diff(im,[], 1))/numel(im);
      im2 = abs(diff(im,[], 2))/numel(im);
      int = sum(im1(:))+sum(im2(:));
      self.focus_history(end+1) = int;
      if numel(self.focus_history) > 100
        self.focus_history = self.focus_history((end-99):end);
      end
      try
        title(self.image_axes, ...
          [ '[' datestr(clock) '] ' imName ], ...
          'interpreter','none','FontWeight','bold');
        xlabel(self.image_axes, self.dir); ylabel(self.image_axes, ' '); zlabel(self.image_axes, ' ');
      end

      % show X marker and focus history
      if self.show_lines
        xl = xlim(self.image_axes);
        yl = ylim(self.image_axes);
        hl = line([ 0 max(xl) ], [ 0 max(yl)]);
        set(hl, 'LineStyle','--','Tag', [ mfilename '_Line1' ], 'Parent',self.image_axes);
        hl = line([ 0 max(xl) ], [ max(yl) 0]);
        set(hl, 'LineStyle','--','Tag', [ mfilename '_Line2' ], 'Parent',self.image_axes);
        % focus history
        plot(self.focus_axes, self.focus_history);
        axis(self.focus_axes, 'tight');
        set(self.focus_axes,'XTickLabel',[],'XTick',[], 'visible','on'); 
        set(self.focus_axes,'ZTickLabel',[],'ZTick',[]);
        xlabel(self.focus_axes,' '); ylabel(self.focus_axes,num2str(int,3)); zlabel(self.focus_axes,' ');
      else
        set(self.focus_axes,'visible','off');
      end
    end
    self.lastPlotDate = clock;
  end
  set(h, 'Name', [ mfilename ': ' strtrim(char(self)) ]);
  
  % Trigger new preview when IDLE or CONTINUOUS
  if ~ishold(self) % 'IDLE'
    if self.shoot_endless
      image(self);
    elseif (~ispreview || ...
      (isempty(self.lastImageDate) || etime(self.lastPreviewDate,self.lastImageDate) > 5)) ...
      && ~strncmp(self.port, 'sim', 3)
      preview(self);
    end
    try
      set(self.image_axes,'XColor','k','YColor','k');
    end
  else
    % set axes borders to red when BUSY
    try
      set(self.image_axes,'XColor','r','YColor','r');
    end
  end
end % CameraWatchFcn

function post_get(self, config)
  % POST_GET executed when a get is registered and camera becomes idle
  
  % update the settings
  message = read(self.proc);
  if self.verbose > 1, disp(message); end
  value = gphoto_parse_output(self, message, config); % read result and parse it
  if isstruct(value) && numel(fieldnames(value)) == 1
    value = struct2cell(value);
    value = value{1};
  end
  self.settings.(config) = value;
  disp([ '[' datestr(now) ']: ' mfilename  ': ' config ]);
  ans = value
  
end % post_get

function post_image(self)
  % images have been written
  message = read(self.proc);
  if self.verbose > 1, disp(message); end
  files = gphoto_parse_output(self, message);
  index = find(strcmp('capture_preview.jpg', files));
  if ~isempty(index)
    self.lastPreviewFile = files(index);
    self.lastPreviewDate = clock;
  end
  index = find(~strcmp('capture_preview.jpg', files)); % not preview
  if ~isempty(index)
    self.lastImageFile = fullfile(self.dir, files(index));
    self.lastImageDate = clock;
    if self.verbose, disp([ '[' datestr(now) '] ' mfilename ': ' self.lastImageFile{1} ]); end
  end
end % post_image

function post_getconfig(self)
  % list-config has been received. We get the output.
  if strncmp(self.port, 'sim', 3), return; end
  message = read(self.proc);
  if self.verbose > 1, disp(message); end
  % get all config fields: they start with '/'
  t = textscan(message, '%s','Delimiter','\n'); % into lines
  t = t{1}; config = {};
  self.UserData.raw1 = t;
  for index=1:numel(t)
    this = t{index};
    if this(1) == '/'
      write(self.proc, sprintf('get-config %s\n', this));
    end
  end
  self.expect{end+1} = { 'post_getvalues', self, config};
end

function post_getvalues(self, config)
  % we have sent get-config for all fields. get results into settings...
  if strncmp(self.port, 'sim', 3), return; end
  message = read(self.proc);
  if self.verbose > 1, disp(message); end
  self.settings = gphoto_parse_output(self, message);
  identify(self); % update identification string
end % post_getvalues
