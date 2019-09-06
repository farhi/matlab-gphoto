function g = gphoto_executable
  % search gphoto2 binary
  
  g = ''; 
  if ismac,      precmd = 'DYLD_LIBRARY_PATH= ;';
  elseif isunix, precmd = 'LD_LIBRARY_PATH= ; '; 
  else           precmd=''; end
  
  if ispc, ext='.exe'; else ext=''; end
  
  % try in order: global(system), local, local_arch
  for try_target={ [ 'gphoto2' ext ], 'gphoto2' }
      
    [status, result] = system([ precmd try_target{1} ' --version' ]); % run from Matlab

    if status == 0
        % the executable is there.
        g = try_target{1};
        disp([ '  GPhoto         (https://www.gphoto.org/) as: ' g ]);
        break
    end
  end
  
  if isempty(g)
    error([ mfilename ': GPHOTO is not available. Install it from gphoto.org' ])
  end
end % gphoto_executable
