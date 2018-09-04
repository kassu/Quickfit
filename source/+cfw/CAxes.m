classdef CAxes < cfw.CHGraphics
    properties
        positionmode = 'position'; % Can be either position (default), outerposition or tightinset
    end
    methods
        function obj=CAxes(varargin)
            obj = obj@cfw.CHGraphics(varargin{:});
        end
        function placeControl(obj)
            obj.handle = axes('parent',obj.getContainerHandle,obj.args{:});
        end
        function resize(obj,units,position)
            % Depending on the positiomode property, the size of the axes
            % is either defined by its position (the black line of te
            % axes), its outerposition (a symmetric border around the axes
            % that leaves a lot of space), or its position taking tighinset
            % into account. The latter uses the smallest box that fits
            % around the axes including all labels etc.
            % Note: if you use tightinset, you should explicitly call
            % resize whenever the plot labels/xlim/ylim/etc change.
            resize@cfw.CControl(obj,units,position);
            if ~isempty(obj.handle) && ishandle(obj.handle)
                if strcmpi(obj.positionmode,'outerposition')
                    set(obj.handle,'units',units,'outerposition',obj.makeAbsPosition(units,position));
                elseif strcmpi(obj.positionmode,'tightinset')
                    set(obj.handle,'units',units);
                    ti = get(obj.handle,'tightinset');
                    pos = obj.makeAbsPosition(units,position);
                    set(obj.handle,'position',[pos(1:2) + ti(1:2), pos(3:4) - ti(1:2) - ti(3:4)]);
                else
                    set(obj.handle,'units',units,'position',obj.makeAbsPosition(units,position));
                end
            end
        end
    end
end     