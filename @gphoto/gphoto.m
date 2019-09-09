classdef gphoto < handle
  % GPHOTO A class to control DSLR camera handled by gPhoto
  %
  % Usage
  % =====
  % This class can curently connect to a single DSLR camera via USB and GPhoto2.
  % Basically, type from Matlab:
  % - addpath /path/to/gphoto
  % - g = gphoto;
  % - image(g)
  % - preview(g)
  % - get(g)
  % - set(g, 'iso', 3200);
  %
  % Installation
  % ============
  % Get the project archive, which shoud contain a @gphoto and @process directories.
  %
  % Methods
  % =======
  % - cd      change or get current directory where images are stored. 
  % - delete  close the Gphoto connection
  % - get     get the camera configuration 
  % - image   capture an image with current camera settings 
  % - ishold  get the camera status (IDLE, BUSY) 
  % - plot    plot the camera liveview and captured images
  % - preview capture a preview (small) image with current camera settings 
  % - set     set a configuration value
  % - start   start the background gphoto control
  % - stop    stop the background gphoto control. Restart it with start.
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
  end % properties
  
  properties (Access=private)
    executable    = [];     % location of gphoto executable
    proc          = [];     % the gphoto2 background process (shell)
    expect        = {};     % commands being cached
    lastPlotDate  = clock;  % the date of last plot
    show_lines    = false;
  end % properties
  
  events
    captureStart
    captureStop
    idle
    busy
  end
  
  methods
    function self = gphoto
      % GPHOTO initialize the remote control for DSLR Cameras

      % where is the executable ?
      self.executable = gphoto_executable;
      
      % get all config states (only when starting - use gphoto in non interactive)
      self.settings = gphoto_getconfig_all(self);
      
      % start gphoto shell and initiate view with a preview capture
      start(self);
      preview(self);
      
    end % gphoto instantiate
    
    function start(self)
      % START start the background gphoto control
      if isempty(self.proc) || ~isvalid(self.proc)
        % we start the gphoto shell which is reactive and allows background
        % set, get, capture.
        self.proc = process([ self.executable ' --shell --force-overwrite' ]);
        silent(self.proc);
        period(self.proc, 1); % auto update period for stdout/err/in
        
        % attach our CameraWatchFcn to the gphoto shell'update'
        addlistener(self.proc, 'processUpdate', @(src,evt)CameraWatchFcn(self));
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
      c = { [ 'Status: ' self.status ] };
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
        stop(self);
        self.settings = gphoto_getconfig_all(self);
        start(self);
      elseif isempty(config)
        disp(char(self, 'long'));
      elseif isfield(self.settings, config)
        % we clear the stdout from the process (to get only what is new)
        self.proc.stdout = '';
        % update value from the camera
        write(self.proc, sprintf('get-config %s\n', config));
        % register expect action as post_get (to get the value when ready)
        self.expect{end+1} = {'post_get', self, config};
      end
    end % get
    
    function set(self, config, value)
      % SET set a configuration value
      %   SET(g, config, value) sets config=value on the camera
      %
      %   SET(g) display all settable configuration fields
      if ~strcmp(self.status,'IDLE'), return; end
      if nargin < 3
        f = fieldnames(self.settings);
        for index=1:numel(f)
          if isfield(self.settings.(f{index}), 'Readonly') ...
            && ~self.settings.(f{index}).Readonly
            if isfield(self.settings.(f{index}),'Current')
              disp([ '  ' f{index} ': ' ...
                num2str(self.settings.(f{index}).Current) ])
            else
              disp([ '  ' f{index} ]);
            end
          end
        end
        return; 
      end
      if ~ischar(config), return; end
      if ~isfield(self.settings, config), return; end
      if isfield(self.settings.(config), 'Readonly') ...
        &&  self.settings.(config).Readonly
        disp([ mfilename ': set: property ' config ' is Readonly.' ])
        return
      end
      
      % we clear the stdout from the process (to get only what is new)
      self.proc.stdout = '';
      write(self.proc, sprintf('set-config %s=%s\n', config, num2str(value)));
      % update the settings
      self.settings.(config).Current = value;
      
    end % set
    
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
      if ~isempty(varargin) && ischar(varargin{1}) && strcmp(varargin{1}, 'gui')
        dt = period(self.proc);
        dt = inputdlg('Specify preview rate [s]. Use Inf or 0 to disable liveview.', ...
          [ mfilename ': Preview rate' ],1,{num2str(dt)});
        if isempty(dt), return; end
        dt = str2num(dt{1});
        if isnan(dt), return; end
        if dt <= 0, dt = Inf; end
        varargin{1} = dt;
      end
        
      dt = period(self.proc, varargin{:}); % this controls the background proc
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
    
    function st = ishold(self)
      % ISHOLD get the camera status (IDLE, BUSY)
      %   st = ISHOLD(s) returns 1 when the camera is BUSY.
      
      % the last line of the shell prompt starts with 'gphoto2:' and ends with '> '
      lines = strread(self.proc.stdout,'%s','delimiter','\n\r');
      lines = lines{end};
      if strncmp(lines, 'gphoto2:',8) && lines(end-1) == '>' && isspace(lines(end))
        self.status = 'IDLE'; st = 0;
      else
        self.status = 'BUSY'; st = 1;
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
      % ABOUT 
      c = cellstr(char(self,'long'));
      c{end+1} = [ mfilename ' for Matlab' ];
      c{end+1} = '(c) E. Farhi <https://github.com/farhi/matlab-gphoto>';
      listdlg('ListString', c, 'Name', [ mfilename ': About' ],'ListSize',[ 320 400 ]);
    end % about
    
    function help(self)
    end % help
    
    function h=plot(self)
      % PLOT plot the last image/preview.
      
      % get the figure handle
      h = findall(0, 'Tag', [ mfilename '_figure' ]);
      if isempty(h) % build the plot window
        h = figure('Tag', [ mfilename '_figure' ], 'Name', mfilename, 'MenuBar','none');
        set(h, 'Units','normalized');
        
        % File menu
        m = uimenu(h, 'Label', 'File');
        uimenu(m, 'Label', 'Save',        ...
          'Callback', 'filemenufcn(gcbf,''FileSave'')','Accelerator','s');
        uimenu(m, 'Label', 'Save As...',        ...
          'Callback', 'filemenufcn(gcbf,''FileSaveAs'')');
        uimenu(m, 'Label', 'Print',        ...
          'Callback', 'filemenufcn(gcbf,''FilePrintPreview'')','Accelerator','p');
        % ---------------------
        uimenu(m, 'Label', 'Close',        ...
          'Callback', 'filemenufcn(gcbf,''FileClose'')', ...
          'Accelerator','w', 'Separator','on');
        
        % Camera menu
        m0 = uimenu(h, 'Label', 'Camera');
        uimenu(m0, 'Label', 'Capture image', ...
          'Callback', @(src,evt)image(self), 'Accelerator','c');
        uimenu(m0, 'Label', 'Capture preview', ...
          'Callback', @(src,evt)preview(self));
        uimenu(m0, 'Label', 'Speficy directory for storage...', ...
          'Callback', @(src,evt)cd(self,'gui'));
        uimenu(m0, 'Label', 'Speficy liveview rate...', ...
          'Callback', @(src,evt)period(self,'gui'));
        uimenu(m0, 'Label', 'Toggle line display', ...
          'Callback', @(src,evt)grid(self));
        % ---------------------
        uimenu(m0, 'Label', 'Help', ...
          'Callback', @(src,evt)help(self), 'Separator','on');
        uimenu(m0, 'Label', [ 'About camera and ' mfilename ], ...
          'Callback', @(src,evt)about(self));
          
        g = gca; % initiate an empty axes
        set(g, 'Units','normalized');
          
        % we add a button for capture
        m0 = uicontrol('Style', 'pushbutton', 'String', 'Capture',...
          'Units','normalized','Position',[ 0 0 0.2 0.1 ], ...
          'Callback', @(src,evt)image(self),'BackgroundColor','r');

      end

    end % plot
    
  end % methods
  
end % gphoto class

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
    file = self.lastImageFile;
  elseif ~isempty(self.lastPreviewDate) && etime(self.lastPreviewDate,self.lastPlotDate) > 0 ...
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
      image(imRGB); 
      axis tight
      set(gca,'XTickLabel',[],'XTick',[]); 
      set(gca,'YTickLabel',[],'YTick',[]); 
      set(gca,'ZTickLabel',[],'ZTick',[])
      xlabel(self.dir); ylabel(' '); zlabel(' ');
      title([ '[' datestr(clock) '] ' imName ],'interpreter','none');
      if self.show_lines
        xl = xlim(gca);
        yl = ylim(gca);
        hl = line([ 0 max(xl) ], [ 0 max(yl)]);
        set(hl, 'LineStyle','--','Tag', [ mfilename '_Line1' ]);
        hl = line([ 0 max(xl) ], [ max(yl) 0]);
        set(hl, 'LineStyle','--','Tag', [ mfilename '_Line2' ]);
      end
    end
    self.lastPlotDate = clock;
  end
  set(h, 'Name', [ mfilename ': ' char(self) ]);
  
  % Trigger new preview when IDLE
  if ~ishold(self) % 'IDLE'
    if (~ispreview || ...
      (isempty(self.lastImageDate) || etime(self.lastPreviewDate,self.lastImageDate) > 5))
      preview(self);
    end
    set(gca,'XColor','k','YColor','k');
  else
    % set axes borders to red when BUSY
    set(gca,'XColor','r','YColor','r');
  end
end % CameraWatchFcn

function post_get(self, config)
  % POST_GET executed when a get is registered and camera becomes idle
  
  % update the settings
  message = read(self.proc);
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

