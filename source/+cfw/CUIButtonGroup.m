classdef CUIButtonGroup < cfw.CHGraphics
    events
        SelectionChanged
    end
    methods
        function obj=CUIButtonGroup(varargin)
            obj = obj@cfw.CHGraphics(varargin{:});
        end
        function placeControl(obj)
            % Because we override getContainerHandle, we must explicitly
            % get the parent handle from our parent object
            if ~isempty(obj.parent) && isa(obj.parent,'cfw.CControl')
                obj.handle = uibuttongroup('parent',obj.parent.getContainerHandle,obj.args{:});
            else
                obj.handle = uibuttongroup('parent',obj.getWindow.hfigure,obj.args{:});
            end
            set(obj.handle,'SelectionChangeFcn',@obj.cb_selectionchanged);
        end
        function cb_selectionchanged(obj,src,evt)
            [ov,nv] = findcontrols(obj,evt.OldValue,evt.NewValue);
            notify(obj,'SelectionChanged',cfw.CUIButtonGroupSelectionChangedEventData(ov,nv));
            function [ov,nv] = findcontrols(obj,ovtarget,nvtarget)
                ov = [];
                nv = [];
                for i=1:length(obj.children)
                    % First recurse
                    [tov,tnv] = findcontrols(obj.children{i},ovtarget,nvtarget);
                    if ~isempty(tov), ov = tov; end
                    if ~isempty(tnv), nv = tnv; end
                    % Then look in our own children
                    if isa(obj.children{i},'cfw.CHGraphics')
                        if obj.children{i}.handle == ovtarget
                            ov = obj.children{i};
                        end
                        if obj.children{i}.handle == nvtarget
                            nv = obj.children{i};
                        end
                    end
                end
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