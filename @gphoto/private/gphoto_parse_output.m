function gphoto_config = gphoto_parse_output(self, message, config)
  % gphoto_parse_output split with '/main' entries
  
  % checks for message type and config (if any)
  if ischar(message)
    t = textscan(message, '%s','Delimiter','\n'); % into lines
    t = t{1};
  elseif iscellstr(message)
    t = message;
  else
    error([ mfilename ': message is ' class(message) ' should be char or cellstr.' ])
  end
  if nargin > 2
    if ischar(config)
      config = textscan(config, '%s', 'Delimiter',' '); % tokens
      config = config{1};
      config = config(find(~cellfun(@isempty, config)));
    end
  else config = {};
  end
  
  main = find(strncmp(t, '/', 1));
  if isempty(main)
    main = [ 1 (find(strncmp(t, 'END', 5))-1) ];
  end
  gphoto_config = {};
  
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
      config{index} = n;
    end
    
    % block fields (as cell)
    block = t(block_start:block_end);
    % get only lines with ':' (remove END and any other parasitic output)
    block = block(~cellfun(@isempty, strfind(block, ':')));
    block = str2struct(block);
    gphoto_config{end+1} = block;
  end
  
  % create structure when relevant
  if numel(gphoto_config) == numel(config)
    gphoto_config = cell2struct(gphoto_config, config, 2);
  end
  % ----------------------------------------------------------------------------
 
