classdef gphoto < handle
  % GPHOTO A class to control DSLR camera handled by gPhoto
  %
  % Usage
  % =====
  % This class can curently connect to a single DSLR camera via USB and GPhoto2.
  % Basically, type from Matlab:
  % - addpath /path/to/gphoto
  % - g = gphoto;
  % - plot(g) 
  % - image(g)
  % - get(g)
  % - set(g, 'iso', 3200);
  %
  % Installation
  % ============
  % Get the project archive, which shoud contain a @gphoto and @process directories.
  %
  % Methods
  % =======
  % - about       display a dialog box showing settings.
  % - cd          change or get current directory where images are stored. 
  % - char        returns a character representation of the object
  % - continuous  set/toggle continuous shooting (timelapse).
  % - delete      close the Gphoto connection.
  % - disp        display GPhoto object (details)
  % - display     display GPhoto object (from command line)
  % - get         get the camera configuration.
  % - grid        set/toggle line markers and focus quality on plot.
  % - identify    identify the connected camera
  % - image       capture an image with current camera settings.
  % - ishold      get the camera status (IDLE, BUSY).
  % - plot        plot the camera liveview and captured images.
  % - period      set/get plot update periodicity, in seconds.
  % - preview     capture a preview (small) image with current camera settings.
  % - set         set a configuration value.
  % - start       start the background gphoto control.
  % - stop        stop the background gphoto control. Restart it with start.
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
    verbose        = false;  % gives more I/O output when true
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

      % where is the executable ?
      self.executable = gphoto_executable;
      
      % we identify the connected cameras
      [cameras,ports] = gphoto_ports(self);
      if ~isempty(cameras)
        disp('Connected cameras (gPhoto):');
        disp('-----------------------------------------------------------')
        for index=1:numel(cameras)
          fprintf(1, '%30s %s\n', cameras{index}, ports{index});  
        end
        if ~nargin && numel(cameras) > 1
          error([ mfilename ': there are more than one camera connected. Specify the port.' ])
        end
      end
      
      % start gphoto shell and initiate view with a preview capture
      start(self, varargin{:});
      preview(self);
      
      % update all settings
      gphoto_getall(self);
      
    end % gphoto instantiate
    
    function start(self, port)
      % START start the background gphoto control
      if nargin < 2, port = self.port; end
      if isempty(self.proc) || ~isvalid(self.proc)
        cmd = [ self.executable ' --shell --force-overwrite' ];
        if nargin > 1 && ~isempty(port) && ischar(port) && ~strcmp(port,'auto')
          % specify the port
          cmd = [ cmd ' --port ' port ];
          self.port = port;
        end
        % we start the gphoto shell which is reactive and allows background
        % set, get, capture.
        self.proc = process(cmd);
        silent(self.proc);
        self.period_preview = period(self.proc, 1); % auto update period for stdout/err/in
        
        % attach our CameraWatchFcn to the gphoto shell'update'
        addlistener(self.proc, 'processUpdate', @(src,evt)CameraWatchFcn(self));
        identify(self);
      end
    end % start
    
    function stop(self)
      % STOP stop the background gphoto control. Restart it with start.
      if ~isempty(self.proc) && isvalid(self.proc)
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
      c = { sprintf(' %6s   %s [port: %s] ', self.status, self.version, self.port) };
      if nargin > 1
        f = fieldnames(self.settings);
        for index=1:numel(f)
          if isfield(self.settings.(f{index}),'Current')
            c{end+1} = [ '  ' f{index} ': ' ...
              num2str(self.settings.(f{index}).Current) ];
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
      disp([ mfilename ': connected to ' id ]);
    end % identify
    
    function get(self, config)
      % GET get the camera configuration
      %   GET(g) get all configuration states (from cache).
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
        disp(char(self, 'long'));
      elseif isfield(self.settings, config)
        % we clear the stdout from the process (to get only what is new)
        self.proc.stdout = '';
        % update value from the camera
        write(self.proc, sprintf('get-config %s\n', config));
        % register expect action as post_get (to get the value when ready)
        self.expect{end+1} = { 'post_get', self, config };
      end
    end % get
    
    
    
    function image(self)
      % IMAGE capture an image with current camera settings
      
      if ~strcmp(self.status,'IDLE')
        % add the request into the 'expect' cache
        self.expect{end+1} = {'image', self};
        return
      end
      
      % we clear the stdout from the process (to get only what is new)
      self.proc.stdout = '';
      write(self.proc, sprintf('capture-image-and-download\n'));
      notify(self, 'captureStart');
      % register a post_image (to get image names)
      self.expect{end+1} = {'post_image', self};
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
      % we clear the stdout from the process (to get only what is new)
      self.proc.stdout = '';
      write(self.proc, sprintf('capture-preview\n'));
      % the capture filename is 'capture_preview.jpg'. Just need to wait for it.
      % the plot window will automatically update its content with the last image 
      % or preview file.
      self.expect{end+1} = {'post_image', self};
    end % preview
    
    function dt = period(self, varargin)
      % PERIOD get or set the gphoto preview rate, in [s].
      
      % special case for d='gui'
      dt0 = period(self.proc);
      if ~isempty(varargin) && ischar(varargin{1}) && strcmp(varargin{1}, 'gui')
        dt = inputdlg('Specify preview rate [s]. Use Inf or 0 to disable liveview.', ...
          [ mfilename ': Preview rate' ],1,{num2str(dt0)});
        if isempty(dt), return; end
        dt = str2num(dt{1});
        if isnan(dt), return; end
        if dt <= 0, dt = Inf; end
        varargin{1} = dt;
      end

      if dt < dt0
        dt = period(self.proc, dt); % this controls the background proc
      elseif dt > 1 && dt0 < 1
        period(self.proc, 1);
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
      %   CONTINUOUS(s, 'on'|'off'|'toggle') controls continuous shooting
      if nargin == 1, st = ''; end
      if ischar(st)
        switch lower(st)
        case 'on'
          self.shoot_endless = true;
        case 'off'
          self.shoot_endless = false;
        case {'','toggle'}
          self.shoot_endless = ~self.shoot_endless;
        end
      end
      h = findall(0, 'Tag', [ mfilename '_continuous' ]);
      if self.shoot_endless
        disp([ mfilename ': continuous shooting: ON' ]);
        if ~isempty(h), set(h, 'Checked','on'); end
      else
        disp([ mfilename ': continuous shooting: OFF' ]);
        if ~isempty(h), set(h, 'Checked','off'); end
      end
    end % continuous
    
    function st = ishold(self)
      % ISHOLD get the camera status (IDLE, BUSY)
      %   st = ISHOLD(s) returns 1 when the camera is BUSY.
      
      % the last line of the shell prompt starts with 'gphoto2:' and ends with '> '
      lines = strread(self.proc.stdout,'%s','delimiter','\n\r');
      if isempty(lines) || isempty(lines{1})
        self.status = 'ERROR';
        if self.verbose, disp(self.proc.stdout); end
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
        write(self.proc, sprintf('lcd %s\n', d));
        self.dir = d;
      end
    end % cd
    
    function about(self)
      % ABOUT display a dialog box showing settings.
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
    if ~isempty(self.expect)
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
      try; imRGB = imread(fullfile(self.dir, file{index})); imName=file{index}; break; end
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
      title(self.image_axes, ...
        [ '[' datestr(clock) '] ' imName ], ...
        'interpreter','none','FontWeight','bold');
      xlabel(self.image_axes, self.dir); ylabel(self.image_axes, ' '); zlabel(self.image_axes, ' ');

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
      (isempty(self.lastImageDate) || etime(self.lastPreviewDate,self.lastImageDate) > 5))
      preview(self);
    end
    set(self.image_axes,'XColor','k','YColor','k');
  else
    % set axes borders to red when BUSY
    set(self.image_axes,'XColor','r','YColor','r');
  end
end % CameraWatchFcn

function post_get(self, config)
  % POST_GET executed when a get is registered and camera becomes idle
  
  % update the settings
  message = read(self.proc);
  if self.verbose, disp(message); end
  value = gphoto_parse_output(self, message, config); % read result and parse it
  if isstruct(value) && numel(fieldnames(value)) == 1
    value = struct2cell(value);
    value = value{1};
  end
  self.settings.(config) = value;
  disp([ mfilename ': ' config ]);
  disp(value);
  
end % post_get

function post_image(self)
  % images have been written
  message = read(self.proc);
  if self.verbose, disp(message); end
  files = gphoto_parse_output(self, message);
  index = find(strcmp('capture_preview.jpg', files));
  if ~isempty(index)
    self.lastPreviewFile = files(index);
    self.lastPreviewDate = clock;
  end
  index = find(~strcmp('capture_preview.jpg', files));
  if ~isempty(index)
    self.lastImageFile = files(index);
    self.lastImageDate = clock;
  end
end % post_image

function post_getconfig(self)
  % list-config has been received. We get the output
  message = read(self.proc);
  if self.verbose, disp(message); end
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
 message = read(self.proc);
 if self.verbose, disp(message); end
 self.settings = gphoto_parse_output(self, message);
 identify(self); % update identification string
end % post_getvalues
