classdef CUITableOld < cfw.CControl
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
    end 
    methods
        function obj = CUITableOld(varargin)
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
            % Explicitly get the figure handle for the old uitable
            obj.ignoredatachanged = true;
            warning off MATLAB:uitable:OldTableUsage
            if isempty(obj.data)
                obj.privatecolumnnames = {};
                obj.handle = uitable(obj.getWindow.hfigure,{'1','2','3'},{'1','2','3'});
                set(obj.handle,'NumColumns',0,'NumRows',0);
            else
                tcols = num2cell(char('A'-1+(1:size(obj.data,2))));
                tcols(1:length(obj.privatecolumnnames)) = obj.privatecolumnnames(1:length(obj.privatecolumnnames));
                obj.privatecolumnnames = tcols;
                obj.handle = uitable(obj.getWindow.hfigure,obj.columnnames,obj.data);
            end
            set(obj.handle,'DataChangedCallback',@obj.cb_datachanged);
            drawnow; % Force datacanged callback to be executed before we set ignoredatachanged back to false
            obj.ignoredatachanged = false;
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
            % Explicitly set the number of columns, and recreate the data
            if iscell(value) && size(value,1)<=1;
                obj.privatecolumnnames = value;

                if ~isempty(obj.handle) && ishandle(obj.handle)
                    obj.ignoredatachanged = true;
                    set(obj.handle,'NumColumns',length(value));
                    set(obj.handle,'ColumnNames',value);
                    drawnow; % Force datacanged callback to be executed before we set ignoredatachanged back to false
                    obj.ignoredatachanged = false;
                end
            else
                throw(MException('CUITable:set_columnnames','Columnnames must be a cell array'));
            end
        end
        function value = get.columnnames(obj)
            if ~isempty(obj.handle) && ishandle(obj.handle)
                value = cell(get(obj.handle,'columnnames'));
            else
                value = obj.privatecolumnnames;
            end
        end
        function set.data(obj,value)
            obj.privatedata = value;
            if ~isempty(obj.handle) && ishandle(obj.handle)
                obj.ignoredatachanged = true;
                cols = size(value,2);
                rows = size(value,1);
                newdata = repmat({[]},max(rows,2),max(cols,2));
                newdata(1:rows,1:cols) = value;
                
                % Make columnnames consistent
                tcols = num2cell(char('A'-1+(1:size(newdata,2))));
                tcols(1:length(obj.privatecolumnnames)) = obj.privatecolumnnames(1:length(obj.privatecolumnnames));
                obj.privatecolumnnames = tcols;
                
                set(obj.handle,'data',newdata,'columnnames',tcols);
                set(obj.handle,'NumRows',rows,'NumColumns',cols);
                drawnow; % Force datacanged callback to be executed before we set ignoredatachanged back to false
                obj.ignoredatachanged = false;
            end
        end
        function value = get.data(obj)
            if ~isempty(obj.handle) && ishandle(obj.handle)
                value = cell(get(obj.handle,'data'));
            else
                value = obj.privatedata;
            end
        end
        function cb_datachanged(obj,tableojb,eventobj)
            if ~obj.ignoredatachanged
                e = get(eventobj,'Event');
                row = get(e,'FirstRow')+1;
                col = get(e,'Column')+1;
                if row>0 && col>0
                    olddata = [];
                    if all([row,col]<=size(obj.privatedata))
                        olddata = obj.privatedata{row,col};
                    end
                    newdata = obj.data{row,col};
                    obj.privatedata{row,col} = newdata;
                    fprintf('Data changed in (%d,%d): %s --> %s\n',row,col,olddata,newdata);
                    notify(obj,'DataChanged',cfw.CUITableDataChangedEventData(row,col,olddata,newdata));
                end
            end
        end
    end
end