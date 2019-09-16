function h=plot(self)
  % PLOT plot the last image/preview.
  
  % get the figure handle
  h = findall(0, 'Tag', [ class(self) '_figure' ]);
  if isempty(h) % build the plot window
    h = figure('Tag', [ class(self) '_figure' ], 'Name', class(self), 'MenuBar','none');
    set(h, 'Units','normalized');
    
    % File menu
    m = uimenu(h, 'Label', 'File');
    uimenu(m, 'Label', 'Save',        ...
      'Callback', 'filemenufcn(gcbf,''FileSave'')','Accelerator','s');
    uimenu(m, 'Label', 'Save As...',        ...
      'Callback', 'filemenufcn(gcbf,''FileSaveAs'')');
    uimenu(m, 'Label', 'Print',        ...
      'Callback', 'filemenufcn(gcbf,''FilePrintPreview'')','Accelerator','p');
    % ---------------------
    uimenu(m, 'Label', 'Close',        ...
      'Callback', 'filemenufcn(gcbf,''FileClose'')', ...
      'Accelerator','w', 'Separator','on');
    
    % Camera menu
    m0 = uimenu(h, 'Label', 'Camera');
    uimenu(m0, 'Label', 'Capture image', ...
      'Callback', @(src,evt)image(self), 'Accelerator','c');
    uimenu(m0, 'Label', 'Capture preview', ...
      'Callback', @(src,evt)preview(self));
    uimenu(m0, 'Label', 'Toggle continuous capture (time-lapse)', ...
      'Callback', @(src,evt)continuous(self), 'Tag', [ class(self) '_continuous' ]);
    
    % ---------------------
    uimenu(m0, 'Label', 'Change settings...', ...
      'Callback', @(src,evt)set(self), 'Separator','on');
    uimenu(m0, 'Label', 'Update all settings', ...
      'Callback', @(src,evt)get(self,'all'));
    uimenu(m0, 'Label', 'Speficy directory for storage...', ...
      'Callback', @(src,evt)cd(self,'gui'));
    uimenu(m0, 'Label', 'Speficy liveview/continuous rate...', ...
      'Callback', @(src,evt)period(self,'gui'));
    uimenu(m0, 'Label', 'Toggle line display', ...
      'Callback', @(src,evt)grid(self));
    
    % ---------------------
    uimenu(m0, 'Label', [ 'About camera and ' class(self) ], ...
      'Callback', @(src,evt)about(self), 'Separator','on');
      
    self.image_axes = gca; % initiate an empty axes
    set(self.image_axes, 'Units','normalized','Position',[0.1 0.11 0.8 0.8]);
      
    % we add a button for capture
    m0 = uicontrol('Style', 'pushbutton', 'String', 'Capture',...
      'Units','normalized','Position',[ 0 0 0.2 0.1 ], ...
      'Callback', @(src,evt)image(self),'BackgroundColor','r');
    % add a small axes to display focus history
    self.focus_axes = axes('position', [0.7 0.01 0.2 0.08]);
    set(self.focus_axes, 'Tag', [ class(self) '_focus_axes' ]);
  end

end % plot
