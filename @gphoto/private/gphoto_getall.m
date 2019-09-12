function gphoto_getall(self)
  % gphoto_getall get all configuration values
  
  self.proc.stdout = '';
  write(self.proc, sprintf('list-config\n'));
  self.expect{end+1} = { 'post_getconfig', self};

end % gphoto_getall
