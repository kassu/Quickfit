classdef CUIPanel < cfw.CHGraphics
    events
        
    end
    methods
        function obj=CUIPanel(varargin)
            obj = obj@cfw.CHGraphics(varargin{:});
        end
        function placeControl(obj)
            % Because we override getContainerHandle, we must explicitly
            % get the parent handle from our parent object
            if ~isempty(obj.parent) && isa(obj.parent,'cfw.CControl')
                obj.handle = uipanel('parent',obj.parent.getContainerHandle,obj.args{:});
            else
                obj.handle = uipanel('parent',obj.getWindow.hfigure,obj.args{:});
            end
        end
        function h = getContainerHandle(obj)
            % To become a container, we override this function and simply
            % return the uibuttongroup handle
            h = obj.handle;
        end
        function resize(obj,units,position)
            % Call super's resize, but don't let it resize the controls
            resize@cfw.CControl(obj,units,position,true);
            
            % Resize myself
            if ~isempty(obj.handle) && ishandle(obj.handle)
                set(obj.handle,'units',units,'position',obj.makeAbsPosition(units,position));
            end
            
            % Make all children fill our full area (having more than one
            % child here is probably pointless, but that's not our problem)
            old_units = get(obj.handle,'Units');
            set(obj.handle,'Units','pixels');
            p = get(obj.handle,'Position');
            for i = 1:length(obj.children)
                obj.children{i}.resize('pixels',[1 1 p(3)-2 p(4)-2]);
            end
            set(obj.handle,'Units',old_units);
        end    
    end
end