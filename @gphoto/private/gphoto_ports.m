function [cameras, ports] = gphoto_ports(self)
  % gphoto_ports returns the camera list and the associated ports
  
  cameras={}; ports={};
  [~,message] = gphoto_exec(self, '--auto-detect'); % can not work with shell
  
  t = textscan(message, '%s','Delimiter','\n'); % into lines
  t = t{1};
  if numel(t) < 3, return; end
  
  % read camera lines
  for index=3:numel(t)
    this = t{index};
    cameras{end+1} = strtrim(this(1:29));
    ports{end+1}   = strtrim(this(30:end));
  end
  
end % gphoto_ports

