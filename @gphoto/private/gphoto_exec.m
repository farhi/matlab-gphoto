function [gphoto_config, message] = gphoto_exec(self, cmd)
% GPHOTO_EXEC get the camera full configuration or execute command.
%   [struct, message] = GPHOTO_EXEC(self, cmd) send 'cmd' to gphoto.
%   and returns the result as a struct, and as raw text.
%   This action does not use the shell mode.

  % required to avoid Matlab to use its own libraries
  if ismac,      precmd = 'DYLD_LIBRARY_PATH= ; DISPLAY= ; ';
  elseif isunix, precmd = 'LD_LIBRARY_PATH= ;  DISPLAY= ; '; 
  else           precmd = ''; end
  
  if nargin < 2 || isempty(cmd)
    cmd = '--list-all-config';
  end
  cmd = [ precmd self.executable  ' ' cmd ' -q' ];
  
  [ret, message] = system(cmd);
  if ret ~= 0
    disp([ mfilename ': ERROR: ' cmd ]);
    disp(message)
    error('GPhoto is not available, or camera is not connected.');
  end
  
  % parse the gphoto output
  gphoto_config = gphoto_parse_output(self, message);
  if isstruct(gphoto_config)
    gphoto_config = orderfields(gphoto_config);
  end
  
end % gphoto2_getconfig
