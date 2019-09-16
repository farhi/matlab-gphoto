function disp(s_in, name)
  % DISP display GPhoto object (details)

  if nargin == 2 && ~isempty(name)
    iname = name;
  elseif ~isempty(inputname(1))
    iname = inputname(1);
  else
    iname = 'ans';
  end
   
  if length(s_in) > 1
    display(s_in, iname);
  else

    if isdeployed || ~usejava('jvm'), id=class(s_in);
    else           id=[ '<a href="matlab:doc gphoto">gphoto</a> ' ...
      '(<a href="matlab:methods gphoto">methods</a>,' ...
      '<a href="matlab:image(' iname ')">capture</a>,' ...
      '<a href="matlab:plot(' iname ')">plot</a>,' ...
      '<a href="matlab:disp(char(' iname ',''long''));set(' iname ');">settings</a>)' ];
    end

    fprintf(1,'%s = %s object %s:\n',iname, id, strtrim(char(s_in)));
  end
  builtin('disp', s_in);

end % disp
