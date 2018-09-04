% CHGraphics - base class for handle graphics object wrappers, such as for
% CUIControl and CAxes.
% On it's own, this class doesn't create any object
classdef CHGraphics < cfw.CControl
    properties
        handle = []
        args = {};
    end
    methods
        function obj = CHGraphics(varargin)
            obj = obj@cfw.CControl(varargin{1:min(1,nargin-1)});
            obj.args = varargin(2:end);
        end
        function delete(obj)
            if ~isempty(obj.handle) && ishandle(obj.handle), delete(obj.handle); end
        end
%         function placeControl(obj)
%             % Override this function in a derived class
%         end
        function set(obj,varargin)
            set(obj.handle,varargin{:});
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
    end
end