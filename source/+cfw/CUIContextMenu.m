classdef CUIContextMenu < cfw.CControl
    events
        Callback
    end
    properties
        handle = []
        args = {};
    end
    methods
        function obj=CUIContextMenu(varargin)
            obj = obj@cfw.CControl(varargin{1:min(1,nargin-1)});
            obj.args = varargin(2:end);
        end
        function delete(obj)
            if ~isempty(obj.handle) && ishandle(obj.handle), delete(obj.handle); end
        end
        function placeControl(obj)
            % uicontextmenu always has a figure as parent
            obj.handle = uicontextmenu('parent',obj.getWindow.hfigure,obj.args{:});
            
            % Detect if there is already a callback defined (e.g.
            % when placed on a uibuttongroup, or user defined through args)
            if isempty(get(obj.handle,'Callback'))
                set(obj.handle,'Callback',@obj.cb_callback);
            end
        end
        function set(obj,varargin)
            set(obj.handle,varargin{:});
        end
        function value = get(obj,name)
            value = get(obj.handle,name);
        end
        function cb_callback(obj,src,evt)
            notify(obj,'Callback');
        end
    end
end     