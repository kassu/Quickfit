classdef CUIControl < cfw.CHGraphics
    events
        Callback
    end
    methods
        function obj=CUIControl(varargin)
            obj = obj@cfw.CHGraphics(varargin{:});
        end
        function placeControl(obj)
            obj.handle = uicontrol('parent',obj.getContainerHandle,obj.args{:});
            
            % Detect if there is already a callback defined (e.g.
            % when placed on a uibuttongroup, or user defined through args)
            if isempty(get(obj.handle,'Callback'))
                set(obj.handle,'Callback',@obj.cb_callback);
            end
            
            % Some controls should just be white
            if any(strcmpi(get(obj.handle,'style'),{'edit','popupmenu'}))
                set(obj.handle,'backgroundcolor','white');
            end
        end
        function cb_callback(obj,src,evt)
            notify(obj,'Callback');
        end
    end
end     