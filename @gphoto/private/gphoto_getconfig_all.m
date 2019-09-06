function gphoto_config = gphoto_getconfig_all(self)
% gphoto_getconfig_all get the camera full configuration

  % required to avoid Matlab to use its own libraries
  if ismac,      precmd = 'DYLD_LIBRARY_PATH= ; DISPLAY= ; ';
  elseif isunix, precmd = 'LD_LIBRARY_PATH= ;  DISPLAY= ; '; 
  else           precmd = ''; end
  
  cmd = [ precmd self.executable  ' --list-all-config -q' ];
  
  [ret, message] = system(cmd);
  if ret ~= 0
    disp(cmd)
    disp(message)
    error('GPhoto is not available, or camera is not connected.');
  end
  
  % parse the gphoto output
  gphoto_config = gphoto_parse_output(self, message);
  
end % gphoto2_getconfig
