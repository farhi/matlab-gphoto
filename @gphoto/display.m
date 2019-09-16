function d = display(s_in, name)
  % DISPLAY display GPhoto object (from command line)

  if nargin == 2 && ~isempty(name)
    iname = name;
  elseif ~isempty(inputname(1))
    iname = inputname(1);
  else
    iname = 'ans';
  end

  d = [ sprintf('%s = ',iname) ];

  if isdeployed || ~usejava('jvm') || ~usejava('desktop'), id=class(s_in);
  else           id=[ '<a href="matlab:doc gphoto">gphoto</a> ' ...
      '(<a href="matlab:methods gphoto">methods</a>,' ...
      '<a href="matlab:image(' iname ')">capture</a>,' ...
      '<a href="matlab:plot(' iname ')">plot</a>,' ...
      '<a href="matlab:set(' iname ')">settings</a>,' ...
      '<a href="matlab:disp(' iname ');">more...</a>)' ];
  end
  
  if length(s_in) == 0
      d = [ d sprintf(' %s: empty\n',id) ];
  elseif length(s_in) >= 1
    % print header lines
    if length(s_in) == 1
      d = [ d sprintf(' %s:\n\n', id) ];
    else
      d = [ d id sprintf(' array [%s]',num2str(size(s_in))) sprintf('\n') ];
    end
    if length(s_in) > 1
      d = [ d sprintf('Index ') ];
    end
    %                  IDLE Sony Corporation ILCE-5100  [port: auto] 
    d = [ d sprintf('[Status] [Camera]\n') ];

    % now build the output string using char method
    d = [ d char(s_in) sprintf('\n') ];
  end

  if nargout == 0
    fprintf(1,d);
  end

end
