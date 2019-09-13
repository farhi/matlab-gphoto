function set(self, config, value)
  % SET set a configuration value
  %   SET(g, config, 'value') sets config=value on the camera. value must
  %   be a string.
  %
  %   SET(g, config, index) sets config=index on the camera for multi-choice
  %   settings (RADIO,MENU), and index is an integer (starting from 0).
  %
  %   SET(g, config) displays a dialog to change the given setting.
  %
  %   SET(g) displays a list of all modifiable settings.
  if ~strcmp(self.status,'IDLE'), return; end
  if nargin == 1
    % build a list of modifiable settings
    f = fieldnames(self.settings);
    settings = {};
    for index=1:numel(f)
      if isfield(self.settings.(f{index}), 'Readonly') ...
        && ~self.settings.(f{index}).Readonly
        if isfield(self.settings.(f{index}),'Current')
          val = self.settings.(f{index}).Current;
          if isnumeric(val), val = val(:)'; end
          settings{end+1} = [ f{index} ' = ' num2str(val) ];
        end
      end
    end
    % display a listdlg
    t = [ class(self) ': Settings' ];
    answer = listdlg('ListString', settings, 'Name', t,'ListSize',[ 320 400 ], ...
      'OKString','Modify','CancelString','Cancel','SelectionMode','single');
    if isempty(answer), return; end
    config = strtok(settings{answer});
    set(self, config);
    return
  end
  
  if ~ischar(config), return; end
  if ~isfield(self.settings, config), return; end
  if isfield(self.settings.(config), 'Readonly') ...
    &&  self.settings.(config).Readonly
    disp([ class(self) ': set: property ' config ' is Readonly.' ])
    return
  end
  
  choices = {};
  if isfield(self.settings.(config), 'Type')
    Type = self.settings.(config).Type;
  else 
    disp([ class(self) ': set: unknown property ' config ' type.' ])
    return
  end
  if any(strcmp(Type, {'RADIO','MENU'}))
    can_use_index = true;
    choices = self.settings.(config).Choice;
    indices = [];
    % get the indices for the available choices
    for ii=1:numel(choices);
      if isnumeric(choices{ii}) % convert numerics to strings
        this = choices{ii};
        choices{ii} = num2str(this(:)');
      end
    end
    [indices,choices] = strtok(choices);
    choices = strtrim(choices);
  else
    can_use_index = false; indices=[];
  end
  
  % change a single setting, propose a list of values or entry field
  if nargin == 2 && isfield(self.settings.(config), 'Type')
    t = [ class(self) ': Set ' config ' ' self.settings.(config).Type ];
    switch Type
    case 'RANGE'
      % Bottom Top Step, Current is numeric
      value = inputdlg([ config ' from ' num2str(self.settings.(config).Bottom) ...
        ' to ' num2str(self.settings.(config).Top) ' in step ' ...
          num2str(self.settings.(config).Step) ], ...
        t, 1, ...
        { num2str(self.settings.(config).Current) });
      if isempty(value), return; end
      value = str2num(value{1});
      if ~isfinite(value), return; end
    case {'RADIO','MENU'}
      % Choice: {'0 3:2'  '1 16:9'} i.e. 'index value'
      answer = listdlg('ListString', choices, 'Name', t, ...
        'ListSize',[ 320 400 ],'SelectionMode','single');
      if isempty(answer), return; end
      value = str2num(indices{answer}); % integer (starting from 0)
    otherwise % MENU TOGGLE: not supported
      disp([ t ': not supported' ])
      return
    end
  end
  if isempty(value), return; end
  
  % we clear the stdout from the process (to get only what is new)
  if can_use_index && isnumeric(value) && ...
    mod(value,1) == 0 && 0 <= value && value <= numel(choices)
    disp([ class(self) ': set: ' config ' = ' choices{value+1} ' [' num2str(value) ']' ])
    if ~strncmp(self.port, 'sim',3)
      self.proc.stdout = '';
      write(self.proc, sprintf('set-config-index %s=%s\n', config, num2str(value)));
    end
    self.settings.(config).Current = choices{value+1};
  else
    disp([ class(self) ': set: ' config ' = ' num2str(value) ])
    if ~strncmp(self.port, 'sim',3)
      self.proc.stdout = '';
      write(self.proc, sprintf('set-config %s=%s\n', config, num2str(value)));
    end
    self.settings.(config).Current = value;
  end
  % update the settings
  
  
end % set
