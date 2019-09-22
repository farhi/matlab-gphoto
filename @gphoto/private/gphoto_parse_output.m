function gphoto_config = gphoto_parse_output(self, message, config)
  % gphoto_parse_output split with '/main' and END entries
  gphoto_config = {};
  
  % checks for message type and config (if any)
  if isempty(message), return; end
  if ischar(message)
    t = textscan(message, '%s','Delimiter','\n'); % into lines
    t = t{1};
  elseif iscellstr(message)
    t = message;
  else
    error([ mfilename ': message is ' class(message) ' should be char or cellstr.' ])
  end
  % check if this is a capture message
  if strncmp(t{1}, 'capture-', 8)
    gphoto_config = gphoto_parse_capture(self, t);
    return
  end
  if nargin > 2
    if ischar(config)
      config = textscan(config, '%s', 'Delimiter',' '); % tokens
      config = config{1};
      config = config(find(~cellfun(@isempty, config)));
    end
  else config = {};
  end
  
  % we first remove any 'get-config ' tokens which shield field names
  t = strrep(t, 'get-config ','');
  
  main = find(strncmp(t, '/', 1));
  if isempty(main)
    main = [ 1 (find(strncmp(t, 'END', 5))-1) ];
  end
  
  % analyse result
  for index=1:numel(main)
    % extract the block
    block_start = main(index);
    if index==numel(main)
      block_end = numel(t);
    else
      block_end = main(index+1);
    end
    
    % block name
    % the block can either start with the gphoto property path
    %   /main/status/deviceversion
    % or with nothing
    % all blocks end with 'END'
    l = t{block_start}; n='';
    if l(1) == '/'
      % get the block name from the '/main' line (as path name)
      n     = t{block_start};
      [r,n] = fileparts(n); n(~isstrprop(n, 'alphanum')) = '_';
      if ~isvarname(n), n= genvarname(n); end
    end
    
    % block fields (as cell)
    block = t(block_start:block_end);
    % get only lines with ':' (remove END and any other parasitic output)
    block = block(~cellfun(@isempty, strfind(block, ':')));
    
    try
      block = str2struct(block);
    catch
      b= block; block=[]; block.Current = b;
    end
    block.name = genvarname(n);
    gphoto_config{end+1} = block;
  end
  
  % create structure when relevant
  s = [];
  if numel(gphoto_config) == numel(config)
    try
      s = cell2struct(gphoto_config, config, 2);
    end
  end
  if isempty(s)
    for index=1:numel(gphoto_config)
      if ~isempty(gphoto_config{index}.name) 
        if ~isfield(s, gphoto_config{index}.name)
          s.(gphoto_config{index}.name) = gphoto_config{index};
        else
          s.(gphoto_config{index}.name) = cat(s.(gphoto_config{index}.name), gphoto_config{index});
        end
      end
    end
  end
  gphoto_config = s;

% ----------------------------------------------------------------------------
function files = gphoto_parse_capture(self, t)
  %  gphoto_parse_capture get the captured image file names
  
  files = {};
  % the file names appear at the end of the lines
  for index=2:numel(t)
    % split into words
    w = textscan(t{index}, '%s', 'Delimiter', ' ');
    w = w{1};
    w = w(find(~cellfun(@isempty, w)));
    if ~isempty(dir(fullfile(self.dir, w{end})))
      files{end+1} = w{end};
    end
  end
    
