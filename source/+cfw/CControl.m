classdef CControl < handle
    properties
        parent = [];                % The parent is [] or another CControl (derived) object
        children = {};              % All children CControls of this control
        childprops = [];            % Structure array for storing properties. For use by derived classes
        units = 'normalized';       % Units (currently always normalized)
        position = [0 0 1 1];       % Position within container
        absunits = 'pixels';        % Units for keeping track of the absolute position
        absposition = [0 0 10 10];    % Absolute position within container. 
        minsize = [10 10];
        minsizeunits = 'pixels';
        tag;                        % For use by the user
    end
    properties (Access=private)
        privatewindow = [];
    end
    methods
        %%%%%%%%%%%%%% Constructor
        function obj = CControl(myposition)
            if nargin>0 && ~isempty(myposition)
                obj.position = myposition;
            end
        end
        function delete(obj)
            for i=1:length(obj.children)
                if ~isempty(obj.children{i}) && isvalid(obj.children{i}), delete(obj.children{i}); end;
            end
            obj.parent = [];
        end
        function placeControl(obj)
            % This function is called by addChild after the
            % parent/child/window relationships have been properly set up.
        end
        %%%%%%%%%%%%%%% Parent/child hierarchy
        function h = getContainerHandle(obj)
            % By default, wel drill down just like in getWindow, but here
            % a derived class can stop the chain and provide its own handle
            if ~isempty(obj.parent) && isa(obj.parent,'cfw.CControl')
                h = obj.parent.getContainerHandle;
            else
                % If there is no parent, it must be the window's hfigure
                h = obj.getWindow.hfigure;
            end
        end
        function w = getWindow(obj)
            % If we have a parent, just ask it for the window object. This
            % way, we drill down the hierarchy until we find the window.
            if ~isempty(obj.parent) && isa(obj.parent,'cfw.CControl')
                w = obj.parent.getWindow();
            else
                w = obj.privatewindow;
            end
        end
        function setWindow(obj,value)
            if ~isempty(obj.parent) && isa(obj.parent,'cfw.CControl')
                throw(MException('CControl:set_window', 'Window can only be set explicitly if the object has no parent.'))
            else
                if isa(value,'cfw.CWindow')
                    obj.privatewindow = value;
                else
                    throw(MException('CControl:set_window', 'Window must be a CWindow class'));
                end
            end
        end
        function set.parent(obj,value)
            if isempty(value)
                obj.parent = [];
            elseif isa(value,'cfw.CControl')
                obj.parent = value;
            else
                throw(MException('CControl:set_parent', 'Parent must be empty or a CControl class'));
            end
        end
        function value = addChild(obj,value,varargin)
            if isa(value,'cfw.CControl')
                if isempty(obj.children)
                    obj.children = {value};
                    value.parent = obj;
                    obj.childprops = obj.makeChildProps(value,varargin{:});
                else
                    obj.children(end+1) = {value};
                    value.parent = obj;
                    obj.childprops(end+1) = obj.makeChildProps(value,varargin{:});
                end
                value.placeControl();
            else
                throw(MException('CControl:addChild', 'Child must be a CControl class'));
            end
        end
        function removeChild(obj,value)
            if isa(value,'cfw.CControl')
                tokeep = cellfun(@(x)x~=value,obj.children);
                % Remove parent tags if possible
                for r = find(~tokeep)
                    if isa(obj.children{r},'cfw.CControl')
                        obj.children{r}.parent = [];
                    end
                end
                % Remove from children list
                obj.children = obj.children(tokeep);
                obj.childprops = obj.childprops(tokeep);
            else
                throw(MException('CControl:removeChild', 'Child must be a CControl class'));
            end
        end
        function removeChildren(obj,deletethemfirst)
            % Remove all children. Also delete the objects, if requested.
            for i = 1:length(obj.children)
                if deletethemfirst
                    try
                        delete(obj.children{i});
                    catch
                    end
                else
                    if isa(obj.children{r},'cfw.CControl') && isvalid(obj.children{r})
                        obj.children{r}.parent = [];
                    end
                end
            end
            obj.children = {};
        end
        %%%%%%%%%%%%%%% Child properties initialization
        function p = makeChildProps(obj,childobj,varargin)
            % Derived classes can overwrite this and define a structure
            % with some fields top keep extra information such as
            % positioning.
            p = struct();
        end
        %%%%%%%%%%%%%%% Positioning within parent-defined region
        function set.units(obj,value)
            if ischar(value) && any(strcmpi(value,{'normalized'}))
                obj.units = value;
            else
                throw(MException('CControl:set_units', 'Only normalized units are currently supported.'));
            end
        end
        function set.position(obj,value)
            if isnumeric(value) && isequal(size(value),[1 4])
                obj.position = value;
               % obj.resize(obj.absunits,obj.absposition);
            else
                throw(MException('CControl:set_position', 'Position must be a numeric 1x4 value.'));
            end
        end
        %%%%%%%%%%%%%%% Resize the object
        function resize(obj,units,position,varargin)
            % This function should be overwritten in derived classes
            % The default implementation is rather pointless, and just
            % makes all children the same size
            
            % Keep current units
            obj.absunits = units;
            obj.absposition = position;
            
            % If the fourth argument is true, don't update children
            % position (so the deriving class can do it).
            if nargin <4 || ~varargin{1}
                % Resize children to inner position of this control
                for i = 1:length(obj.children)
                    obj.children{i}.resize(units,obj.makeAbsPosition(units,position));
                end
            end
        end
        function pos = makeAbsPosition(obj,units,position)
            % Calculate internal size in absolute units
            % Note: currently assumes obj.units == 'normalized'
            w = position(3)*obj.position(3);
            h = position(4)*obj.position(4);
            x = position(1) + position(3)*obj.position(1);
            y = position(2) + position(4)*obj.position(2);
            pos = [x y w h];
        end
	end
end