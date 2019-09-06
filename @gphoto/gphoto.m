classdef gphoto < handle
  % GPHOTO A class to control DSLR camera handled by gPhoto
  %
  % (c) E. Farhi, GPL2, 2019.

  properties
    settings      = [];
    status        = 'INIT';
    UserData      = [];
    lastImageFile = '';
    lastImageRGB  = [];
    lastImageDate = '';
    lastPreviewRGB= [];
    lastPreviewDate='';
  end % properties
  
  properties (Access=private)
    executable    = [];
    proc          = [];
    expect        = {};
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
      
      % first we connect using gphoto --list-all-config to get:
      % - all current settings
      % - all available settings
      % - setters and getters
      
      self.executable = gphoto_executable;
      
      % get all config states (only when starting - use gphoto in non interactive)
      self.settings = gphoto_getconfig_all(self);
      start(self);
      
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
      % STOP stop the background gphoto control
      if ~isempty(self.proc) && isvalid(self.proc)
        delete(self.proc); % stop and kill gphoto shell
      end
      self.proc = [];
    end % stop
    
    function delete(self)
      % DELETE close the Gphoto connection
      stop(self);
    end % delete
    
    function get(self, config)
      % GET get the camera configuration
      %   GET(self) get all configuration states (from cache).
      %
      %   GET(self, config) update the specified configuration from the camera.
      if ~strcmp(self.status,'IDLE'), return; end
      if nargin == 1, config = ''; end
      if ~ischar(config), return; end
      
      if isempty(config) || strcmp(config, 'all')
        f = fieldnames(self.settings);
        for index=1:numel(f)
          if isfield(self.settings.(f{index}),'Current')
            disp([ '  ' f{index} ': ' ...
              num2str(self.settings.(f{index}).Current) ])
          else
            disp([ '  ' f{index} ]);
          end
        end
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
      %   SET(self, config, value) sets config=value on the camera
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
      if isfield(self.settings.config, 'Readonly') ...
        &&  self.settings.config.Readonly
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
      
      if ~strcmp(self.status,'IDLE'), return; end
      
      % we clear the stdout from the process (to get only what is new)
      self.proc.stdout = '';
      write(self.proc, sprintf('capture-image-and-download\n'));
      % register a post_image (to get image names)
      self.expect{end+1} = {'post_image', self};
    end % image
    
    function preview(self)
      % PREVIEW capture a preview (small) image with current camera settings
      
      if ~strcmp(self.status,'IDLE'), return; end
      if ~isempty(dir(fullfile(pwd,'capture-preview.png')))
        delete(fullfile(pwd,'capture-preview.png'));
      end
      % we clear the stdout from the process (to get only what is new)
      self.proc.stdout = '';
      write(self.proc, sprintf('capture-preview\n'));
      % the capture filename is 'capture_preview.jpg'. Just need to wait for it.
      % the plot window will automatically update its content with the last image 
      % or preview file.
      self.expect{end+1} = {'post_preview', self};
    end % image
    
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
    
  end % methods
  
end % gphoto class

% ------------------------------------------------------------------------------
function CameraWatchFcn(self)
  % CameraWatchFcn callnback attached to the proc timer
  if ~ishold(self) % 'IDLE'
    % when an action has been registered, we execute it
    for index=1:numel(self.expect)
      this = self.expect{index};
      feval(this{:}); % expand callback for action
    end
    % clear action callbacks
    self.expect = {};
      
  end
end % end

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
  % POST_IMAGE executed when a capture is registered and camera becomes idle
  % images have been written
  disp([ mfilename ': image' ]);
  message = read(self.proc);
  disp(message)
end % post_image

function post_preview(self)
  % POST_PRVEIEW executed when a preview is registered and camera becomes idle
  disp([ mfilename ': preview' ]);
  message = read(self.proc);
  disp(message)
end % post_preview
