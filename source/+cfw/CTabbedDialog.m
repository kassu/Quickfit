classdef CTabbedDialog < cfw.CControl
    properties
        currenttab
    end
    properties (SetAccess = protected)
        tabnames = {};
        tabs;
    end
    properties (Access= protected)
        grid;
        buttons;
        tbbImages = {};
    end
    events
        TabChanged
    end
    methods
        function obj=CTabbedDialog(varargin)
            obj = obj@cfw.CControl(varargin{1:min(1,nargin-1)});
            obj.tabnames = varargin(2:end);
            if nargin<2
                error('CTabbedDialog: at least one tab is required.');
            end
        end
        function delete(obj)
            delete@cfw.CControl(obj);
            
            obj.tabs = []; obj.grid = []; obj.buttons = [];
        end
        function placeControl(obj)
            % Strategy: We add the grid control as a chil of ourselves,
            % such that the parent/children tree of all controls still
            % tracks all the way back to the window. This means however,
            % that creating a tab control adds controls to the tree that
            % the end user hasn't asked for, and that may be confusing. 
            
            % Create a grid
            obj.grid = obj.addChild(cfw.CGridLayout([]));
            pxcell = cellfun(@(x)'pixels', obj.tabnames, 'uniformoutput',false);
            obj.grid.setColumns([pxcell {'normalized'}], [80*ones(1,length(obj.tabnames)) 1]);
            obj.grid.setRows({'normalized','pixels'},[1 29]);
            obj.grid.margin = [0 0 0 0];
            
            % Create button and tab controls that reside within this
            dy = 30/29 - 1;
            for i = 1:length(obj.tabnames)
                buttons(i) = obj.grid.addChild(cfw.CUIControl([0 -dy 1 1+dy],'style','pushbutton','String',obj.tabnames{i}),[2 i]);
                addlistener(buttons(i), 'Callback', @obj.cb_tab_callback);
                tabs(i) = obj.grid.addChild(cfw.CUIPanel([],'bordertype','beveledout','visible','off'),[1 1],[1 length(obj.tabnames)+1]);
            end
            obj.buttons =buttons;
            obj.tabs = tabs;
            
            % Tabbed dialog button images
            bcol = obj.tabs(1).get('BackgroundColor');
            obj.tbbImages{1} = repmat(reshape(bcol,[1 1 3]), [30 80 1]);
            obj.tbbImages{1}(1:2,:,:) = 1; obj.tbbImages{1}(:,2:3,:) = 1;
            obj.tbbImages{1}(2:end,end-1,:) = 0.75;
            obj.tbbImages{1}(1:end-1,end,:) = 0.5;
            
            obj.tbbImages{2} = repmat(reshape(bcol,[1 1 3]), [30 80 1]);
            for y = 5:29;
                obj.tbbImages{2}(y,2:end,:) = (1-y/30/10)*mean(bcol);
            end
            obj.tbbImages{2}(4,:,:) = 1; obj.tbbImages{2}(4:end,1,:) = 1; 
            obj.tbbImages{2}(4:end,end,:) = 0.5; obj.tbbImages{2}(end,:,:) = 1;
            
            obj.currenttab =1 ;
            obj.buttons(1).set('CData',obj.tbbImages{1});
            obj.tabs(1).set('Visible','on');
            for i= 2:length(obj.tabnames)
                obj.buttons(i).set('CData',obj.tbbImages{2});
            end
        end
        
        
        function resize(obj,units,position)
            % Call super's resize
            resize@cfw.CControl(obj,units,position);
            
            % Resize grid, which in turn resizes the buttons and panels
            obj.grid.resize(units,position);
        end    
        
        function cb_tab_callback(obj,source,event)
            
            oldtab = obj.currenttab;
            for i = 1:length(obj.buttons)
                if source==obj.buttons(i)
                    obj.currenttab = i;
                    break;
                end
            end
            
            obj.buttons(oldtab).set('CData',obj.tbbImages{2});
            source.set('CData', obj.tbbImages{1});
            obj.tabs(oldtab).set('Visible','off');
            obj.tabs(obj.currenttab).set('Visible','on');
            
            notify(obj,'TabChanged',cfw.CTabbedDialogTabChanged(oldtab, obj.currenttab));
        end
    end
end