classdef CUITable < cfw.CControl
    properties
        handle = []
        args = {};
    end 
    properties (Dependent)
        columnnames
        data
    end
    properties (Access = private)
        ignoredatachanged = false;
        privatedata = {};
        privatecolumnnames = {};
    end
    events
        DataChanged
        CellSelect
    end 
    methods
        function obj = CUITable(varargin)
            obj = obj@cfw.CControl(varargin{1:min(1,nargin-1)});
            obj.args = varargin(2:end);
        end
        function delete(obj)
            try
                delete(obj.handle);
            catch e
            end
        end
        function placeControl(obj)
            obj.handle = uitable(obj.getContainerHandle,obj.args{:});
            set(obj.handle,'CellEditCallback',@obj.cb_celledit);
            set(obj.handle,'CellSelectionCallback',@obj.cb_cellselect);
            %             % Explicitly get the figure handle for the old uitable
%             obj.ignoredatachanged = true;
%             warning off MATLAB:uitable:OldTableUsage
%             if isempty(obj.data)
%                 obj.privatecolumnnames = {};
%                 obj.handle = uitable(obj.getWindow.hfigure,{'1','2','3'},{'1','2','3'});
%                 set(obj.handle,'NumColumns',0,'NumRows',0);
%             else
%                 tcols = num2cell(char('A'-1+(1:size(obj.data,2))));
%                 tcols(1:length(obj.privatecolumnnames)) = obj.privatecolumnnames(1:length(obj.privatecolumnnames));
%                 obj.privatecolumnnames = tcols;
%                 obj.handle = uitable(obj.getWindow.hfigure,obj.columnnames,obj.data);
%             end
%             set(obj.handle,'DataChangedCallback',@obj.cb_datachanged);
%             drawnow; % Force datacanged callback to be executed before we set ignoredatachanged back to false
%             obj.ignoredatachanged = false;
        end
        function set(obj,name,value)
            set(obj.handle,name,value);
        end
        function value = get(obj,name)
            value = get(obj.handle,name);
        end
        function resize(obj,units,position)
            resize@cfw.CControl(obj,units,position);
            if ~isempty(obj.handle) && ishandle(obj.handle)
                set(obj.handle,'units',units,'position',obj.makeAbsPosition(units,position));
            end
        end
        function set.columnnames(obj,value)
            set(obj.handle,'ColumnName',value);
        end
        function value = get.columnnames(obj)
            value = get(obj.handle,'columnnames');
        end
        function set.data(obj,value)
            set(obj.handle,'Data',value);
        end
        function value = get.data(obj)
            value = get(obj.handle,'data');
        end
        function cb_celledit(obj,tableojb,event)
            if ~isempty(event.Indices)
                notify(obj,'DataChanged',cfw.CUITableDataChangedEventData(event.Indices(1),event.Indices(2),event.PreviousData,event.NewData));
            end
        end
        function cb_cellselect(obj,tableojb,event)
            if ~isempty(event.Indices)
                notify(obj,'CellSelect',cfw.CUITableCellSelectEventData(event.Indices(1),event.Indices(2)));
            end
        end    
    end
end